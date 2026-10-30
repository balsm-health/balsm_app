import 'package:flutter/foundation.dart';
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
/// We do not request `READ_CONTACTS`: it would add a Contacts collection
/// disclosure to the Play listing, which is a compliance decision and not one
/// to take inside a picker call. An imported contact with no number is still a
/// real care-team row the patient can complete by hand.
///
/// So the properties are asked for only where they can be read — see
/// [propertiesFor], which is where the cost of getting this wrong lives.
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
      picked = await FlutterContacts.native.showPicker(properties: await propertiesFor(defaultTargetPlatform));
    } catch (_) {
      return const [];
    }

    if (picked == null) return const [];
    final draft = _toDraft(picked);
    return draft == null ? const [] : [draft];
  }

  /// What to ask the picker for on [platform] — one trip through it, never two.
  ///
  /// Android resolves the extra properties only *after* the patient has chosen
  /// someone: `ShowPickerImpl` starts `ACTION_PICK`, and checks `READ_CONTACTS`
  /// when the result comes back. Asking for them without the permission
  /// therefore fails with the choice already made, and the only way on from
  /// there is a second `ACTION_PICK` — the patient hunts down and taps the same
  /// person twice. Since the app never holds `READ_CONTACTS`, that was every
  /// Android import, not an edge case.
  ///
  /// So on Android ask only when the permission has been granted some other
  /// way, and otherwise take the name alone in a single trip. iOS returns the
  /// fields with no permission of its own, so it always asks.
  @visibleForTesting
  static Future<Set<ContactProperty>> propertiesFor(TargetPlatform platform) async {
    const wanted = {ContactProperty.phone, ContactProperty.email};
    if (platform != TargetPlatform.android) return wanted;
    try {
      return await FlutterContacts.permissions.has(PermissionType.read) ? wanted : const <ContactProperty>{};
    } catch (_) {
      // Checking is not worth failing the pick over; the name alone still works.
      return const <ContactProperty>{};
    }
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
