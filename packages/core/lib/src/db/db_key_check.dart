/// `checkDbKey` and `setAsideUnreadableData`: native files, or no-ops on web.
library;

export 'db_key.dart' show DbKeyStatus;
export 'db_key_check_io.dart' if (dart.library.js_interop) 'db_key_check_web.dart';
