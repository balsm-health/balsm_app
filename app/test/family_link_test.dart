import 'dart:convert';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/family/profile_own_emergency_card.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/family/family_screen.dart';
import 'package:app/balsm_app/screens/family/linked_member_screen.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:account/account.dart' show ProfileDetails;
import 'package:profile/profile.dart';

/// Family links behind `family_link` + `mother_child`: the scan row, incoming
/// requests, the pending badge, a linked member's read-only shared card — and
/// nothing of it with the flag off. Every name and value is invented.
void main() {
  const user = UserId.value('00000000-0000-0000-0000-000000000001');
  const other = '00000000-0000-0000-0000-000000000002';
  const linkId = '00000000-0000-0000-0000-0000000000a1';
  late AppDatabase db;
  late FakeSecureStorage storage;
  late FakeFamilyLinksApi api;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = FakeSecureStorage();
    api = FakeFamilyLinksApi();
  });
  tearDown(() => db.close());

  PatientAppState appState({bool family = true, bool links = true}) {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)
      ..setOverride(AppFlags.motherChild, family)
      ..setOverride(AppFlags.familyLink, links);
    return PatientAppState()..attachFlags(flags);
  }

  void seedLink({required String status, required String direction, String? name, String? handle}) =>
      api.links[linkId] = FamilyLinkResponse(
        id: linkId,
        relation: 'daughter',
        status: status,
        direction: direction,
        createdAt: DateTime.utc(2026, 9, 1),
        otherAccountId: status == 'linked' || direction == 'incoming' ? other : null,
        otherDisplayName: name,
        otherHandle: handle,
      );

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState state) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(user),
      secureStorageProvider.overrideWithValue(storage),
      familyLinksApiProvider.overrideWithValue(api),
      familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
      accountSummaryProvider.overrideWith((ref) async => const AccountSummary(
            id: user,
            displayName: 'Test Holder',
            countryCode: 'EG',
            preferredLanguage: 'en',
            deletionState: 'ACTIVE',
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: Scaffold(body: screen),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  test('family links need Mother & Child on as well', () {
    expect(familyLinkOn(appState().flags), isTrue);
    expect(familyLinkOn(appState(family: false).flags), isFalse);
    expect(familyLinkOn(appState(links: false).flags), isFalse);
    expect(AppFlags.familyLink.fallback, isFalse);
  });

  group('ProfileOwnEmergencyCard (port → profile + account modules)', () {
    test('reads blood type from the self profile and name and birth date from the account', () async {
      final profiles = DriftProfileDataSource(db: db, activeUser: () => user);
      final selfId = await db.ensureSelfHealthProfile(user);
      final self = (await profiles.getProfile(user))!;
      await profiles.put(selfId, self.copyWith(bloodType: BloodType.bPositive), scope: user);
      final reader = ProfileOwnEmergencyCard(
        profiles: profiles,
        details: () async => const ProfileDetails(firstName: 'Test', lastName: 'Holder', dateOfBirth: '1990-01-01'),
        activeUser: () => user,
      );

      final card = (await reader.read())!;

      expect(card.name, 'Test Holder');
      expect(card.dateOfBirth, '1990-01-01');
      expect(card.bloodType, 'B+');
      expect(card.allergies, isEmpty);
    });

    test('unreachable account details read as no card, so a shared one is left as it is', () async {
      final reader = ProfileOwnEmergencyCard(
        profiles: DriftProfileDataSource(db: db, activeUser: () => user),
        details: () async => throw const ApiException(code: 'network_error', isOffline: true),
        activeUser: () => user,
      );

      expect(await reader.read(), isNull);
    });
  });

  group('Add family member sheet', () {
    Future<void> openSheet(WidgetTester tester, PatientAppState state) async {
      await pump(tester, const FamilyScreen(), state);
      await tester.tap(find.text(state.strings.family.add_member));
      await tester.pumpAndSettle();
    }

    testWidgets('offers "Scan their QR code" with family links on', (tester) async {
      final state = appState();
      await openSheet(tester, state);

      expect(find.text(state.strings.family.manual_t), findsOne);
      expect(find.text(state.strings.family.scan_t), findsOne);
      expect(find.text(state.strings.family.scan_b), findsOne);
    });

    testWidgets('manual entry only with family links off', (tester) async {
      final state = appState(links: false);
      await openSheet(tester, state);

      expect(find.text(state.strings.family.manual_t), findsOne);
      expect(find.text(state.strings.family.scan_t), findsNothing);
    });
  });

  group('Family screen', () {
    testWidgets('an incoming request shows with a dot on the profile bar; approving links it', (tester) async {
      final state = appState();
      final f = state.strings.family;
      seedLink(status: 'pending', direction: 'incoming', name: 'Test Requester', handle: 'test_requester');

      await pump(tester, const FamilyScreen(), state);

      expect(find.text(f.link_requests), findsOne);
      expect(find.text('Test Requester'), findsOne);
      expect(find.text(f.link_asks(f.pick_daughter)), findsOne);
      expect(find.byKey(const ValueKey('family-link-dot')), findsOne);

      await tester.tap(find.text(state.strings.common.fam_approve));
      await tester.pumpAndSettle();

      expect(api.links[linkId]!.status, 'linked');
      expect(api.sentKeys[linkId], isNotNull, reason: 'approval carries this phone key');
      expect(find.text(f.link_requests), findsNothing);
      expect(find.text(f.link_read_only), findsOne);
      expect(find.byKey(const ValueKey('family-link-dot')), findsNothing);
    });

    testWidgets('declining ends the request', (tester) async {
      final state = appState();
      seedLink(status: 'pending', direction: 'incoming', name: 'Test Requester');
      await pump(tester, const FamilyScreen(), state);

      await tester.tap(find.text(state.strings.common.fam_decline));
      await tester.pumpAndSettle();

      expect(api.links[linkId]!.status, 'declined');
      expect(find.text('Test Requester'), findsNothing);
    });

    testWidgets('a sent request shows the scanned name with "Waiting for approval"', (tester) async {
      final state = appState();
      final f = state.strings.family;
      seedLink(status: 'pending', direction: 'outgoing');
      await SecureLinkLocalStore(storage: storage, accountId: user.value)
          .write(linkId, const LinkLocalState(scanned: ScannedIdentity(name: 'Test Scanned')));

      await pump(tester, const FamilyScreen(), state);

      expect(find.text('Test Scanned'), findsOne);
      expect(find.text(f.link_waiting), findsOne);
      expect(find.text(f.rel_daughter), findsOne);
      expect(find.byKey(const ValueKey('family-link-dot')), findsNothing);
    });

    testWidgets('flags off: no link sections and no call to the server', (tester) async {
      final state = appState(links: false);
      seedLink(status: 'pending', direction: 'incoming', name: 'Test Requester');

      await pump(tester, const FamilyScreen(), state);

      expect(find.text('Test Requester'), findsNothing);
      expect(find.text(state.strings.family.link_requests), findsNothing);
      expect(api.calls, isEmpty);
    });
  });

  group('Linked member', () {
    testWidgets('shows their shared card read-only, opened on this phone', (tester) async {
      final state = appState();
      final f = state.strings.family;
      seedLink(status: 'linked', direction: 'outgoing', name: 'Test Linked');
      final me = await SecureDeviceKeyStore(storage: storage, accountId: user.value).ensure();
      final sealed = await EciesCardSealer().seal(
        const EmergencyCardPayload(name: 'Test Linked', bloodType: 'AB-', allergies: ['Test allergen']),
        viewerPublicKey: me.publicKey,
        linkId: linkId,
        ownerAccountId: other,
        version: 2,
      );
      api.cards[linkId] = SealedCardResponse(
        version: 2,
        ephemeralPublicKey: base64.encode(sealed.ephemeralPublicKey),
        nonce: base64.encode(sealed.nonce),
        ciphertext: base64.encode(sealed.ciphertext),
        updatedAt: DateTime.utc(2026, 10, 3, 12),
      );
      final c = await pump(tester, const LinkedMemberScreen(linkId: linkId), state);
      await c.read(familyLinksProvider.future);
      await tester.pumpAndSettle();

      expect(find.text(f.link_read_only), findsOne);
      expect(find.text('AB−'), findsOne);
      expect(find.text('Test allergen'), findsOne);
      expect(find.textContaining(f.link_card_updated('').trim()), findsOne);
      expect(find.text(f.link_share_t), findsOne);
      expect(find.text(f.link_unlink), findsOne);
    });

    testWidgets('"Not shared" when they share nothing; my switch seals my card for them', (tester) async {
      final state = appState();
      final f = state.strings.family;
      seedLink(status: 'linked', direction: 'outgoing', name: 'Test Linked');
      final viewerKey = await SecureDeviceKeyStore(storage: FakeSecureStorage(), accountId: other).ensure();
      api.links[linkId] = FamilyLinkResponse(
        id: linkId,
        relation: 'daughter',
        status: 'linked',
        direction: 'outgoing',
        createdAt: DateTime.utc(2026, 9, 1),
        otherAccountId: other,
        otherDisplayName: 'Test Linked',
        otherPublicKey: base64.encode(viewerKey.publicKey),
      );
      final c = await pump(tester, const LinkedMemberScreen(linkId: linkId), state);
      await c.read(familyLinksProvider.future);
      await tester.pumpAndSettle();

      expect(find.text(f.link_card_not_shared), findsOne);
      expect(find.text(f.link_share_b(state.gender)), findsOne);

      // Unbound card reader in this test: nothing to seal, so sharing fails
      // closed and nothing reaches the server.
      await tester.tap(find.byType(PSwitch));
      await tester.pumpAndSettle();

      expect(api.sentCards, isEmpty);
      expect(find.text(f.link_share_failed(state.gender)), findsOne);
    });
  });
}
