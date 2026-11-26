import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web only: whether this browser tab owns the on-device database. False means
/// another tab holds it, and this one shows `OtherTabScreen` instead of an app
/// that cannot read or write anything. Always true off the web.
///
/// Kept for the app's lifetime: the claim is made once per tab.
final FutureProvider<bool> databaseTabClaimProvider = FutureProvider<bool>((ref) => claimDatabaseTab());
