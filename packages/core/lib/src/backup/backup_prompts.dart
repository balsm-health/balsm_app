import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../kit/tokens.dart';
import '../localization/core_messages.dart';
import 'restore_service.dart';

/// Shows the freshly generated recovery code **once**. This is the only key to
/// the user's encrypted backup — Balsm cannot recover it.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) {
  final m = coreMessagesOf(context);
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(m.backup_save_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.backup_save_body),
          const SizedBox(height: 16),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: FontSizes.subhead,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          icon: const Icon(Icons.copy, size: 18),
          label: Text(m.common.copy),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(m.backup_saved)),
      ],
    ),
  );
}

/// Prompts the user to restore from an existing cloud backup (US1b). Returns
/// true on a successful restore.
Future<bool> showRestoreDialog(BuildContext context, RestoreService restore) async {
  final m = coreMessagesOf(context);
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> doRestore() async {
            setState(() {
              busy = true;
              error = null;
            });
            try {
              await restore.restore(controller.text);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on Object catch (_) {
              setState(() {
                busy = false;
                error = m.restore_error;
              });
            }
          }

          return AlertDialog(
            title: Text(m.restore_title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.restore_body),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: m.restore_code_label,
                    hintText: 'XXXXX-XXXXX-…',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: Text(m.common.skip)),
              FilledButton(
                onPressed: busy ? null : doRestore,
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(m.restore_action),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}
