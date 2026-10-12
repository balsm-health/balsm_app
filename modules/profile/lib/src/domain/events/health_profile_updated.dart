import 'package:core/core.dart';

/// Published on the [EventBus] whenever a health profile field is modified.
/// Contains no PHI — only the userId (non-PHI cloud reference) and a field tag.
class HealthProfileUpdated extends AppEvent {
  const HealthProfileUpdated({
    required this.userId,
    required this.fieldChanged,
  });

  /// Cloud user ID — non-PHI reference only.
  final UserId userId;

  /// Coarse tag describing which field changed. One of:
  /// 'blood_type' | 'allergy_added' | 'allergy_removed' |
  /// 'condition_added' | 'condition_removed' | 'contact_added' | 'measurements'
  final String fieldChanged;

  @override
  String get eventName => 'health_profile_updated';

  @override
  Map<String, dynamic> toJson() => {
        'user_id': userId.value,
        'field_changed': fieldChanged,
      };
}
