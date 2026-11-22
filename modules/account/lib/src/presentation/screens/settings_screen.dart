import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

/// Account settings hub.
///
/// Sections: Account (Country / Language / Handle), Privacy (Sessions /
/// Delete Account), Emergency (Emergency Card). In dev builds an extra,
/// spatially-separated Developer section exposes the server switcher.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final summary = summaryAsync.asData?.value;
    final isDev = FlavorConfig.current.flavor == Flavor.dev;
    final m = ref.watch(accountStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar(title: m.account.settings),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  _SectionLabel(m.sectionAccount),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.public),
                        label: m.account.country,
                        sublabel: summary?.countryCode,
                        onTap: () => context.goNamed('account.country'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.language),
                        label: m.account.language,
                        sublabel: summary?.preferredLanguage,
                        onTap: () => context.goNamed('account.language'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.alternate_email),
                        label: m.rowHandle,
                        sublabel: summary?.handle != null ? '@${summary!.handle}' : m.notSet,
                        onTap: () => context.goNamed('handle.claim'),
                      ),
                    ],
                  ),
                  _SectionLabel(m.sectionBackup),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.cloud_outlined),
                        label: m.backupTitle,
                        trailing: const SyncStatusBadge(compact: true),
                        onTap: () => _maybeGo(context, m, 'account.backup'),
                      ),
                    ],
                  ),
                  _SectionLabel(m.sectionPrivacy),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.devices),
                        label: m.rowSessions,
                        onTap: () => _maybeGo(context, m, 'account.sessions'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.delete_outline),
                        label: m.rowDeleteAccount,
                        onTap: () => _maybeGo(context, m, 'account.delete'),
                      ),
                    ],
                  ),
                  _SectionLabel(m.sectionEmergency),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.medical_services_outlined),
                        label: m.rowEmergencyCard,
                        onTap: () => _maybeGo(context, m, 'emergency.card'),
                      ),
                    ],
                  ),
                  if (isDev) ...[
                    const SizedBox(height: 24),
                    const _DevSectionLabel(),
                    BalsmListCard(
                      children: [
                        BalsmListRow(
                          leading: const Icon(Icons.dns_outlined),
                          label: 'Switch server',
                          sublabel: _activePreset(ref),
                          onTap: () => context.goNamed('account.developer'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activePreset(WidgetRef ref) {
    try {
      return ref.read(balsmApiClientProvider).dio.options.baseUrl;
    } on Object catch (_) {
      return FlavorConfig.current.defaultServer.apiBaseUrl;
    }
  }

  /// Navigates to a named route if it is registered; otherwise shows a
  /// lightweight "coming soon" notice (these routes are owned by sibling
  /// modules that may not be wired in every build).
  void _maybeGo(BuildContext context, Messages m, String name) {
    try {
      context.goNamed(name);
    } on Object catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m.notAvailableYet)),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: FontSizes.meta,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textTertiary,
          ),
        ),
      );
}

class _DevSectionLabel extends StatelessWidget {
  const _DevSectionLabel();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              'DEVELOPER',
              style: TextStyle(
                fontSize: FontSizes.meta,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.warning.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
}
