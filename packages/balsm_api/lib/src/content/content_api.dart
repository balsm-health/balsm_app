import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'responses.dart';

/// Platform reference content (.NET `ContentController`). Authenticated;
/// general information only. Throws [ApiException] on transport errors.
// Port interface; the real client and the test fakes are swapped per environment.
// ignore: one_member_abstracts
abstract class ContentApi {
  /// GET /api/v1/content/pregnancy-weeks?lang=[lang] (`en` or `ar`; the
  /// server answers English for anything else). Pass the ETag of the copy
  /// already held in that language as [etag] to get [NotModified] instead of
  /// the body again.
  Future<Revalidated<PregnancyWeeksResponse>> pregnancyWeeks({
    required String lang,
    String? etag,
    CancelToken? cancelToken,
  });
}
