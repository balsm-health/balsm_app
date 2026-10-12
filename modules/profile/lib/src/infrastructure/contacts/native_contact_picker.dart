import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/contact_picker.dart';
import '../../domain/entities/imported_contact.dart';

/// [ContactPicker] backed by the platform's own picker dialog.
///
/// `FlutterContacts.native.showPicker` renders the OS list and hands back only
/// the chosen contact — the app never sees the rest of the address book.
///
/// Permission model, straight from the plugin's contract:
/// - The picker itself is permissionless on both platforms.
/// - Asking for extra properties (phones, emails) always works on iOS, but on
///   **Android it requires `READ_CONTACTS`** and throws without it.
///
/// So we ask for the numbers, and when Android refuses we fall back to the
/// name alone rather than prompting: requesting `READ_CONTACTS` would add a
/// Contacts collection disclosure to the Play listing, which is a compliance
/// decision and not one to take inside a picker call. An imported contact with
/// no number is still a real care-team row the patient can complete by hand.
class NativeContactPicker implements ContactPicker {
  const NativeContactPicker();

  @override
  bool get isAvailable =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<List<ImportedContact>?> pick() async {
    if (!isAvailable) return null;

    Contact? picked;
    try {
      picked = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone, ContactProperty.email},
      );
    } on PlatformException {
      // Android without READ_CONTACTS. Retry permissionless: id + displayName.
      try {
        picked = await FlutterContacts.native.showPicker();
      } catch (_) {
        return const [];
      }
    } catch (_) {
      return const [];
    }

    if (picked == null) return const [];
    final draft = _toDraft(picked);
    return draft == null ? const [] : [draft];
  }

  static ImportedContact? _toDraft(Contact c) {
    final name = (c.displayName ?? '').trim();
    final phones = c.phones.map((p) => p.number.trim()).where((p) => p.isNotEmpty).toList();
    // Nothing to show and nothing to call — not a care-team row.
    if (name.isEmpty && phones.isEmpty) return null;
    final emails = c.emails.map((e) => e.address.trim()).where((e) => e.isNotEmpty);
    return ImportedContact(
      // The platform id can be null; the draft id only needs to be unique for
      // the lifetime of the sheet, so fall back to the name and number.
      id: c.id ?? 'picked:$name:${phones.isEmpty ? '' : phones.first}',
      name: name.isEmpty ? phones.first : name,
      phones: phones,
      email: emails.isEmpty ? null : emails.first,
    );
  }
}

/// Overridden in tests with a fake; the app uses the platform picker.
final contactPickerProvider = Provider<ContactPicker>((ref) => const NativeContactPicker());
