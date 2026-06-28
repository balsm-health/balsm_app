import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'restore_service.dart';

/// Shows the freshly generated recovery code **once**. This is the only key to
/// the user's encrypted backup — Balsm cannot recover it.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Save your recovery code'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'This is the only key that can restore your health data on a new '
          'device. Write it down and keep it safe — we can never recover it.',
        ),
        const SizedBox(height: 16),
        SelectableText(
          code,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ]),
      actions: [
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("I've saved it")),
      ],
    ),
  );
}

/// Prompts the user to restore from an existing cloud backup (US1b). Returns
/// true on a successful restore.
Future<bool> showRestoreDialog(BuildContext context, RestoreService restore) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(builder: (ctx, setState) {
        Future<void> doRestore() async {
          setState(() { busy = true; error = null; });
          try {
            await restore.restore(controller.text);
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (_) {
            setState(() { busy = false; error = 'Wrong code or no backup found. Try again.'; });
          }
        }

        return AlertDialog(
          title: const Text('Restore your data?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('We found a backup in your cloud. Enter your recovery code to restore your profile, medications, and history.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Recovery code',
                hintText: 'XXXXX-XXXXX-…',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Skip')),
            FilledButton(
              onPressed: busy ? null : doRestore,
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Restore'),
            ),
          ],
        );
      });
    },
  );
  return result ?? false;
}
