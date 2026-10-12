import 'data_source.dart';

/// Device/app-wide data, no partition: app config, feature flags, onboarding
/// state, non-user caches. Survives login/logout.
///
/// Module usage — bind the record's own id type:
/// ```dart
/// class AppFlagsDataSource implements GlobalDataSource<FlagId, AppFlag> {...}
/// ```
abstract class GlobalDataSource<K, V> extends DataSource<K, V> {}
