import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


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

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BalsmAppBar(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  const _SectionLabel('Account'),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.public),
                        label: 'Country',
                        sublabel: summary?.countryCode,
                        onTap: () => context.goNamed('account.country'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.language),
                        label: 'Language',
                        sublabel: summary?.preferredLanguage,
                        onTap: () => context.goNamed('account.language'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.alternate_email),
                        label: 'Handle',
                        sublabel:
                            summary?.handle != null ? '@${summary!.handle}' : 'Not set',
                        onTap: () => context.goNamed('handle.claim'),
                      ),
                    ],
                  ),
                  const _SectionLabel('Backup'),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.cloud_outlined),
                        label: 'Backup & sync',
                        trailing: const SyncStatusBadge(compact: true),
                        onTap: () => _maybeGo(context, 'account.backup'),
                      ),
                    ],
                  ),
                  const _SectionLabel('Privacy'),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.devices),
                        label: 'Sessions',
                        onTap: () => _maybeGo(context, 'account.sessions'),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.delete_outline),
                        label: 'Delete Account',
                        onTap: () => _maybeGo(context, 'account.delete'),
                      ),
                    ],
                  ),
                  const _SectionLabel('Emergency'),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.medical_services_outlined),
                        label: 'Emergency Card',
                        onTap: () => _maybeGo(context, 'emergency.card'),
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
    } catch (_) {
      return FlavorConfig.current.apiBaseUrl;
    }
  }

  /// Navigates to a named route if it is registered; otherwise shows a
  /// lightweight "coming soon" notice (these routes are owned by sibling
  /// modules that may not be wired in every build).
  void _maybeGo(BuildContext context, String name) {
    try {
      context.goNamed(name);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not available yet.')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: BalsmColors.fg3,
          ),
        ),
      );
}

class _DevSectionLabel extends StatelessWidget {
  const _DevSectionLabel();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: BalsmColors.warning),
            const SizedBox(width: 6),
            Text(
              'DEVELOPER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: BalsmColors.warning.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
}
