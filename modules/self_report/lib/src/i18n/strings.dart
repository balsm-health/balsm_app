import 'dart:ui' show Locale;

import 'package:core/core.dart';

import 'messages.i69n.dart';
import 'messages_ar.i69n.dart';

export 'messages.i69n.dart';
export 'messages_ar.i69n.dart';

/// Self-report catalog copy (body-region labels). English + Arabic both
/// compiled in — the catalog is tiny; deferring Arabic would flash English
/// on the body map before `loadLibrary` returns.
///
/// Pure Dart — safe in the domain layer. Read:
/// ```dart
/// selfReportStrings.current                 // sync, LocalizationUtil locale
/// selfReportMessagesOf(patientAppState.lang.value)
/// ```
final selfReportStrings = LocalizedStrings<Messages>.defaultLangs(
  en: LocaleFactory.sync(() => const Messages()),
  ar: LocaleFactory.sync(() => const Messages_ar()),
);

/// Locale-explicit lookup (prototype [PatientAppState.lang], route params).
Messages selfReportMessagesOf(String locale) =>
    selfReportStrings.resolveSync(Locale(locale.split(RegExp('[-_]')).first));
