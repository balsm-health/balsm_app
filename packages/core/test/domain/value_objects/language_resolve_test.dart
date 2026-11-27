import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// First-launch language (issue #100): a saved choice wins, then the device's
/// language when the app can render it, then Arabic. English is never the
/// fallback by omission.
void main() {
  group('LanguageCode.resolveUi', () {
    test('a saved choice wins over the device language', () {
      expect(LanguageCode.resolveUi(saved: 'en', deviceTags: ['ar-EG']), LanguageCode.en);
      expect(LanguageCode.resolveUi(saved: 'ar', deviceTags: ['en-US']), LanguageCode.ar);
    });

    test('with nothing saved, the device language is used', () {
      expect(LanguageCode.resolveUi(deviceTags: ['ar-EG']), LanguageCode.ar);
      expect(LanguageCode.resolveUi(deviceTags: ['en-GB']), LanguageCode.en);
    });

    test('the first device language the app can render is used, in preference order', () {
      expect(LanguageCode.resolveUi(deviceTags: ['fr-FR', 'en-US', 'ar']), LanguageCode.en);
      expect(LanguageCode.resolveUi(deviceTags: ['de', 'ar-SA', 'en']), LanguageCode.ar);
    });

    test('a device with no supported language lands on Arabic', () {
      expect(LanguageCode.resolveUi(deviceTags: ['fr-FR', 'de-DE']), LanguageCode.ar);
    });

    test('nothing saved and no device languages lands on Arabic', () {
      expect(LanguageCode.resolveUi(), LanguageCode.defaultUi);
      expect(LanguageCode.defaultUi, LanguageCode.ar);
    });

    test('a saved value the app cannot render falls through to the device, then Arabic', () {
      expect(LanguageCode.resolveUi(saved: 'fr', deviceTags: ['en-US']), LanguageCode.en);
      expect(LanguageCode.resolveUi(saved: 'fr'), LanguageCode.ar);
      expect(LanguageCode.resolveUi(saved: ''), LanguageCode.ar);
    });
  });
}
