import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';
import 'package:profile/src/presentation/providers/profile_edit.dart';

final _empty = HealthProfile(
  id: const HealthProfileId.value('hp-test'),
  userId: const UserId.value('usr-test'),
  bloodType: null,
  allergies: const [],
  conditions: const [],
  emergencyContacts: const [],
  updatedAt: DateTime.utc(2030),
);

/// Answers each call from a completer the test controls.
class _AddCondition implements AddChronicConditionUseCase {
  Completer<AppResult<HealthProfile>> answer = Completer();
  int calls = 0;

  @override
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    required String name,
    HealthProfileId? profileId,
    String? icd10Code,
    int? onsetYear,
  }) {
    calls++;
    return answer.future;
  }
}

class _RemoveAllergy implements RemoveAllergyUseCase {
  _RemoveAllergy(this.answer);
  final AppResult<HealthProfile> answer;

  @override
  Future<AppResult<HealthProfile>> execute({
    required UserId userId,
    required AllergyId allergyId,
    HealthProfileId? profileId,
  }) async =>
      answer;
}

void main() {
  late _AddCondition addCondition;

  /// [hold] keeps the auto-dispose editor alive, as the open screen would.
  ProviderContainer make({
    UserId? user = const UserId.value('usr-test'),
    AppResult<HealthProfile>? remove,
    bool hold = true,
  }) {
    addCondition = _AddCondition();
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        currentUserIdProvider.overrideWithValue(user),
        addChronicConditionUseCaseProvider.overrideWithValue(addCondition),
        removeAllergyUseCaseProvider.overrideWithValue(_RemoveAllergy(remove ?? AppResult.success(_empty))),
      ],
    );
    addTearDown(c.dispose);
    if (hold) c.listen(profileEditProvider, (_, __) {});
    return c;
  }

  test('a failed change is kept, and the next change clears it', () async {
    final c = make(remove: AppResult.failure(const StorageFailure()));
    await c.read(profileEditProvider.notifier).removeAllergy(const AllergyId.value('a-1'));
    expect(c.read(profileEditProvider), isA<StorageFailure>());

    final pending = c.read(profileEditProvider.notifier).addCondition('x');
    expect(c.read(profileEditProvider), isNull);
    addCondition.answer.complete(AppResult.success(_empty));
    await pending;
    expect(c.read(profileEditProvider), isNull);
  });

  test('nothing is sent without a signed-in user', () async {
    final c = make(user: null);
    await c.read(profileEditProvider.notifier).addCondition('x');
    expect(addCondition.calls, 0);
  });

  test('closing the editor mid-change neither throws nor writes', () async {
    final c = make(hold: false);
    final sub = c.listen(profileEditProvider, (_, __) {});
    final pending = c.read(profileEditProvider.notifier).addCondition('x');
    sub.close();
    await c.pump();
    addCondition.answer.complete(AppResult.failure(const StorageFailure()));
    await expectLater(pending, completes);
  });

  group('allergy draft', () {
    test('starts mild and not controlled, and each sheet has its own', () {
      final c = make();
      final one = Object();
      final two = Object();
      c
        ..listen(allergyDraftProvider(one), (_, __) {})
        ..listen(allergyDraftProvider(two), (_, __) {});
      expect(c.read(allergyDraftProvider(one)), const AllergyDraft());

      c.read(allergyDraftProvider(one).notifier)
        ..setSeverity('severe')
        ..setControlled(value: true);
      expect(c.read(allergyDraftProvider(one)), const AllergyDraft(severity: 'severe', controlled: true));
      expect(c.read(allergyDraftProvider(two)), const AllergyDraft());
    });

    test('equality covers both fields', () {
      const a = AllergyDraft();
      expect(a == a.withSeverity('moderate'), isFalse);
      expect(a == a.withControlled(value: true), isFalse);
      expect(a.withSeverity('severe'), const AllergyDraft(severity: 'severe'));
    });
  });
}
