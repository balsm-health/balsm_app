/// Balsm API contract — typed endpoint interfaces, DTOs, and dio transport.
///
/// Pure Dart (no Flutter). PHI constraint: nothing in this package may log
/// or stringify emails, user ids, tokens, or payload bodies.
library balsm_api;

export 'src/transport/api_exception.dart';
export 'src/transport/envelope.dart';
export 'src/transport/phi_leak_interceptor.dart';
