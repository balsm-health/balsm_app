import '../../domain/entities/imported_contact.dart';

/// Opens the phone's own contact picker.
///
/// Deliberately a picker, not an address-book reader: the OS picker hands back
/// only what the patient chose, so nothing new appears in an app-store
/// data-safety declaration. Reading the whole address book would need
/// `READ_CONTACTS` / `NSContactsUsageDescription` and a Contacts collection
/// disclosure in both stores — a compliance decision, not a code one.
///
/// Opening the picker needs no permission on either platform, but asking it for
/// fields beyond the contact's identity does not behave the same way: iOS always
/// returns them, Android requires `READ_CONTACTS` and throws without it. The
/// adapter therefore degrades to the name alone on an Android device that has
/// not granted it, rather than prompting.
///
/// The cost is that the platform pickers are single-select (Android's
/// `ACTION_PICK` has no multi mode), so the sheet lets the patient pick again to
/// add more.
abstract class ContactPicker {
  /// Whether this platform offers a picker at all. False on web and desktop,
  /// where the sheet falls back to adding a provider by hand.
  bool get isAvailable;

  /// Opens the picker. Returns the chosen contacts, an empty list when the
  /// patient backed out, and null when the platform has no picker.
  Future<List<ImportedContact>?> pick();
}
