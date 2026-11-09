import 'package:account/account.dart';
import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/personal_details.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Saving Personal details applies the saved gender to the app at once.
///
/// The screen sent the new gender to the server and stopped there. The app kept
/// the gender it had read when the screen opened until the screen was opened
/// again, so Arabic copy, the body map and the pregnancy prompt went on using
/// the old one.
void main() {
  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
  });

  testWidgets('choosing Female and saving makes the app female', (tester) async {
    // Wide enough that the test font, which draws every glyph as a full
    // square, does not overflow rows that fit on a phone with the real fonts.
    tester.view.physicalSize = const Size(560, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = PatientAppState();
    final profile = _Profile(stored: Gender.male);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(const UserId.value('u1')),
        accountProfileUseCaseProvider.overrideWithValue(profile),
        readAccountRepositoryProvider.overrideWithValue(_Accounts()),
      ],
      child: AppScope(state: state, child: MaterialApp(home: PersonalDetailsScreen(s: state))),
    ));
    await tester.pumpAndSettle();
    expect(state.gender, Gender.male, reason: 'opening the screen reads the stored gender');

    final strings = state.strings;
    await tester.tap(find.text(strings.onboarding.pf_female));
    await tester.pump();
    await tester.tap(find.text(strings.profile.pd_save));
    await tester.pumpAndSettle();

    expect(profile.sent, Gender.female, reason: 'the server got the new gender');
    expect(state.gender, Gender.female, reason: 'and so did the app, without reopening the screen');

    // Let the "Saved" pill's 2s timer finish before the test ends.
    await tester.pump(const Duration(seconds: 3));
  });
}

class _Profile implements AccountProfileUseCase {
  _Profile({required this.stored});

  Gender? stored;
  Gender? sent;

  @override
  Future<ProfileDetails?> load() async => ProfileDetails(handle: 'tester', firstName: 'A', lastName: 'B', gender: stored);

  @override
  Future<AppResult<void>> update(UpdateProfileInput input) async {
    sent = input.gender;
    stored = input.gender;
    return AppResult.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Accounts implements ReadAccountRepository {
  @override
  Future<AccountSummary?> getAccount(String userId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
