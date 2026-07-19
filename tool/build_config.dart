/// Declarative build config — the single source of truth for which apps
/// (brands) exist and how each is built. Add a brand here to make it buildable
/// everywhere (melos, CI, VS Code tasks) with no command changes.
///
/// Per brand `<key>`:
///   entrypoint : lib/brands/<key>/main_<key>.dart
///   flavor     : Android/iOS product flavor (usually == key)
///   defines    : env/<key>/<env>.json + env/shared.json
library;

class Brand {
  const Brand({required this.flavor, required this.envs});

  /// Android/iOS product flavor for this brand.
  final String flavor;

  /// Environments with a matching env/<brand>/<env>.json defines file.
  final List<String> envs;
}

/// brand key → config. The key is the entrypoint/env stem.
const brands = <String, Brand>{
  'balsm': Brand(flavor: 'balsm', envs: ['dev', 'staging', 'prod']),
  // Add once lib/brands/balsm_pro/main_balsm_pro.dart AND an Android
  // productFlavor 'balsm_pro' exist:
  // 'balsm_pro': Brand(flavor: 'balsm_pro', envs: ['dev', 'staging', 'prod']),
};
