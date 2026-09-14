import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device record of the user's permanent medical-profile QR.
///
/// Holds the token id, the AES-256-GCM key (base64url, no padding), the etag
/// of the last snapshot pushed to the server, and the full QR URL. Lives in
/// the platform keystore ([SecureStorageWrapper]) because the key decrypts
/// PHI; it is never logged and never leaves the device except inside the QR
/// URL fragment itself.
class PermanentQrRecord {
  const PermanentQrRecord({
    required this.jti,
    required this.keyB64Url,
    required this.etag,
    required this.qrUrl,
  });

  final String jti;
  final String keyB64Url;
  final String etag;
  final String qrUrl;

  PermanentQrRecord copyWith({String? etag}) => PermanentQrRecord(
        jti: jti,
        keyB64Url: keyB64Url,
        etag: etag ?? this.etag,
        qrUrl: qrUrl,
      );

  Map<String, dynamic> toJson() => {
        'jti': jti,
        'key': keyB64Url,
        'etag': etag,
        'qrUrl': qrUrl,
      };

  factory PermanentQrRecord.fromJson(Map<String, dynamic> json) => PermanentQrRecord(
        jti: json['jti'] as String,
        keyB64Url: json['key'] as String,
        etag: json['etag'] as String,
        qrUrl: json['qrUrl'] as String,
      );
}

/// Persistence for the (at most one) permanent QR record.
class PermanentQrStore {
  const PermanentQrStore({required SecureStorageWrapper storage}) : _storage = storage;

  static const _key = 'emergency_qr_permanent';

  final SecureStorageWrapper _storage;

  Future<PermanentQrRecord?> read() async {
    final raw = await _storage.readToken(_key);
    if (raw == null) return null;
    try {
      return PermanentQrRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // Corrupt record: drop it — the sheet falls back to the mint affordance.
      await _storage.deleteToken(_key);
      return null;
    }
  }

  Future<void> write(PermanentQrRecord record) => _storage.writeToken(_key, jsonEncode(record.toJson()));

  Future<void> clear() => _storage.deleteToken(_key);
}

final permanentQrStoreProvider = Provider<PermanentQrStore>((ref) {
  return PermanentQrStore(storage: ref.watch(secureStorageProvider));
});
