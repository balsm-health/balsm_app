import 'package:core/core.dart';

import '../value_objects/ids.dart';

class EmergencyQrTokenMinted extends AppEvent {
  const EmergencyQrTokenMinted({
    required this.jti,
    required this.expiresAt,
  });

  final QrTokenId jti;
  final DateTime expiresAt;

  @override
  String get eventName => 'emergency_qr_token_minted';

  @override
  Map<String, dynamic> toJson() => {
        'jti': jti.value,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}
