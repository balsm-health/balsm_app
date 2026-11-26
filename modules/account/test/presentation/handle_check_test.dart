import 'dart:async';

import 'package:account/src/application/use_cases/claim_handle_use_case.dart';
import 'package:account/src/presentation/providers/handle_check.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AccountApi {}

class _Claim implements ClaimHandleUseCase {
  _Claim(this.answer);
  final AppResult<String> answer;

  @override
  Future<AppResult<String>> execute(String handle) async => answer;
}

void main() {
  late _Api api;

  ProviderContainer make({AppResult<String>? claim}) {
    api = _Api();
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        accountApiProvider.overrideWithValue(api),
        claimHandleUseCaseProvider.overrideWithValue(_Claim(claim ?? AppResult.success('nadia'))),
      ],
    );
    addTearDown(c.dispose);
    c.listen(handleCheckProvider, (_, __) {});
    return c;
  }

  void answer(String handle, Future<HandleAvailabilityResponse> Function() reply) =>
      when(() => api.checkHandleAvailability(handle, cancelToken: any(named: 'cancelToken'))).thenAnswer((_) => reply());

  /// Lets the debounce fire and the fake answer arrive.
  Future<void> settle() => Future<void>.delayed(HandleCheckNotifier.debounce + const Duration(milliseconds: 20));

  test('a malformed handle is invalid at once, with no request', () {
    final c = make();
    c.read(handleCheckProvider.notifier).input('ab');
    expect(c.read(handleCheckProvider).status, HandleStatus.invalid);
    verifyNever(() => api.checkHandleAvailability(any(), cancelToken: any(named: 'cancelToken')));
  });

  test('a free handle becomes available after the debounce', () async {
    final c = make();
    answer('nadia', () async => const HandleAvailabilityResponse(available: true));
    c.read(handleCheckProvider.notifier).input('nadia');
    expect(c.read(handleCheckProvider).status, HandleStatus.checking);
    await settle();
    expect(c.read(handleCheckProvider), const HandleCheck(handle: 'nadia', status: HandleStatus.available));
  });

  test('only the last keystroke is checked', () async {
    final c = make();
    answer('nadia', () async => const HandleAvailabilityResponse(available: true));
    c.read(handleCheckProvider.notifier)
      ..input('nad')
      ..input('nadia');
    await settle();
    verifyNever(() => api.checkHandleAvailability('nad', cancelToken: any(named: 'cancelToken')));
  });

  test('a stale answer does not overwrite a newer handle', () async {
    final c = make();
    final slow = Completer<HandleAvailabilityResponse>();
    answer('first', () => slow.future);
    c.read(handleCheckProvider.notifier).input('first');
    await settle();
    c.read(handleCheckProvider.notifier).input('ab');
    slow.complete(const HandleAvailabilityResponse(available: true));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(handleCheckProvider).status, HandleStatus.invalid);
  });

  test('a 409 reads as taken; any other error as a failed check', () async {
    final c = make();
    answer('taken', () async => throw const ApiException(code: 'conflict', statusCode: 409));
    answer('broken', () async => throw const ApiException(code: 'server', statusCode: 500));
    c.read(handleCheckProvider.notifier).input('taken');
    await settle();
    expect(c.read(handleCheckProvider).status, HandleStatus.taken);
    c.read(handleCheckProvider.notifier).input('broken');
    await settle();
    expect(c.read(handleCheckProvider), const HandleCheck(handle: 'broken', checkFailed: true));
  });

  test('a conflict on claim marks the handle taken', () async {
    final c = make(claim: AppResult.failure(const ConflictFailure('Handle taken')));
    answer('nadia', () async => const HandleAvailabilityResponse(available: true));
    c.read(handleCheckProvider.notifier).input('nadia');
    await settle();
    expect(await c.read(handleCheckProvider.notifier).claim(), isNull);
    expect(c.read(handleCheckProvider).status, HandleStatus.taken);
  });

  test('another claim failure is kept for the screen to show', () async {
    final c = make(claim: AppResult.failure(const OfflineFailure()));
    answer('nadia', () async => const HandleAvailabilityResponse(available: true));
    c.read(handleCheckProvider.notifier).input('nadia');
    await settle();
    expect(await c.read(handleCheckProvider.notifier).claim(), isNull);
    expect(c.read(handleCheckProvider).claimFailure, isA<OfflineFailure>());
  });

  test('a successful claim returns the claimed handle', () async {
    final c = make();
    answer('nadia', () async => const HandleAvailabilityResponse(available: true));
    c.read(handleCheckProvider.notifier).input('nadia');
    await settle();
    expect(await c.read(handleCheckProvider.notifier).claim(), 'nadia');
  });

  test('closing the screen mid-check neither throws nor writes', () async {
    api = _Api();
    final c = ProviderContainer(retry: noProviderRetry, overrides: [accountApiProvider.overrideWithValue(api)]);
    addTearDown(c.dispose);
    final slow = Completer<HandleAvailabilityResponse>();
    answer('nadia', () => slow.future);
    final sub = c.listen(handleCheckProvider, (_, __) {});
    c.read(handleCheckProvider.notifier).input('nadia');
    await settle();
    sub.close();
    await c.pump();
    slow.complete(const HandleAvailabilityResponse(available: true));
    await Future<void>.delayed(Duration.zero);
  });
}
