import 'dart:async';

import 'package:app/balsm_app/flags.dart';
import 'package:core/core.dart';

/// [FeatureFlags] over every app flag, with [overrides] already applied.
///
/// `setOverride` mutates before its first await, so the returned future (the
/// persisted write) can be dropped and no pump is needed.
FeatureFlags flagsWith(Map<FeatureFlag, bool> overrides) {
  final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true);
  overrides.forEach((flag, on) => unawaited(flags.setOverride(flag, on)));
  return flags;
}
