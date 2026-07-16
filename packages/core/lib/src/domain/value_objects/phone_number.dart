import '../app_failure.dart';
import '../app_result.dart';
import 'country_code.dart';
import 'value_object.dart';

/// An E.164 phone number: a [country] (for its dial code) plus a normalized
/// [nationalNumber] (Western digits, no leading zero, digits only).
///
/// Build via the smart constructor [create], which validates and returns an
/// [AppResult] carrying a **failure code** (e.g. `phone.too_short`) — not a
/// localized string — so the presentation layer owns translation. Inputs are
/// normalized per FR-213: Arabic-Indic (`٠–٩`) and Persian (`۰–۹`) digits are
/// mapped to Western `0–9`, and formatting (spaces, dashes, parentheses) is
/// stripped.
class PhoneNumber extends ValueObject {
  const PhoneNumber._(this.country, this.nationalNumber);

  /// Validates [raw] as a national number dialed within [country].
  ///
  /// Failure codes: `phone.empty`, `phone.not_numeric`, `phone.too_short`,
  /// `phone.too_long`.
  static AppResult<PhoneNumber> create({
    required CountryCode country,
    required String raw,
  }) {
    var n = _normalize(raw);
    // Tolerate a pasted `+<dialcode>` or leading `00<dialcode>` prefix.
    final dialDigits = country.dialCode.replaceAll('+', '');
    if (dialDigits.isNotEmpty && n.startsWith(dialDigits)) {
      n = n.substring(dialDigits.length);
    }
    n = _stripLeadingZeros(n);

    if (n.isEmpty) {
      return AppResult.failure(const ValidationFailure('phone.empty'));
    }
    if (!_isDigits(n)) {
      return AppResult.failure(const ValidationFailure('phone.not_numeric'));
    }
    if (n.length < 4) {
      return AppResult.failure(const ValidationFailure('phone.too_short'));
    }
    if (n.length > 15) {
      return AppResult.failure(const ValidationFailure('phone.too_long'));
    }
    return AppResult.success(PhoneNumber._(country, n));
  }

  /// Parses a full E.164 string (`+201234567890`) by matching a known
  /// country dial code. Returns null when no known dial code matches.
  static PhoneNumber? tryParse(String e164) {
    final normalized = _normalize(e164);
    if (normalized.isEmpty) return null;
    // Longest dial code first so `+1` doesn't shadow a longer match.
    final known = CountryCode.known.toList()
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final country in known) {
      final dial = country.dialCode.replaceAll('+', '');
      if (dial.isNotEmpty && normalized.startsWith(dial)) {
        final national = _stripLeadingZeros(normalized.substring(dial.length));
        if (national.isNotEmpty) return PhoneNumber._(country, national);
      }
    }
    return null;
  }

  final CountryCode country;

  /// Normalized national number: Western digits, no leading zero.
  final String nationalNumber;

  /// Canonical E.164 form, e.g. `+201234567890`.
  String get e164 => '${country.dialCode}$nationalNumber';

  /// Human-friendly grouping: `+20 123 456 7890` (dial code then national
  /// number split into 3-4-… groups). Phone numbers stay LTR under RTL.
  String display() {
    final buf = StringBuffer(country.dialCode)..write(' ');
    for (var i = 0; i < nationalNumber.length; i += 3) {
      if (i > 0) buf.write(' ');
      buf.write(nationalNumber.substring(
          i, (i + 3).clamp(0, nationalNumber.length)));
    }
    return buf.toString();
  }

  // ── Normalization helpers ────────────────────────────────────────────────

  /// Maps Arabic-Indic / Persian digits to Western and drops any non-digit.
  static String _normalize(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        out.writeCharCode(rune); // 0-9
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(rune - 0x0660 + 0x30); // Arabic-Indic ٠-٩
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(rune - 0x06F0 + 0x30); // Persian ۰-۹
      }
      // everything else (space, -, (), +) dropped
    }
    return out.toString();
  }

  static String _stripLeadingZeros(String s) {
    var i = 0;
    while (i < s.length - 1 && s[i] == '0') {
      i++;
    }
    return s.substring(i);
  }

  static bool _isDigits(String s) =>
      s.isNotEmpty && s.codeUnits.every((u) => u >= 0x30 && u <= 0x39);

  @override
  List<Object?> get props => [country, nationalNumber];

  @override
  String toString() => e164;
}
