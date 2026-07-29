import 'package:go_router/go_router.dart';

import 'screens/consolidated_disclosure_screen.dart';

/// Arguments required to render the [ConsolidatedDisclosureScreen].
///
/// Passed via [GoRouterState.extra] when navigating to the disclosure
/// onboarding route. PHI-free: only disclosure metadata + locale/country.
class DisclosureRouteArgs {
  const DisclosureRouteArgs({
    required this.disclosureId,
    required this.version,
    required this.countryCode,
    required this.preferredLanguage,
  });

  final String disclosureId;
  final String version;
  final String countryCode;
  final String preferredLanguage;
}

/// Routes exported by the disclosure module.
///
/// The consolidated disclosure screen requires per-session arguments
/// ([DisclosureRouteArgs]) supplied through [GoRouterState.extra]. Query
/// parameters are used as a fallback so the route can also be reached via a
/// deep link (e.g. `/disclosure/onboarding?disclosure_id=...&version=...`).
final disclosureRoutes = <RouteBase>[
  GoRoute(
    path: '/disclosure/onboarding',
    name: 'disclosure.onboarding',
    builder: (context, state) {
      final args = state.extra is DisclosureRouteArgs ? state.extra as DisclosureRouteArgs : null;
      final query = state.uri.queryParameters;

      return ConsolidatedDisclosureScreen(
        disclosureId: args?.disclosureId ?? query['disclosure_id'] ?? 'consolidated',
        version: args?.version ?? query['version'] ?? '1',
        countryCode: args?.countryCode ?? query['country_code'] ?? '',
        preferredLanguage: args?.preferredLanguage ?? query['preferred_language'] ?? 'en',
      );
    },
  ),
];
