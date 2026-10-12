import '../../i18n/strings.dart';

/// How severe an allergic reaction is — a fixed, clinically meaningful scale.
///
/// Was a bare `String` on [Allergy] plus a `kAllergySeverities` list, which put
/// the classification in whichever widget happened to render it: the profile
/// editor carried its own `mild|moderate|severe` switch returning hardcoded
/// English. The set of levels, their wire form, their order and their copy are
/// domain facts, so they live here — the widget is left to pick a colour.
///
/// Mirrors the `BodyRegion` / `BodyTissue` pattern in `self_report`: the enum
/// owns its label and resolves it against the module's i69n bundle.
enum AllergySeverity {
  mild('mild'),
  moderate('moderate'),
  severe('severe');

  const AllergySeverity(this.wire);

  /// Persisted form. Stable across releases — rows already hold these strings,
  /// so this must never be derived from [name] or reordered.
  final String wire;

  /// Parses a persisted value, or null when it is not a known level.
  ///
  /// Null rather than a throw: a row written by a future version must not make
  /// the profile unreadable, and the caller can fall back to the raw text.
  static AllergySeverity? fromWire(String value) {
    for (final level in values) {
      if (level.wire == value) return level;
    }
    return null;
  }

  /// Every level in escalating order — the source of truth for validation and
  /// for any picker that offers a choice.
  static List<String> get wireValues => [for (final l in values) l.wire];

  /// Localized label in [messages]' locale (module i69n `severity.*`).
  String label(Messages messages) => messages.severity[wire] as String;

  /// Label for a language code (`en` / `ar`).
  String labelForLang(String lang) => label(profileMessagesOf(lang));
}
