import 'package:core/core.dart';

class EmergencyQrTokenMinted extends AppEvent {
  const EmergencyQrTokenMinted({
    required this.jti,
    required this.expiresAt,
  });

  final String jti;
  final DateTime expiresAt;

  @override
  String get eventName => 'emergency_qr_token_minted';

  @override
  Map<String, dynamic> toJson() => {
        'jti': jti,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}
