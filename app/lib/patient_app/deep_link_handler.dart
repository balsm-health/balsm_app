import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:auth/auth.dart' show signInUseCaseProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'screens/auth_flow.dart' show enterAfterSignIn;

/// Listens for the magic sign-in deep link (`balsm://auth/link?t=<token>`) and
/// redeems it. The emailed https link 302-redirects into this scheme; the token
/// is single-use, so it is exchanged for a session via [signInUseCaseProvider]
/// and — on success — the shared post-sign-in entry runs (disclosure gate →
/// app). Handles both the cold-start initial link and warm-resume stream.
class DeepLinkHandler extends ConsumerStatefulWidget {
  const DeepLinkHandler({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends ConsumerState<DeepLinkHandler> {
  late final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    // Cold start: the link that launched the app (null if launched normally).
    unawaited(_appLinks.getInitialLink().then((uri) {
      if (uri != null) _onUri(uri);
    }));
    // Warm resume: links delivered while the app is already running.
    _sub = _appLinks.uriLinkStream.listen(_onUri, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Extracts the token from `balsm://auth/link?t=…` and redeems it. Other
  /// schemes/paths are ignored.
  Future<void> _onUri(Uri uri) async {
    if (uri.scheme != 'balsm' || uri.host != 'auth' || !uri.path.contains('link')) return;
    final token = uri.queryParameters['t'];
    if (token == null || token.isEmpty || _handling) return;

    _handling = true;
    final s = AppScope.of(context);
    final result = await ref.read(signInUseCaseProvider).verifyMagicLink(token: token);
    if (!mounted) {
      _handling = false;
      return;
    }
    result.fold(
      (_) => unawaited(enterAfterSignIn(context, ref, s)),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
    );
    _handling = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
