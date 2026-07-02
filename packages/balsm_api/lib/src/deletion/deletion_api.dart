import 'responses.dart';

/// Account-deletion endpoints (.NET module: Deletion).
/// All methods throw [ApiException] on transport or envelope errors.
abstract class DeletionApi {
  /// POST /deletion/intake
  Future<DeletionIntakeResponse> requestIntake();

  /// POST /deletion/cancel
  Future<DeletionCancelResponse> cancel();
}
