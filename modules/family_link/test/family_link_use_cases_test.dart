import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic data only — clearly test values, never a real person.
const _me = '00000000-0000-0000-0000-000000000001';
const _them = '00000000-0000-0000-0000-000000000002';
const _linkId = '00000000-0000-0000-0000-0000000000a1';

class _Card implements OwnEmergencyCardReader {
  EmergencyCardPayload? card = const EmergencyCardPayload(name: 'Test Owner', bloodType: 'O+');
  @override
  Future<EmergencyCardPayload?> read() async => card;
}

/// One account's side: its fake server view, secure store and use cases.
class _Side {
  _Side(this.accountId, {DateTime Function()? now}) {
    keys = SecureDeviceKeyStore(storage: storage, accountId: accountId);
    local = SecureLinkLocalStore(storage: storage, accountId: accountId);
    sharing = SetCardSharingUseCase(
      api: api,
      sealer: sealer,
      local: local,
      card: card,
      ownerAccountId: () => accountId,
      now: now ?? () => DateTime.utc(2026, 10, 1),
    );
    refresh = RefreshFamilyLinksUseCase(api: api, keys: keys, local: local, sharing: sharing);
    request = RequestFamilyLinkUseCase(api: api, keys: keys, local: local, newId: () => _linkId);
    respond = RespondToFamilyLinkUseCase(api: api, keys: keys, local: local);
    end = EndFamilyLinkUseCase(api: api, local: local);
    read = ReadSharedCardUseCase(api: api, sealer: sealer, keys: keys);
  }

  final String accountId;
  final api = FakeFamilyLinksApi();
  final storage = FakeSecureStorage();
  final sealer = EciesCardSealer();
  final card = _Card();
  late final SecureDeviceKeyStore keys;
  late final SecureLinkLocalStore local;
  late final SetCardSharingUseCase sharing;
  late final RefreshFamilyLinksUseCase refresh;
  late final RequestFamilyLinkUseCase request;
  late final RespondToFamilyLinkUseCase respond;
  late final EndFamilyLinkUseCase end;
  late final ReadSharedCardUseCase read;

  Future<String> publicKey() async => base64.encode((await keys.ensure()).publicKey);

  void seed({
    required String status,
    required String direction,
    String? otherKey,
    String relation = 'daughter',
    String? otherName,
  }) =>
      api.links[_linkId] = FamilyLinkResponse(
        id: _linkId,
        relation: relation,
        status: status,
        direction: direction,
        createdAt: DateTime.utc(2026, 9, 1),
        otherAccountId: direction == 'incoming' || status == 'linked' ? _them : null,
        otherDisplayName: otherName,
        otherPublicKey: otherKey,
      );

  Future<FamilyLink> link() async => (await refresh()).value.byId(_linkId)!;
}

