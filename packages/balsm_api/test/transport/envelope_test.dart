import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

Response<dynamic> _resp(Object? body, {int status = 200}) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: body,
    );

void main() {
  test('unwrapEnvelope returns data map', () {
    final data = unwrapEnvelope(_resp({'data': {'a': 1}, 'error': null}));
    expect(data, {'a': 1});
  });

  test('unwrapEnvelope returns {} when data missing or not a map', () {
    expect(unwrapEnvelope(_resp({'error': null})), isEmpty);
    expect(unwrapEnvelope(_resp('not json')), isEmpty);
    expect(unwrapEnvelope(_resp(null)), isEmpty);
  });

  test('unwrapEnvelope throws ApiException with fromEnvelope on error', () {
    expect(
      () => unwrapEnvelope(_resp({
        'data': null,
        'error': {'code': 'conflict', 'message': 'Handle taken'},
      })),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'conflict')
          .having((e) => e.serverMessage, 'serverMessage', 'Handle taken')
          .having((e) => e.fromEnvelope, 'fromEnvelope', isTrue)),
    );
  });

  test('unwrapEnvelopeList returns list data and throws on error', () {
    expect(unwrapEnvelopeList(_resp({'data': [1, 2]})), [1, 2]);
    expect(unwrapEnvelopeList(_resp({'data': {'not': 'list'}})), isEmpty);
    expect(
      () => unwrapEnvelopeList(_resp({'error': {'message': 'x'}})),
      throwsA(isA<ApiException>()),
    );
  });
}
