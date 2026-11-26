import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/accept_disclosure_use_case.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/disclosure_dao.dart';

/// Riverpod provider for [AcceptDisclosureUseCase].
final acceptDisclosureUseCaseProvider = Provider<AcceptDisclosureUseCase>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(disclosureApiProvider);
  final bus = ref.watch(eventBusProvider);
  return AcceptDisclosureUseCase(
    dao: DisclosureDao(db),
    api: api,
    eventBus: bus,
  );
});

/// Whether an acceptance is being sent, and why the last one failed.
@immutable
class AcceptDisclosureState {
  const AcceptDisclosureState({this.busy = false, this.failure});

  final bool busy;
  final AppFailure? failure;

  @override
  bool operator ==(Object other) => other is AcceptDisclosureState && other.busy == busy && other.failure == failure;

  @override
  int get hashCode => Object.hash(busy, failure);
}

/// Records the patient's acceptance of the consolidated disclosure.
class AcceptDisclosureNotifier extends Notifier<AcceptDisclosureState> {
  @override
  AcceptDisclosureState build() => const AcceptDisclosureState();

  /// Returns true once the acceptance is stored; on failure the reason is in
  /// the state.
  Future<bool> accept({
    required String disclosureId,
    required String version,
    required String countryCode,
    required String preferredLanguage,
  }) async {
    if (state.busy) return false;
    state = const AcceptDisclosureState(busy: true);
    final result = await ref.read(acceptDisclosureUseCaseProvider).execute(
          disclosureId: DisclosureId.value(disclosureId),
          version: version,
          countryCode: countryCode,
          supervisoryAuthority: ref.read(countryRegistryProvider).supervisoryAuthority(countryCode),
          preferredLanguage: preferredLanguage,
        );
    if (!ref.mounted) return false;
    state = AcceptDisclosureState(failure: result.isSuccess ? null : result.error);
    return result.isSuccess;
  }
}

/// The disclosure screen's acceptance; dropped when the screen closes.
final NotifierProvider<AcceptDisclosureNotifier, AcceptDisclosureState> acceptDisclosureProvider =
    NotifierProvider.autoDispose<AcceptDisclosureNotifier, AcceptDisclosureState>(AcceptDisclosureNotifier.new);
