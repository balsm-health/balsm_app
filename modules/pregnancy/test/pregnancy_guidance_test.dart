import 'package:flutter_test/flutter_test.dart';
import 'package:pregnancy/pregnancy.dart';

/// Placeholder guidance only — no real content, nothing about a patient.
WeeklyGuidance _guidance(String version) => WeeklyGuidance(
      language: 'en',
      version: version,
      source: 'Test source',
      disclaimer: 'Test disclaimer',
      multiplesNote: 'Test multiples',
      weeks: const [
        GuidanceWeek(week: 4, title: 'T4', body: 'B4'),
        GuidanceWeek(week: 5, title: 'T5', body: 'B5'),
      ],
      labels: const {'sources_more': 'Sources ({n}) for week {week}'},
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
  test('WeeklyGuidance.label fills its placeholders, and is null for a label the content lacks', () {
    final g = _guidance('v1');
    expect(g.label('sources_more', {'n': 2, 'week': 5}), 'Sources (2) for week 5');
    expect(g.label('tests_due'), isNull);
  });

  test('WeeklyGuidance.forWeek finds the week or null outside the content', () {
    final g = _guidance('v1');
    expect(g.forWeek(5)!.title, 'T5');
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

    test('placeholder copy counts as none, kept or fetched', () async {
      expect(await versions(_Source(fresh: _guidance('placeholder-2026-11-04'))), [null]);
      expect(await versions(_Source(kept: _guidance('placeholder-2026-11-04'))), [null]);
      expect(
        await versions(_Source(kept: _guidance('placeholder-2026-11-04'), fresh: _guidance('partner-v1'))),
        ['partner-v1'],
      );
    });
  });
}
