import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'maintenance_controller.dart';
import 'maintenance_widgets.dart';

/// The one guard every paused action calls first: add, log, edit, sync,
/// share, sign-in. Returns true — and shows "This is paused during
/// maintenance" — when maintenance pauses the action; the caller then stops.
///
/// Nothing is paused outside a [ProviderScope], or before the shell has
/// started the maintenance check (its state is still unknown then). Reading
/// it here would start the poller from a bare screen.
bool maintenancePaused(BuildContext context) {
  if (context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() == null) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(maintenanceProvider.exists)) return false;
  final status = container.read(maintenanceProvider);
  if (!status.pausesActions) return false;
  unawaited(showMaintenanceSheet(context, paused: true));
  return true;
}
