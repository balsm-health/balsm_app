import 'package:app/balsm_app/app_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Records whether the screen actually reached the network.
class _RecordingCareTeamApi implements CareTeamApi {
  int pulls = 0;

  @override
  Future<List<CareProviderResponse>> pull({
    required String healthProfileId,
    DateTime? since,
    CancelToken? cancelToken,
  }) async {
    pulls++;
    return const [];
  }

  @override
  Future<void> upsert(UpsertCareProviderRequest request, {CancelToken? cancelToken}) async {}

  @override
  Future<void> delete(String id, {CancelToken? cancelToken}) async {}
}

void main() {
  test('careTeamSyncServiceProvider throws until bootstrap overrides it', () {
    // Guards the bootstrap contract: a missing override must fail loudly at the
    // first read rather than silently never syncing.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(careTeamSyncServiceProvider), throwsA(isA<UnimplementedError>()));
  });

  testWidgets('pulling the care team list down triggers a sync', (tester) async {
    const profileId = HealthProfileId.value('hp-1');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _RecordingCareTeamApi();
    final service = CareTeamSyncService(
      api: api,
      outbox: SyncOutboxDao(db),
      db: db,
      status: SyncStatusNotifier(),
      activeUser: () => const UserId.value('u-wiring-1'),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        careTeamProvider.overrideWith((ref) => Stream.value(const <CareProvider>[])),
        currentProfileIdProvider.overrideWithValue(profileId),
        careTeamSyncServiceProvider.overrideWithValue(service),
      ],
      child: AppScope(
        state: PatientAppState(),
        // material_ui's MaterialApp, matching care_team_test.dart: this repo's
        // Material layer is material_ui, so SubScreen's RefreshIndicator resolves
        // to material_ui's and wants material_ui's MaterialLocalizations.
        child: const MaterialApp(home: CareTeamScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(api.pulls, greaterThan(0));
  });
}
