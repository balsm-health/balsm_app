import 'package:core/core.dart';

import '../../i18n/strings.dart';

export '../../i18n/strings.dart';

/// Locale-reactive typed strings — PRESENTATION ONLY (providers are a
/// presentation concern; business logic uses `deletionStrings.current`).
///
/// ```dart
/// final m = ref.watch(deletionStringsProvider);
/// ```
final deletionStringsProvider =
    LocalizationUtil.getProvider<Messages>(deletionStrings);
