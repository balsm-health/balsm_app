import 'package:core/core.dart';

import '../value_objects/allergy_severity.dart';
import '../value_objects/ids.dart';

/// Main PHI aggregate for the profile bounded context — one **person**.
/// PHI is stored ON-DEVICE ONLY via drift/SQLCipher — never sent to the cloud.
///
/// An account owns one [ProfileKind.self] profile (the account holder) and any
/// number of member profiles: [ProfileKind.dependent] (a person they manage)
/// and [ProfileKind.prenatal] (a baby before birth). Each is its own PHI
/// partition; switching between them re-binds the scope, it never merges data.
///
/// Member rules live here, not in callers: build a new member with
/// [createMember], change its details with [withMemberDetails], retire it with
/// [close]. [memberViolations] reports every broken rule at once.
class HealthProfile {
  const HealthProfile({
    required this.id,
    required this.userId,
    required this.bloodType,
    this.weightKg,
    this.heightCm,
    required this.allergies,
    required this.conditions,
    required this.emergencyContacts,
    required this.updatedAt,
    this.kind = ProfileKind.self,
    this.displayName,
    this.dateOfBirth,
    this.sex,
    this.relationship,
    this.groupId,
    this.tone,
    this.status = ProfileStatus.active,
    this.closedOn,
    this.pregnancyId,
    this.sequence,
  });

  /// Longest display name a member profile may carry.
  static const maxDisplayNameLength = 60;

  /// Builds a new [ProfileKind.dependent] or [ProfileKind.prenatal] profile
  /// for [userId], or a [ValidationFailure] naming every broken rule (codes
  /// from [MemberRuleViolation], comma-separated). The self profile is never
  /// created here — core ensures it at session start.
  static AppResult<HealthProfile> createMember({
    required HealthProfileId id,
    required UserId userId,
    required ProfileKind kind,
    required String? displayName,
    required DateTime now,
    DateTime? dateOfBirth,
    Sex? sex,
    Relationship? relationship,
    MemberGroupId? groupId,
    String? tone,
    PregnancyId? pregnancyId,
    int? sequence,
  }) {
    final profile = HealthProfile(
      id: id,
      userId: userId,
      bloodType: null,
      allergies: const [],
      conditions: const [],
      emergencyContacts: const [],
      updatedAt: now,
      kind: kind,
      displayName: displayName?.trim(),
      dateOfBirth: dateOfBirth,
      sex: sex,
      relationship: relationship,
      groupId: groupId,
      tone: tone,
      pregnancyId: pregnancyId,
      sequence: sequence,
    );
    return _checked(profile, now);
  }

  final HealthProfileId id;

  /// Cloud reference (non-PHI). Used to associate the on-device record
  /// with the authenticated Supabase user — never transmitted with PHI.
  final UserId userId;

  /// Nullable ABO/Rh blood type. One of:
  /// 'A+'|'A-'|'B+'|'B-'|'AB+'|'AB-'|'O+'|'O-' or null (unknown).
  final BloodType? bloodType;

  /// Optional body weight in kilograms. On-device PHI only.
  final double? weightKg;

  /// Optional height in centimetres. On-device PHI only.
  final double? heightCm;

  /// Up to 50 allergies (validation enforced in use-cases).
  final List<Allergy> allergies;

  final List<ChronicCondition> conditions;

  /// Up to 3 emergency contacts (validation enforced in use-cases).
  final List<EmergencyContact> emergencyContacts;

  final DateTime updatedAt;

  /// Who this profile is: the account holder, a managed member, or a baby
  /// before birth.
  final ProfileKind kind;

  /// The member's name as the account holder entered it. Null on the self
  /// profile, whose name comes from the account.
  final String? displayName;

  /// Calendar date of birth (time-of-day ignored). Never set on a prenatal
  /// profile.
  final DateTime? dateOfBirth;

  /// Recorded sex; never set before birth.
  final Sex? sex;

  /// How the member relates to the account holder.
  final Relationship? relationship;

  /// The family group the member is filed under.
  final MemberGroupId? groupId;

