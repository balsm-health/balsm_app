/// Arabic-Indic (`٠-٩`) and Persian (`۰-۹`) digits folded to ASCII `0-9` (FR-213); every other character is
/// kept as typed. The one implementation for any field a patient may type on an Arabic or Persian keyboard.
///
/// Pure Dart, safe in any layer. PHI-safe: a local transform, never logged or sent anywhere.
String toWesternDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + (rune - 0x06F0));
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}
