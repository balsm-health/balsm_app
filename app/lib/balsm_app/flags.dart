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

  /// The "Beta" ribbon across the corner of every screen. On until the app is
  /// declared stable, then switched off remotely — no release needed.
  static const betaBanner = FeatureFlag(
    'beta_banner',
    fallback: true,
    label: 'Beta ribbon',
    description: 'Corner ribbon marking this release as a beta.',
  );

  /// Mother & Child (P003b): family member profiles on this device, the
  /// people picker that re-points the whole app to one of them, and their
  /// emergency cards. Off keeps today's single-profile app, including the
  /// session-only account switcher.
  static const motherChild = FeatureFlag(
    'mother_child',
    fallback: false,
    label: 'Mother & Child',
    description:
        'Family profiles, the people picker, per-member emergency cards, child vaccinations and growth, and pregnancy tracking.',
  );

  /// Family links (P003b, Identity & Access): add someone with their own
  /// Balsm account by scanning their profile QR, approve or decline incoming
  /// requests, and share a sealed emergency card per link. Off by default — it
  /// sends data to the server. Only takes effect with [motherChild] on too:
  /// its screens are the Mother & Child ones ([familyLinkOn]).
  static const familyLink = FeatureFlag(
    'family_link',
    fallback: false,
    label: 'Family links',
    description:
        'Link Balsm accounts by profile QR; approve requests; share a sealed emergency card. Needs Mother & Child.',
  );

  static final all = <FeatureFlag>[sync, ..._syncTypes.values, betaBanner, motherChild, familyLink];
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

/// Whether family links are offered in this build, on this device, right now:
/// both its own flag and Mother & Child, whose screens carry it, are on.
bool familyLinkOn(FeatureFlags flags) => flags.isOn(AppFlags.motherChild) && flags.isOn(AppFlags.familyLink);
