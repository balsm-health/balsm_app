import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'deep_links.dart';
import 'routes.dart';
import 'screens/auth_flow.dart';
import 'screens/care_team_screen.dart';
import 'screens/personal_details.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_subscreens.dart';
import 'screens/report_flow.dart';

/// A link opened the app. Counted for every inbound link, including the ones
/// this build does not route — see [deepLinkKind].
const kDeepLinkOpened = 'deep_link_opened';

/// Constant telemetry label for an inbound link. Never any part of the URI: the
/// magic-link token is a query param and the emergency-QR AES key is the
/// fragment, so the URI itself must not reach a prop.
String deepLinkKind(Uri uri) => parseDeepLink(uri)?.kind ?? 'other';

/// The app's single link subscription, for the life of the process.
///
/// Not per-widget, because app_links cannot be subscribed per-widget: it
/// delivers over one EventChannel whose native side keeps a single sink. When
/// [DeepLinkHandler] was re-created, the old State's `dispose` cancelled the
/// channel — clearing the sink the NEW State depended on — and live link
/// delivery silently stopped. (It looked like it worked because each new State
/// also re-read `getInitialLink()`, which on iOS returns the first link ever
/// received, so old links kept replaying: a device test caught every tab link
/// being yanked back to an earlier `/map` link.) The re-creation itself came
/// from Flutter's built-in deep linking pushing a second shell per link, now
/// switched off in Info.plist and AndroidManifest.xml — but any remount (hot
/// restart, a keyed ancestor) must still keep delivery intact.
///
/// So: subscribe and read the launch link exactly once, and hand each link to
/// whichever handler is attached — queueing any that arrive while none is.
@visibleForTesting
class DeepLinkInbox {
  DeepLinkInbox._(Stream<Uri> links, Future<Uri?> launchLink) {
    links.listen(_deliver, onError: (_) {});
    unawaited(launchLink.then((uri) {
      if (uri != null) _deliver(uri);
    }));
  }

  static DeepLinkInbox? _instance;

  static DeepLinkInbox get instance {
    final links = AppLinks();
    return _instance ??= DeepLinkInbox._(links.uriLinkStream, links.getInitialLink());
  }

  /// Builds an inbox over arbitrary sources, for tests.
  @visibleForTesting
  factory DeepLinkInbox.forTest(Stream<Uri> links, {Future<Uri?>? launchLink}) =>
      DeepLinkInbox._(links, launchLink ?? Future.value());

  final _queue = <Uri>[];
  void Function(Uri)? _sink;
  Uri? _lastUri;
  DateTime? _lastAt;

  void _deliver(Uri uri) {
    // On iOS a cold-start link arrives twice — once from getInitialLink and
    // once replayed by the plugin when the stream is first listened to. A link
    // identical to the previous one within two seconds is that echo; the same
    // link tapped again later is a real open and still goes through.
    final now = DateTime.now();
    if (uri == _lastUri && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 2)) return;
    _lastUri = uri;
    _lastAt = now;
    final sink = _sink;
    if (sink == null) {
      _queue.add(uri);
    } else {
      sink(uri);
    }
  }

  /// Makes [sink] the receiver, and flushes anything that arrived meanwhile.
  void attach(void Function(Uri) sink) {
    _sink = sink;
    final queued = List.of(_queue);
    _queue.clear();
    queued.forEach(sink);
  }

  /// Detaches [sink] — only if it is still the receiver. A re-created handler
  /// attaches before the old one is disposed, and must not be detached by it.
  void detach(void Function(Uri) sink) {
    if (_sink == sink) _sink = null;
  }
}

