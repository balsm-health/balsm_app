import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/widgets/exit_confirm_scope.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Android's system back on the last screen asks "Exit Balsm?" before closing
/// the app. Screens pushed above the root still pop normally.
void main() {
  late List<String> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (
      call,
    ) async {
      platformCalls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  final state = PatientAppState();
  final c = state.strings.common;

  Future<void> pumpRoot(WidgetTester tester, {bool Function()? stepBack}) => tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: ExitConfirmScope(stepBack: stepBack, child: const Scaffold(body: Text('root screen'))),
          ),
        ),
      );

  bool closed() => platformCalls.contains('SystemNavigator.pop');

  testWidgets('back on the last screen asks first; Cancel stays in the app', (tester) async {
    await pumpRoot(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(c.exit_t), findsOne);
    expect(find.text(c.exit_b), findsOne);
    expect(closed(), isFalse, reason: 'nothing closes until the patient says so');
    await tester.tap(find.text(c.cancel));
    await tester.pumpAndSettle();
    expect(find.text(c.exit_t), findsNothing);
    expect(find.text('root screen'), findsOne);
    expect(closed(), isFalse);
  });

  testWidgets('Exit closes the app', (tester) async {
    await pumpRoot(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.exit_cta));
    await tester.pumpAndSettle();

    expect(closed(), isTrue);
  });

  testWidgets('back while the question is open closes the question, not the app', (tester) async {
    await pumpRoot(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(c.exit_t), findsNothing);
    expect(closed(), isFalse);
  });

  testWidgets('a screen pushed above the root pops normally, with no question', (tester) async {
    await pumpRoot(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('pushed screen'))));
    await tester.pumpAndSettle();
    expect(find.text('pushed screen'), findsOne);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('pushed screen'), findsNothing);
    expect(find.text(c.exit_t), findsNothing);
    expect(find.text('root screen'), findsOne);
  });

  testWidgets('a root screen that sits above another takes the back itself', (tester) async {
    var stepped = 0;
    await pumpRoot(tester, stepBack: () => ++stepped == 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stepped, 1);
    expect(find.text(c.exit_t), findsNothing, reason: 'it went up a level instead of asking');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stepped, 2);
    expect(find.text(c.exit_t), findsOne, reason: 'at the top level it asks');
  });
}
