import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Account endpoints (.NET module: Account).
/// All methods throw [ApiException] on transport or envelope errors,
/// except [getSelf], which returns null on HTTP 404.
/// Pass a [CancelToken] to abort the request; a cancelled request throws
/// [ApiException] with `isCancelled == true`.
abstract class AccountApi {
  /// GET /account/self — null when the account does not exist (404).
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken});

  /// POST /account/handle/claim
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request, {CancelToken? cancelToken});

  /// PATCH /account/profile — partial update of the self profile.
  Future<void> updateProfile(UpdateProfileRequest request, {CancelToken? cancelToken});

  /// POST /account/language
  Future<void> changeLanguage(ChangeLanguageRequest request, {CancelToken? cancelToken});

  /// POST /account/country
  Future<void> changeCountry(ChangeCountryRequest request, {CancelToken? cancelToken});

  /// GET /account/handle/available?handle=
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle, {CancelToken? cancelToken});
}