/// Routes inbound links — App Links, Universal Links and the `balsm://` scheme —
/// to their destination. The route table is `deep_links.dart`; this widget only
/// carries each decision out.
///
/// - Public destinations (profile QR, account deletion, magic sign-in) open
///   immediately, signed in or not.
/// - Destinations inside the signed-in shell are held while the patient is
///   signed out and applied the moment they reach the shell, so a link is never
///   silently dropped at the sign-in screen.
///
/// Handles both the cold-start link and links delivered while running. Sits
/// under the Navigator and [AppScope], so it can push screens itself.
class DeepLinkHandler extends ConsumerStatefulWidget {
  const DeepLinkHandler({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends ConsumerState<DeepLinkHandler> {
  bool _handling = false;

  /// A signed-in destination that arrived while signed out. Applied once the
  /// shell route becomes [AppRoutes.app]; the newest link wins.
  DeepLinkTarget? _pending;

  @override
  void initState() {
    super.initState();
    // Cold-start and live links both arrive through the process-wide inbox.
    DeepLinkInbox.instance.attach(_onUri);
  }

  @override
  void dispose() {
    DeepLinkInbox.instance.detach(_onUri);
    super.dispose();
  }

  /// Carries the link's own `utm_*` (last touch, this open only) next to the
  /// constant kind. `campaignPropertiesFrom` reads just the seven allowlisted
  /// campaign params off the query — never `t`, never the fragment.
  void _logOpen(Uri uri, String kind, String result) => ref.read(analyticsLoggerProvider).logEvent(
        kDeepLinkOpened,
        props: {'source': kind, 'result': result, ...campaignPropertiesFrom(uri)},
      );

  Future<void> _onUri(Uri uri) async {
    // A link can be the first campaign this install ever saw (an organic
    // install, later re-engaged by a campaign email). Record it as first touch
    // if nothing is recorded yet; a no-op otherwise. It reaches the `initial_*`
    // super properties on the next launch — they are registered once at boot.
    unawaited(CampaignAttribution.resolve(ref.read(globalKVDataSourceProvider), launchUri: uri));

    final target = parseDeepLink(uri);
    if (target == null) return; // the bare app root — not a deep link
    final kind = target.kind;

    // Web: `app_links` reports the browser URL as the initial link, and the
    // shell has already rendered these public pages in place of the app (see
    // `_PatientAppState.initState`). Pushing them again would stack a duplicate.
    if (kIsWeb &&
        (target is EmergencyCardTarget || target is DeleteAccountTarget || target is DeleteAccountCancelTarget)) {
      _logOpen(uri, kind, 'ok');
      return;
    }

    switch (target) {
      case MagicLinkTarget(:final token):
        await _redeemMagicLink(uri, kind, token);
      case EmergencyCardTarget(:final tokenId, :final key):
        _logOpen(uri, kind, 'ok');
        pushSubScreen(context, (_) => PublicEmergencyResolveScreen(tokenId: tokenId, keyOverride: key));
      case DeleteAccountTarget():
        _logOpen(uri, kind, 'ok');
        pushSubScreen(context, (_) => const PublicDeleteScreen());
      case DeleteAccountCancelTarget():
        _logOpen(uri, kind, 'ok');
        pushSubScreen(context, (_) => const PublicDeleteCancelledScreen());
      case TabTarget() || MapTarget() || ScreenTarget():
        if (ref.read(patientAppStateProvider).route == AppRoutes.app) {
          _logOpen(uri, kind, 'ok');
          _applyInShell(target);
        } else {
          // Held, not dropped: applied after sign-in by the listener in build.
          _logOpen(uri, kind, 'deferred');
          _pending = target;
        }
      case UnknownTarget():
        _logOpen(uri, kind, 'ignored');
    }
  }

  /// Opens a destination inside the signed-in shell. Pushed screens pop back to
  /// the tab they came from, exactly as when opened by hand.
  void _applyInShell(DeepLinkTarget target) {
    switch (target) {
      case TabTarget(:final tab):
        AppScope.of(context).setTab(tab);
      case MapTarget(:final types):
        AppScope.of(context).openMap(types: types);
      case ScreenTarget(:final screen):
        switch (screen) {
          case AppScreen.medicalProfile:
            openMedicalProfile(context);
          case AppScreen.privacy:
            openPrivacyData(context, onDeleteAccount: () => openAccountDeletion(context));
          case AppScreen.emergencyNumbers:
            openEmergency(context);
          case AppScreen.careTeam:
            openCareTeam(context);
          case AppScreen.personalDetails:
            openPersonalDetails(context);
          case AppScreen.checkIn:
            openCheckin(context);
        }
      default:
        break;
    }
  }

  /// Exchanges the single-use token for a session. [token] is null when the
  /// link arrived truncated (some mail clients cut long query strings).
  Future<void> _redeemMagicLink(Uri uri, String kind, String? token) async {
    if (token == null) {
      _logOpen(uri, kind, 'malformed');
      return;
    }
    // Re-delivery of a link already being redeemed is not a new open.
    if (_handling) return;

    _handling = true;
    final s = AppScope.of(context);
    final result = await ref.read(signInUseCaseProvider).verifyMagicLink(token: token);
    if (!mounted) {
      _handling = false;
      return;
    }
    result.fold(
      (_) {
        _logOpen(uri, kind, 'ok');
        unawaited(enterAfterSignIn(context, ref, s));
      },
      (failure) {
        // A single-use token that was already spent, or expired — the most
        // common real failure, and worth a number rather than only a snackbar.
        _logOpen(uri, kind, 'failed');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
    _handling = false;
  }

  @override
  Widget build(BuildContext context) {
    // Apply a held destination the moment the patient reaches the shell —
    // after sign-in, after the disclosure gate, after a restored session boots.
    ref.listen(patientAppStateProvider, (_, state) {
      final pending = _pending;
      if (pending == null || state.route != AppRoutes.app) return;
      _pending = null;
      // After this frame: the shell has to be built before a tab switch shows
      // or a pushed screen has a route under it to pop back to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyInShell(pending);
      });
    });
    return widget.child;
  }
}
