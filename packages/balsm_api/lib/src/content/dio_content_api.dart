import 'dart:convert';

import 'package:dio/dio.dart';

import '../api_routes.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'content_api.dart';
import 'responses.dart';

class DioContentApi implements ContentApi {
  const DioContentApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<Revalidated<PregnancyWeeksResponse>> pregnancyWeeks({String? etag, CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.content_pregnancy_weeks,
      cancelToken: cancelToken,
      options: Options(
        headers: {if (etag != null && etag.isNotEmpty) 'If-None-Match': etag},
        validateStatus: (s) => s != null && (s == 304 || (s >= 200 && s < 300)),
        // A 304 has no body and no JSON content type; decode it to null
        // rather than the empty string dio would otherwise hand back.
        responseDecoder: (bytes, _, __) => bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true),
      ),
    );
    if (res.statusCode == 304) return const NotModified();
    return Modified(PregnancyWeeksResponse.fromJson(unwrapEnvelope(res)), etag: res.headers.value('etag'));
  }
}
