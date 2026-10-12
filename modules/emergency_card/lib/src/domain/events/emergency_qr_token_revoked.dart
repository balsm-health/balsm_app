import 'package:core/core.dart';

import '../value_objects/ids.dart';

class EmergencyQrTokenRevoked extends AppEvent {
  const EmergencyQrTokenRevoked({required this.jti});

  final QrTokenId jti;

  @override
  String get eventName => 'emergency_qr_token_revoked';

  @override
  Map<String, dynamic> toJson() => {'jti': jti.value};
}
