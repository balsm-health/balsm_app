import 'package:dio/dio.dart' show CancelToken;

import 'responses.dart';

/// Platform reference content (.NET `ContentController`). Authenticated;
/// general information only. Throws [ApiException] on transport errors.
abstract class ContentApi {
  /// GET /api/v1/content/pregnancy-weeks. Pass the ETag of the copy already
  /// held as [etag] to get [NotModified] instead of the body again.
  Future<Revalidated<PregnancyWeeksResponse>> pregnancyWeeks({String? etag, CancelToken? cancelToken});
}
