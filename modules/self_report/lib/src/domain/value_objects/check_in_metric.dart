/// A self-reportable metric the patient may include in a check-in.
///
/// Closed catalog — adding a metric is a product decision, not free-form
/// input. The full-check-in wizard walks whichever subset the profile
/// tracks ([CheckInMetric.defaultFullCheckup] until the patient can pick).
///
/// [id] is the stable persistence / wizard-step key. [kind] orders the
/// wizard (feeling → vital → journal) and tells the composer where to
/// insert the medications step (before the first journal metric).
class CheckInMetric {
  const CheckInMetric._(
    this.id, {
    required this.kind,
    this.inDefaultFullCheckup = false,
    this.wizardReady = false,
  });

  final String id;
  final CheckInMetricKind kind;

  /// Included in a full check-in when the profile has no custom set yet.
  final bool inDefaultFullCheckup;

  /// The app shell has a capture step for this metric today. Tracked-but-
  /// not-ready metrics stay in the catalog (settings can offer them later)
  /// without spawning an empty wizard page.
  final bool wizardReady;

  static const mood = CheckInMetric._(
    'mood',
    kind: CheckInMetricKind.feeling,
    inDefaultFullCheckup: true,
    wizardReady: true,
  );
  static const bloodPressure = CheckInMetric._(
    'bp',
    kind: CheckInMetricKind.vital,
    inDefaultFullCheckup: true,
    wizardReady: true,
  );
  static const glucose = CheckInMetric._(
    'glucose',
    kind: CheckInMetricKind.vital,
    inDefaultFullCheckup: true,
    wizardReady: true,
  );
  static const heartRate = CheckInMetric._(
    'heartRate',
    kind: CheckInMetricKind.vital,
  );
  static const temperature = CheckInMetric._(
    'temperature',
    kind: CheckInMetricKind.vital,
  );
  static const weight = CheckInMetric._(
    'weight',
    kind: CheckInMetricKind.vital,
    wizardReady: true,
  );
  static const spo2 = CheckInMetric._(
    'spo2',
    kind: CheckInMetricKind.vital,
    wizardReady: true,
  );

  /// 0–10 scale + body map (quick-log pain template).
  static const pain = CheckInMetric._(
    'pain',
    kind: CheckInMetricKind.journal,
    inDefaultFullCheckup: true,
    wizardReady: true,
  );

  /// Curated symptom chips (quick-log symptoms template).
  static const symptoms = CheckInMetric._(
    'symptoms',
    kind: CheckInMetricKind.journal,
    inDefaultFullCheckup: true,
    wizardReady: true,
  );

  /// Display / default-tracking order.
  static const catalog = <CheckInMetric>[
    mood,
    bloodPressure,
    glucose,
    heartRate,
    temperature,
    weight,
    spo2,
    pain,
    symptoms,
  ];

  static const defaultFullCheckup = <CheckInMetric>[
    mood,
    bloodPressure,
    glucose,
    pain,
    symptoms,
  ];

  static final Map<String, CheckInMetric> _byId = {
    for (final m in catalog) m.id: m,
  };

  /// Resolve a stored id, or null if unknown / retired.
  static CheckInMetric? fromId(String id) => _byId[id];

  @override
  bool operator ==(Object other) => other is CheckInMetric && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Groups metrics so the wizard can stay feeling → vitals → journal when
/// the tracked set is a patient-chosen subset.
enum CheckInMetricKind { feeling, vital, journal }
