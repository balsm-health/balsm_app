import 'package:core/core.dart';
import 'package:riverpod/src/providers/notifier.dart';

import '../../i18n/strings.dart';

export '../../i18n/strings.dart';

/// Locale-reactive typed strings — PRESENTATION ONLY (providers are a
/// presentation concern; business logic uses `sessionsStrings.current`).
///
/// ```dart
/// final m = ref.watch(sessionsStringsProvider);
/// ```
final NotifierProvider<StringsProvider<Messages>, Messages> sessionsStringsProvider =
    LocalizationUtil.getProvider<Messages>(sessionsStrings);
