import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/check_in_metric.dart';

/// Step id for the medications page. Not a [CheckInMetric] — adherence is
/// recorded via the medications module, and the page is inserted only when
/// the profile actually has medications.
const kMedsCheckInStepId = 'meds';

/// Turns a stored id list into catalog metrics.
///
/// Empty / null / all-unknown → [CheckInMetric.defaultFullCheckup] so a
/// full check-in is never an empty wizard. Unknown ids are dropped
/// (retired catalog entries). Order of known ids is preserved.
List<CheckInMetric> resolveTrackedMetrics(Iterable<String>? ids) {
  if (ids == null) return CheckInMetric.defaultFullCheckup;
  final resolved = <CheckInMetric>[
    for (final id in ids)
      if (CheckInMetric.fromId(id) case final metric?) metric,
  ];
  return resolved.isEmpty ? CheckInMetric.defaultFullCheckup : resolved;
}

/// Ordered wizard page ids for a full check-in.
///
/// Walks [tracked] (patient-chosen, or defaults), keeps only metrics the
/// shell can capture today, then inserts [kMedsCheckInStepId] before the
/// first journal metric (or at the end) when [hasMeds] is true.
List<String> fullCheckInSteps({
  required List<CheckInMetric> tracked,
  required bool hasMeds,
}) {
  final ids = <String>[
    for (final m in tracked)
      if (m.wizardReady) m.id,
  ];
  if (!hasMeds) return ids;

  final insertAt = ids.indexWhere((id) {
    final m = CheckInMetric.fromId(id);
    return m?.kind == CheckInMetricKind.journal;
  });
  if (insertAt < 0) return [...ids, kMedsCheckInStepId];
  return [
    ...ids.sublist(0, insertAt),
    kMedsCheckInStepId,
    ...ids.sublist(insertAt),
  ];
}

/// Metrics this profile includes in a full check-in.
///
/// Today: catalog defaults. When the patient can pick metrics, replace the
/// body with a profile-scoped read (KV / settings) that feeds
/// [resolveTrackedMetrics].
final trackedCheckInMetricsProvider = Provider<List<CheckInMetric>>(
  (ref) => CheckInMetric.defaultFullCheckup,
);
