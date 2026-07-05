import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = TranslationCatalog();

  test('resolves the English default bundle', () {
    expect(c.translate('common.done', locale: 'en'), 'Done');
    expect(c.translate('auth.email.title', locale: 'en'), 'Enter your email');
  });

  test('resolves an Arabic locale', () {
    expect(c.translate('common.done', locale: 'ar'), isNotEmpty);
    expect(c.translate('auth.email.title', locale: 'ar-EG'), isNotEmpty);
  });

  test('all ar-* regions resolve to the single Arabic bundle', () {
    final base = c.translate('common.done', locale: 'ar');
    for (final l in ['ar-SA', 'ar-AE', 'ar-EG']) {
      expect(c.translate('common.done', locale: l), base);
    }
  });

  test('missing key falls back to the key itself', () {
    expect(c.translate('does.not.exist', locale: 'en'), 'does.not.exist');
    expect(c.translate('does.not.exist', locale: 'ar-SA'), 'does.not.exist');
  });

  test('a namespace key (non-leaf) falls back to the key', () {
    expect(c.translate('common', locale: 'en'), 'common');
  });

  test('aliased reserved-word key resolves (common.continue)', () {
    expect(c.translate('common.continue', locale: 'en'), 'Continue');
  });

  test('aliased leaf-vs-namespace key resolves (profile.allergies)', () {
    expect(c.translate('profile.allergies', locale: 'en'), isNotEmpty);
    expect(c.translate('profile.allergies', locale: 'en'), isNot('profile.allergies'));
  });

  test('unknown locale falls back to the English bundle', () {
    expect(c.translate('common.done', locale: 'fr'), 'Done');
  });

  test('hasTranslation reflects presence', () {
    expect(c.hasTranslation('common.done', 'en'), isTrue);
    expect(c.hasTranslation('does.not.exist', 'en'), isFalse);
  });
}
