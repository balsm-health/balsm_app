import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the update gate gets its answers: `brand`'s manifest through an
/// `AppUpdateChecker` on `prefs`, or the test overrides `cached` / `check`.
typedef UpdateSource = ({
  AppBrand brand,
  AppUpdatePrefs? prefs,
  Future<AppUpdateInfo> Function(String lang)? cached,
  Future<AppUpdateInfo> Function(String lang)? check,
});

/// What the update gate knows: the latest answer and the version the patient
/// chose to skip (persisted). No PHI.
@immutable
class UpdateGateState {
  const UpdateGateState({this.info = AppUpdateInfo.none, this.skipped});

  final AppUpdateInfo info;
  final String? skipped;

  UpdateGateState withInfo(AppUpdateInfo i) => UpdateGateState(info: i, skipped: skipped);

  UpdateGateState withSkipped(String? v) => UpdateGateState(info: info, skipped: v);

  @override
  bool operator ==(Object other) => other is UpdateGateState && other.info == info && other.skipped == skipped;

  @override
  int get hashCode => Object.hash(info, skipped);
}

/// Runs the update check and keeps its answer. App-lifetime, not
/// auto-disposed: the gate re-checks on resume and on a language change.
class UpdateGateNotifier extends Notifier<UpdateGateState> {
  AppUpdateChecker? _checker;

  @override
  UpdateGateState build() => const UpdateGateState();

  /// The cached answer first on [first], so a forced update blocks at once
  /// even with no connection; then the live one.
  Future<void> refresh(UpdateSource source, {required String lang, bool first = false}) async {
    final prefs = source.prefs;
    if (source.check == null && prefs == null) return;
    final checker = prefs == null ? null : (_checker ??= AppUpdateChecker(prefs: prefs, brand: source.brand));
    const nothing = AppUpdateInfo.none;
    if (prefs != null) {
      final skipped = await prefs.skipped();
      if (!ref.mounted) return;
      state = state.withSkipped(skipped);
    }
    if (first) {
      final cached = await (source.cached?.call(lang) ?? checker?.cached(lang: lang) ?? Future.value(nothing));
      if (!ref.mounted) return;
      state = state.withInfo(cached);
    }
    final live = await (source.check?.call(lang) ?? checker?.check(lang: lang) ?? Future.value(nothing));
    if (!ref.mounted) return;
    state = state.withInfo(live);
  }

  /// Silences [UpdateGateState.info]'s version until a newer release.
  Future<void> skip(AppUpdatePrefs? prefs) async {
    final latest = state.info.latest;
    state = state.withSkipped(latest);
    await prefs?.setSkipped(latest);
  }
}

final NotifierProvider<UpdateGateNotifier, UpdateGateState> updateGateProvider =
    NotifierProvider<UpdateGateNotifier, UpdateGateState>(UpdateGateNotifier.new);
