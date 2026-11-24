/// Tells a deliberate shake from a bump.
///
/// One hard sample is not a shake: a knock on the table, a dropped phone or a
/// firm step each make a single spike. A shake is several spikes in quick
/// succession, so [onSample] fires only once [jolts] of them land inside
/// [window].
class ShakeDetector {
  ShakeDetector({
    this.thresholdMs2 = 15.0,
    this.jolts = 3,
    this.window = const Duration(milliseconds: 1000),
    this.minGap = const Duration(milliseconds: 100),
    this.cooldown = const Duration(seconds: 2),
  });

  /// Gravity-free acceleration, in m/s², that counts as a jolt.
  final double thresholdMs2;

  /// Jolts needed inside [window].
  final int jolts;

  /// How long a run of jolts may take.
  final Duration window;

  /// Spikes closer than this are one jolt: a single bump spans two or three
  /// samples at the sampling rate in use.
  final Duration minGap;

  /// Quiet time after a detection, so one shake opens the screen once.
  final Duration cooldown;

  final List<DateTime> _jolts = [];
  DateTime? _firedAt;

  /// Feeds one reading (gravity-free magnitude in m/s², and when it was taken).
  /// True when it completes a shake.
  bool onSample(double magnitudeMs2, DateTime at) {
    if (magnitudeMs2 < thresholdMs2) return false;
    final firedAt = _firedAt;
    if (firedAt != null && at.difference(firedAt) < cooldown) return false;
    if (_jolts.isNotEmpty && at.difference(_jolts.last) < minGap) return false;

    _jolts
      ..removeWhere((t) => at.difference(t) > window)
      ..add(at);
    if (_jolts.length < jolts) return false;

    _jolts.clear();
    _firedAt = at;
    return true;
  }
}
