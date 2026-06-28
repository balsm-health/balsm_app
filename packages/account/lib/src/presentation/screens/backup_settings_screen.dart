import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backup & sync hub: live status, manual backup, and recovery-code management.
class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupServiceProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BalsmAppBar(title: 'Backup & sync'),
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
                        label: 'Status',
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
                        label: 'Back up now',
                        onTap: () => _backUpNow(context, backup),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.vpn_key_outlined),
                        label: 'View recovery code',
                        onTap: () => _viewCode(context, backup),
                      ),
                      BalsmListRow(
                        leading: const Icon(Icons.autorenew),
                        label: 'Rotate recovery code',
                        onTap: () => _rotate(context, backup),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
                    child: Text(
                      'Your health data is end-to-end encrypted and stored in your '
                      'own cloud. Only your recovery code can unlock it — Balsm can '
                      'never read or recover it. Keep your code safe.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: BalsmColors.fg3),
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

  Future<void> _backUpNow(BuildContext context, BackupService backup) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await backup.isProvisioned()) {
      final code = await backup.provisionIfNeeded();
      if (code != null && context.mounted) await showRecoveryCodeDialog(context, code);
    }
    messenger.showSnackBar(const SnackBar(content: Text('Backing up…')));
    await backup.backUpNow();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Backup complete')));
  }

  Future<void> _viewCode(BuildContext context, BackupService backup) async {
    final code = await backup.revealCode();
    if (!context.mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup set up yet — tap "Back up now".')),
      );
      return;
    }
    await showRecoveryCodeDialog(context, code);
  }

  Future<void> _rotate(BuildContext context, BackupService backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rotate recovery code?'),
        content: const Text(
          'A new code will be generated and your backup re-encrypted. Your old '
          'code stops working immediately. Save the new one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rotate')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final code = await backup.rotate();
    if (context.mounted) await showRecoveryCodeDialog(context, code);
  }
}
