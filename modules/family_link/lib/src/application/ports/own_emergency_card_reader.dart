import '../../domain/value_objects/emergency_card_payload.dart';

/// The account holder's OWN emergency card, read from their self health
/// profile and account details. The profile and account modules own that
/// data, so the app shell binds this port — this module imports neither.
abstract class OwnEmergencyCardReader {
  /// Null when the card cannot be read right now (signed out, or the account
  /// details are unreachable) — callers then leave a shared card as it is
  /// rather than replace it with a thinner one.
  Future<EmergencyCardPayload?> read();
}
