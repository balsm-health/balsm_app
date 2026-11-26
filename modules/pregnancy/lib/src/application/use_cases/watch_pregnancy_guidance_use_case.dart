import '../../domain/value_objects/weekly_guidance.dart';
import '../ports/pregnancy_guidance_source.dart';

/// Weekly guidance for the pregnancy screens: the copy kept on the device
/// straight away, then — once the server has been asked — the newer one if
/// it changed. Emits nothing when there is no guidance at all, so the screens
/// simply leave it out. Placeholder copy counts as none.
class WatchPregnancyGuidanceUseCase {
  const WatchPregnancyGuidanceUseCase({required PregnancyGuidanceSource source}) : _source = source;

  final PregnancyGuidanceSource _source;

  Stream<WeeklyGuidance?> call() async* {
    final keptCopy = await _source.cached();
    final kept = (keptCopy?.isPlaceholder ?? false) ? null : keptCopy;
    if (kept != null) yield kept;
    final freshCopy = await _source.refresh();
    final fresh = (freshCopy?.isPlaceholder ?? false) ? null : freshCopy;
    if (fresh == null) {
      if (kept == null) yield null;
      return;
    }
    if (kept == null || fresh.version != kept.version) yield fresh;
  }
}
