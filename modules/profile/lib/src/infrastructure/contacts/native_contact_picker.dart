import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/contact_picker.dart';
import '../../domain/entities/imported_contact.dart';

/// [ContactPicker] backed by the platform's own picker UI.
///
/// Uses `openExternalPick` rather than `getContacts`: the OS renders its own
/// list, hands back only the chosen contact, and asks for no permission. The
/// app never sees the rest of the address book, so there is nothing to disclose
/// in a data-safety filing.
class NativeContactPicker implements ContactPicker {
  const NativeContactPicker();

  @override
  bool get isAvailable =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<List<ImportedContact>?> pick() async {
    if (!isAvailable) return null;
    try {
      final picked = await FlutterContacts.openExternalPick();
      if (picked == null) return const [];
      return [_toDraft(picked)].whereType<ImportedContact>().toList();
    } catch (_) {
      // A cancelled or unavailable picker is not a failure worth surfacing —
      // the sheet still offers adding a provider by hand.
      return const [];
    }
  }

  static ImportedContact? _toDraft(Contact c) {
    final name = c.displayName.trim();
    final phones = c.phones.map((p) => p.number.trim()).where((p) => p.isNotEmpty).toList();
    // A contact with neither a name nor a number cannot become a care-team row.
    if (name.isEmpty && phones.isEmpty) return null;
    final emails = c.emails.map((e) => e.address.trim()).where((e) => e.isNotEmpty);
    return ImportedContact(
      id: c.id,
      name: name.isEmpty ? phones.first : name,
      phones: phones,
      email: emails.isEmpty ? null : emails.first,
    );
  }
}

/// Overridden in tests with a fake; the app uses the platform picker.
final contactPickerProvider = Provider<ContactPicker>((ref) => const NativeContactPicker());
