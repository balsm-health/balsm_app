import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/weekly_guidance.dart';

/// Where weekly pregnancy guidance comes from. The app binds it to the
/// platform content endpoint and keeps the last good copy on the device, so
/// guidance still shows offline once it has been fetched.
///
/// Neither call sends or stores anything about the patient: the content is
/// the same for everyone.
abstract interface class PregnancyGuidanceSource {
  /// The copy kept on the device, or null when there is none yet.
  Future<WeeklyGuidance?> cached();

  /// Asks the server for a newer copy and keeps it. Returns the newest copy
  /// available — the kept one when nothing changed or the server could not be
  /// reached — or null when there is none at all. Never throws for a network
  /// failure.
  Future<WeeklyGuidance?> refresh();
}

/// Bound in the app composition root (`bootstrap()`) via `overrideWith`.
final pregnancyGuidanceSourceProvider = Provider<PregnancyGuidanceSource>(
  (ref) => throw UnimplementedError('pregnancyGuidanceSourceProvider must be overridden in bootstrap()'),
);
