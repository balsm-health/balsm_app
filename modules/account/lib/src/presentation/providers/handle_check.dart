import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/claim_handle_use_case.dart';

/// Status of the live handle-availability check.
enum HandleStatus { idle, checking, available, taken, invalid }

/// The handle being typed and what is known about it. Holds reasons, not
/// localized text: the screen turns them into words.
@immutable
class HandleCheck {
  const HandleCheck({this.handle = '', this.status = HandleStatus.idle, this.checkFailed = false, this.claimFailure});

  /// The canonical handle (no `@`, lowercase) the status is about.
  final String handle;
  final HandleStatus status;

  /// The availability request failed (not a 409); the status is back to idle.
  final bool checkFailed;

  /// The claim failed for a reason other than the handle being taken.
  final AppFailure? claimFailure;

  @override
  bool operator ==(Object other) =>
      other is HandleCheck &&
      other.handle == handle &&
      other.status == status &&
      other.checkFailed == checkFailed &&
      other.claimFailure == claimFailure;

  @override
  int get hashCode => Object.hash(handle, status, checkFailed, claimFailure);
}

/// Validates the typed handle, checks availability 500 ms after the last
/// keystroke, and claims it.
class HandleCheckNotifier extends Notifier<HandleCheck> {
  static const debounce = Duration(milliseconds: 500);

  Timer? _debounce;

  @override
  HandleCheck build() {
    ref.onDispose(() => _debounce?.cancel());
    return const HandleCheck();
  }

  /// [value] is the canonical handle the field now shows.
  void input(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      state = const HandleCheck();
      return;
    }
    if (!kHandleFormat.hasMatch(value)) {
      state = HandleCheck(handle: value, status: HandleStatus.invalid);
      return;
    }
    state = HandleCheck(handle: value, status: HandleStatus.checking);
    _debounce = Timer(debounce, () => unawaited(_check(value)));
  }

  Future<void> _check(String handle) async {
    final api = ref.read(accountApiProvider);
    HandleCheck next;
    try {
      final res = await api.checkHandleAvailability(handle);
      next = HandleCheck(handle: handle, status: res.available ? HandleStatus.available : HandleStatus.taken);
    } on ApiException catch (e) {
      next = e.statusCode == 409
          ? HandleCheck(handle: handle, status: HandleStatus.taken)
          : HandleCheck(handle: handle, checkFailed: true);
    }
    // A newer keystroke owns the state now; this answer is stale.
    if (!ref.mounted || state.handle != handle) return;
    state = next;
  }

  /// Claims the available handle. Returns the claimed handle, or null when the
  /// claim failed (the reason is in the state).
  Future<String?> claim() async {
    final handle = state.handle;
    if (handle.isEmpty || state.status != HandleStatus.available) return null;
    final result = await ref.read(claimHandleUseCaseProvider).execute(handle);
    if (!ref.mounted) return null;
    return result.fold(
      (claimed) => claimed,
      (failure) {
        if (state.handle != handle) return null;
        state = failure is ConflictFailure
            ? HandleCheck(handle: handle, status: HandleStatus.taken)
            : HandleCheck(handle: handle, status: state.status, claimFailure: failure);
        return null;
      },
    );
  }
}

/// The claim screen's check; dropped when the screen closes.
final NotifierProvider<HandleCheckNotifier, HandleCheck> handleCheckProvider =
    NotifierProvider.autoDispose<HandleCheckNotifier, HandleCheck>(HandleCheckNotifier.new);