void main() {
  group('request', () {
    test('sends the jti, relation and this phone key, and keeps the scan on the phone', () async {
      final a = _Side(_me);
      a.api.knownJtis.add('jti-b');

      final result = await a.request(
        jti: 'jti-b',
        relation: LinkRelation.mother,
        scanned: const ScannedIdentity(name: 'Test Mother', dateOfBirth: '1960-01-01'),
      );

      expect(result.value, _linkId);
      expect(a.api.links[_linkId]!.relation, 'mother');
      expect(a.api.sentKeys[_linkId], await a.publicKey());
      final pending = (await a.refresh()).value.waiting.single;
      expect(pending.displayName, 'Test Mother');
      expect(pending.scanned!.dateOfBirthDay, DateTime(1960));
    });

    test('an unknown code answers NotFound and stores nothing', () async {
      final a = _Side(_me);

      final result = await a.request(jti: 'jti-unknown', relation: LinkRelation.son);

      expect(result.error, isA<NotFoundFailure>());
      expect(await a.local.readAll(), isEmpty);
    });

    test('offline answers OfflineFailure', () async {
      final a = _Side(_me);
      a.api.failWith = const ApiException(code: 'network_error', isOffline: true);

      final result = await a.request(jti: 'jti-b', relation: LinkRelation.son);

      expect(result.error, isA<OfflineFailure>());
    });
  });

  group('refresh', () {
    test('splits requests waiting for me from those I sent', () async {
      final b = _Side(_me);
      b.seed(status: 'pending', direction: 'incoming', otherName: 'Test Requester');

      final links = (await b.refresh()).value;

      expect(links.awaitingMe.single.displayName, 'Test Requester');
    });

    test('sends this phone key where the server holds another, once', () async {
      final b = _Side(_me);
      b.seed(status: 'linked', direction: 'incoming');

      await b.refresh();
      await b.refresh();

      expect(b.api.sentKeys[_linkId], await b.publicKey());
      expect(b.api.calls.where((c) => c.startsWith('putKeys')), hasLength(1));
    });

    test('forgets the phone state of a link that ended', () async {
      final a = _Side(_me);
      await a.local.write(_linkId, const LinkLocalState(scanned: ScannedIdentity(name: 'Test Member')));
      a.seed(status: 'declined', direction: 'outgoing');

      await a.refresh();

      expect(await a.local.readAll(), isEmpty);
    });

    test('a failed pull reports the failure', () async {
      final a = _Side(_me);
      a.api.failWith = const ApiException(code: 'server_error', statusCode: 500);

      expect((await a.refresh()).error, isA<NetworkFailure>());
    });
  });

  group('respond', () {
    test('approve sends this phone key; a second approve is a conflict', () async {
      final b = _Side(_me);
      b.seed(status: 'pending', direction: 'incoming');

      final first = await b.respond.approve(_linkId);
      final second = await b.respond.approve(_linkId);

      expect(first.isSuccess, isTrue);
      expect(b.api.links[_linkId]!.status, 'linked');
      expect(b.api.sentKeys[_linkId], await b.publicKey());
      expect(second.error, isA<ConflictFailure>());
    });

    test('decline ends the request', () async {
      final b = _Side(_me);
      b.seed(status: 'pending', direction: 'incoming');

      final result = await b.respond.decline(_linkId);

      expect(result.isSuccess, isTrue);
      expect(b.api.links[_linkId]!.status, 'declined');
    });
  });

  group('end', () {
    test('cancel withdraws a pending request and forgets the scan', () async {
      final a = _Side(_me);
      a.seed(status: 'pending', direction: 'outgoing');
      await a.local.write(_linkId, const LinkLocalState(scanned: ScannedIdentity(name: 'Test Member')));

      final result = await a.end.cancel(_linkId);

      expect(result.isSuccess, isTrue);
      expect(a.api.links[_linkId]!.status, 'cancelled');
      expect(await a.local.readAll(), isEmpty);
    });

    test('unlink ends a link', () async {
      final b = _Side(_me);
      b.seed(status: 'linked', direction: 'incoming');

      await b.end.unlink(_linkId);

      expect(b.api.links[_linkId]!.status, 'unlinked');
    });
  });

  group('card sharing', () {
    test('a shared card opens on the viewer phone and nowhere else', () async {
      final owner = _Side(_me);
      final viewer = _Side(_them);
      owner.seed(status: 'linked', direction: 'outgoing', otherKey: await viewer.publicKey());

      final on = await owner.sharing(await owner.link(), on: true);
      final sent = owner.api.sentCards[_linkId]!;
      viewer.api.links[_linkId] = FamilyLinkResponse(
        id: _linkId,
        relation: 'daughter',
        status: 'linked',
        direction: 'incoming',
        createdAt: DateTime.utc(2026, 9, 1),
        otherAccountId: _me,
      );
      viewer.api.cards[_linkId] = SealedCardResponse(
        version: sent.version,
        ephemeralPublicKey: sent.ephemeralPublicKey,
        nonce: sent.nonce,
        ciphertext: sent.ciphertext,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      final opened = await viewer.read(await viewer.link());
      final stranger = _Side(_them)
        ..api.links.addAll(viewer.api.links)
        ..api.cards.addAll(viewer.api.cards);
      final notForMe = await stranger.read(await stranger.link());

      expect(on.isSuccess, isTrue);
      expect(opened.value!.card.name, 'Test Owner');
      expect(opened.value!.card.bloodType, 'O+');
      expect(opened.value!.updatedAt, DateTime.utc(2026, 10, 1));
      expect(notForMe.error, isA<ValidationFailure>());
    });

    test('re-seals only when the card or the viewer key changed', () async {
      var clock = DateTime.utc(2026, 10, 1);
      final owner = _Side(_me, now: () => clock);
      final viewer = _Side(_them);
      owner.seed(status: 'linked', direction: 'outgoing', otherKey: await viewer.publicKey());
      await owner.sharing(await owner.link(), on: true);
      final firstVersion = owner.api.sentCards[_linkId]!.version;

      await owner.refresh();
      final unchanged = owner.api.calls.where((c) => c.startsWith('putCard')).length;
      owner.card.card = const EmergencyCardPayload(name: 'Test Owner', bloodType: 'A+');
      clock = clock.add(const Duration(minutes: 1));
      await owner.refresh();
      final afterEdit = owner.api.sentCards[_linkId]!.version;
      owner.seed(status: 'linked', direction: 'outgoing', otherKey: await _Side('new-phone').publicKey());
      clock = clock.add(const Duration(minutes: 1));
      await owner.refresh();

      expect(unchanged, 1);
      expect(afterEdit, greaterThan(firstVersion));
      expect(owner.api.sentCards[_linkId]!.version, greaterThan(afterEdit));
    });

    test('turning sharing off purges the card', () async {
      final owner = _Side(_me);
      owner.seed(status: 'linked', direction: 'outgoing', otherKey: await _Side(_them).publicKey());
      await owner.sharing(await owner.link(), on: true);

      await owner.sharing(await owner.link(), on: false);

      expect(owner.api.sentCards, isEmpty);
      expect((await owner.link()).cardSharing, isFalse);
    });

    test('a pending request cannot carry a card', () async {
      final owner = _Side(_me);
      owner.seed(status: 'pending', direction: 'outgoing');

      final result = await owner.sharing(await owner.link(), on: true);

      expect(result.error, isA<ConflictFailure>());
      expect(owner.api.sentCards, isEmpty);
    });

    test('an unreadable own card leaves the shared card as it was', () async {
      final owner = _Side(_me);
      owner.seed(status: 'linked', direction: 'outgoing', otherKey: await _Side(_them).publicKey());
      owner.card.card = null;

      final result = await owner.sharing(await owner.link(), on: true);

      expect(result.error, isA<StorageFailure>());
      expect(owner.api.sentCards, isEmpty);
    });

    test('nothing shared reads as null', () async {
      final viewer = _Side(_them);
      viewer.seed(status: 'linked', direction: 'incoming');

      final result = await viewer.read(await viewer.link());

      expect(result.value, isNull);
    });
  });
}
