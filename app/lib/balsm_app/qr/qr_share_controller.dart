import 'dart:async';

import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// View state of the profile-QR share sheet. Immutable — every transition
/// goes through [QrShareController].
@immutable
class QrShareState {
  const QrShareState({
    this.mint,
    this.ttlSeconds = 86400, // default 24h (FR-017)
    this.minting = false,
    this.revoking = false,
    this.rotating = false,
    this.error,
    this.remaining = Duration.zero,
  });

  /// The active token + its `#k=` fragment URL; null until minted (or after
  /// revoke). The fragment key never leaves the device except inside the QR.
  final MintResult? mint;
  final int ttlSeconds;
  final bool minting;
  final bool revoking;
  final bool rotating;

  /// Mint/revoke failure message, rendered under the affordance.
  final String? error;

  /// Countdown for temporary tokens; permanent tokens ignore it.
  final Duration remaining;

  bool get isPermanent => mint?.token.isPermanent ?? false;
  bool get isExpired => !isPermanent && (mint == null || remaining.isNegative || remaining == Duration.zero);

  static const _unset = Object();

  QrShareState copyWith({
    Object? mint = _unset,
    int? ttlSeconds,
    bool? minting,
    bool? revoking,
    bool? rotating,
    Object? error = _unset,
    Duration? remaining,
  }) =>
      QrShareState(
        mint: identical(mint, _unset) ? this.mint : mint as MintResult?,
        ttlSeconds: ttlSeconds ?? this.ttlSeconds,
        minting: minting ?? this.minting,
        revoking: revoking ?? this.revoking,
        rotating: rotating ?? this.rotating,
        error: identical(error, _unset) ? this.error : error as String?,
        remaining: remaining ?? this.remaining,
      );
}

/// Data controller behind the QR share sheet: restore, mint, revoke, rotate,
/// and the expiry countdown. The sheet keeps only ephemeral view state
/// (toast, export-in-flight, capture key) — per CODING_STANDARDS §7.
///
/// autoDispose: the sheet closing drops the state; reopening restores from
/// the keystore, so nothing token-shaped lingers without a listener.
class QrShareController extends AutoDisposeNotifier<QrShareState> {
  Timer? _ticker;

  @override
  QrShareState build() {
    ref.onDispose(() => _ticker?.cancel());
    // Kick the keystore restore after the first state is installed.
    Future.microtask(_restorePermanent);
    return const QrShareState();
  }

  /// A permanent QR survives sheet/app restarts: {jti, key} live in the
  /// keystore, so the exact same QR is re-displayed. Also kicks a silent
  /// ciphertext refresh in case the identity changed since the last sync.
  Future<void> _restorePermanent() async {
    final record = await ref.read(permanentQrStoreProvider).read();
    if (record == null) return;
    state = state.copyWith(
      mint: (
        token: EmergencyQrToken(
          jti: QrTokenId.value(record.jti),
          expiresAt: null,
          ttlSeconds: kPermanentQrTtlSeconds,
        ),
        qrUrl: record.qrUrl,
      ),
      ttlSeconds: kPermanentQrTtlSeconds,
    );
    unawaited(ref.read(refreshPermanentQrUseCaseProvider)());
  }

  void setTtl(int seconds) => state = state.copyWith(ttlSeconds: seconds);

  /// Mints a token for the selected TTL. Returns true on success; failures —
  /// including the age gate (FR-301b) — land in [QrShareState.error].
  Future<bool> mint() async {
    state = state.copyWith(minting: true, error: null);
    final result = await ref.read(mintEmergencyQrTokenUseCaseProvider).call(ttlSeconds: state.ttlSeconds);
    return result.fold(
      (m) {
        state = state.copyWith(
          mint: m,
          minting: false,
          remaining: m.token.expiresAt?.difference(DateTime.now()) ?? Duration.zero,
        );
        if (!m.token.isPermanent) _startTicker();
        return true;
      },
      (f) {
        state = state.copyWith(minting: false, error: f.message);
        return false;
      },
    );
  }

  /// Revokes the active token; on success the sheet returns to the mint
  /// affordance. Returns true on success.
  Future<bool> revoke() async {
    final m = state.mint;
    if (m == null) return false;
    state = state.copyWith(revoking: true);
    final result = await ref.read(revokeEmergencyQrTokenUseCaseProvider).call(tokenId: m.token.jti);
    return result.fold(
      (_) {
        _ticker?.cancel();
        state = state.copyWith(mint: null, revoking: false, error: null);
        return true;
      },
      (f) {
        state = state.copyWith(revoking: false, error: f.message);
        return false;
      },
    );
  }

  /// Spec v2.0 rotate: revoke + fresh permanent mint in one act. Returns true
  /// on success (caller toasts either way).
  Future<bool> rotate() async {
    state = state.copyWith(rotating: true);
    final result = await ref.read(rotatePermanentQrUseCaseProvider)();
    return result.fold(
      (m) {
        state = state.copyWith(mint: m, rotating: false);
        return true;
      },
      (_) {
        state = state.copyWith(rotating: false);
        return false;
      },
    );
  }

  /// An expired temporary token returns the sheet to the mint affordance.
  void clearExpired() {
    _ticker?.cancel();
    state = state.copyWith(mint: null, error: null, remaining: Duration.zero);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final exp = state.mint?.token.expiresAt;
      if (exp == null) {
        _ticker?.cancel();
        return;
      }
      state = state.copyWith(remaining: exp.difference(DateTime.now()));
    });
  }
}

final qrShareControllerProvider = NotifierProvider.autoDispose<QrShareController, QrShareState>(QrShareController.new);
