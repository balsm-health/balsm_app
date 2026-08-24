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
