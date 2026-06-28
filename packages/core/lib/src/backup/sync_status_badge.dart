import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  (IconData, Color, String) _render(SyncStatus s) => switch (s.state) {
        SyncState.syncing => (Icons.sync, Colors.blueGrey, 'Syncing…'),
        SyncState.synced => (Icons.cloud_done, const Color(0xFF1F6A36), 'Synced${_ago(s.lastSyncedAt)}'),
        SyncState.offline => (Icons.cloud_off, const Color(0xFFD9A020), 'Offline — will sync'),
        SyncState.error => (Icons.error_outline, const Color(0xFFD44A3C), 'Sync error'),
        SyncState.idle => (Icons.smartphone, Colors.grey, 'Local only'),
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
