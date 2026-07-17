import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_providers.dart';
import '_tokens.dart';
import 'shared_widgets.dart';

/// G6 / FR-046a·b / SC-011a — PUBLIC (no-auth) service status page.
///
/// Reached at `{BASE_URL}/status` (see [statusRoutes]). Fetches the backend
/// health JSON (`GET {BASE_URL}/status`, `AllowAnonymous`) and renders the
/// overall service state plus an incident feed. Every hard-blocking screen
/// (lockout / geofence-blocked / 404) links here so a locked-out user can
/// reach a support channel WITHOUT app authentication (SC-011a: ≤2 taps).
///
/// PHI constraint: this page shows only service-level health — never any
/// user identifier or health data.

/// Coarse health state derived from the backend `status` field.
enum ServiceStatusLevel { operational, degraded, down, unknown }

/// One incident-feed entry (title + optional detail/severity).
class StatusIncident {
  const StatusIncident({required this.title, this.detail, this.severity});
  final String title;
  final String? detail;
  final String? severity;
}

/// Parsed, presentation-ready view of the backend `/status` payload.
///
/// Defensive by design: the exact JSON shape of the .NET health endpoint is not
/// pinned here, so parsing tolerates several common shapes and unknown keys.
class ServiceHealth {
  const ServiceHealth({
    required this.level,
    required this.label,
    required this.incidents,
  });

  final ServiceStatusLevel level;

  /// Raw label from the payload (e.g. "Healthy", "Degraded") when present,
  /// otherwise a sensible default for [level].
  final String label;
  final List<StatusIncident> incidents;

  static ServiceStatusLevel _levelFrom(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'healthy':
      case 'up':
      case 'ok':
      case 'operational':
      case 'online':
      case 'pass':
        return ServiceStatusLevel.operational;
      case 'degraded':
      case 'warning':
      case 'warn':
      case 'partial':
        return ServiceStatusLevel.degraded;
      case 'unhealthy':
      case 'down':
      case 'outage':
      case 'offline':
      case 'fail':
        return ServiceStatusLevel.down;
      default:
        return ServiceStatusLevel.unknown;
    }
  }

  static String _defaultLabel(ServiceStatusLevel level) {
    switch (level) {
      case ServiceStatusLevel.operational:
        return 'All systems operational';
      case ServiceStatusLevel.degraded:
        return 'Degraded performance';
      case ServiceStatusLevel.down:
        return 'Service disruption';
      case ServiceStatusLevel.unknown:
        return 'Status unknown';
    }
  }

  static List<StatusIncident> _incidentsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <StatusIncident>[];
    for (final item in raw) {
      if (item is String) {
        if (item.trim().isNotEmpty) out.add(StatusIncident(title: item.trim()));
      } else if (item is Map) {
        final title = (item['title'] ??
                item['name'] ??
                item['summary'] ??
                item['message'] ??
                'Incident')
            .toString();
        final detailRaw = item['description'] ?? item['detail'] ?? item['body'];
        final sevRaw = item['severity'] ?? item['status'] ?? item['impact'];
        out.add(StatusIncident(
          title: title,
          detail: detailRaw?.toString(),
          severity: sevRaw?.toString(),
        ));
      }
    }
    return out;
  }

  /// Tolerant parser for whatever the backend returns. Accepts a Map with a
  /// `status`/`state`/`health` field and an optional `incidents` list.
  factory ServiceHealth.fromJson(dynamic json) {
    if (json is Map) {
      final rawStatus =
          (json['status'] ?? json['state'] ?? json['health'])?.toString();
      final level = _levelFrom(rawStatus);
      final label = (rawStatus == null || rawStatus.trim().isEmpty)
          ? _defaultLabel(level)
          : rawStatus.trim();
      return ServiceHealth(
        level: level,
        label: label,
        incidents: _incidentsFrom(json['incidents'] ?? json['events']),
      );
    }
    if (json is String) {
      final level = _levelFrom(json);
      return ServiceHealth(
        level: level,
        label: json.trim().isEmpty ? _defaultLabel(level) : json.trim(),
        incidents: const [],
      );
    }
    return const ServiceHealth(
      level: ServiceStatusLevel.unknown,
      label: 'Status unknown',
      incidents: [],
    );
  }
}

