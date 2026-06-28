// T189 — i18n translation completeness.
//
// Loads en.json (the source-of-truth key set) and the three Arabic locales,
// asserting each Arabic bundle is >= 98% complete relative to en and contains
// no orphan keys absent from en.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _localesUnderTest = ['ar-EG', 'ar-SA', 'ar-AE'];
const _completenessThreshold = 0.98;

/// Resolves the i18n asset directory regardless of the working directory the
/// test runner is launched from (repo root or package dir).
Directory _i18nDir() {
  const candidates = [
    'packages/core/assets/i18n',
    '../packages/core/assets/i18n',
    '../../packages/core/assets/i18n',
  ];
  for (final c in candidates) {
    final dir = Directory(c);
    if (dir.existsSync()) return dir;
  }
  fail('Could not locate packages/core/assets/i18n from ${Directory.current.path}');
}

Map<String, dynamic> _loadBundle(Directory dir, String locale) {
  final file = File('${dir.path}/$locale.json');
  expect(file.existsSync(), isTrue, reason: 'Missing bundle: ${file.path}');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final dir = _i18nDir();
  final en = _loadBundle(dir, 'en');
  final enKeys = en.keys.toSet();

  test('en bundle is non-empty and has >= 60 keys', () {
    expect(enKeys.length, greaterThanOrEqualTo(60));
  });

  for (final locale in _localesUnderTest) {
    group(locale, () {
      final bundle = _loadBundle(dir, locale);
      final keys = bundle.keys.toSet();

      test('is >= 98% complete vs en', () {
        final present = enKeys.where(keys.contains).length;
        final completeness = present / enKeys.length;
        final missing = enKeys.difference(keys);
        expect(
          completeness,
          greaterThanOrEqualTo(_completenessThreshold),
          reason: 'Completeness ${(completeness * 100).toStringAsFixed(1)}% '
              'below ${(_completenessThreshold * 100).toStringAsFixed(0)}%. '
              'Missing keys: $missing',
        );
      });

      test('has no orphan keys missing from en', () {
        final orphans = keys.difference(enKeys);
        expect(orphans, isEmpty, reason: 'Orphan keys not in en: $orphans');
      });

      test('has no empty translation values', () {
        final empty = bundle.entries
            .where((e) => (e.value as String).trim().isEmpty)
            .map((e) => e.key)
            .toList();
        expect(empty, isEmpty, reason: 'Empty values for keys: $empty');
      });
    });
  }
}
