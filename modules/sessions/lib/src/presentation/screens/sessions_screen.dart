import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/use_cases/list_active_sessions_use_case.dart';
import '../../application/use_cases/revoke_session_use_case.dart';
import '../../application/use_cases/sign_out_everywhere_use_case.dart';
import '../../domain/aggregates/active_session.dart';

/// Loads the current user's active device sessions.
final sessionsProvider = FutureProvider<List<ActiveSession>>((ref) async {
  final result = await ref.watch(listActiveSessionsUseCaseProvider).call();
  return result.fold(
    (sessions) => sessions,
    (failure) => throw Exception(failure.message),
  );
});

/// Active-sessions management screen.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: 'Active sessions',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: sessionsAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: BalsmErrorBanner(
                    message: 'Could not load sessions.',
                    onRetry: () => ref.invalidate(sessionsProvider),
                  ),
                ),
                data: (sessions) => _SessionsList(sessions: sessions),
              ),
            ),
            sessionsAsync.maybeWhen(
              data: (sessions) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: BalsmButton(
                  label: 'Sign out everywhere',
                  variant: BalsmButtonVariant.danger,
                  icon: Icons.logout,
                  onPressed: () => _confirmSignOutEverywhere(context, ref),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOutEverywhere(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text(
          'This revokes every session on all devices, including this one. '
          'You will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign out everywhere',
              style: TextStyle(color: BalsmColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(signOutEverywhereUseCaseProvider).call();
    if (!context.mounted) return;
    result.fold(
      (count) {
        ref.invalidate(sessionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed out of $count sessions.')),
        );
      },
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }
}

class _SessionsList extends ConsumerWidget {
  const _SessionsList({required this.sessions});

  final List<ActiveSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'No active sessions.',
          style: TextStyle(color: BalsmColors.fg3),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        BalsmListCard(
          children: [
            for (final session in sessions)
              BalsmListRow(
                leading: Icon(_iconFor(session.deviceType)),
                label: session.deviceLabel,
                sublabel: _subtitleFor(session),
                showChevron: false,
                onTap: session.isCurrent
                    ? null
                    : () => _confirmRevoke(context, ref, session),
                trailing: session.isCurrent
                    ? const BalsmPill(
                        label: 'This device',
                        variant: BalsmPillVariant.success,
                      )
                    : const Icon(
                        Icons.logout,
                        size: 18,
                        color: BalsmColors.fg4,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    ActiveSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: Text(
          'Sign out "${session.deviceLabel}"? That device will need to sign '
          'in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Revoke',
              style: TextStyle(color: BalsmColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(revokeSessionUseCaseProvider).call(
          sessionId: session.id,
          deviceLabel: session.deviceLabel,
        );
    if (!context.mounted) return;
    result.fold(
      (_) {
        ref.invalidate(sessionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session revoked.')),
        );
      },
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  static IconData _iconFor(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'ios':
      case 'android':
      case 'mobile':
      case 'phone':
        return Icons.smartphone;
      case 'tablet':
      case 'ipad':
        return Icons.tablet_mac;
      case 'web':
      case 'browser':
        return Icons.language;
      case 'desktop':
      case 'mac':
      case 'windows':
        return Icons.computer;
      default:
        return Icons.devices_other;
    }
  }

  static String _subtitleFor(ActiveSession session) {
    return 'Active ${_relativeTime(session.lastActivityAt)}';
  }

  static String _relativeTime(DateTime when) {
    final diff = DateTime.now().toUtc().difference(when.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
