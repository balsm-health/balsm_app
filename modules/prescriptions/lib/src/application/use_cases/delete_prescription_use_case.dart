import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/prescription.dart';
import '../../infrastructure/drift/prescriptions_data_source.dart' show prescriptionsDataSourceProvider;
import '../ports/prescriptions_data_source.dart';

/// Thrown when a clinic-issued prescription is asked to be deleted.
class PrescriptionNotDeletableException implements Exception {
  const PrescriptionNotDeletableException();
  @override
  String toString() => 'Only patient-entered prescriptions can be deleted.';
}

/// Removes a patient-entered prescription.
///
/// Clinic-issued prescriptions are a record of what a prescriber actually
/// wrote; the patient may not erase them. Only `isSelf` rows are theirs to
/// delete. The screen hides the button for the rest, but the rule is domain
/// policy, not button visibility — it is enforced here so every caller gets it.
class DeletePrescriptionUseCase {
  const DeletePrescriptionUseCase(this._prescriptions);

  final PrescriptionsDataSource _prescriptions;

  Future<void> call(Prescription rx) async {
    if (!rx.isSelf) throw const PrescriptionNotDeletableException();
    await _prescriptions.delete(rx.id);
  }
}

final deletePrescriptionUseCaseProvider = Provider<DeletePrescriptionUseCase>(
  (ref) => DeletePrescriptionUseCase(ref.watch(prescriptionsDataSourceProvider)),
);
