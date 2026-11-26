import 'package:core/core.dart';

class AgeGateUseCase {
  AgeGateUseCase();

  AppResult<void> validate(DateTime dateOfBirth) {
    final age = _age(dateOfBirth);
    if (age < 18) {
      return AppResult.failure(const AgeGateFailure());
    }
    return AppResult.success(null);
  }

  int _age(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
