import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev_config_store.dart';
import 'dev_log_buffer.dart';
import 'server_health.dart';

// State behind the Dev Config console (ServerSelectorScreen). Developer tool
// only; nothing here holds PHI.

enum ServerHealthStatus { idle, checking, ok, fail }

/// The connection check's latest answer.
@immutable
class ServerHealthState {
  ServerHealthState({this.status = ServerHealthStatus.idle, this.message = '', Map<String, Object?> details = const {}})
      : details = Map.unmodifiable(details);

  final ServerHealthStatus status;

  /// "200 OK · v1.4.0 · 82ms", or why the server could not be reached.
  final String message;

  /// Every field the server put in its health body, in the order it sent
  /// them. Unmodifiable.
  final Map<String, Object?> details;

  @override
  bool operator ==(Object other) =>
      other is ServerHealthState &&
      other.status == status &&
      other.message == message &&
      mapEquals(other.details, details);

  @override
  int get hashCode => Object.hash(status, message, Object.hashAll(details.entries.map((e) => (e.key, e.value))));
}

/// Probes a server's health endpoint. Auto-disposed with the console.
class ServerHealthNotifier extends Notifier<ServerHealthState> {
  /// The probe; tests pass a fake.
  ServerHealthNotifier([this._probe = const ServerHealthProbe()]);
  final ServerHealthProbe _probe;

  @override
  ServerHealthState build() => ServerHealthState();

  Future<void> check(String baseUrl) async {
    state = ServerHealthState(status: ServerHealthStatus.checking);
    final result = await _probe.check(baseUrl);
    if (!ref.mounted) return;
    state = switch (result) {
      // A server that answers non-200 is reachable but unwell — worth telling
      // apart from silence, so the status code is shown either way.
      ServerHealthy(:final statusCode, :final elapsed, :final isOk, :final version, :final details) =>
        ServerHealthState(
          status: isOk ? ServerHealthStatus.ok : ServerHealthStatus.fail,
          message: [
            '$statusCode ${isOk ? 'OK' : 'Unhealthy'}',
            if (version != null) 'v$version',
            '${elapsed.inMilliseconds}ms',
          ].join(' · '),
          details: details,
        ),
      ServerUnreachable(:final reason) => ServerHealthState(status: ServerHealthStatus.fail, message: reason),
    };
  }

  /// Forgets the answer: after a server switch it would describe the old one.
  void reset() => state = ServerHealthState();
}

final NotifierProvider<ServerHealthNotifier, ServerHealthState> serverHealthProvider =
    NotifierProvider.autoDispose<ServerHealthNotifier, ServerHealthState>(ServerHealthNotifier.new);

/// The Report bug tab's choices that feed the send: severity and whether the
/// screenshot goes with it. Title and steps stay in their text fields.
@immutable
class BugReportDraft {
  const BugReportDraft({this.severity = 'medium', this.attachShot = true});

  /// `low` · `medium` · `high` · `critical`.
  final String severity;
  final bool attachShot;

  @override
  bool operator ==(Object other) =>
      other is BugReportDraft && other.severity == severity && other.attachShot == attachShot;

  @override
  int get hashCode => Object.hash(severity, attachShot);
}

class BugReportDraftNotifier extends Notifier<BugReportDraft> {
  @override
  BugReportDraft build() => const BugReportDraft();

  void setSeverity(String id) => state = BugReportDraft(severity: id, attachShot: state.attachShot);

  void toggleAttachShot() => state = BugReportDraft(severity: state.severity, attachShot: !state.attachShot);
}

final NotifierProvider<BugReportDraftNotifier, BugReportDraft> bugReportDraftProvider =
    NotifierProvider.autoDispose<BugReportDraftNotifier, BugReportDraft>(BugReportDraftNotifier.new);

/// Counts changes to the Dev Config store and the dev log buffer, so the
/// console rebuilds when either changes. Both are shared mutable singletons
/// that outlive the console; this listens without owning them.
class DevConsoleChangesNotifier extends Notifier<int> {
  @override
  int build() {
    final store = DevConfigStore.instance;
    final buffer = DevLogBuffer.instance;
    void changed() {
      if (ref.mounted) state++;
    }

    store.addListener(changed);
    buffer.addListener(changed);
    ref.onDispose(() {
      store.removeListener(changed);
      buffer.removeListener(changed);
    });
    return 0;
  }
}

final NotifierProvider<DevConsoleChangesNotifier, int> devConsoleChangesProvider =
    NotifierProvider.autoDispose<DevConsoleChangesNotifier, int>(DevConsoleChangesNotifier.new);
