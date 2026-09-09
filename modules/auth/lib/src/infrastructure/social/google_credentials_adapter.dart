import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import '../../application/ports/social_credentials_port.dart';

/// Google implementation of [SocialCredentialsPort].
///
/// [serverClientId] is the OAuth **web** client id. It is what makes the flow
/// work at all: Android returns a null `idToken` without it, and it pins the
/// token's `aud` to a single value on every platform so the API can validate
/// against one configured audience.
class GoogleCredentialsAdapter implements SocialCredentialsPort {
  const GoogleCredentialsAdapter({
    required this.serverClientId,
    this.iosClientId = '',
  });

  final String serverClientId;

  /// iOS needs its own platform client alongside the server one. On Android the
  /// platform client is matched by package name + signing SHA-1 instead.
  final String iosClientId;

  @override
  Future<SocialCredentialsResult> obtain() async {
    try {
      final signIn = GoogleSignIn(
        serverClientId: serverClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isNotEmpty ? iosClientId : null,
      );
      final account = await signIn.signIn();
      if (account == null) return const SocialCredentialsCancelled();

      final idToken = (await account.authentication).idToken;
      if (idToken == null) return const SocialCredentialsFailure(missingToken: true);

      final (given, family) = _splitDisplayName(account.displayName);
      return SocialCredentials(
        idToken: idToken,
        email: account.email,
        givenName: given,
        familyName: family,
      );
    } catch (_) {
      return const SocialCredentialsFailure();
    }
  }

  /// Google exposes one `displayName`, not separate name parts. Split on the
  /// first space so the common "Given Family" case prefills both fields; a
  /// single-word name fills only the first.
  static (String?, String?) _splitDisplayName(String? displayName) {
    final name = displayName?.trim() ?? '';
    if (name.isEmpty) return (null, null);
    final space = name.indexOf(' ');
    if (space < 0) return (name, null);
    return (name.substring(0, space), name.substring(space + 1).trim());
  }
}
