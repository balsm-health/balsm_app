import 'package:core/core.dart';

/// With Mother & Child off nothing on screen can show or leave a member
/// profile, so the app keeps the account holder's own profile active: a
/// member selected while the flag was on (and persisted) is dropped back to
/// self as soon as the flag reads off. Returns whether it switched.
Future<bool> keepSelfActiveWithoutFamily({
  required bool familyOn,
  required HealthProfileId? active,
  required Future<HealthProfileId?> Function() self,
  required Future<void> Function() selectSelf,
}) async {
  if (familyOn || active == null) return false;
  final own = await self();
  if (own == null || own == active) return false;
  await selectSelf();
  return true;
}
