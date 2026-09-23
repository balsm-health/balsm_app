/// The kind of care a provider gives.
///
/// Ported from `home.jsx` `PROVIDER_TYPES` — a care team is not only doctors,
/// so the list covers people (doctor, nurse, caregiver, physiotherapist) and
/// places (pharmacy, lab, clinic) alike. The [id] is what persists; renaming
/// one would orphan existing rows.
enum CareProviderType {
  doctor('doctor'),
  nurse('nurse'),
  carer('carer'),
  pharmacy('pharmacy'),
  lab('lab'),
  physio('physio'),
  clinic('clinic'),
  other('other');

  const CareProviderType(this.id);

  /// Stable storage key (the `type` column).
  final String id;

  /// Places rather than people — their name and "specialty" read differently,
  /// so the add form relabels those two fields (`PLACE_TYPES` in the design).
  bool get isPlace => this == pharmacy || this == lab || this == clinic;

  /// Parses a stored [id]; unknown values degrade to [doctor] rather than
  /// throwing, so a row written by a newer build still renders.
  static CareProviderType fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => doctor);
}
