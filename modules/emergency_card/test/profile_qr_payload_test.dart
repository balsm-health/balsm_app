import 'dart:convert';

import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileQrPayload (spec v2.0 schema v1)', () {
    test('serialises snake_case with v and kind inside the payload', () {
      final p = ProfileQrPayload(
        name: 'Jane Doe',
        dateOfBirth: '1990-01-01',
        gender: 'female',
        lang: 'ar',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );

      expect(p.toJson(), {
        'v': 1,
        'kind': 'profile',
        'name': 'Jane Doe',
        'date_of_birth': '1990-01-01',
        'gender': 'female',
        'lang': 'ar',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
    });

    test('round-trips through JSON', () {
      final p = ProfileQrPayload(
        name: 'Jane Doe',
        dateOfBirth: '1990-01-01',
        gender: 'other',
        lang: 'en',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );

      final back = ProfileQrPayload.tryParseString(p.toJsonString())!;

      expect(back.name, 'Jane Doe');
      expect(back.dateOfBirth, '1990-01-01');
      expect(back.gender, 'other');
      expect(back.lang, 'en');
      expect(back.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('all identity fields optional — empty payload still valid', () {
      final p = ProfileQrPayload(lang: 'en', createdAt: DateTime.parse('2026-01-01T00:00:00Z'));

      final back = ProfileQrPayload.tryParseString(p.toJsonString())!;

      expect(back.name, isNull);
      expect(back.dateOfBirth, isNull);
      expect(back.gender, isNull);
    });

    test('legacy payload (no v field) parses to null — resolvers show a hint', () {
      final legacy = jsonEncode({
        'bloodType': 'O+',
        'allergyNames': ['Penicillin'],
        'createdAt': '2026-01-01T00:00:00Z',
      });

      expect(ProfileQrPayload.tryParseString(legacy), isNull);
    });

    test('garbage input parses to null, never throws', () {
      expect(ProfileQrPayload.tryParseString('not json'), isNull);
      expect(ProfileQrPayload.tryParseString('[1,2]'), isNull);
    });
  });
}
