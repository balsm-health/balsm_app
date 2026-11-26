final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [input] has the shape of an email address: something, one `@`, then a
/// domain containing a dot, with no whitespace. A format check only — the server
/// owns real validation. Surrounding whitespace is ignored.
bool isPlausibleEmail(String input) => _email.hasMatch(input.trim());
