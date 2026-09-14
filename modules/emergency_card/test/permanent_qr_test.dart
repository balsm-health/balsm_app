import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements EmergencyQrApi {}

class _MockSnapshotReader extends Mock implements EmergencySnapshotReader {}

class _FakeBus extends Fake implements EventBus {
  final published = <AppEvent>[];
  @override
  void publish(AppEvent event) => published.add(event);
}

/// In-memory stand-in for the keystore-backed store.
class _MemStorage extends Fake implements SecureStorageWrapper {
  final map = <String, String>{};
  @override
  Future<String?> readToken(String key) async => map[key];
  @override
  Future<void> writeToken(String key, String value) async => map[key] = value;
  @override
  Future<void> deleteToken(String key) async => map.remove(key);
}

EmergencyCardSnapshot _snap([String blood = 'O+']) => EmergencyCardSnapshot(
      bloodType: blood,
      allergyNames: const ['Penicillin'],
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(
        const MintQrRequest(ciphertextBase64: '', ttlSeconds: 0, profileEtag: '', preferredLanguage: 'en'));
    registerFallbackValue(
        const UpdateQrCiphertextRequest(ciphertextBase64: '', profileEtag: '', preferredLanguage: 'en'));
  });

  group('PermanentQrStore', () {
    test('round-trips a record and clears it', () async {
      final store = PermanentQrStore(storage: _MemStorage());

      await store.write(const PermanentQrRecord(jti: 'j1', keyB64Url: 'k', etag: 'e1', qrUrl: 'https://x/j1#k=k'));
      final read = await store.read();

      expect(read!.jti, 'j1');
      expect(read.etag, 'e1');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('drops a corrupt record instead of crashing', () async {
      final mem = _MemStorage()..map['emergency_qr_permanent'] = 'not-json';
      final store = PermanentQrStore(storage: mem);

      expect(await store.read(), isNull);
      expect(mem.map, isEmpty);
    });
  });

  group('MintEmergencyQrTokenUseCase (permanent)', () {
    test('ttl 0 mints, persists {jti,key,etag}, token has no expiry', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final mem = _MemStorage();
      final store = PermanentQrStore(storage: mem);
      when(() => reader.readSnapshot()).thenAnswer((_) async => _snap());
      when(() => api.mint(any())).thenAnswer((_) async => const MintQrResponse(tokenId: 'jti-p', expiresAt: null));

      final uc =
          MintEmergencyQrTokenUseCase(api: api, snapshotReader: reader, eventBus: _FakeBus(), permanentStore: store);
      final res = await uc.call(ttlSeconds: 0);

      final m = res.fold((v) => v, (f) => fail('mint failed: $f'));
      expect(m.token.isPermanent, isTrue);
      expect(m.token.expiresAt, isNull);

      final record = await store.read();
      expect(record!.jti, 'jti-p');
      expect(m.qrUrl, contains('#k=${record.keyB64Url}'));
      final sent = verify(() => api.mint(captureAny())).captured.single as MintQrRequest;
      expect(sent.ttlSeconds, 0);
      expect(sent.profileEtag, record.etag);
    });

    test('temporary mint clears a stored permanent record (server revoked it)', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final mem = _MemStorage();
      final store = PermanentQrStore(storage: mem);
      await store.write(const PermanentQrRecord(jti: 'old', keyB64Url: 'k', etag: 'e', qrUrl: 'u'));
      when(() => reader.readSnapshot()).thenAnswer((_) async => _snap());
      when(() => api.mint(any())).thenAnswer(
          (_) async => MintQrResponse(tokenId: 'jti-t', expiresAt: DateTime.now().add(const Duration(hours: 1))));

      final uc =
          MintEmergencyQrTokenUseCase(api: api, snapshotReader: reader, eventBus: _FakeBus(), permanentStore: store);
      await uc.call(ttlSeconds: 3600);

      expect(await store.read(), isNull);
    });
  });

  group('RefreshPermanentQrUseCase', () {
    test('no stored record is a no-op success', () async {
      final api = _MockApi();
      final uc = RefreshPermanentQrUseCase(
          api: api, snapshotReader: _MockSnapshotReader(), permanentStore: PermanentQrStore(storage: _MemStorage()));

      final res = await uc.call();

      expect(res.fold((v) => v, (f) => fail('$f')), isNull);
      verifyNever(() => api.updateCiphertext(any(), any()));
    });

    test('unchanged etag skips the network entirely', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final store = PermanentQrStore(storage: _MemStorage());
      final snap = _snap();
      when(() => reader.readSnapshot()).thenAnswer((_) async => snap);
      await store.write(PermanentQrRecord(jti: 'j', keyB64Url: 'k', etag: snapshotEtag(snap), qrUrl: 'u'));

      final uc = RefreshPermanentQrUseCase(api: api, snapshotReader: reader, permanentStore: store);
      final res = await uc.call();

      expect(res.isSuccess, isTrue);
      verifyNever(() => api.updateCiphertext(any(), any()));
    });

    test('changed snapshot re-encrypts with the SAME key and updates etag', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final store = PermanentQrStore(storage: _MemStorage());
      final aes = AesGcm.with256bits();
      final key = await aes.newSecretKey();
      final keyBytes = await key.extractBytes();
      final keyB64Url = base64Url.encode(keyBytes).replaceAll('=', '');
      final newSnap = _snap('A-');
      when(() => reader.readSnapshot()).thenAnswer((_) async => newSnap);
      when(() => api.updateCiphertext(any(), any())).thenAnswer((_) async {});
      await store.write(PermanentQrRecord(jti: 'j', keyB64Url: keyB64Url, etag: 'stale', qrUrl: 'u'));

      final uc = RefreshPermanentQrUseCase(api: api, snapshotReader: reader, permanentStore: store);
      final res = await uc.call();

      expect(res.isSuccess, isTrue);
      final captured = verify(() => api.updateCiphertext('j', captureAny())).captured;
      final req = captured.single as UpdateQrCiphertextRequest;
      expect(req.profileEtag, snapshotEtag(newSnap));

      // The pushed ciphertext must decrypt with the ORIGINAL key.
      final payload = base64.decode(req.ciphertextBase64);
      final box = SecretBox(
        payload.sublist(12, payload.length - 16),
        nonce: payload.sublist(0, 12),
        mac: Mac(payload.sublist(payload.length - 16)),
      );
      final plain = utf8.decode(await aes.decrypt(box, secretKey: key));
      expect(jsonDecode(plain)['bloodType'], 'A-');

      expect((await store.read())!.etag, snapshotEtag(newSnap));
    });

    test('410 from server drops the stale record', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readSnapshot()).thenAnswer((_) async => _snap('B+'));
      when(() => api.updateCiphertext(any(), any())).thenThrow(const ApiException(code: 'gone', statusCode: 410));
      await store.write(const PermanentQrRecord(
          jti: 'j', keyB64Url: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', etag: 'stale', qrUrl: 'u'));

      final res = await uc(api, reader, store).call();

      expect(res.fold((v) => v, (f) => fail('$f')), isNull);
      expect(await store.read(), isNull);
    });

    test('network failure keeps the record for a later retry', () async {
      final api = _MockApi();
      final reader = _MockSnapshotReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readSnapshot()).thenAnswer((_) async => _snap('B+'));
      when(() => api.updateCiphertext(any(), any())).thenThrow(const ApiException(code: 'offline', isOffline: true));
      await store.write(const PermanentQrRecord(
          jti: 'j', keyB64Url: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', etag: 'stale', qrUrl: 'u'));

      final res = await uc(api, reader, store).call();

      expect(res.isFailure, isTrue);
      expect((await store.read())!.etag, 'stale');
    });
  });

  group('RevokeEmergencyQrTokenUseCase', () {
    test('revoking the permanent token clears its stored record', () async {
      final api = _MockApi();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => api.revoke(any())).thenAnswer((_) async {});
      await store.write(const PermanentQrRecord(jti: 'jti-p', keyB64Url: 'k', etag: 'e', qrUrl: 'u'));

      final res = await RevokeEmergencyQrTokenUseCase(api: api, eventBus: _FakeBus(), permanentStore: store)
          .call(tokenId: QrTokenId.value('jti-p'));

      expect(res.isSuccess, isTrue);
      expect(await store.read(), isNull);
    });

    test('revoking another token leaves the permanent record alone', () async {
      final api = _MockApi();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => api.revoke(any())).thenAnswer((_) async {});
      await store.write(const PermanentQrRecord(jti: 'jti-p', keyB64Url: 'k', etag: 'e', qrUrl: 'u'));

      await RevokeEmergencyQrTokenUseCase(api: api, eventBus: _FakeBus(), permanentStore: store)
          .call(tokenId: QrTokenId.value('jti-other'));

      expect(await store.read(), isNotNull);
    });
  });
}

RefreshPermanentQrUseCase uc(EmergencyQrApi api, EmergencySnapshotReader r, PermanentQrStore s) =>
    RefreshPermanentQrUseCase(api: api, snapshotReader: r, permanentStore: s);
