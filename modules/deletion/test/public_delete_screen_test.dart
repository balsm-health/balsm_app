import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Reauth implements ReauthPort {
  _Reauth({required this.accept});
  final bool accept;

  @override
  Future<AppResult<void>> requestChallenge(ReauthChannel channel, String identifier) async => AppResult.success(null);

  @override
  Future<AppResult<void>> verify(ReauthCredentials credentials) async =>
      accept ? AppResult.success(null) : AppResult.failure(const UnauthorizedFailure('Code refused'));
}

class _Request implements RequestDeletionUseCase {
  @override
  Future<AppResult<DeletionIntakeResult>> call() async => AppResult.success(
        DeletionIntakeResult(graceUntil: DateTime.utc(2030), state: DeletionState.deletionRequested),
      );
}

void main() {
  Future<void> pump(WidgetTester tester, {required bool accept}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          reauthPortProvider.overrideWithValue(_Reauth(accept: accept)),
          requestDeletionUseCaseProvider.overrideWithValue(_Request()),
        ],
        child: const MaterialApp(home: PublicDeleteScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> enterCode(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'someone');
    await tester.pump();
    await tester.tap(find.text('Send me a code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
  }

  testWidgets('a verified code leads to confirmation, then to the scheduled date', (tester) async {
    await pump(tester, accept: true);
    await enterCode(tester);

    expect(find.text('Request account deletion'), findsOneWidget);
    await tester.tap(find.text('Request account deletion'));
    await tester.pump();

    expect(find.text('Deletion scheduled'), findsOneWidget);
  });

  testWidgets('a refused code keeps the form and shows why', (tester) async {
    await pump(tester, accept: false);
    await enterCode(tester);

    expect(find.text('Code refused'), findsOneWidget);
    expect(find.text('Request account deletion'), findsNothing);
  });
}
