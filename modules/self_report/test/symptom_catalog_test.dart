import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// The curated symptom catalog, against `metric-inputs.jsx` SYMPTOMS.
///
/// Self-report is a journal, not a symptom checker, so the set is closed and
/// carries no clinical meaning. It still has to match the design's list —
/// tingling, itching and vomiting were missing for several revisions, and the
/// check-in screen carried its own hardcoded "located" set that silently
/// disagreed with the domain.
void main() {
  test('carries every symptom the design offers', () {
    expect(
      SymptomId.catalog.map((s) => s.id).toSet(),
      {
        'headache',
        'dizzy',
        'fatigue',
        'blurredVision',
        'swelling',
        'chestTightness',
        'nausea',
        'thirst',
        'tingling',
        'itching',
        'vomiting',
        'urine',
        'stool',
      },
    );
  });

  test('every id round-trips, and an unknown one is null', () {
    for (final s in SymptomId.catalog) {
      expect(SymptomId.fromId(s.id), s);
    }
    expect(SymptomId.fromId('retired'), isNull);
  });

  test('the located set is exactly the design’s loc: true symptoms', () {
    expect(
      SymptomId.catalog.where((s) => s.hasLocation).map((s) => s.id).toSet(),
      {'swelling', 'chestTightness', 'tingling', 'itching'},
    );
  });

  test('only urine and stool ask for extra detail', () {
    expect(SymptomId.catalog.where((s) => s.hasDetail).map((s) => s.id).toSet(), {'urine', 'stool'});
    expect(SymptomId.catalog.where((s) => s.asksUrineDetail).map((s) => s.id).toSet(), {'urine'});
  });

  test('a symptom is either located or detailed, never silently both', () {
    // Nothing in the design carries a body map AND a colour/volume card; if
    // that ever changes the detail card and the map would stack unreviewed.
    expect(SymptomId.catalog.where((s) => s.hasLocation && s.hasDetail), isEmpty);
  });
}
