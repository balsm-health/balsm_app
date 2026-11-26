/// `{ mode, message, ends_at, updated_at }` from GET /api/v1/maintenance.
///
/// [mode] is the raw wire value (`off` / `readonly` / `block`); the app maps
/// anything else to "unknown", which never blocks. Carries no PHI.
class MaintenanceStatusResponse {
  const MaintenanceStatusResponse({required this.mode, this.message, this.endsAt, this.updatedAt});

  factory MaintenanceStatusResponse.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    return MaintenanceStatusResponse(
      mode: (json['mode'] as String?)?.trim().toLowerCase() ?? '',
      message: message is String && message.trim().isNotEmpty ? message.trim() : null,
      endsAt: _instant(json['ends_at']),
      updatedAt: _instant(json['updated_at']),
    );
  }

  final String mode;

  /// Optional admin message to patients; null means "use the default copy".
  final String? message;

  /// Announced end time (UTC); null means "not announced".
  final DateTime? endsAt;

  final DateTime? updatedAt;

  static DateTime? _instant(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
}
