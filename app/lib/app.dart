import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

class BalsmApp extends ConsumerStatefulWidget {
  const BalsmApp({super.key});

  @override
  ConsumerState<BalsmApp> createState() => _BalsmAppState();
}

class _BalsmAppState extends ConsumerState<BalsmApp> {
  @override
  void initState() {
    super.initState();
    // Start listening for Universal/App Links + web deep links. Routes
    // emergency QR (`/emergency/public/...`), account deletion, and recovery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(routerProvider);
      ref.read(deeplinkRouterProvider).listen(router);

      // T145 / T035bm: notification tap → highlight the due dose on Today.
      ref.read(notificationServiceProvider).initialize(
        onTap: (payload) {
          if (payload == null || payload.isEmpty) {
            router.go('/medications/today');
          } else {
            router.go('/medications/today?highlightDoseId=$payload');
          }
        },
      );

      // Start the encrypted offline backup pipeline.
      ref.read(backupDebouncerProvider); // begin emitting flush triggers
      _initBackup();
    });
  }

  /// Boots the backup/restore flow: restore on a new device, otherwise set up a
  /// recovery code on first run, then keep status current.
  Future<void> _initBackup() async {
    // Only meaningful once signed in (backup is keyed to the account).
    if (ref.read(currentUserIdProvider) == null) return;
    final backup = ref.read(backupServiceProvider);
    await backup.hydrateStatus();
    if (await backup.isProvisioned()) return; // device already set up
    final restore = ref.read(restoreServiceProvider);
    if (await restore.hasBackup()) {
      if (mounted) await showRestoreDialog(context, restore);
    } else {
      final code = await backup.provisionIfNeeded();
      if (code != null && mounted) await showRecoveryCodeDialog(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Balsm',
      theme: BalsmTheme.light(),
      darkTheme: BalsmTheme.dark(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
