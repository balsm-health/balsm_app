import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:medications/medications.dart';
import 'package:prescriptions/prescriptions.dart';

import '../i18n/strings.i69n.dart';
import '../widgets/med_plan_draft.dart';
import '../widgets/photo_attach.dart';

/// One medication row of the form. `key` stays with the row when another is
/// removed, so each card keeps its own text fields.
typedef PrescribedMed = ({int key, MedPlanDraft plan});

/// What the Add prescription sheet holds while the patient fills it: the
/// dates, the file or link, and the medications. Text fields that feed only
/// the save (title, doctor) stay in their controllers. On-device PHI.
@immutable
class PrescriptionDraft {
  PrescriptionDraft({
    required this.issued,
    this.expiry,
    this.attach,
    this.url = '',
    List<PrescribedMed>? meds,
    this.nextKey = 1,
  }) : meds = List.unmodifiable(meds ?? [(key: 0, plan: MedPlanDraft())]);

  final DateTime issued;
  final DateTime? expiry;
  final PickedAttach? attach;
  final String url;

  /// Unmodifiable; at least one row.
  final List<PrescribedMed> meds;

  /// The key the next added row gets.
  final int nextKey;

  /// A file, a link or one named medication is enough to save.
  bool get ready => attach != null || url.trim().isNotEmpty || meds.any((m) => m.plan.isNamed);

  PrescriptionDraft _copy({
    DateTime? issued,
    DateTime? Function()? expiry,
    PickedAttach? Function()? attach,
    String? url,
    List<PrescribedMed>? meds,
    int? nextKey,
  }) =>
      PrescriptionDraft(
        issued: issued ?? this.issued,
        expiry: expiry == null ? this.expiry : expiry(),
        attach: attach == null ? this.attach : attach(),
        url: url ?? this.url,
        meds: meds ?? this.meds,
        nextKey: nextKey ?? this.nextKey,
      );

  PrescriptionDraft withIssued(DateTime v) => _copy(issued: v);
  PrescriptionDraft withExpiry(DateTime? v) => _copy(expiry: () => v);
  PrescriptionDraft withAttach(PickedAttach? a) => _copy(attach: () => a);
  PrescriptionDraft withUrl(String v) => _copy(url: v);

  PrescriptionDraft addMed() => _copy(meds: [...meds, (key: nextKey, plan: MedPlanDraft())], nextKey: nextKey + 1);

  /// The last row is never removed: the form always offers one.
  PrescriptionDraft removeMed(int key) =>
      meds.length <= 1 ? this : _copy(meds: meds.where((m) => m.key != key).toList());

  PrescriptionDraft updateMed(int key, MedPlanDraft plan) =>
      _copy(meds: meds.map((m) => m.key == key ? (key: key, plan: plan) : m).toList());

  @override
  bool operator ==(Object other) =>
      other is PrescriptionDraft &&
      other.issued == issued &&
      other.expiry == expiry &&
      identical(other.attach, attach) &&
      other.url == url &&
      listEquals(other.meds, meds) &&
      other.nextKey == nextKey;

  @override
  int get hashCode => Object.hash(issued, expiry, attach, url, Object.hashAll(meds), nextKey);
}

/// One Add prescription sheet's draft; the key is a token its State creates
/// once. Auto-disposed: the PHI leaves memory when the sheet closes.
class PrescriptionDraftNotifier extends Notifier<PrescriptionDraft> {
  PrescriptionDraftNotifier(this.form);
  final Object form;

  @override
  PrescriptionDraft build() => PrescriptionDraft(issued: DateTime.now());

  void setIssued(DateTime v) => state = state.withIssued(v);
  void setExpiry(DateTime? v) => state = state.withExpiry(v);
  void attach(PickedAttach? a) => state = state.withAttach(a);
  void setUrl(String v) => state = state.withUrl(v);
  void addMed() => state = state.addMed();
  void removeMed(int key) => state = state.removeMed(key);
  void updateMed(int key, MedPlanDraft plan) => state = state.updateMed(key, plan);

  /// Saves the prescription and adds each named medication to the Meds tab.
  /// False when there is nothing to save or no one signed in.
  Future<bool> save({required String title, required String doctor, required MedsStrings strings}) async {
    final userId = ref.read(currentUserIdProvider);
    final draft = state;
    if (userId == null || !draft.ready) return false;
    final named = draft.meds.map((m) => m.plan).where((p) => p.isNamed).toList();
    final items = named
        .map(
          (p) => PrescribedItem(
            name: p.name.trim(),
            dose: p.summary(strings),
            notes: p.notes.trim().isEmpty ? null : p.notes.trim(),
          ),
        )
        .toList();
    // Read before the first await: the providers may be gone after it.
    final files = ref.read(userFileStoreProvider);
    final prescriptions = ref.read(prescriptionsDataSourceProvider);
    final addMedication = ref.read(addMedicationUseCaseProvider(userId));
    String? attachPath;
    String? attachKind;
    final url = draft.url.trim();
    if (draft.attach case PickedAttach(:final kind, bytes: final bytes?)) {
      final id = 'rx-${DateTime.now().microsecondsSinceEpoch}';
      attachPath = await files.save('$id.${kind == 'pdf' ? 'pdf' : 'jpg'}', bytes);
      attachKind = kind;
    } else if (url.isNotEmpty) {
      attachPath = url;
      attachKind = 'url';
    }
    final id = PrescriptionId.value('rx-${DateTime.now().microsecondsSinceEpoch}');
    await prescriptions.put(
      id,
      Prescription(
        id: id,
        userId: userId,
        clinician: doctor.isEmpty ? title : doctor,
        title: title,
        source: 'self',
        attachmentPath: attachPath,
        attachmentKind: attachKind,
        items: items,
        issuedAt: draft.issued,
        validUntil: draft.expiry,
        createdAt: DateTime.now(),
      ),
    );
    // Each med also joins the Meds tab's daily list, on its own schedule.
    for (final p in named) {
      await addMedication.call(p.toMedication(userId));
    }
    if (!ref.mounted) return true;
    ref
      ..invalidate(todayDosesProvider)
      ..invalidate(medicationListProvider);
    return true;
  }
}

final NotifierProviderFamily<PrescriptionDraftNotifier, PrescriptionDraft, Object> prescriptionDraftProvider =
    NotifierProvider.autoDispose.family<PrescriptionDraftNotifier, PrescriptionDraft, Object>(
  PrescriptionDraftNotifier.new,
);
