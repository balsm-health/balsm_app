import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../application/use_cases/change_country_use_case.dart';
import '../../application/use_cases/change_language_use_case.dart';

/// Which account setting a settings screen changes.
enum AccountSetting { language, country }

/// A change to one account setting: the value applied ahead of the server
/// (language only, for an immediate direction flip), whether the request is
/// in flight, and why the last one failed.
@immutable
class AccountSettingChange {
  const AccountSettingChange({this.pending, this.busy = false, this.failure});

  /// The value shown before the stored summary catches up; null shows the
  /// stored value.
  final String? pending;
  final bool busy;
  final AppFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is AccountSettingChange && other.pending == pending && other.busy == busy && other.failure == failure;

  @override
  int get hashCode => Object.hash(pending, busy, failure);
}

/// Sends a language or country change. Each method returns true on success,
/// after which the screen refreshes the account summary.
class AccountSettingChangeNotifier extends Notifier<AccountSettingChange> {
  AccountSettingChangeNotifier(this.setting);

  final AccountSetting setting;

  @override
  AccountSettingChange build() => const AccountSettingChange();

  /// Applies [tag] at once, then sends it; on failure the stored language
  /// comes back and the failure is kept.
  Future<bool> changeLanguage(AccountSummary summary, String tag) async {
    if (state.busy || tag == (state.pending ?? summary.preferredLanguage)) return false;
    state = AccountSettingChange(pending: tag, busy: true);
    final result = await ref.read(changeLanguageUseCaseProvider).execute(
          userId: summary.id,
          oldLanguage: summary.preferredLanguage,
          newLanguage: tag,
        );
    if (!ref.mounted) return false;
    state = result.fold(
      (_) => AccountSettingChange(pending: tag),
      (failure) => AccountSettingChange(pending: summary.preferredLanguage, failure: failure),
    );
    return result.isSuccess;
  }

  /// Sends [code] as the account country. The identity confirmation comes
  /// before this, in the screen.
  Future<bool> changeCountry(AccountSummary summary, String code) async {
    if (state.busy || code == summary.countryCode) return false;
    state = const AccountSettingChange(busy: true);
    final result = await ref.read(changeCountryUseCaseProvider).execute(
          userId: summary.id,
          oldCountry: summary.countryCode,
          newCountry: code,
        );
    if (!ref.mounted) return false;
    state = AccountSettingChange(failure: result.isSuccess ? null : result.error);
    return result.isSuccess;
  }
}

/// One change in flight per setting; dropped when its screen closes.
final NotifierProviderFamily<AccountSettingChangeNotifier, AccountSettingChange, AccountSetting>
    accountSettingChangeProvider =
    NotifierProvider.autoDispose.family<AccountSettingChangeNotifier, AccountSettingChange, AccountSetting>(
  AccountSettingChangeNotifier.new,
);
