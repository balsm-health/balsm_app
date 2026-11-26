import 'package:app/balsm_app/widgets/add_family_member_draft.dart';
import 'package:app/balsm_app/widgets/qr_scan_resolve.dart';
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account sheet's add-member draft and the profile-QR scan state, with
/// no widget or camera involved. Every value is synthetic.
void main() {
  final payload =
      ProfileQrPayload(lang: 'en', createdAt: DateTime(2020), name: 'Test Person', dateOfBirth: '2001-02-03');

  group('AddFamilyMemberDraft', () {
    test('a scan fills the name and date of birth and keeps the relation', () {
      final d = const AddFamilyMemberDraft(relation: 'Sibling').applyScan((jti: 'jti-test', payload: payload));
      expect((d.name, d.relation, d.dob, d.scanned?.jti), ('Test Person', 'Sibling', DateTime(2001, 2, 3), 'jti-test'));
    });

    test('a name needs two letters and must not be the account holder', () {
      const d = AddFamilyMemberDraft();
      expect(d.withName('A').canSave, isFalse);
      expect(d.withName('Ab').canSave, isTrue);
      expect(d.withName(' test self ').isSelf('Test Self'), isTrue);
      expect(d.withName('Test Self').isSelf(''), isFalse);
    });

    test('one draft per sheet token', () {
      final c = ProviderContainer(retry: noProviderRetry);
      addTearDown(c.dispose);
      final a = Object();
      c.read(addFamilyMemberDraftProvider(a).notifier).setRelation('Other');
      expect(c.read(addFamilyMemberDraftProvider(a)).relation, 'Other');
      expect(c.read(addFamilyMemberDraftProvider(Object())).relation, '');
    });
  });

  group('QrScanNotifier', () {
    ProviderContainer scanWith({PermanentQrRecord? own, ProfileQrPayload? resolved}) {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          permanentQrStoreProvider.overrideWithValue(_FakeOwnQr(own)),
          resolveEmergencyQrTokenUseCaseProvider.overrideWithValue(_FakeResolve(resolved)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a resolved code is found and hands over its profile', () async {
      final c = scanWith(resolved: payload);
      final view = Object();
      final sub = c.listen(qrScanProvider(view), (_, __) {});
      expect(await c.read(qrScanProvider(view).notifier).resolve(jti: 'jti-test', key: 'k'), QrResolveOutcome.found);
      expect(sub.read(), QrScanFound((jti: 'jti-test', payload: payload)));
      expect(
        await c.read(qrScanProvider(view).notifier).resolve(jti: 'other', key: 'k'),
        isNull,
        reason: 'one code per scan',
      );
    });

    test('your own code and an unreadable code go back to scanning', () async {
      const own =
          PermanentQrRecord(jti: 'jti-own', keyB64Url: 'k', etag: 'e', qrUrl: 'https://example.invalid/t/jti-own');
      final c = scanWith(own: own);
      final view = Object();
      final sub = c.listen(qrScanProvider(view), (_, __) {});
      final n = c.read(qrScanProvider(view).notifier);
      expect(await n.resolve(jti: 'jti-own', key: 'k'), QrResolveOutcome.ownCode);
      expect(sub.read(), const QrScanIdle());
      expect(await n.resolve(jti: 'jti-other', key: 'k'), QrResolveOutcome.failed);
      expect(sub.read(), const QrScanIdle());
    });
  });
}

class _FakeOwnQr implements PermanentQrStore {
  _FakeOwnQr(this.own);
  final PermanentQrRecord? own;

  @override
  Future<PermanentQrRecord?> read() async => own;

  // Only read() is used by the scan; anything else is a test bug and throws.
  // `dynamic` is noSuchMethod's own signature.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResolve implements ResolveEmergencyQrTokenUseCase {
  _FakeResolve(this.payload);
  final ProfileQrPayload? payload;

  @override
  Future<AppResult<ResolvedProfileQr>> call({required String tokenId, required String keyBase64Url}) async =>
      switch (payload) {
        final p? => AppResult.success((payload: p, type: ProfileQrPayload.kindProfile)),
        _ => AppResult.failure(const ValidationFailure('unreadable')),
      };
}
