import 'dart:convert';

import 'package:core/core.dart';

import '../../application/ports/link_local_store.dart';
import '../../domain/entities/family_link.dart';

/// [LinkLocalStore] as one JSON map in the platform secure store, per
/// account. The scanned identity in it is PHI — never logged.
class SecureLinkLocalStore implements LinkLocalStore {
  SecureLinkLocalStore({required SecureStorageWrapper storage, required String accountId})
      : _storage = storage,
        _key = 'balsm.family_link.links.$accountId';

  final SecureStorageWrapper _storage;
  final String _key;

  @override
  Future<Map<String, LinkLocalState>> readAll() async {
    final raw = await _storage.readToken(_key);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in json.entries) e.key: _decode(e.value as Map<String, dynamic>)};
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  @override
  Future<LinkLocalState> read(String linkId) async => (await readAll())[linkId] ?? const LinkLocalState();

  @override
  Future<void> write(String linkId, LinkLocalState state) async {
    final all = await readAll();
    all[linkId] = state;
    await _save(all);
  }

  @override
  Future<void> remove(String linkId) async {
    final all = await readAll();
    if (all.remove(linkId) != null) await _save(all);
  }

  Future<void> _save(Map<String, LinkLocalState> all) =>
      _storage.writeToken(_key, jsonEncode({for (final e in all.entries) e.key: _encode(e.value)}));

  static Map<String, dynamic> _encode(LinkLocalState s) => {
        'share': s.cardSharing,
        'fp': s.sealedFingerprint,
        'ver': s.sealedVersion,
        'key': s.uploadedKey,
        if (s.scanned != null) 'scan': s.scanned!.toJson(),
      };

  static LinkLocalState _decode(Map<String, dynamic> j) => LinkLocalState(
        cardSharing: j['share'] as bool? ?? false,
        sealedFingerprint: j['fp'] as String?,
        sealedVersion: (j['ver'] as num?)?.toInt() ?? 0,
        uploadedKey: j['key'] as String?,
        scanned: j['scan'] is Map<String, dynamic> ? ScannedIdentity.fromJson(j['scan'] as Map<String, dynamic>) : null,
      );
}
