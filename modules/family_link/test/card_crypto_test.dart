import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic card — clearly test data, never a real person.
const _card = EmergencyCardPayload(
  name: 'Test Parent',
  dateOfBirth: '1990-01-01',
  bloodType: 'O+',
  allergies: ['Test allergen'],
  conditions: ['Test condition'],
  contacts: [CardContact(name: 'Test Contact', phone: '+20 100 000 0000', relation: 'Sibling')],
);

const _link = '00000000-0000-0000-0000-0000000000a1';
const _owner = '00000000-0000-0000-0000-000000000002';

void main() {
  final sealer = EciesCardSealer();

  Future<DeviceKeyPair> newPair() => SecureDeviceKeyStore(storage: FakeSecureStorage(), accountId: 'a').ensure();

  Future<SealedCard> sealFor(DeviceKeyPair viewer, {int version = 1}) =>
      sealer.seal(_card, viewerPublicKey: viewer.publicKey, linkId: _link, ownerAccountId: _owner, version: version);

  test('a card sealed for a key opens with that key, every field intact', () async {
    final viewer = await newPair();
    final sealed = await sealFor(viewer, version: 7);

    final opened = await sealer.open(sealed, keyPair: viewer, linkId: _link, ownerAccountId: _owner);

    expect(opened.isSuccess, isTrue);
    final card = opened.value;
    expect(card.name, 'Test Parent');
    expect(card.dateOfBirth, '1990-01-01');
    expect(card.bloodType, 'O+');
    expect(card.allergies, ['Test allergen']);
    expect(card.conditions, ['Test condition']);
    expect(card.contacts.single.phone, '+20 100 000 0000');
    expect(card.contacts.single.relation, 'Sibling');
    expect(sealed.version, 7);
    expect(sealed.nonce, hasLength(12));
    expect(sealed.ephemeralPublicKey, hasLength(32));
  });

  test('every seal uses a fresh ephemeral key and nonce', () async {
    final viewer = await newPair();

    final a = await sealFor(viewer);
    final b = await sealFor(viewer);

    expect(a.ephemeralPublicKey, isNot(equals(b.ephemeralPublicKey)));
    expect(a.ciphertext, isNot(equals(b.ciphertext)));
  });

  test('a card does not open with another key', () async {
    final sealed = await sealFor(await newPair());

    final opened = await sealer.open(sealed, keyPair: await newPair(), linkId: _link, ownerAccountId: _owner);

    expect(opened.error, isA<ValidationFailure>());
  });

  test('a tampered ciphertext does not open', () async {
    final viewer = await newPair();
    final sealed = await sealFor(viewer);
    final bytes = Uint8List.fromList(sealed.ciphertext)..[0] ^= 0x01;
    final tampered = SealedCard(
      version: sealed.version,
      ephemeralPublicKey: sealed.ephemeralPublicKey,
      nonce: sealed.nonce,
      ciphertext: bytes,
    );

    final opened = await sealer.open(tampered, keyPair: viewer, linkId: _link, ownerAccountId: _owner);

    expect(opened.error, isA<ValidationFailure>());
  });

  test('the AAD binds link, owner and version', () async {
    final viewer = await newPair();
    final sealed = await sealFor(viewer, version: 5);
    final rolledBack = SealedCard(
      version: 4,
      ephemeralPublicKey: sealed.ephemeralPublicKey,
      nonce: sealed.nonce,
      ciphertext: sealed.ciphertext,
    );

    final otherLink = await sealer.open(sealed, keyPair: viewer, linkId: 'another-link', ownerAccountId: _owner);
    final otherOwner = await sealer.open(sealed, keyPair: viewer, linkId: _link, ownerAccountId: 'someone-else');
    final otherVersion = await sealer.open(rolledBack, keyPair: viewer, linkId: _link, ownerAccountId: _owner);

    expect(otherLink.error, isA<ValidationFailure>());
    expect(otherOwner.error, isA<ValidationFailure>());
    expect(otherVersion.error, isA<ValidationFailure>());
  });

  test('a truncated card is refused without throwing', () async {
    final viewer = await newPair();
    final sealed = await sealFor(viewer);
    final short = SealedCard(
      version: sealed.version,
      ephemeralPublicKey: sealed.ephemeralPublicKey,
      nonce: sealed.nonce,
      ciphertext: Uint8List(4),
    );

    final opened = await sealer.open(short, keyPair: viewer, linkId: _link, ownerAccountId: _owner);

    expect(opened.error, isA<ValidationFailure>());
  });

  test('the device key pair is kept in the secure store and reused', () async {
    final storage = FakeSecureStorage();

    final first = await SecureDeviceKeyStore(storage: storage, accountId: 'acct').ensure();
    final again = await SecureDeviceKeyStore(storage: storage, accountId: 'acct').ensure();
    final otherAccount = await SecureDeviceKeyStore(storage: storage, accountId: 'other').ensure();

    expect(again.publicKey, first.publicKey);
    expect(again.privateKey, first.privateKey);
    expect(otherAccount.publicKey, isNot(equals(first.publicKey)));
  });

  test('the fingerprint changes with any field and not otherwise', () async {
    const same = EmergencyCardPayload(
      name: 'Test Parent',
      dateOfBirth: '1990-01-01',
      bloodType: 'O+',
      allergies: ['Test allergen'],
      conditions: ['Test condition'],
      contacts: [CardContact(name: 'Test Contact', phone: '+20 100 000 0000', relation: 'Sibling')],
    );
    const changed = EmergencyCardPayload(name: 'Test Parent', bloodType: 'A+');

    expect(await same.fingerprint(), await _card.fingerprint());
    expect(await changed.fingerprint(), isNot(await _card.fingerprint()));
  });
}
