import 'package:account/account.dart';
import 'package:core/core.dart';

import 'app_state.dart';

/// Copies the signed-in account's gender into [state].
///
/// [PatientAppState.gender] picks the grammatical gender of Arabic copy, the
/// body map's figure and, with Mother & Child on, whether Home offers pregnancy
/// tracking. It is not kept on the device, so without this it stayed
/// [Gender.other] from launch until Personal details was opened. Which gender
/// the app used depended on whether that screen had been visited this run.
///
/// [load] is normally `AccountProfileUseCase.load`, passed as a function so
/// that resolving the use case happens inside the `try` below too.
///
/// An account with no gender recorded resets to [Gender.other], the app's
/// neutral default. When the profile cannot be read (offline, or signed out
/// mid-call), [state] is left as it is rather than reset.
Future<void> syncAccountGender(PatientAppState state, Future<ProfileDetails?> Function() load) async {
  final ProfileDetails? details;
  try {
    details = await load();
  } catch (_) {
    return;
  }
  if (details == null) return;
  state.setGender(details.gender ?? Gender.other);
}
