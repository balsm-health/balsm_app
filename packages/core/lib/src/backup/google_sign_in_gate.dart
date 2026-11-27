import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import '../config/flavor.dart';

/// google_sign_in 7 requires `initialize` to be awaited exactly once before any
/// other call. Sign-in (auth module) and the Drive backup both need it, so they
/// share this gate; whichever runs first initialises with the flavor's client
/// ids, which is why neither passes its own.
abstract final class GoogleSignInGate {
  static Future<void>? _ready;

  /// Initialises Google Sign-In once. [serverClientId] and [clientId] default to
  /// the current flavor's; without the server id Android returns a null idToken.
  static Future<void> ensureInitialized({String? serverClientId, String? clientId}) {
    final flavor = FlavorConfig.currentOrNull;
    final server = serverClientId ?? flavor?.googleServerClientId;
    final ios = clientId ?? flavor?.googleIosClientId;
    return _ready ??= GoogleSignIn.instance.initialize(
      serverClientId: (server == null || server.isEmpty) ? null : server,
      // The iOS platform client only applies on iOS; Android matches by package + SHA-1.
      clientId: (defaultTargetPlatform != TargetPlatform.iOS || ios == null || ios.isEmpty) ? null : ios,
    );
  }
}
