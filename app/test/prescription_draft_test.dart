import 'package:app/balsm_app/screens/prescription_draft.dart';
import 'package:app/balsm_app/widgets/med_plan_draft.dart';
import 'package:app/balsm_app/widgets/photo_attach.dart';
import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Add prescription sheet's draft: one Notifier per open sheet, read by
/// the Save button and the save alike.
void main() {
  late ProviderContainer container;
  final form = Object();

  setUp(() {
    container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
  });

  PrescriptionDraft read() => container.read(prescriptionDraftProvider(form));
  PrescriptionDraftNotifier notifier() => container.read(prescriptionDraftProvider(form).notifier);

  test('starts with one empty medication and is not ready', () {
    expect(read().meds, hasLength(1));
    expect(read().ready, isFalse);
  });

  test('a file, a link or a named medication makes it ready', () {
    notifier().attach(const PickedAttach(kind: 'pdf'));
    expect(read().ready, isTrue);
    notifier()
      ..attach(null)
      ..setUrl('https://example.test/rx');
    expect(read().ready, isTrue);
    notifier()
      ..setUrl('')
      ..updateMed(read().meds.single.key, MedPlanDraft(name: 'Med'));
    expect(read().ready, isTrue);
  });

  test('removing a row keeps the others with their keys; the last row stays', () {
    notifier()
      ..addMed()
      ..addMed();
    final keys = read().meds.map((m) => m.key).toList();
    notifier().updateMed(keys[2], MedPlanDraft(name: 'Third'));
    notifier().removeMed(keys[1]);
    expect(read().meds.map((m) => m.key), [keys[0], keys[2]]);
    expect(read().meds.last.plan.name, 'Third');

    notifier()
      ..removeMed(keys[0])
      ..removeMed(keys[2]);
    expect(read().meds, hasLength(1));
  });

  test('the expiry can be cleared', () {
    notifier().setExpiry(DateTime(2027));
    expect(read().expiry, DateTime(2027));
    notifier().setExpiry(null);
    expect(read().expiry, isNull);
  });

  test('two sheets never share a draft', () {
    final other = Object();
    notifier().setUrl('https://example.test/a');
    expect(container.read(prescriptionDraftProvider(other)).url, '');
  });
}
