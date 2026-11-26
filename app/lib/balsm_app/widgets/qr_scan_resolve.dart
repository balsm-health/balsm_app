import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// A successfully scanned + decrypted profile QR.
typedef ScannedProfile = ({String jti, ProfileQrPayload payload});

/// Where a profile-QR scan is: waiting for a code, resolving one, or done.
///
/// PHI: [QrScanFound] holds the decrypted identity; it lives only while the
/// scan view is open (auto-dispose) and is never logged.
@immutable
sealed class QrScanState {
  const QrScanState();
}

final class QrScanIdle extends QrScanState {
  const QrScanIdle();
  @override
  bool operator ==(Object other) => other is QrScanIdle;
  @override
  int get hashCode => (QrScanIdle).hashCode;
}

final class QrScanResolving extends QrScanState {
  const QrScanResolving();
  @override
  bool operator ==(Object other) => other is QrScanResolving;
  @override
  int get hashCode => (QrScanResolving).hashCode;
}

final class QrScanFound extends QrScanState {
  const QrScanFound(this.profile);
  final ScannedProfile profile;
  @override
  bool operator ==(Object other) => other is QrScanFound && other.profile == profile;
  @override
  int get hashCode => profile.hashCode;
}

/// How one code ended, for the view's notice.
enum QrResolveOutcome {
  found,

  /// The account holder's own permanent QR: you cannot add yourself.
  ownCode,

  /// The code could not be resolved or decrypted.
  failed,
}

class QrScanNotifier extends Notifier<QrScanState> {
  QrScanNotifier(this.view);

  /// A token the scan view's State creates once.
  final Object view;

  @override
  QrScanState build() => const QrScanIdle();

  /// Resolves the code with token [jti] and fragment key [key]. Null when a
  /// code is already being resolved or found, or the view closed meanwhile.
  Future<QrResolveOutcome?> resolve({required String jti, required String key}) async {
    if (state is! QrScanIdle) return null;
    state = const QrScanResolving();
    final own = await ref.read(permanentQrStoreProvider).read();
    if (!ref.mounted) return null;
    if (own != null && own.jti == jti) {
      state = const QrScanIdle();
      return QrResolveOutcome.ownCode;
    }
    final result = await ref.read(resolveEmergencyQrTokenUseCaseProvider).call(tokenId: jti, keyBase64Url: key);
    if (!ref.mounted) return null;
    final payload = result.fold((v) => v, (_) => null)?.payload;
    if (payload == null) {
      state = const QrScanIdle();
      return QrResolveOutcome.failed;
    }
    state = QrScanFound((jti: jti, payload: payload));
    return QrResolveOutcome.found;
  }
}

final NotifierProviderFamily<QrScanNotifier, QrScanState, Object> qrScanProvider =
    NotifierProvider.autoDispose.family<QrScanNotifier, QrScanState, Object>(QrScanNotifier.new);
