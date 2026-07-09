import '../domain/value_objects/user_id.dart';

/// Immutable read-model summary of the signed-in user's account.
///
/// PHI rule: this object carries no PHI. `displayName` and `handle` are
/// user-chosen public-ish identifiers, never medical data. Do not add
/// PHI fields (e.g. date_of_birth) to this summary.
class AccountSummary {
  final UserId id;
  final String? handle;
  final String? displayName;
  final String countryCode;
  final String preferredLanguage;

  /// One of 'ACTIVE' | 'DELETION_REQUESTED' | 'DELETION_CANCELLED'.
  final String deletionState;

  const AccountSummary({
    required this.id,
    this.handle,
    this.displayName,
    required this.countryCode,
    required this.preferredLanguage,
    required this.deletionState,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        id: UserId.value(j['id'] as String),
        handle: j['handle'] as String?,
        displayName: j['displayName'] as String?,
        countryCode: j['countryCode'] as String,
        preferredLanguage: j['preferredLanguage'] as String,
        deletionState: (j['deletionState'] as String?) ?? 'ACTIVE',
      );

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'handle': handle,
        'displayName': displayName,
        'countryCode': countryCode,
        'preferredLanguage': preferredLanguage,
        'deletionState': deletionState,
      };

  AccountSummary copyWith({
    String? handle,
    String? displayName,
    String? countryCode,
    String? preferredLanguage,
    String? deletionState,
  }) =>
      AccountSummary(
        id: id,
        handle: handle ?? this.handle,
        displayName: displayName ?? this.displayName,
        countryCode: countryCode ?? this.countryCode,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        deletionState: deletionState ?? this.deletionState,
      );

  @override
  bool operator ==(Object other) =>
      other is AccountSummary &&
      other.id == id &&
      other.handle == handle &&
      other.displayName == displayName &&
      other.countryCode == countryCode &&
      other.preferredLanguage == preferredLanguage &&
      other.deletionState == deletionState;

  @override
  int get hashCode => Object.hash(
        id,
        handle,
        displayName,
        countryCode,
        preferredLanguage,
        deletionState,
      );
}
