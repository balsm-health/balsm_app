/// A curated self-reportable symptom. Structural id only; the localized label
/// resolves from the i69n bundle (`symptom.<id>`). This is a fixed catalog —
/// self-report is a journal, NOT a symptom checker, so the set is closed and
/// carries no clinical semantics or advice.
class SymptomId {
  const SymptomId(this.id);

  final String id;

  static const headache = SymptomId('headache');
  static const dizzy = SymptomId('dizzy');
  static const fatigue = SymptomId('fatigue');
  static const blurredVision = SymptomId('blurredVision');
  static const swelling = SymptomId('swelling');
  static const chestTightness = SymptomId('chestTightness');
  static const nausea = SymptomId('nausea');
  static const thirst = SymptomId('thirst');

  /// Excretory observations. These two carry the extra detail the design asks
  /// for (`SymptomDetail`): colour and volume for urine, blood for both.
  static const urine = SymptomId('urine');
  static const stool = SymptomId('stool');

  /// The curated catalog, in display order.
  static const catalog = <SymptomId>[
    headache,
    dizzy,
    fatigue,
    blurredVision,
    swelling,
    chestTightness,
    nausea,
    thirst,
    urine,
    stool,
  ];

  static final Map<String, SymptomId> _byId = {
    for (final s in catalog) s.id: s,
  };

  /// Resolve a stored symptom id, or null if unknown (retired catalog entry).
  static SymptomId? fromId(String id) => _byId[id];

  /// Symptoms that ask for [SymptomDetail] beyond "I had this".
  bool get hasDetail => this == urine || this == stool;

  /// Only urine asks for colour and volume; stool asks for blood alone.
  bool get asksUrineDetail => this == urine;

  @override
  bool operator ==(Object other) => other is SymptomId && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