  /// Avatar colour key from the design's member palette (presentation-only).
  final String? tone;

  /// Active, or closed (kept, read-only, never the active profile).
  final ProfileStatus status;

  /// Calendar date the profile was closed; set exactly when [status] is closed.
  final DateTime? closedOn;

  /// The pregnancy a prenatal profile belongs to (kept after birth).
  final PregnancyId? pregnancyId;

  /// Order among the babies of one pregnancy (1 = "Baby A"), when set.
  final int? sequence;

  bool get isSelf => kind == ProfileKind.self;

  bool get isClosed => status == ProfileStatus.closed;

  /// Every member rule this profile breaks, as of [now] (empty = valid).
  List<MemberRuleViolation> memberViolations(DateTime now) {
    final v = <MemberRuleViolation>[];
    final name = displayName?.trim() ?? '';
    if (!isSelf && kind != ProfileKind.prenatal && name.isEmpty) v.add(MemberRuleViolation.nameRequired);
    if (name.length > maxDisplayNameLength) v.add(MemberRuleViolation.nameTooLong);
    final dob = dateOfBirth;
    if (dob != null && _day(dob).isAfter(_day(now))) v.add(MemberRuleViolation.birthDateInFuture);
    if (kind == ProfileKind.prenatal) {
      if (sex != null) v.add(MemberRuleViolation.sexBeforeBirth);
      if (dob != null) v.add(MemberRuleViolation.birthDateBeforeBirth);
      if (pregnancyId == null) v.add(MemberRuleViolation.pregnancyRequired);
    }
    final seq = sequence;
    if (seq != null && seq < 1) v.add(MemberRuleViolation.invalidSequence);
    if (isClosed && isSelf) v.add(MemberRuleViolation.selfCannotClose);
    if (isClosed != (closedOn != null)) v.add(MemberRuleViolation.closedOnMismatch);
    return v;
  }

  /// This member with new details, validated like [createMember]. Kind,
  /// status and pregnancy link are not details: they change only through
  /// their own transitions ([close]; birth arrives with the pregnancy module).
  AppResult<HealthProfile> withMemberDetails({
    required String? displayName,
    required DateTime? dateOfBirth,
    required Sex? sex,
    required Relationship? relationship,
    required MemberGroupId? groupId,
    required String? tone,
    required int? sequence,
    required DateTime now,
  }) {
    if (isClosed) return AppResult.failure(ValidationFailure(MemberRuleViolation.closed.name));
    return _checked(
      HealthProfile(
        id: id,
        userId: userId,
        bloodType: bloodType,
        weightKg: weightKg,
        heightCm: heightCm,
        allergies: allergies,
        conditions: conditions,
        emergencyContacts: emergencyContacts,
        updatedAt: now,
        kind: kind,
        displayName: displayName?.trim(),
        dateOfBirth: dateOfBirth,
        sex: sex,
        relationship: relationship,
        groupId: groupId,
        tone: tone,
        status: status,
        closedOn: closedOn,
        pregnancyId: pregnancyId,
        sequence: sequence,
      ),
      now,
    );
  }

  /// Closes this member profile on [on] (a calendar date). Its records stay;
  /// it just can no longer be the active profile. The self profile cannot be
  /// closed, and closing twice is refused.
  AppResult<HealthProfile> close(DateTime on) {
    if (isSelf) return AppResult.failure(ValidationFailure(MemberRuleViolation.selfCannotClose.name));
    if (isClosed) return AppResult.failure(ValidationFailure(MemberRuleViolation.closed.name));
    return AppResult.success(HealthProfile(
      id: id,
      userId: userId,
      bloodType: bloodType,
      weightKg: weightKg,
      heightCm: heightCm,
      allergies: allergies,
      conditions: conditions,
      emergencyContacts: emergencyContacts,
      updatedAt: on,
      kind: kind,
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      sex: sex,
      relationship: relationship,
      groupId: groupId,
      tone: tone,
      status: ProfileStatus.closed,
      closedOn: _day(on),
      pregnancyId: pregnancyId,
      sequence: sequence,
    ));
  }

