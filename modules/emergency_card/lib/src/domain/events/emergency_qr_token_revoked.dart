import 'package:core/core.dart';

class EmergencyQrTokenRevoked extends AppEvent {
  const EmergencyQrTokenRevoked({required this.jti});

  final String jti;

  @override
  String get eventName => 'emergency_qr_token_revoked';

  @override
  Map<String, dynamic> toJson() => {'jti': jti};
}
