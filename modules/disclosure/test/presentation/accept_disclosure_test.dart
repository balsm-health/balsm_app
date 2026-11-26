import 'dart:async';

import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:disclosure/src/presentation/providers/disclosure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Accept implements AcceptDisclosureUseCase {
  Completer<AppResult<void>> answer = Completer();
  String? authority;

  @override
  Future<AppResult<void>> execute({
    required DisclosureId disclosureId,
    required String version,
    required String countryCode,
    required String supervisoryAuthority,
    required String preferredLanguage,
  }) {
    authority = supervisoryAuthority;
    return answer.future;
  }

  @override
  Future<bool> resync({required DisclosureId disclosureId, required String version}) async => true;
}

void main() {
  late _Accept useCase;

  ProviderContainer make({bool hold = true}) {
    useCase = _Accept();
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [acceptDisclosureUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(c.dispose);
    if (hold) c.listen(acceptDisclosureProvider, (_, __) {});
    return c;
  }

  Future<bool> accept(ProviderContainer c) => c.read(acceptDisclosureProvider.notifier).accept(
        disclosureId: 'd-1',
        version: '1',
        countryCode: 'SA',
        preferredLanguage: 'en',
      );

  test('busy while sending, idle after success, with the country authority', () async {
    final c = make();
    final pending = accept(c);
    expect(c.read(acceptDisclosureProvider), const AcceptDisclosureState(busy: true));
    useCase.answer.complete(AppResult.success(null));
    expect(await pending, isTrue);
    expect(c.read(acceptDisclosureProvider), const AcceptDisclosureState());
    expect(useCase.authority, CountryRegistry().supervisoryAuthority('SA'));
  });

  test('a failure is kept, and a retry clears it', () async {
    final c = make();
    final first = accept(c);
    useCase.answer.complete(AppResult.failure(const NetworkFailure()));
    expect(await first, isFalse);
    expect(c.read(acceptDisclosureProvider).failure, isA<NetworkFailure>());

    useCase.answer = Completer();
    final retry = accept(c);
    expect(c.read(acceptDisclosureProvider).failure, isNull);
    useCase.answer.complete(AppResult.success(null));
    await retry;
  });

  test('a second tap while sending is ignored', () async {
    final c = make();
    final first = accept(c);
    expect(await accept(c), isFalse);
    useCase.answer.complete(AppResult.success(null));
    expect(await first, isTrue);
  });

  test('closing the screen mid-request neither throws nor writes', () async {
    final c = make(hold: false);
    final sub = c.listen(acceptDisclosureProvider, (_, __) {});
    final pending = accept(c);
    sub.close();
    await c.pump();
    useCase.answer.complete(AppResult.success(null));
    expect(await pending, isFalse);
  });
}
