import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../kit/tokens.dart';
import 'sync_status.dart';

/// Reactive badge reflecting backup state: "Syncing…", "Synced · 2m ago",
/// "Offline — will sync", "Local only", or an error. Drop into any app bar or
/// settings row; it watches [syncStatusProvider].
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key, this.compact = false});

  /// Icon-only (no label) for tight spots like an app-bar action.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final (icon, color, label) = _render(status);
    if (compact) return Icon(icon, size: 18, color: color, semanticLabel: label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: FontSizes.meta, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  (IconData, Color, String) _render(SyncStatus s) => switch (s.state) {
        SyncState.syncing => (Icons.sync, AppColors.ink600, 'Syncing…'),
        SyncState.synced => (Icons.cloud_done, AppColors.hueMintInk, 'Synced${_ago(s.lastSyncedAt)}'),
        SyncState.offline => (Icons.cloud_off, AppColors.sun600, 'Offline — will sync'),
        SyncState.error => (Icons.error_outline, AppColors.danger, 'Sync error'),
        SyncState.idle => (Icons.smartphone, AppColors.ink500, 'Local only'),
      };

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return ' · just now';
    if (d.inMinutes < 60) return ' · ${d.inMinutes}m ago';
    if (d.inHours < 24) return ' · ${d.inHours}h ago';
    return ' · ${d.inDays}d ago';
  }
}
