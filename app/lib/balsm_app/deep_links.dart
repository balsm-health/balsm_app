/// The app's deep-link route table: turns a URL into a destination plus its
/// arguments.
///
/// One parser for every entry point, so a path means the same thing wherever it
/// arrives:
/// - Android App Links / iOS Universal Links — `https://app.balsm.health/<path>`
/// - the custom scheme — `balsm://<path>` (no domain verification; QA, email
///   clients that rewrite https, and the magic sign-in redirect)
/// - the Flutter web shell — `Uri.base` at boot
///
/// No widgets and no navigation here: routing is decided here and tested here;
/// `DeepLinkHandler` only carries the decision out.
///
/// The host is deliberately NOT checked. Which hosts can reach the app at all is
/// decided by the OS — the Android intent-filters and the iOS associated
/// domains, each verified against the files in `app/web/.well-known/` — and on
/// web the page is already on its own origin. Re-checking here would only break
/// staging and localhost.
library;

import 'care/care_entity.dart';
import 'routes.dart';

/// Where a link leads. Each target carries its own arguments.
sealed class DeepLinkTarget {
  const DeepLinkTarget();

  /// Constant telemetry label — never any part of the URL (see
  /// `deep_link_handler.dart`).
  String get kind;

  /// Whether the destination needs a signed-in session. A signed-out patient's
  /// link is held and applied after sign-in instead of being dropped.
  bool get requiresSession;
}

/// A scanned profile QR: `/t/{jti}#k={key}` (legacy `/emergency/{jti}#k=…`).
/// Public by design — the person scanning is a first responder, not the owner.
final class EmergencyCardTarget extends DeepLinkTarget {
  const EmergencyCardTarget({required this.tokenId, required this.key});

  /// The token id — the path segment.
  final String tokenId;

  /// The AES key from the `#k=` fragment. Null when the link lost its fragment
  /// (some scanners and chat apps strip it); the resolve screen then says so
  /// rather than showing ciphertext.
  final String? key;

  @override
  String get kind => 'emergency_card';

  @override
  bool get requiresSession => false;
}

/// Session-less account deletion (`/delete-account`) — the URL filed with Google
/// Play's data-deletion form, so it must work for someone without an account.
final class DeleteAccountTarget extends DeepLinkTarget {
  const DeleteAccountTarget();

  @override
  String get kind => 'account_delete';

  @override
  bool get requiresSession => false;
}

/// Cancelling a pending deletion (`/delete-account-cancel`), linked from the
/// confirmation email.
final class DeleteAccountCancelTarget extends DeepLinkTarget {
  const DeleteAccountCancelTarget();

  @override
  String get kind => 'account_delete_cancelled';

  @override
  bool get requiresSession => false;
}

/// The emailed magic sign-in link: `/auth/link?t={token}` or
/// `balsm://auth/link?t={token}`. [token] is null when the link is truncated.
final class MagicLinkTarget extends DeepLinkTarget {
  const MagicLinkTarget({required this.token});

  final String? token;

  @override
  String get kind => 'auth_magic_link';

  @override
  bool get requiresSession => false;
}

/// A tab (or tab-routed sub-screen) of the signed-in shell: `/meds`, `/map`, …
final class TabTarget extends DeepLinkTarget {
  const TabTarget(this.tab);

  final AppTab tab;

  @override
  String get kind => 'tab_${tab.id}';

  @override
  bool get requiresSession => true;
}

/// The care map, optionally pre-filtered: `/map?type=pharmacy,lab`.
///
/// [types] empty means "All", exactly as the map's own filter treats an empty
/// selection — so a bare `/map` and a link whose every type was unrecognised
/// both open the unfiltered map rather than an empty one.
final class MapTarget extends DeepLinkTarget {
  const MapTarget({this.types = const {}});

  final Set<CareEntityType> types;

  @override
  String get kind => 'tab_${AppTab.map.id}';

  @override
  bool get requiresSession => true;
}

/// A pushed screen of the signed-in shell: `/profile/privacy`, `/checkin`, …
final class ScreenTarget extends DeepLinkTarget {
  const ScreenTarget(this.screen);

