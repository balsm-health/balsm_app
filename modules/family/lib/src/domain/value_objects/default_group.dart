/// The groups every account starts with. Stored by [key] — never by their
/// name, which the app writes in the patient's language at display time.
enum DefaultGroup {
  family('family'),
  neighbours('neighbours');

  const DefaultGroup(this.key);

  /// Stable stored key (`member_group.system_key`).
  final String key;

  static DefaultGroup? tryFromKey(String? key) {
    for (final g in values) {
      if (g.key == key) return g;
    }
    return null;
  }
}
