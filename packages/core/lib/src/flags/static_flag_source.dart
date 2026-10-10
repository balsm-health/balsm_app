import 'feature_flags.dart';

/// Flags fixed at build time: `--dart-define=FEATURE_FLAGS=sync=true,sync_care=true`.
///
/// For a QA build that must have a feature on with no flag tool involved, and
/// the simplest example of a [FeatureFlagSource].
class StaticFlagSource implements FeatureFlagSource {
  const StaticFlagSource(this._values, {this.name = 'build'});

  /// Reads the `FEATURE_FLAGS` define of this build.
  factory StaticFlagSource.fromEnvironment() => StaticFlagSource(parse(const String.fromEnvironment('FEATURE_FLAGS')));

  final Map<String, bool> _values;

  @override
  final String name;

  @override
  Future<void> refresh() async {}

  @override
  Future<bool?> read(String key) async => _values[key];

  /// `a=true,b=false` → `{a: true, b: false}`. A bare `a` means on. Anything
  /// that is not clearly on or off is dropped rather than guessed at. `;`
  /// separates as well, for shells and CI files where a comma is awkward.
  static Map<String, bool> parse(String raw) {
    final out = <String, bool>{};
    for (final part in raw.split(RegExp('[,;]'))) {
      final pair = part.trim();
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final key = (eq < 0 ? pair : pair.substring(0, eq)).trim();
      final value = eq < 0 ? 'true' : pair.substring(eq + 1).trim().toLowerCase();
      if (key.isEmpty) continue;
      if (const {'true', '1', 'on'}.contains(value)) out[key] = true;
      if (const {'false', '0', 'off'}.contains(value)) out[key] = false;
    }
    return out;
  }
}
