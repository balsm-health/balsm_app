import 'package:drift/drift.dart';

/// Web executor. The on-device PHI database is not used on web (Flutter Web
/// serves only the public no-auth routes — emergency QR resolve, account
/// deletion). The throw is deferred via [LazyDatabase] so app bootstrap does
/// not fail; it only triggers if code actually queries the local DB on web.
QueryExecutor openExecutor() => LazyDatabase(
      () async => throw UnsupportedError(
        'On-device PHI database is not available on Flutter Web.',
      ),
    );
