import 'i18n/strings.i69n.dart';

/// Where the on-device journal is backed up. Closed catalog — adding a
/// target is a product decision, not free-form input.
///
/// [id] is the stable persistence key (matches existing `pa.storage` rows).
/// Localized copy lives in the app i69n bundle; resolve via [label].
enum StorageTarget {
  local,
  icloud,
  gdrive,
  balsmCloud;

  /// Wire / prefs value. Hyphenated where [name] is camelCase.
  String get id => switch (this) {
        balsmCloud => 'balsm-cloud',
        _ => name,
      };

  /// Picker order: device first, then clouds.
  static const picker = [local, icloud, gdrive, balsmCloud];

  static final Map<String, StorageTarget> _byId = {
    for (final t in values) t.id: t,
  };

  /// Resolve a stored id, or null if unknown / retired.
  static StorageTarget? tryFromId(String id) => _byId[id];

  bool get isLocal => this == local;

  /// Label in the given bundle (`storage.store_*`).
  String label(StorageStrings s) => switch (this) {
        local => s.store_local,
        icloud => s.store_icloud,
        gdrive => s.store_gdrive,
        balsmCloud => s.store_balsm_cloud,
      };
}

/// Whether a target can actually receive data today.
///
/// `storage.jsx` offers all three clouds as connectable. In this build none of
/// them is: `ICloudBackupAdapter` throws (the `cloud_kit` plugin was removed),
/// Balsm Cloud has no adapter at all, and `BackupService` is not wired to
/// Drive. A target that cannot receive a byte must not render as a switch —
/// telling a patient their health record reached a cloud it never left for is
/// the one failure this screen cannot have.
extension StorageTargetAvailability on StorageTarget {
  bool get isAvailable => isLocal;
}

/// The kinds of data the storage screen accounts for, in the order
/// `storage.jsx` lists them (`DATA_CATS`).
///
/// A closed catalog on purpose: this is the patient's answer to "where is my
/// X kept", so every category must map to something the app actually stores.
enum DataCategory {
  records,
  rx,
  meds,
  checkins,
  symptoms,
  vitals,
  medical,
  care,
  appts;

  /// Stable key, for prefs and for the `cat` a screen's pill names.
  String get id => name;

  static final Map<String, DataCategory> _byId = {for (final c in values) c.id: c};

  static DataCategory? tryFromId(String id) => _byId[id];

  /// Label in the app bundle (`storage.cat_*`).
  String label(StorageStrings s) => switch (this) {
        records => s.cat_records,
        rx => s.cat_rx,
        meds => s.cat_meds,
        checkins => s.cat_checkins,
        symptoms => s.cat_symptoms,
        vitals => s.cat_vitals,
        medical => s.cat_medical,
        care => s.cat_care,
        appts => s.cat_appts,
      };
}
