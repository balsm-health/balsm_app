// Documentation-screenshot entrypoint — the real app wired to the SAME fake
// APIs as e2e (`e2eApiOverrides`) with a pre-seeded synthetic session, so the
// shell renders signed-in as the "E2E Tester" fixture. Nothing real is
// reachable: every API call hits an in-memory fake, and the on-device DB
// starts empty. Used by tool/docshots.dart (see docs/screenshots.md).
//
//   fvm flutter run --flavor balsm -t lib/brands/balsm/main_docshots.dart \
//     --dart-define-from-file=env/balsm/dev.json \
//     --dart-define-from-file=env/shared.json -d <simulator>

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'main_balsm.dart' as app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seed a revivable synthetic session BEFORE bootstrap reads the keychain:
  // the shell ejects sessionless users by design, and the boot path requires
  // id + refresh token together to consider a session alive.
  const storage = FlutterSecureStorage(mOptions: MacOsOptions(useDataProtectionKeyChain: false));
  await storage.write(key: 'balsm.user_id', value: E2eFixture.userId);
  await storage.write(key: 'balsm.refresh_token', value: 'docshots-refresh-token');
  await storage.write(key: 'balsm.access_token', value: 'docshots-access-token');
  await app.bootstrap(extraOverrides: e2eApiOverrides());
}
