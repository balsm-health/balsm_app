import 'package:core/core.dart';

import '../i18n/strings.dart';

/// User-facing text for a failure from an account use case.
///
/// Only [OfflineFailure] is localised here. Every other [AppFailure] still
/// carries its own English message — a pre-existing gap across the whole
/// hierarchy, not something the offline work introduced, and not worth fixing
/// one subtype at a time. This exists so the offline mapping lives in one
/// place rather than being repeated at each screen that shows an error.
String accountFailureText(AppFailure failure) =>
    failure is OfflineFailure ? accountStrings.current.account.offline : failure.message;
