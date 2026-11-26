import 'dart:async';

import 'package:core/core.dart' show accountApiProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../app_state.dart' show UsernameStatus;

/// One handle field: `form` is a token its screen's State creates once, so
/// two open forms never share a check; `required` says whether an empty
/// handle is an error (Personal details: every profile has one) or simply
/// none chosen yet (profile setup).
typedef HandleCheckKey = ({Object form, bool required});

/// What the handle field shows: the handle as typed (normalized) and whether
/// it can be claimed.
@immutable
class HandleCheck {
  const HandleCheck({this.handle = '', this.status = UsernameStatus.idle});

  /// The status a typed [handle] has before the server is asked. [original]
  /// is the handle the account already holds: keeping it is no change.
  factory HandleCheck.typed(String handle, {required bool required, String original = ''}) {
    final status = switch (handle) {
      '' => required ? UsernameStatus.required : UsernameStatus.idle,
      _ when handle == original => UsernameStatus.idle,
      _ when !format.hasMatch(handle) => UsernameStatus.invalid,
      _ => UsernameStatus.checking,
    };
    return HandleCheck(handle: handle, status: status);
  }

  /// Backend handle format: 3–30 characters, a–z 0–9 `_` or `.`.
  static final format = RegExp(r'^[a-z0-9_.]{3,30}$');

  /// Lower-cases [raw] and drops every character a handle cannot hold.
  static String normalize(String raw) => raw.toLowerCase().replaceAll(RegExp('[^a-z0-9_.]'), '');

  final String handle;
  final UsernameStatus status;

  /// Unchanged, or changed and free: nothing about the handle blocks a save.
  bool get acceptable => status == UsernameStatus.idle || status == UsernameStatus.available;

  HandleCheck withStatus(UsernameStatus status) => HandleCheck(handle: handle, status: status);

  @override
  bool operator ==(Object other) => other is HandleCheck && other.handle == handle && other.status == status;

  @override
  int get hashCode => Object.hash(handle, status);
}

/// Live handle availability, shared by profile setup and Personal details:
/// format first, then a debounced ask to the account API.
class HandleCheckController extends Notifier<HandleCheck> {
  HandleCheckController(this.args);
  final HandleCheckKey args;

  /// Typing pauses this long before the server is asked.
  static const debounce = Duration(milliseconds: 500);

  Timer? _debounce;

  @override
  HandleCheck build() {
    ref.onDispose(() => _debounce?.cancel());
    return const HandleCheck();
  }

  /// The field changed to [raw]; returns the normalized handle the field
  /// should show. [original] is the handle the account already holds.
  String changed(String raw, {String original = ''}) {
    final handle = HandleCheck.normalize(raw);
    _debounce?.cancel();
    state = HandleCheck.typed(handle, required: args.required, original: original);
    if (state.status == UsernameStatus.checking) {
      _debounce = Timer(debounce, () => unawaited(_check(handle)));
    }
    return handle;
  }

  Future<void> _check(String handle) async {
    final UsernameStatus status;
    try {
      final res = await ref.read(accountApiProvider).checkHandleAvailability(handle);
      status = res.available ? UsernameStatus.available : UsernameStatus.taken;
    } on Object catch (_) {
      // Network / server error — "couldn't verify" (idle), never a
      // false-available. A genuinely taken handle still fails at claim time.
      if (!ref.mounted || state.handle != handle) return;
      state = state.withStatus(UsernameStatus.idle);
      return;
    }
    // A stale answer for a handle no longer in the field is ignored.
    if (!ref.mounted || state.handle != handle) return;
    state = state.withStatus(status);
  }

  /// Save was tried with the field empty.
  void markRequired() {
    _debounce?.cancel();
    state = HandleCheck(handle: state.handle, status: UsernameStatus.required);
  }

  /// The claim was refused: someone holds it.
  void markTaken() => state = state.withStatus(UsernameStatus.taken);

  /// The field shows [handle], the account's own (seeded, restored or just
  /// claimed): nothing to check.
  void settle(String handle) {
    _debounce?.cancel();
    state = HandleCheck(handle: handle);
  }
}

final NotifierProviderFamily<HandleCheckController, HandleCheck, HandleCheckKey> handleCheckProvider =
    NotifierProvider.autoDispose.family<HandleCheckController, HandleCheck, HandleCheckKey>(HandleCheckController.new);