  static AppResult<HealthProfile> _checked(HealthProfile p, DateTime now) {
    if (p.isSelf) return AppResult.failure(ValidationFailure(MemberRuleViolation.selfNotAMember.name));
    final v = p.memberViolations(now);
    if (v.isNotEmpty) return AppResult.failure(ValidationFailure(v.map((e) => e.name).join(',')));
    return AppResult.success(p);
  }

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Returns true when at least one PHI field is populated.
  bool get hasMinimalInfo => bloodType != null || weightKg != null || heightCm != null || allergies.isNotEmpty;

  HealthProfile copyWith({
    HealthProfileId? id,
    UserId? userId,
    BloodType? bloodType,
    bool clearBloodType = false,
    double? weightKg,
    bool clearWeight = false,
    double? heightCm,
    bool clearHeight = false,
    List<Allergy>? allergies,
    List<ChronicCondition>? conditions,
    List<EmergencyContact>? emergencyContacts,
    DateTime? updatedAt,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodType: clearBloodType ? null : (bloodType ?? this.bloodType),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      updatedAt: updatedAt ?? this.updatedAt,
      // Member fields are not copyWith-able on purpose: they change only
      // through [withMemberDetails] / [close], which enforce the rules.
      kind: kind,
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      sex: sex,
      relationship: relationship,
      groupId: groupId,
      tone: tone,
      status: status,
      closedOn: closedOn,
      pregnancyId: pregnancyId,
      sequence: sequence,
    );
  }
}

/// A broken member-profile rule. The [name] is the machine-readable code
/// carried by the [ValidationFailure] message.
enum MemberRuleViolation {
  /// A dependent needs a name (a prenatal profile may stay "Baby A").
  nameRequired,
  nameTooLong,
  birthDateInFuture,

  /// No fetal sex is recorded before birth.
  sexBeforeBirth,

  /// A prenatal profile has no date of birth yet.
  birthDateBeforeBirth,
  pregnancyRequired,
  invalidSequence,
  selfCannotClose,

  /// `closedOn` must be set exactly when the profile is closed.
  closedOnMismatch,

  /// The profile is closed and can no longer change.
  closed,

  /// The self profile is not created or edited as a member.
  selfNotAMember,
}

/// Allergy value within HealthProfile.
class Allergy {
  const Allergy({
    required this.id,
    required this.healthProfileId,
    required this.name,
    required this.severity,
    required this.isControlledSubstance,
    required this.createdAt,
  });

  final AllergyId id;
  final HealthProfileId healthProfileId;

  /// Free text, max 100 chars.
  final String name;

  /// One of 'mild' | 'moderate' | 'severe'.
  final String severity;

  final bool isControlledSubstance;
  final DateTime createdAt;
}

/// Chronic condition value within HealthProfile.
class ChronicCondition {
  const ChronicCondition({
    required this.id,
    required this.healthProfileId,
    required this.name,
    this.icd10Code,
    this.onsetYear,
    required this.createdAt,
  });

  final ChronicConditionId id;
  final HealthProfileId healthProfileId;
  final String name;

  /// Optional ICD-10 diagnosis code (e.g. 'E11.9'). Null when uncoded.
  final String? icd10Code;

  /// Optional year of onset (e.g. 2018). Null when unknown.
  final int? onsetYear;

  final DateTime createdAt;
}

/// Emergency contact value within HealthProfile.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.healthProfileId,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
    required this.createdAt,
  });

  final EmergencyContactId id;
  final HealthProfileId healthProfileId;
  final String name;

  /// Phone stored in Western Arabic digits (FR-213 normalization applied on input).
  final String phone;

  final String? relation;
  final bool isPrimary;
  final DateTime createdAt;
}

// Blood types are the core [BloodType] enum (null means unknown/not set).

/// Valid allergy severity levels, in escalating order.
///
/// Derived from [AllergySeverity] so the list and the enum cannot drift apart.
List<String> get kAllergySeverities => AllergySeverity.wireValues;
