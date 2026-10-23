/// What names this build's environment in every host it talks to: `stg` for
/// staging, empty for production. Set by `HOST_SUFFIX` in
/// `app/env/<brand>/<env>.json`; a build with none is a production one.
const String kHostSuffix = String.fromEnvironment('HOST_SUFFIX');

/// The host called [name] in this build's environment: the production name
/// with `-<suffix>` appended to its first label.
///
/// ```dart
/// envHost('app');                 // app.balsm.health      (no suffix)
/// envHost('api', suffix: 'stg');  // api-stg.balsm.health
/// ```
///
/// One rule for every host, so an environment is added by naming it once, in
/// the build config, and nowhere else.
String envHost(String name, {String suffix = kHostSuffix}) =>
    suffix.isEmpty ? '$name.balsm.health' : '$name-$suffix.balsm.health';
