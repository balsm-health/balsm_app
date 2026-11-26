import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'db_key.dart';

/// Web: the key lives in the browser next to the data (see
/// `installWebSecureStorage`), not in a keychain tied to a signing team, so
/// the two are kept or cleared together. Always [DbKeyStatus.ok].
Future<DbKeyStatus> checkDbKey({FlutterSecureStorage? storage, Object? documents}) async => DbKeyStatus.ok;

/// Web: never needed ([checkDbKey] never reports a lost key). Does nothing.
Future<void> setAsideUnreadableData({Object? documents, DateTime? now}) async {}
