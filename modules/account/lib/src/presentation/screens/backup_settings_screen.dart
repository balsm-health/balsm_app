import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

/// Backup & sync hub: live status, manual backup, and recovery-code management.
class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupServiceProvider);
    final m = ref.watch(accountStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar(title: m.backupTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  // Status
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.cloud_outlined),
                        label: m.backupStatus,
                        trailing: const SyncStatusBadge(),
                        showChevron: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BalsmListCard(
                    children: [
                      BalsmListRow(
                        leading: const Icon(Icons.cloud_upload_outlined),
                        label: m.backupNow,
                        onTap: () => _backUpNow(context, backup, m),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.vpn_key_outlined),
                        label: m.viewRecoveryCode,
                        onTap: () => _viewCode(context, backup, m),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.autorenew),
                        label: m.rotateRecoveryCode,
                        onTap: () => _rotate(context, backup, m),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 0),
                    child: Text(
                      m.backupExplainer,
                      style: const TextStyle(fontSize: FontSizes.meta, height: 1.5, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backUpNow(BuildContext context, BackupService backup, Messages m) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await backup.isProvisioned()) {
      final code = await backup.provisionIfNeeded();
      if (code != null && context.mounted) await showRecoveryCodeDialog(context, code);
    }
    messenger.showSnackBar(SnackBar(content: Text(m.backingUp)));
    await backup.backUpNow();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m.backupComplete)));
  }

  Future<void> _viewCode(BuildContext context, BackupService backup, Messages m) async {
    final code = await backup.revealCode();
    if (!context.mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m.noBackupYet)),
      );
      return;
    }
    await showRecoveryCodeDialog(context, code);
  }

  Future<void> _rotate(BuildContext context, BackupService backup, Messages m) async {
    final common = coreMessagesOf(context).common;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.rotateTitle),
        content: Text(m.rotateBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(common.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(m.rotateAction)),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final code = await backup.rotate();
    if (context.mounted) await showRecoveryCodeDialog(context, code);
  }
}
