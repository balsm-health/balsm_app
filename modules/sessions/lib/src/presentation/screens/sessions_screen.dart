import 'package:balsm_api/balsm_api.dart' show isOfflineError;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/list_active_sessions_use_case.dart';
import '../../application/use_cases/revoke_session_use_case.dart';
import '../../application/use_cases/sign_out_everywhere_use_case.dart';
import '../../domain/aggregates/active_session.dart';
import '../i18n/i18n.dart';

/// Loads the current user's active device sessions.
///
/// Watches core's [currentUserIdProvider] (overridden in the app shell at
/// bootstrap, invalidated on sign-out) so the surface is signed-out-safe:
/// when no user is authenticated it resolves to an empty list — the list shows
/// its empty state and the "sign out everywhere" action hides. Same pattern as
/// the meds / profile ports (FutureProvider watching currentUserId +
/// invalidate-after-write).
final sessionsProvider = FutureProvider<List<ActiveSession>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <ActiveSession>[];
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
    final m = ref.watch(sessionsStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: m.title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: sessionsAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                // No cached fallback here on purpose: a stale list of active
                // sessions is a security-relevant lie — it could show a device
                // as signed in that was revoked, or hide one that was added.
                // Offline gets an explanation instead of a retry button that
                // cannot succeed.
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: isOfflineError(e)
                      ? BalsmErrorBanner(message: m.offline)
                      : BalsmErrorBanner(
                          message: m.loadError,
                          onRetry: () => ref.invalidate(sessionsProvider),
                        ),
                ),
                data: (sessions) => _SessionsList(sessions: sessions),
              ),
            ),
            sessionsAsync.maybeWhen(
              data: (sessions) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                child: BalsmButton(
                  label: m.signOutAll,
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
    final m = ref.read(sessionsStringsProvider);
    final common = coreMessagesOf(context).common;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.signOutAllTitle),
        content: Text(m.signOutAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              m.signOutAll,
              style: const TextStyle(color: AppColors.danger),
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
          SnackBar(content: Text(m.signedOutCount(count))),
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
    final m = ref.watch(sessionsStringsProvider);
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          m.empty,
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
      children: [
        BalsmListCard(
          children: [
            ...sessions.map(
              (session) => BalsmListRow(
                leading: Icon(_iconFor(session.deviceType)),
                label: session.deviceLabel,
                sublabel: _subtitleFor(m, session),
                showChevron: false,
                onTap: session.isCurrent ? null : () => _confirmRevoke(context, ref, session),
                trailing: session.isCurrent
                    ? BalsmPill(
                        label: m.thisDevice,
                        variant: BalsmPillVariant.success,
                      )
                    : const Icon(
                        Icons.logout,
                        size: 18,
                        color: AppColors.textHint,
                      ),
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
    final m = ref.read(sessionsStringsProvider);
    final common = coreMessagesOf(context).common;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.revokeTitle),
        content: Text(m.revokeBody(session.deviceLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              m.revokeAction,
              style: const TextStyle(color: AppColors.danger),
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
          SnackBar(content: Text(m.revoked)),
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

  // G11: surface real device metadata per row — device type, when the session
  // was first seen and when it was last active — instead of a bare
  // "Active <time>". The approximate location is appended only when the API
  // supplies it (never fabricated on-device); it stays omitted until then.
  static String _subtitleFor(Messages m, ActiveSession session) {
    final parts = <String>[
      _deviceTypeLabel(m, session.deviceType),
      m.firstSeen(_shortDate(session.firstSeenAt)),
      m.lastActive(_relativeTime(m, session.lastActivityAt)),
      if (session.approxLocation case final approxLocation? when session.approxLocation!.trim().isNotEmpty)
        approxLocation.trim(),
    ];
    return parts.join(' · ');
  }

  static String _deviceTypeLabel(Messages m, String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'ios':
        return 'iOS';
      case 'ipados':
        return 'iPadOS';
      case 'android':
        return 'Android';
      case 'web':
      case 'browser':
        return m.deviceWeb;
      case 'desktop':
        return m.deviceDesktop;
      case 'macos':
      case 'mac':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case '':
        return m.deviceGeneric;
      default:
        return deviceType[0].toUpperCase() + deviceType.substring(1);
    }
  }

  static String _shortDate(DateTime when) =>
      DateFormat.yMMMd(LocalizationUtil.currentLocale.languageCode).format(when.toLocal());

  static String _relativeTime(Messages m, DateTime when) {
    final diff = DateTime.now().toUtc().difference(when.toUtc());
    if (diff.inMinutes < 1) return m.justNow;
    if (diff.inMinutes < 60) return m.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return m.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return m.daysAgo(diff.inDays);
    return m.weeksAgo((diff.inDays / 7).floor());
  }
}
