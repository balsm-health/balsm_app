import 'dart:ui' show Locale;

import 'package:core/core.dart';

import 'messages.i69n.dart';
// Arabic loads on demand (deferred library) — kept out of the initial payload.
import 'messages_ar.i69n.dart' deferred as ar;

export 'messages.i69n.dart';

/// Locale-reactive typed strings for this module. Watch it anywhere —
/// business logic or UI — and read compile-time-checked fields:
///
/// ```dart
/// final m = ref.watch(profileStringsProvider);
/// ```
///
/// Tracks core's `currentLocaleProvider`; while the deferred Arabic bundle
/// loads, the English bundle is emitted, then replaced.
final profileStringsProvider = LocalizationUtil.getProvider<Messages>(
  profileStrings,
);

/// Module bundle registry (English compiled in; Arabic deferred).
final profileStrings = LocalizedStrings<Messages>.defaultLangs(
  en: LocaleFactory.sync(() => const Messages()),
  ar: LocaleFactory.deferred(ar.loadLibrary, () => ar.Messages_ar()),
);

/// Locale-explicit lookup for widget code that carries its own locale
/// (e.g. a `preferredLanguage` route param). Non-reactive; Arabic must have
/// been loaded (or falls back to English).
Messages profileMessagesOf(String locale) =>
    profileStrings.resolveSync(Locale(locale.split(RegExp('[-_]')).first));