/// Fetches `GET {BASE_URL}/status` using the shared (public) Dio client.
///
/// Uses the raw client rather than [NetworkManager] so no auth token or
/// envelope-unwrapping is applied — the endpoint is `AllowAnonymous`.
final serviceStatusProvider =
    FutureProvider.autoDispose<ServiceHealth>((ref) async {
  final dio = ref.watch(balsmApiClientProvider).dio;
  final res = await dio.get<dynamic>('/status');
  return ServiceHealth.fromJson(res.data);
});

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  /// Public deeplink / web path. Mirrors the emergency public route contract:
  /// the app router's redirect guard MUST allowlist this path so the page is
  /// reachable without authentication.
  static const routePath = '/status';
  static const routeName = 'status';
  static const supportEmail = 'support@balsm.health';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceStatusProvider);
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      appBar: AppBar(
        title: const Text('Service status'),
        backgroundColor: BalsmColors.cream50,
        foregroundColor: BalsmColors.ink900,
        elevation: 0,
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(serviceStatusProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: BalsmLoadingIndicator(),
                ),
                error: (_, __) => const _UnavailableView(),
                data: (health) => _HealthView(health: health),
              ),
              const SizedBox(height: 32),
              const _SupportFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthView extends StatelessWidget {
  const _HealthView({required this.health});
  final ServiceHealth health;

  ({Color fg, Color bg, IconData icon}) get _palette {
    switch (health.level) {
      case ServiceStatusLevel.operational:
        return (
          fg: BalsmColors.success,
          bg: BalsmColors.successBg,
          icon: Icons.check_circle_outline,
        );
      case ServiceStatusLevel.degraded:
        return (
          fg: BalsmColors.warning,
          bg: BalsmColors.warningBg,
          icon: Icons.error_outline,
        );
      case ServiceStatusLevel.down:
        return (
          fg: BalsmColors.danger,
          bg: BalsmColors.dangerBg,
          icon: Icons.cancel_outlined,
        );
      case ServiceStatusLevel.unknown:
        return (
          fg: BalsmColors.ink500,
          bg: BalsmColors.ink50,
          icon: Icons.help_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall status card.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(BalsmRadius.md),
          ),
          child: Row(
            children: [
              Icon(p.icon, color: p.fg, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  health.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Incidents',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: BalsmColors.fg3,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        if (health.incidents.isEmpty)
          const Text(
            'No incidents',
            style: TextStyle(fontSize: 15, color: BalsmColors.fg2),
          )
        else
          for (final incident in health.incidents) ...[
            _IncidentTile(incident: incident),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident});
  final StatusIncident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BalsmRadius.md),
        border: Border.all(color: BalsmColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incident.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BalsmColors.fg1,
            ),
          ),
          if (incident.severity != null && incident.severity!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              incident.severity!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BalsmColors.warning,
              ),
            ),
          ],
          if (incident.detail != null && incident.detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              incident.detail!,
              style: const TextStyle(fontSize: 14, color: BalsmColors.fg2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the backend health call fails — still surfaces support so a user
/// on a hard-blocking screen is never stranded without a channel (SC-011a).
class _UnavailableView extends StatelessWidget {
  const _UnavailableView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BalsmColors.ink50,
        borderRadius: BorderRadius.circular(BalsmRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_off_outlined,
                  color: BalsmColors.ink500, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Status unavailable',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BalsmColors.fg1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'We could not reach the status service. If you need help, contact '
            'support below.',
            style: TextStyle(fontSize: 14, color: BalsmColors.fg2),
          ),
        ],
      ),
    );
  }
}

/// Support channel — reachable with no auth, in ≤2 taps from any blocking
/// screen that links to this page (SC-011a).
class _SupportFooter extends StatelessWidget {
  const _SupportFooter();

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: StatusScreen.supportEmail,
      query: 'subject=Balsm support',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort; nothing sensitive to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Need help?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: BalsmColors.fg3,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _emailSupport,
          borderRadius: BorderRadius.circular(BalsmRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.mail_outline,
                    size: 20, color: BalsmColors.appAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    StatusScreen.supportEmail,
                    style: const TextStyle(
                      color: BalsmColors.appAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: BalsmColors.ink300),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── App-router wiring ───────────────────────────────────────────────────────
// PUBLIC route. Mirrors `emergencyCardRoutes` (`/emergency/public/:token`): the
// app router's redirect/auth guard MUST allowlist `/status` so the page is
// reachable WITHOUT authentication, on web and as a deeplink. See
// `deeplink_router.dart` for the deeplink branch.
final statusRoutes = <RouteBase>[
  GoRoute(
    path: StatusScreen.routePath,
    name: StatusScreen.routeName,
    builder: (_, __) => const StatusScreen(),
  ),
];
