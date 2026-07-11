import 'dart:ui' show Locale;

import 'package:core/core.dart';

import 'messages.i69n.dart';
// Arabic loads on demand (deferred library) — kept out of the initial payload.
import 'messages_ar.i69n.dart' deferred as ar;

export 'messages.i69n.dart';

/// Module bundle registry (English compiled in; Arabic deferred).
///
/// Pure Dart — safe in ANY layer. Business logic reads:
/// ```dart
/// authStrings.current           // sync, active locale
/// await authStrings.load()      // deferred-safe, active locale
/// ```
/// Presentation should prefer the reactive provider in
/// `presentation/i18n/i18n.dart`.
final authStrings = LocalizedStrings<Messages>.defaultLangs(
  en: LocaleFactory.sync(() => const Messages()),
  ar: LocaleFactory.deferred(ar.loadLibrary, () => ar.Messages_ar()),
);

/// Locale-explicit lookup for code that carries its own locale (e.g. a
/// `preferredLanguage` route param). Non-reactive; Arabic must have been
/// loaded (or falls back to English).
Messages authMessagesOf(String locale) =>
    authStrings.resolveSync(Locale(locale.split(RegExp('[-_]')).first));
