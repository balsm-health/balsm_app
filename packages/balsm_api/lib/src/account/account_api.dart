import 'requests.dart';
import 'responses.dart';

/// Account endpoints (.NET module: Account).
/// All methods throw [ApiException] on transport or envelope errors,
/// except [getSelf], which returns null on HTTP 404.
abstract class AccountApi {
  /// GET /account/self — null when the account does not exist (404).
  Future<AccountSelfResponse?> getSelf();

  /// POST /account/handle/claim
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request);

  /// POST /account/language
  Future<void> changeLanguage(ChangeLanguageRequest request);

  /// POST /account/country
  Future<void> changeCountry(ChangeCountryRequest request);

  /// GET /account/handle/available?handle=
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle);
}
