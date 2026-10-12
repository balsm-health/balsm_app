import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements EmergencyQrApi {}

class _MockIdentityReader extends Mock implements ProfileIdentityReader {}

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

ProfileQrPayload _snap([String name = 'Jane Doe']) => ProfileQrPayload(
      name: name,
      dateOfBirth: '1990-01-01',
      gender: 'female',
      lang: 'en',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const MintQrRequest(ciphertextBase64: '', ttlSeconds: 0, profileEtag: ''));
    registerFallbackValue(const UpdateQrCiphertextRequest(ciphertextBase64: '', profileEtag: ''));
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
      final reader = _MockIdentityReader();
      final mem = _MemStorage();
      final store = PermanentQrStore(storage: mem);
      when(() => reader.readIdentity()).thenAnswer((_) async => _snap());
      when(() => api.mint(any())).thenAnswer((_) async => const MintQrResponse(tokenId: 'jti-p', expiresAt: null));

      final uc =
          MintEmergencyQrTokenUseCase(api: api, identityReader: reader, eventBus: _FakeBus(), permanentStore: store);
      final res = await uc.call(ttlSeconds: 0);

      final m = res.fold((v) => v, (f) => fail('mint failed: $f'));
      expect(m.token.isPermanent, isTrue);
      expect(m.token.expiresAt, isNull);

      final record = await store.read();
      // jti is generated ON-DEVICE (offline-first) and sent as token_id.
      final sent = verify(() => api.mint(captureAny())).captured.single as MintQrRequest;
      expect(sent.tokenId, record!.jti);
      expect(sent.ttlSeconds, 0);
      expect(sent.profileEtag, record.etag);
      expect(m.token.jti.value, record.jti);
      expect(m.qrUrl, contains('#k=${record.keyB64Url}'));
      expect(record.synced, isTrue);
    });

    test('offline mint still succeeds — record kept unsynced for later', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readIdentity()).thenAnswer((_) async => _snap());
      when(() => api.mint(any())).thenThrow(const ApiException(code: 'offline', isOffline: true));

      final res = await MintEmergencyQrTokenUseCase(
              api: api, identityReader: reader, eventBus: _FakeBus(), permanentStore: store)
          .call(ttlSeconds: 0);

      final m = res.fold((v) => v, (f) => fail('offline mint failed: $f'));
      final record = await store.read();
      expect(record!.synced, isFalse);
      expect(m.qrUrl, contains(record.jti));
    });

    test('mints even with an empty medical profile — the QR is an identity token', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readIdentity())
          .thenAnswer((_) async => ProfileQrPayload(lang: 'en', createdAt: DateTime.parse('2026-01-01T00:00:00Z')));
      when(() => api.mint(any())).thenAnswer((_) async => const MintQrResponse(tokenId: 'jti-empty', expiresAt: null));

      final res = await MintEmergencyQrTokenUseCase(
              api: api, identityReader: reader, eventBus: _FakeBus(), permanentStore: store)
          .call(ttlSeconds: 0);

      final m = res.fold((v) => v, (f) => fail('mint failed: $f'));
      expect(m.token.isPermanent, isTrue);
      expect((await store.read())!.jti, m.token.jti.value);
    });

    test('temporary mint clears a stored permanent record (server revoked it)', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final mem = _MemStorage();
      final store = PermanentQrStore(storage: mem);
      await store.write(const PermanentQrRecord(jti: 'old', keyB64Url: 'k', etag: 'e', qrUrl: 'u'));
      when(() => reader.readIdentity()).thenAnswer((_) async => _snap());
      when(() => api.mint(any())).thenAnswer(
          (_) async => MintQrResponse(tokenId: 'jti-t', expiresAt: DateTime.now().add(const Duration(hours: 1))));

      final uc =
          MintEmergencyQrTokenUseCase(api: api, identityReader: reader, eventBus: _FakeBus(), permanentStore: store);
      await uc.call(ttlSeconds: 3600);

      expect(await store.read(), isNull);
    });
  });

  group('RefreshPermanentQrUseCase', () {
    test('no stored record is a no-op success', () async {
      final api = _MockApi();
      final uc = RefreshPermanentQrUseCase(
          api: api, identityReader: _MockIdentityReader(), permanentStore: PermanentQrStore(storage: _MemStorage()));

      final res = await uc.call();

      expect(res.fold((v) => v, (f) => fail('$f')), isNull);
      verifyNever(() => api.updateCiphertext(any(), any()));
    });

    test('unchanged etag skips the network entirely', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      final snap = _snap();
      when(() => reader.readIdentity()).thenAnswer((_) async => snap);
      await store.write(PermanentQrRecord(jti: 'j', keyB64Url: 'k', etag: payloadEtag(snap), qrUrl: 'u'));

      final uc = RefreshPermanentQrUseCase(api: api, identityReader: reader, permanentStore: store);
      final res = await uc.call();

      expect(res.isSuccess, isTrue);
      verifyNever(() => api.updateCiphertext(any(), any()));
    });

    test('changed snapshot re-encrypts with the SAME key and updates etag', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      final aes = AesGcm.with256bits();
      final key = await aes.newSecretKey();
      final keyBytes = await key.extractBytes();
      final keyB64Url = base64Url.encode(keyBytes).replaceAll('=', '');
      final newSnap = _snap('A-');
      when(() => reader.readIdentity()).thenAnswer((_) async => newSnap);
      when(() => api.updateCiphertext(any(), any())).thenAnswer((_) async {});
      await store.write(PermanentQrRecord(jti: 'j', keyB64Url: keyB64Url, etag: 'stale', qrUrl: 'u'));

      final uc = RefreshPermanentQrUseCase(api: api, identityReader: reader, permanentStore: store);
      final res = await uc.call();

      expect(res.isSuccess, isTrue);
      final captured = verify(() => api.updateCiphertext('j', captureAny())).captured;
      final req = captured.single as UpdateQrCiphertextRequest;
      expect(req.profileEtag, payloadEtag(newSnap));

      // The pushed ciphertext must decrypt with the ORIGINAL key.
      final payload = base64.decode(req.ciphertextBase64);
      final box = SecretBox(
        payload.sublist(12, payload.length - 16),
        nonce: payload.sublist(0, 12),
        mac: Mac(payload.sublist(payload.length - 16)),
      );
      final plain = utf8.decode(await aes.decrypt(box, secretKey: key));
      expect(jsonDecode(plain)['name'], 'A-');

      expect((await store.read())!.etag, payloadEtag(newSnap));
    });

    test('unsynced record syncs via idempotent mint with its own jti', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      final snap = _snap();
      when(() => reader.readIdentity()).thenAnswer((_) async => snap);
      when(() => api.mint(any())).thenAnswer((_) async => const MintQrResponse(tokenId: 'ignored', expiresAt: null));
      await store.write(PermanentQrRecord(
          jti: 'jti-local',
          keyB64Url: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          etag: payloadEtag(snap),
          qrUrl: 'u',
          synced: false));

      final res = await uc(api, reader, store).call();

      expect(res.isSuccess, isTrue);
      final sent = verify(() => api.mint(captureAny())).captured.single as MintQrRequest;
      expect(sent.tokenId, 'jti-local');
      expect((await store.read())!.synced, isTrue);
      verifyNever(() => api.updateCiphertext(any(), any()));
    });

    test('410 from server drops the stale record', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readIdentity()).thenAnswer((_) async => _snap('B+'));
      when(() => api.updateCiphertext(any(), any())).thenThrow(const ApiException(code: 'gone', statusCode: 410));
      await store.write(const PermanentQrRecord(
          jti: 'j', keyB64Url: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', etag: 'stale', qrUrl: 'u'));

      final res = await uc(api, reader, store).call();

      expect(res.fold((v) => v, (f) => fail('$f')), isNull);
      expect(await store.read(), isNull);
    });

    test('network failure keeps the record for a later retry', () async {
      final api = _MockApi();
      final reader = _MockIdentityReader();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => reader.readIdentity()).thenAnswer((_) async => _snap('B+'));
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

    test('404 on an unsynced local token still clears it — server never saw it', () async {
      final api = _MockApi();
      final store = PermanentQrStore(storage: _MemStorage());
      when(() => api.revoke(any())).thenThrow(const ApiException(code: 'not_found', statusCode: 404));
      await store
          .write(const PermanentQrRecord(jti: 'jti-local', keyB64Url: 'k', etag: 'e', qrUrl: 'u', synced: false));

      final res = await RevokeEmergencyQrTokenUseCase(api: api, eventBus: _FakeBus(), permanentStore: store)
          .call(tokenId: QrTokenId.value('jti-local'));

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

RefreshPermanentQrUseCase uc(EmergencyQrApi api, ProfileIdentityReader r, PermanentQrStore s) =>
    RefreshPermanentQrUseCase(api: api, identityReader: r, permanentStore: s);
