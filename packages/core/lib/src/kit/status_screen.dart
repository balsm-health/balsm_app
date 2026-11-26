import 'package:balsm_api/balsm_api.dart' show NetworkManager;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/core_messages.dart';
import '../localization/i18n/messages.i69n.dart';
import '../network/api_providers.dart';
import 'shared_widgets.dart';
import 'tokens.dart';

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

  /// Tolerant parser for whatever the backend returns. Accepts a Map with a
  /// `status`/`state`/`health` field and an optional `incidents` list.
  factory ServiceHealth.fromJson(Object? json) {
    // The API wraps every body in `{ "data": … }`; read inside it.
    if (json is Map && json['data'] is Map) return ServiceHealth.fromJson(json['data']);
    if (json is Map) {
      final rawStatus = (json['status'] ?? json['state'] ?? json['health'])?.toString();
      final level = _levelFrom(rawStatus);
      final label = (rawStatus == null || rawStatus.trim().isEmpty) ? _defaultLabel(level) : rawStatus.trim();
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

  static List<StatusIncident> _incidentsFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <StatusIncident>[];
    for (final item in raw) {
      if (item is String) {
        if (item.trim().isNotEmpty) out.add(StatusIncident(title: item.trim()));
      } else if (item is Map) {
        final title = (item['title'] ?? item['name'] ?? item['summary'] ?? item['message'] ?? 'Incident').toString();
        final detailRaw = item['description'] ?? item['detail'] ?? item['body'];
        final sevRaw = item['severity'] ?? item['status'] ?? item['impact'];
        out.add(
          StatusIncident(
            title: title,
            detail: detailRaw?.toString(),
            severity: sevRaw?.toString(),
          ),
        );
      }
    }
    return out;
  }
}

/// Fetches `GET {BASE_URL}/status` using the shared (public) Dio client.
///
/// Uses the raw client rather than [NetworkManager] so no auth token or
/// envelope-unwrapping is applied — the endpoint is `AllowAnonymous`.
final FutureProvider<ServiceHealth> serviceStatusProvider = FutureProvider.autoDispose<ServiceHealth>((ref) async {
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
      backgroundColor: AppColors.cream50,
      appBar: AppBar(
        title: Text(coreMessagesOf(context).status.title),
        backgroundColor: AppColors.cream50,
        foregroundColor: AppColors.ink900,
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
          fg: AppColors.success,
          bg: AppColors.successBackground,
          icon: Icons.check_circle_outline,
        );
      case ServiceStatusLevel.degraded:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBackground,
          icon: Icons.error_outline,
        );
      case ServiceStatusLevel.down:
        return (
          fg: AppColors.danger,
          bg: AppColors.dangerBackground,
          icon: Icons.cancel_outlined,
        );
      case ServiceStatusLevel.unknown:
        return (
          fg: AppColors.ink500,
          bg: AppColors.ink50,
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
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(p.icon, color: p.fg, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _levelLabel(coreMessagesOf(context), health.level),
                  style: TextStyle(
                    fontSize: FontSizes.subhead,
                    fontWeight: FontWeight.w700,
                    color: p.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          coreMessagesOf(context).status.incidents,
          style: const TextStyle(
            fontSize: FontSizes.bodySm,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        if (health.incidents.isEmpty)
          Text(
            coreMessagesOf(context).status.no_incidents,
            style: const TextStyle(fontSize: FontSizes.bodyLg, color: AppColors.textSecondary),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incident.title,
            style: const TextStyle(
              fontSize: FontSizes.bodyLg,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (incident.severity case final severity? when incident.severity!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              severity,
              style: const TextStyle(
                fontSize: FontSizes.meta,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
          if (incident.detail case final detail? when incident.detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textSecondary),
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
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.ink500, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  coreMessagesOf(context).status.unavailable,
                  style: const TextStyle(
                    fontSize: FontSizes.subheadSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coreMessagesOf(context).status.unavailable_body,
            style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textSecondary),
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
    } on Object catch (_) {
      // Best-effort; nothing sensitive to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          coreMessagesOf(context).status.need_help,
          style: const TextStyle(
            fontSize: FontSizes.bodySm,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _emailSupport,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.mail_outline, size: 20, color: AppColors.hueBlue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    StatusScreen.supportEmail,
                    style: TextStyle(
                      color: AppColors.hueBlue,
                      fontSize: FontSizes.bodyLg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: AppColors.ink300),
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
// `app/lib/balsm_app/deep_links.dart` for the deep-link route table.
final statusRoutes = <RouteBase>[
  GoRoute(
    path: StatusScreen.routePath,
    name: StatusScreen.routeName,
    builder: (_, __) => const StatusScreen(),
  ),
];

/// The core bundle for the screen's language: the page follows the app's
/// locale instead of always speaking English.

/// What the page says for each level, in the screen's language. The server's
/// own word ("operational") is not shown: it is a code, not copy.
String _levelLabel(Messages m, ServiceStatusLevel level) => switch (level) {
      ServiceStatusLevel.operational => m.status.operational,
      ServiceStatusLevel.degraded => m.status.degraded,
      ServiceStatusLevel.down => m.status.down,
      ServiceStatusLevel.unknown => m.status.unknown,
    };
