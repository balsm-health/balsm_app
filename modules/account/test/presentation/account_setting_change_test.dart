import 'dart:async';

import 'package:account/src/application/use_cases/change_country_use_case.dart';
import 'package:account/src/application/use_cases/change_language_use_case.dart';
import 'package:account/src/presentation/providers/account_setting_change.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Language implements ChangeLanguageUseCase {
  Completer<AppResult<String>> answer = Completer();

  @override
  Future<AppResult<String>> execute({
    required UserId userId,
    required String oldLanguage,
    required String newLanguage,
  }) =>
      answer.future;
}

class _Country implements ChangeCountryUseCase {
  _Country(this.answer);
  final AppResult<String> answer;

  @override
  Future<AppResult<String>> execute({
    required UserId userId,
    required String oldCountry,
    required String newCountry,
  }) async =>
      answer;
}

const _summary = AccountSummary(
  id: UserId.value('usr-test'),
  countryCode: 'SA',
  preferredLanguage: 'en',
  deletionState: 'ACTIVE',
);

void main() {
  late _Language language;
  final lang = accountSettingChangeProvider(AccountSetting.language);
  final country = accountSettingChangeProvider(AccountSetting.country);

  /// [hold] keeps both auto-dispose changes alive, as an open screen would.
  ProviderContainer make({AppResult<String>? countryAnswer, bool hold = true}) {
    language = _Language();
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        changeLanguageUseCaseProvider.overrideWithValue(language),
        changeCountryUseCaseProvider.overrideWithValue(_Country(countryAnswer ?? AppResult.success('AE'))),
      ],
    );
    addTearDown(c.dispose);
    if (hold) {
      c
        ..listen(lang, (_, __) {})
        ..listen(country, (_, __) {});
    }
    return c;
  }

  test('a new language shows at once and stays after success', () async {
    final c = make();
    final pending = c.read(lang.notifier).changeLanguage(_summary, 'ar');
    expect(c.read(lang), const AccountSettingChange(pending: 'ar', busy: true));
    language.answer.complete(AppResult.success('ar'));
    expect(await pending, isTrue);
    expect(c.read(lang), const AccountSettingChange(pending: 'ar'));
  });

  test('a failed language change reverts and keeps the failure', () async {
    final c = make();
    final pending = c.read(lang.notifier).changeLanguage(_summary, 'ar');
    language.answer.complete(AppResult.failure(const OfflineFailure()));
    expect(await pending, isFalse);
    expect(c.read(lang).pending, 'en');
    expect(c.read(lang).failure, isA<OfflineFailure>());
    expect(c.read(lang).busy, isFalse);
  });

  test('picking the language already shown, or picking while busy, does nothing', () async {
    final c = make();
    expect(await c.read(lang.notifier).changeLanguage(_summary, 'en'), isFalse);
    final first = c.read(lang.notifier).changeLanguage(_summary, 'ar');
    expect(await c.read(lang.notifier).changeLanguage(_summary, 'fr'), isFalse);
    expect(c.read(lang).pending, 'ar');
    language.answer.complete(AppResult.success('ar'));
    await first;
  });

  test('a country change reports success, and a failure is kept', () async {
    var c = make();
    expect(await c.read(country.notifier).changeCountry(_summary, 'AE'), isTrue);
    expect(c.read(country), const AccountSettingChange());

    c = make(countryAnswer: AppResult.failure(const GeofenceFailure()));
    expect(await c.read(country.notifier).changeCountry(_summary, 'AE'), isFalse);
    expect(c.read(country).failure, isA<GeofenceFailure>());
  });

  test('closing the screen mid-request neither throws nor writes', () async {
    final c = make(hold: false);
    final sub = c.listen(lang, (_, __) {});
    final pending = c.read(lang.notifier).changeLanguage(_summary, 'ar');
    sub.close();
    await c.pump();
    language.answer.complete(AppResult.success('ar'));
    expect(await pending, isFalse);
  });

  test('equality covers every field', () {
    const a = AccountSettingChange(pending: 'ar');
    expect(a, const AccountSettingChange(pending: 'ar'));
    expect(a == const AccountSettingChange(pending: 'ar', busy: true), isFalse);
    expect(a == const AccountSettingChange(pending: 'en'), isFalse);
    expect(a == const AccountSettingChange(pending: 'ar', failure: NetworkFailure()), isFalse);
  });
}
