import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncState {
  /// Nothing pending; never synced or freshly reset.
  idle,

  /// Snapshot/encrypt/upload in progress.
  syncing,

  /// Last upload succeeded.
  synced,

  /// Upload failed because the device is offline; will retry on reconnect.
  offline,

  /// Upload failed for another reason.
  error,
}

class SyncStatus {
  const SyncStatus({this.state = SyncState.idle, this.lastSyncedAt, this.message});

  final SyncState state;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncStatus copyWith({SyncState? state, DateTime? lastSyncedAt, String? message}) =>
      SyncStatus(
        state: state ?? this.state,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: message,
      );
}

/// Reactive sync status the UI watches to show "Synced · 2m ago" / "Local
/// only" / "Syncing…" / "Offline — will sync".
class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void set(SyncState s, {DateTime? lastSyncedAt, String? message}) =>
      state = state.copyWith(state: s, lastSyncedAt: lastSyncedAt, message: message);
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) => SyncStatusNotifier());
