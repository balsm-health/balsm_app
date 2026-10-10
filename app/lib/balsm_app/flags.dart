import 'package:core/core.dart';

import 'storage_target.dart';

/// Every feature flag this app reads.
///
/// To put a new feature behind a flag: add a `const` here, add it to [all], and
/// ask `flags.isOn(AppFlags.yours)`. Create a flag with the same key in
/// whichever tool serves flags to switch it remotely; until then it sits at its
/// fallback. See `docs/feature-flags.md`.
abstract final class AppFlags {
  /// Master switch for sending patient data to Balsm Cloud. Off stops every
  /// type at once, whatever its own flag says.
  static const sync = FeatureFlag(
    'sync',
    fallback: false,
    label: 'Cloud sync',
    description: 'Master switch. Off stops every type below.',
  );

  /// One switch per kind of data, so sync can be opened — and closed again —
  /// a type at a time. A type syncs only with [sync] on as well, and only if
  /// the app has a sync engine for it ([DataCategorySync.hasSyncEngine]).
  static const _syncTypes = <DataCategory, FeatureFlag>{
    DataCategory.records: FeatureFlag('sync_records', fallback: false, label: 'Sync: records'),
    DataCategory.rx: FeatureFlag('sync_rx', fallback: false, label: 'Sync: prescriptions'),
    DataCategory.meds: FeatureFlag('sync_meds', fallback: false, label: 'Sync: medications'),
    DataCategory.checkins: FeatureFlag('sync_checkins', fallback: false, label: 'Sync: check-ins'),
    DataCategory.symptoms: FeatureFlag('sync_symptoms', fallback: false, label: 'Sync: symptoms'),
    DataCategory.vitals: FeatureFlag('sync_vitals', fallback: false, label: 'Sync: vitals'),
    DataCategory.medical: FeatureFlag('sync_medical', fallback: false, label: 'Sync: medical profile'),
    DataCategory.care: FeatureFlag('sync_care', fallback: false, label: 'Sync: care team'),
    DataCategory.appts: FeatureFlag('sync_appts', fallback: false, label: 'Sync: appointments'),
  };

  static FeatureFlag syncFor(DataCategory category) => _syncTypes[category]!;

  static final all = <FeatureFlag>[sync, ..._syncTypes.values];
}

extension DataCategorySync on DataCategory {
  /// Whether the app can sync this type at all. Only the care team has an
  /// engine today (`CareTeamSyncService`); a flag turned on for any other type
  /// changes nothing, and must never make a screen claim a cloud copy.
  bool get hasSyncEngine => this == DataCategory.care;
}

/// Whether [category] is being sent to Balsm Cloud in this build, on this
/// device, right now: there is an engine for it, and both the master flag and
/// the type's own flag are on.
bool cloudSyncOn(DataCategory category, FeatureFlags flags) =>
    category.hasSyncEngine && flags.isOn(AppFlags.sync) && flags.isOn(AppFlags.syncFor(category));
