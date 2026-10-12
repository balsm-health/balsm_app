/// The user's gender, used for grammatically-gendered copy (Arabic addresses
/// males and females with different verb forms). `other` is the neutral /
/// unknown fallback and resolves to the masculine form, the common Arabic
/// app convention. Matched by `.name` in i69n `${_select(gender, …)}` messages.
enum Gender {
  female,
  male,
  other;

  /// Parse a stored/server gender string; anything unrecognized (incl. null
  /// or empty) falls back to [other].
  static Gender fromString(String? value) => switch (value?.trim().toLowerCase()) {
        'female' => Gender.female,
        'male' => Gender.male,
        _ => Gender.other,
      };
}
