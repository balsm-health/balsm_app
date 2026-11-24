import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';

/// Opens this app's page in the system Settings, where a refused permission can
/// be switched back on.
///
/// `geolocator` already carries the platform call, and it opens the app-wide
/// page rather than a location-only one, so camera and photos use it too instead
/// of a second plugin for one call. Returns false when the page could not open.
Future<bool> openAppPermissionSettings() => Geolocator.openAppSettings();

/// Says [message] in a snackbar with a Settings action.
///
/// For a permission the OS refused: the patient has to know why nothing
/// happened and where to fix it. A refusal the app swallows reads as a broken
/// button.
void showPermissionDenied(BuildContext context, String message) {
  final label = AppScope.of(context).strings.common.perm_settings;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: label, onPressed: () => unawaited(openAppPermissionSettings())),
    ),
  );
}
