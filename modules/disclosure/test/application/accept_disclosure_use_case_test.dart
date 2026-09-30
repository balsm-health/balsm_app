import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:disclosure/src/application/use_cases/accept_disclosure_use_case.dart';
import 'package:disclosure/src/domain/aggregates/disclosure_acceptance.dart';
import 'package:disclosure/src/domain/value_objects/ids.dart';
import 'package:disclosure/src/infrastructure/drift/disclosure_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDisclosureDao extends Mock implements DisclosureDao {}

class _MockDisclosureApi extends Mock implements DisclosureApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(const DisclosureId.value(''));
    registerFallbackValue(AcceptDisclosureRequest(
      disclosureId: '',
      version: '',
      countryCode: '',
      supervisoryAuthority: '',
      preferredLanguage: '',
    ));
  });

  late _MockDisclosureDao dao;
  late _MockDisclosureApi api;
  late EventBus eventBus;
  late AcceptDisclosureUseCase usecase;

  setUp(() {
    dao = _MockDisclosureDao();
    api = _MockDisclosureApi();
    eventBus = EventBus();
    usecase = AcceptDisclosureUseCase(dao: dao, api: api, eventBus: eventBus);
  });

  group('resync', () {
    test('sends the stored acceptance', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(DisclosureAcceptance(
            disclosureId: const DisclosureId.value('consolidated'),
            version: 'v1',
            countryCodeAtAccept: 'EG',
            supervisoryAuthorityNameAtAccept: 'PDPC',
            preferredLanguageAtAccept: 'ar',
            acceptedAt: DateTime.utc(2026, 10, 1),
          )));
      when(() => api.accept(any())).thenAnswer((_) async {});
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isTrue);
      final sent = verify(() => api.accept(captureAny())).captured.single as AcceptDisclosureRequest;
      expect(sent.disclosureId, 'consolidated');
      expect(sent.version, 'v1');
      expect(sent.countryCode, 'EG');
      expect(sent.supervisoryAuthority, 'PDPC');
      expect(sent.preferredLanguage, 'ar');
    });

    test('nothing stored → false, no call', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(null));
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isFalse);
      verifyNever(() => api.accept(any()));
    });

    test('API failure → false, no throw', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(DisclosureAcceptance(
            disclosureId: const DisclosureId.value('consolidated'),
            version: 'v1',
            countryCodeAtAccept: 'EG',
            supervisoryAuthorityNameAtAccept: 'PDPC',
            preferredLanguageAtAccept: 'ar',
            acceptedAt: DateTime.utc(2026, 10, 1),
          )));
      when(() => api.accept(any())).thenThrow(Exception('offline'));
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isFalse);
    });

    test('DAO error → false, no throw, API never called', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.error(Exception('db')));
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isFalse);
      verifyNever(() => api.accept(any()));
    });
  });
}
