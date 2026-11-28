import 'dart:convert';
import 'dart:math';

import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../application/ports/social_credentials_port.dart';

/// A fresh single-use nonce: 32 random bytes, base64url without padding (43
/// chars). Apple gets its SHA-256 ([sha256Hex]); the API gets this raw value.
@visibleForTesting
String generateNonce([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Lowercase hex SHA-256 of [input]'s UTF-8 bytes.
@visibleForTesting
String sha256Hex(String input) {
  final digest = const DartSha256().hashSync(utf8.encode(input));
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Apple implementation of [SocialCredentialsPort], using the native iOS flow.
///
/// iOS only. The Android/web flow authenticates through a Service ID, whose id
/// becomes the token's `aud` — a different audience than the bundle id the API
/// validates, so it would need server-side support before it can be offered.
class AppleCredentialsAdapter implements SocialCredentialsPort {
  const AppleCredentialsAdapter();

  @override
  Future<SocialCredentialsResult> obtain() async {
    try {
      final rawNonce = generateNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Hex(rawNonce),
      );

      final idToken = credential.identityToken;
      if (idToken == null) return const SocialCredentialsFailure(missingToken: true);

      return SocialCredentials(
        idToken: idToken,
        authorizationCode: credential.authorizationCode,
        nonce: rawNonce,
        email: credential.email ?? '',
        // Populated only on the first authorization for this Apple ID.
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // Dismissing the sheet raises the same exception type as a real error;
      // only `canceled` means the user chose to back out.
      return e.code == AuthorizationErrorCode.canceled
          ? const SocialCredentialsCancelled()
          : const SocialCredentialsFailure();
    } on Object catch (_) {
      return const SocialCredentialsFailure();
    }
  }
}
