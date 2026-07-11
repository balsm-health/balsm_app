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
/// final m = ref.watch(accountStringsProvider);
/// ```
///
/// Tracks core's `currentLocaleProvider`; while the deferred Arabic bundle
/// loads, the English bundle is emitted, then replaced.
final accountStringsProvider = LocalizationUtil.getProvider<Messages>(
  accountStrings,
);

/// Module bundle registry (English compiled in; Arabic deferred).
final accountStrings = LocalizedStrings<Messages>.defaultLangs(
  en: LocaleFactory.sync(() => const Messages()),
  ar: LocaleFactory.deferred(ar.loadLibrary, () => ar.Messages_ar()),
);

/// Locale-explicit lookup for widget code that carries its own locale
/// (e.g. a `preferredLanguage` route param). Non-reactive; Arabic must have
/// been loaded (or falls back to English).
Messages accountMessagesOf(String locale) =>
    accountStrings.resolveSync(Locale(locale.split(RegExp('[-_]')).first));
