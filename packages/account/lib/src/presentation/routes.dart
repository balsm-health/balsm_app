import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/backup_settings_screen.dart';
import 'screens/country_settings_screen.dart';
import 'screens/handle_claim_screen.dart';
import 'screens/language_settings_screen.dart';
import 'screens/settings_screen.dart';

final accountRoutes = <RouteBase>[
  GoRoute(
    path: '/account/settings',
    name: 'account.settings',
    builder: (_, __) => const SettingsScreen(),
  ),
  GoRoute(
    path: '/account/country',
    name: 'account.country',
    builder: (_, __) => const CountrySettingsScreen(),
  ),
  GoRoute(
    path: '/account/language',
    name: 'account.language',
    builder: (_, __) => const LanguageSettingsScreen(),
  ),
  GoRoute(
    path: '/account/handle',
    name: 'handle.claim',
    builder: (_, __) => const HandleClaimScreen(),
  ),
  GoRoute(
    path: '/account/backup',
    name: 'account.backup',
    builder: (_, __) => const BackupSettingsScreen(),
  ),
  // Developer route: registered always but only meaningful in dev builds.
  // `ServerSelectorScreen` lives in core (dev-gated export) and needs a
  // BalsmApiClient; we read it from the provider. In non-dev builds we render
  // a harmless placeholder so the dev-only path is never exercised.
  GoRoute(
    path: '/account/developer',
    name: 'account.developer',
    builder: (context, __) {
      if (FlavorConfig.current.flavor != Flavor.dev) {
        return const SizedBox.shrink();
      }
      final client =
          ProviderScope.containerOf(context).read(balsmApiClientProvider);
      return ServerSelectorScreen(client: client);
    },
  ),
];
