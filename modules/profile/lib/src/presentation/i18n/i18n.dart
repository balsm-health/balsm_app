import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.dart';

export '../../i18n/strings.dart';

/// Locale-reactive typed strings — PRESENTATION ONLY (providers are a
/// presentation concern; business logic uses `profileStrings.current`).
///
/// ```dart
/// final m = ref.watch(profileStringsProvider);
/// ```
final NotifierProvider<StringsProvider<Messages>, Messages> profileStringsProvider =
    LocalizationUtil.getProvider<Messages>(profileStrings);
