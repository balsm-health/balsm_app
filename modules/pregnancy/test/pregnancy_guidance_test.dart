import 'package:flutter_test/flutter_test.dart';
import 'package:pregnancy/pregnancy.dart';

/// Placeholder guidance only — no real content, nothing about a patient.
WeeklyGuidance _guidance(String version) => WeeklyGuidance(
      version: version,
      source: const GuidanceText(en: 'Test source', ar: ''),
      disclaimer: const GuidanceText(en: 'Test disclaimer', ar: 'تنبيه تجريبي'),
      multiplesNote: const GuidanceText(en: 'Test multiples', ar: 'توائم تجريبي'),
      weeks: const [
        GuidanceWeek(week: 4, title: GuidanceText(en: 'T4', ar: 'ع4'), body: GuidanceText(en: 'B4', ar: 'ن4')),
        GuidanceWeek(week: 5, title: GuidanceText(en: 'T5', ar: 'ع5'), body: GuidanceText(en: 'B5', ar: 'ن5')),
      ],
    );

class _Source implements PregnancyGuidanceSource {
  _Source({this.kept, this.fresh});
  final WeeklyGuidance? kept;
  final WeeklyGuidance? fresh;

  @override
  Future<WeeklyGuidance?> cached() async => kept;

  @override
  Future<WeeklyGuidance?> refresh() async => fresh ?? kept;
}

void main() {
  group('GuidanceText', () {
    test('picks the language, English when Arabic is missing', () {
      const t = GuidanceText(en: 'Hello', ar: 'مرحبا');
      expect(t.inLanguage('ar'), 'مرحبا');
      expect(t.inLanguage('en'), 'Hello');
      expect(const GuidanceText(en: 'Hello', ar: '').inLanguage('ar'), 'Hello');
    });
  });

  test('WeeklyGuidance.forWeek finds the week or null outside the content', () {
    final g = _guidance('v1');
    expect(g.forWeek(5)!.title.en, 'T5');
    expect(g.forWeek(3), isNull);
    expect(g.forWeek(41), isNull);
  });

  group('WatchPregnancyGuidanceUseCase', () {
    Future<List<String?>> versions(PregnancyGuidanceSource source) =>
        WatchPregnancyGuidanceUseCase(source: source)().map((g) => g?.version).toList();

    test('kept copy first, then the newer one', () async {
      expect(await versions(_Source(kept: _guidance('v1'), fresh: _guidance('v2'))), ['v1', 'v2']);
    });

    test('kept copy once when the server has nothing newer or is unreachable', () async {
      expect(await versions(_Source(kept: _guidance('v1'))), ['v1']);
      expect(await versions(_Source(kept: _guidance('v1'), fresh: _guidance('v1'))), ['v1']);
    });

    test('nothing kept: the fetched copy, or null when the fetch failed', () async {
      expect(await versions(_Source(fresh: _guidance('v1'))), ['v1']);
      expect(await versions(_Source()), [null]);
    });
  });
}
