import 'dart:convert';

import 'package:core/core.dart';

import '../../domain/events/user_signed_in.dart';
import 'offline_password_hasher.dart';

sealed class UnlockResult {
  const UnlockResult();
}

class Unlocked extends UnlockResult {
  const Unlocked();
}

class WrongPassword extends UnlockResult {
  const WrongPassword(this.failures);
  final int failures;
}

class LockedUntil extends UnlockResult {
  const LockedUntil(this.until);
  final DateTime until;
}

/// Device-only account: created with no network, unlocked by a password that
/// is checked on the device. PHI constraint: never log email, id or password.
class OfflineAccountService {
  OfflineAccountService({
    required SecureStorageWrapper storage,
    required OfflinePasswordHasher hasher,
    required EventBus eventBus,
    DateTime Function()? now,
  })  : _s = storage,
        _hasher = hasher,
        _bus = eventBus,
        _now = now ?? (() => DateTime.now().toUtc());

  final SecureStorageWrapper _s;
  final OfflinePasswordHasher _hasher;
  final EventBus _bus;
  final DateTime Function() _now;

  static const kUserId = 'balsm.user_id';
  static const kEmail = 'balsm.offline.email';
  static const kHash = 'balsm.offline.pw_hash';
  static const kPlain = 'balsm.offline.pw_plain';
  static const kLockout = 'balsm.offline.lockout';
  static const kPendingMerge = 'balsm.pending_merge';
  static const kRefreshToken = 'balsm.refresh_token';

  static const minPasswordLength = 8;
  static const _freeAttempts = 4; // the 5th failure starts the first wait
  static const _waits = [30, 60, 300, 900, 3600];

  Future<String> create({required String email, required String password}) async {
    if (password.length < minPasswordLength) {
      throw ArgumentError.value('<redacted>', 'password', 'must be at least $minPasswordLength characters');
    }
    // A stale lockout/pending-merge from a previous device-only account must
    // never carry into a new one — otherwise a freshly created account could
    // start locked, or wrongly flagged for merge.
    await _s.deleteToken(kLockout);
    await _s.deleteToken(kPendingMerge);
    final id = UuidV7.generate().toString();
    final normalized = email.trim().toLowerCase();
    final hash = await _hasher.hash(password);
    await _s.writeToken(kEmail, normalized);
    await _s.writeToken(kHash, hash);
    await _s.writeToken(kPlain, password);
    await _s.writeToken(kUserId, id);
    // Mode last: a crash before this leaves an ordinary signed-out install.
    await _s.writeToken(kAccountModeKey, AccountMode.deviceOnly.wire);
    _bus.publish(UserSignedIn(userId: UserId.value(id), email: normalized, provider: 'device'));
    return id;
  }

  Future<AccountMode> mode() async => AccountMode.fromWire(await _s.readToken(kAccountModeKey));

  /// Cleans up a `create()` that crashed before it could write
  /// `balsm.account_mode` (the last write `create()` makes). Call this once,
  /// at app bootstrap, *before* anything reads [mode] — a later task wires
  /// that call in.
  ///
  /// `balsm.account_mode` absent means `create()` never finished:
  /// `markOnline()` always writes an explicit `'online'`, so a missing key
  /// can't be a completed account of either mode. If any offline-account key
  /// is present in that state, it is an orphan from the crash and is
  /// deleted, along with `balsm.pending_merge`. `balsm.user_id` is deleted
  /// too, but only if `balsm.refresh_token` is absent — a present refresh
  /// token means a real online session owns that id, which this must never
  /// disturb. Once `create()` has completed (mode `deviceOnly`) or
  /// `markOnline()` has run (mode `online`, where a lingering `pw_plain` is
  /// the legitimate pending `SetPassword`, not an orphan), this is a no-op.
  Future<void> discardIncompleteCreate() async {
    if (await _s.readToken(kAccountModeKey) != null) return;
    final orphaned = await _s.readToken(kEmail) != null ||
        await _s.readToken(kHash) != null ||
        await _s.readToken(kPlain) != null ||
        await _s.readToken(kLockout) != null;
    if (!orphaned) return;
    for (final k in [kEmail, kHash, kPlain, kLockout, kPendingMerge]) {
      await _s.deleteToken(k);
    }
    if (await _s.readToken(kRefreshToken) == null) {
      await _s.deleteToken(kUserId);
    }
  }

  Future<LockedUntil?> lockout() async {
    final st = await _readLockout();
    if (st.until != null && _now().isBefore(st.until!)) return LockedUntil(st.until!);
    return null;
  }

  Future<UnlockResult> unlock(String password) async {
    final locked = await lockout();
    if (locked != null) return locked;
    final hash = await _s.readToken(kHash);
    if (hash != null && await _hasher.verify(password, hash)) {
      await _s.deleteToken(kLockout);
      return const Unlocked();
    }
    final st = await _readLockout();
    final failures = st.failures + 1;
    DateTime? until;
    if (failures > _freeAttempts) {
      final i = (failures - _freeAttempts - 1).clamp(0, _waits.length - 1);
      until = _now().add(Duration(seconds: _waits[i]));
    }
    await _s.writeToken(kLockout, jsonEncode({'failures': failures, 'until': until?.toIso8601String()}));
    return until == null ? WrongPassword(failures) : LockedUntil(until);
  }

  Future<({String email, String password})?> pendingCredentials() async {
    final pw = await _s.readToken(kPlain);
    if (pw == null) return null;
    return (email: await _s.readToken(kEmail) ?? '', password: pw);
  }

  Future<void> clearPlainPassword() => _s.deleteToken(kPlain);

  Future<void> markOnline() async {
    await _s.writeToken(kAccountModeKey, AccountMode.online.wire);
    await _s.deleteToken(kEmail);
    await _s.deleteToken(kHash);
    await _s.deleteToken(kLockout);
  }

  Future<void> setPendingMerge(bool pending) =>
      pending ? _s.writeToken(kPendingMerge, 'true') : _s.deleteToken(kPendingMerge);

  Future<bool> pendingMerge() async => await _s.readToken(kPendingMerge) == 'true';

  Future<void> wipe() async {
    for (final k in [kEmail, kHash, kPlain, kLockout, kPendingMerge, kAccountModeKey, kUserId]) {
      await _s.deleteToken(k);
    }
  }

  Future<({int failures, DateTime? until})> _readLockout() async {
    final raw = await _s.readToken(kLockout);
    if (raw == null) return (failures: 0, until: null);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final u = m['until'] as String?;
    return (failures: m['failures'] as int? ?? 0, until: u == null ? null : DateTime.parse(u));
  }
}
