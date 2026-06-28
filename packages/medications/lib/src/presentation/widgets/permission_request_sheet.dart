import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

const _kResheetKey = 'notification_permission_resheet_last_shown_at';
const _kResheetWindowDays = 14;

// Shows at most once per 14 days when notifications denied + ≥1 medication added. Per Q3 FR-017b.
Future<void> maybeShowPermissionSheet(BuildContext context) async {
  const storage = FlutterSecureStorage();
  final lastShownStr = await storage.read(key: _kResheetKey);
  if (lastShownStr != null) {
    final last = DateTime.tryParse(lastShownStr);
    if (last != null && DateTime.now().difference(last).inDays < _kResheetWindowDays) return;
  }
  final status = await Permission.notification.status;
  if (status.isGranted) return;

  if (!context.mounted) return;
  await storage.write(key: _kResheetKey, value: DateTime.now().toIso8601String());
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _PermissionSheet(),
  );
}

class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_outlined, size: 32, color: Color(0xFF1283FF)),
            const SizedBox(height: 16),
            Text('Enable medication reminders', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              "You won't miss a dose if you allow notifications. "
              "We only send medication reminders — no marketing.",
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Permission.notification.request();
                },
                child: const Text('Allow notifications'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      );
}