  final AppScreen screen;

  @override
  String get kind => 'screen_${screen.name}';

  @override
  bool get requiresSession => true;
}

/// A link into the app whose path matches nothing in this build. Still counted
/// by telemetry; lands wherever the app already is.
final class UnknownTarget extends DeepLinkTarget {
  const UnknownTarget();

  @override
  String get kind => 'other';

  @override
  bool get requiresSession => false;
}

/// Screens reachable by link that are pushed rather than tab-switched. The
/// [path] is the public contract — renaming one breaks links already sent.
enum AppScreen {
  medicalProfile('profile/medical'),
  privacy('profile/privacy'),
  emergencyNumbers('profile/emergency-numbers'),
  careTeam('profile/care-team'),
  personalDetails('profile/details'),
  checkIn('checkin');

  const AppScreen(this.path);

  /// Path without a leading slash.
  final String path;
}

/// Parses [uri] into a destination, or null when it is not a deep link at all
/// (the bare app root — a normal web load, or a launch with no path).
DeepLinkTarget? parseDeepLink(Uri uri) {
  // Raw segments carry the arguments (a token id is case-sensitive); the
  // lowercased copy is only for matching route names.
  final raw = _segments(uri);
  if (raw.isEmpty) return null;
  final segments = raw.map((s) => s.toLowerCase()).toList(growable: false);
  final path = segments.join('/');

  // Profile QR — `/t/{jti}` and the legacy `/emergency/{jti}` alias.
  if (segments.length == 2 && (segments[0] == PublicQrPaths.token || segments[0] == PublicQrPaths.legacyEmergency)) {
    return EmergencyCardTarget(tokenId: raw[1], key: _fragmentKey(uri));
  }

  switch (path) {
    case PublicQrPaths.deleteAccount:
    // Older emails and the previous Android intent-filter used this shape.
    case 'account/delete':
      return const DeleteAccountTarget();
    case PublicQrPaths.deleteAccountCancel:
    case 'account/delete-cancelled':
      return const DeleteAccountCancelTarget();
    case 'auth/link':
      final token = uri.queryParameters['t'];
      return MagicLinkTarget(token: token == null || token.isEmpty ? null : token);
  }

  if (path == AppTab.map.id) return MapTarget(types: _mapTypes(uri));
  for (final tab in AppTab.values) {
    if (path == tab.id) return TabTarget(tab);
  }
  for (final screen in AppScreen.values) {
    if (path == screen.path) return ScreenTarget(screen);
  }
  return const UnknownTarget();
}

/// Path segments, normalised across URL shapes. For the custom scheme the
/// "host" is really the first path segment — `balsm://auth/link` means
/// `/auth/link` — so it is folded back in. Trailing slashes and empty
/// segments are ignored. Case is preserved; the caller lowercases for matching.
List<String> _segments(Uri uri) {
  final isWeb = uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme.isEmpty;
  return [
    if (!isWeb && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments,
  ].where((s) => s.isNotEmpty).toList(growable: false);
}

/// `k` from a `#k=<key>` fragment. The key is base64url and case-sensitive, so
/// it is read straight from the fragment.
String? _fragmentKey(Uri uri) {
  if (uri.fragment.isEmpty) return null;
  final key = Uri.splitQueryString(uri.fragment)['k'];
  return key == null || key.isEmpty ? null : key;
}

/// Care types from `?type=`. Accepts a comma list and/or repeated params
/// (`type=pharmacy,lab`, `type=pharmacy&type=lab`), case-insensitive, matched
/// against each type's API wire id.
///
/// Exact matching on purpose: `CareEntityType.fromWire` falls back to `clinic`
/// for an unknown value, which would turn a typo in a campaign link into a
/// clinics-only map. Unknown values are dropped instead.
Set<CareEntityType> _mapTypes(Uri uri) {
  final wanted = {
    for (final raw in uri.queryParametersAll['type'] ?? const <String>[])
      for (final part in raw.split(',')) part.trim().toLowerCase(),
  };
  return {
    for (final type in CareEntityType.values)
      if (wanted.contains(type.wire)) type,
  };
}
