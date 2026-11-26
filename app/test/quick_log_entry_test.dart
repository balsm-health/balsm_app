import 'package:app/balsm_app/screens/metric_drafts.dart';
import 'package:app/balsm_app/screens/quick_log_entry.dart';
import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// The quick-log sheet's open entry as plain transitions: what the header's
/// Save and the discard prompt read. Synthetic readings only.
void main() {
  const opened = MetricLogCapture(summary: '120/80', vitals: Vitals(systolic: 120, diastolic: 80));
  const edited = MetricLogCapture(summary: '120/84', vitals: Vitals(systolic: 120, diastolic: 84));

  test('the first report is where the entry opened, not an edit', () {
    final e = const QuickLogEntry().report(opened, valid: true);
    expect(e.initial, opened);
    expect(e.dirty, isFalse);
  });

  test('a changed capture is dirty; changing it back is not', () {
    final e = const QuickLogEntry().report(opened, valid: true).report(edited, valid: true);
    expect(e.dirty, isTrue);
    expect(e.report(opened, valid: true).dirty, isFalse);
  });

  test('only a complete entry can be saved', () {
    expect(const QuickLogEntry().report(opened, valid: false).saveable, isNull);
    expect(const QuickLogEntry().report(opened, valid: true).saveable, opened);
  });

  test('an edited capture is a different entry, though the reading is the same one', () {
    final a = const QuickLogEntry().report(opened, valid: true);
    expect(a, const QuickLogEntry().report(opened, valid: true));
    expect(a.report(edited, valid: true), isNot(a));
  });

  test('each flow has its own entry, gone once nothing listens', () async {
    final c = ProviderContainer(retry: noProviderRetry);
    addTearDown(c.dispose);
    final first = Object();
    final second = Object();
    final sub = c.listen(quickLogEntryProvider(first), (_, __) {});
    c.listen(quickLogEntryProvider(second), (_, __) {});
    c.read(quickLogEntryProvider(first).notifier).report(edited, valid: true);
    expect(c.read(quickLogEntryProvider(second)).capture, isNull);

    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(quickLogEntryProvider(first)).capture, isNull, reason: 'disposed, so it opens empty again');
  });
}
