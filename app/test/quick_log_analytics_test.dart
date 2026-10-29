import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:app/balsm_app/screens/quick_log.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

class _RecordingLogger implements AnalyticsLogger {
  final events = <(String, Map<String, Object?>)>[];

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) => events.add((name, props ?? {}));

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {}

  @override
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {}

  @override
  void setUser(String? id) {}

  @override
  Future<void> flush() async {}
}

/// The quick-log sheet reports what kind of thing a patient did — never
/// which metric or symptom (`ProductEvent`).
void main() {
  late PatientAppState s;
  late _RecordingLogger log;

  Future<void> open(WidgetTester tester) async {
    s = PatientAppState();
    log = _RecordingLogger();
    tester.view.physicalSize = const Size(402, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [analyticsLoggerProvider.overrideWithValue(log)],
      child: AppScope(
        state: s,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(child: TextButton(onPressed: () => showQuickLog(context), child: const Text('open'))),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Iterable<String> names() => log.events.map((e) => e.$1);
  Map<String, Object?> last(String name) => log.events.lastWhere((e) => e.$1 == name).$2;

  testWidgets('opening the sheet and an entry reports the source and the group', (tester) async {
    await open(tester);
    expect(last(ProductEvent.quickLogOpened), {'source': ProductSource.tabBar});

    await tester.tap(find.text(s.strings.profile.m_mood));
    await tester.pumpAndSettle();
    expect(last(ProductEvent.quickLogItemOpened), {'category': ProductCategory.wellbeing});
  });

  testWidgets('discarding an entry reports the group and where it went', (tester) async {
    await open(tester);
    await tester.tap(find.text(s.strings.profile.m_mood));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MoodCell).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.checkin.ql_discard));
    await tester.pumpAndSettle();
    expect(last(ProductEvent.quickLogDiscarded), {'category': ProductCategory.wellbeing, 'action': 'back'});
  });

  testWidgets('a search is one event with a count, never the query', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'zzzzq');
    await tester.pump(const Duration(seconds: 1));
    final searches = log.events.where((e) => e.$1 == ProductEvent.quickLogSearched).toList();
    expect(searches, hasLength(1));
    expect(searches.single.$2, {'result': 'empty', 'count': 0});
  });

  testWidgets('no event carries a metric id, a symptom id or a property outside the catalog', (tester) async {
    await open(tester);
    await tester.tap(find.text(s.strings.profile.m_bp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(s.strings.checkin.full_checkin));

    final ids = {for (final m in CheckInMetric.catalog) m.id};
    for (final (name, props) in log.events.where((e) => e.$1.startsWith('quick_log_'))) {
      expect(kProductEventPropKeys.containsAll(props.keys), isTrue, reason: '$name: ${props.keys}');
      for (final v in props.values) {
        expect(ids, isNot(contains(v)), reason: '$name leaked a metric id');
      }
    }
    expect(names(), contains(ProductEvent.quickLogItemOpened));
    expect(last(ProductEvent.quickLogItemOpened), {'category': ProductCategory.vital});
  });
}
