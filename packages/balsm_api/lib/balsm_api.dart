/// Balsm API contract — typed endpoint interfaces, DTOs, and dio transport.
///
/// Pure Dart (no Flutter). PHI constraint: nothing in this package may log
/// or stringify emails, user ids, tokens, or payload bodies.
library balsm_api;

export 'src/transport/api_exception.dart';
export 'src/transport/balsm_api_client.dart';
export 'src/transport/envelope.dart';
export 'src/transport/phi_leak_interceptor.dart';

export 'src/emergency_qr/emergency_qr_api.dart';
export 'src/emergency_qr/dio_emergency_qr_api.dart';
export 'src/emergency_qr/requests.dart';
export 'src/emergency_qr/responses.dart';

export 'src/sessions/sessions_api.dart';
export 'src/sessions/dio_sessions_api.dart';
export 'src/sessions/responses.dart';
