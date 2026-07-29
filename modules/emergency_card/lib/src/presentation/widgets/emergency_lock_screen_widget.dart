import 'dart:convert';

/// Shared, platform-agnostic data class describing the minimal emergency
/// information surfaced on lock-screen widgets / tiles (iOS WidgetKit, Android
/// quick-settings tile).
///
/// This is intentionally a tiny, non-PHI-heavy projection: only the few fields
/// a first responder needs at a glance. It is written to a shared container
/// (iOS App Group UserDefaults / Android SharedPreferences) by the host app.
class EmergencyLockScreenData {
  const EmergencyLockScreenData({
    this.bloodType,
    this.topAllergies = const [],
    this.topConditions = const [],
    this.primaryContactName,
  });

  final String? bloodType;
  final List<String> topAllergies;
  final List<String> topConditions;
  final String? primaryContactName;

  bool get hasAnyData =>
      bloodType != null || topAllergies.isNotEmpty || topConditions.isNotEmpty || primaryContactName != null;

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'topAllergies': topAllergies,
        'topConditions': topConditions,
        'primaryContactName': primaryContactName,
      };

  factory EmergencyLockScreenData.fromJson(Map<String, dynamic> json) => EmergencyLockScreenData(
        bloodType: json['bloodType'] as String?,
        topAllergies: (json['topAllergies'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        topConditions: (json['topConditions'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
        primaryContactName: json['primaryContactName'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory EmergencyLockScreenData.fromJsonString(String s) => EmergencyLockScreenData.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      );
}
