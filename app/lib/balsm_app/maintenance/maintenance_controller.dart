import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../flags.dart';

/// What Balsm's super admins set (design `maintenance.jsx`).
///
/// [unknown] is the state before the first answer and after any failed check.
/// It behaves exactly like [off]: an unreachable server or a phone without
/// signal must never lock the patient out of their own data.
enum MaintenanceMode {
  off,
  readonly,
  block,
  unknown;

  static MaintenanceMode fromWire(String value) => switch (value) {
        'off' => off,
        'readonly' => readonly,
        'block' => block,
        _ => unknown,
      };
}

/// The maintenance state the shell renders. No PHI: the message is free text
/// written by a Balsm admin, the same for every patient.
@immutable
class MaintenanceStatus {
  const MaintenanceStatus({
    this.mode = MaintenanceMode.unknown,
    this.message,
    this.startsAt,
    this.endsAt,
    this.checking = false,
  });

  final MaintenanceMode mode;

  /// Admin message; null means "use the default copy".
  final String? message;

  /// When this window began (UTC): the manifest's `starts_at`, the API's
  /// `updated_at`, or when this app first saw it. Only the start of the
  /// countdown's progress bar; null outside maintenance.
  final DateTime? startsAt;

  /// Announced end (UTC); null means "not announced".
  final DateTime? endsAt;

  /// A check is in flight (drives the "Checking…" button).
  final bool checking;

  /// Logging, adding, syncing, sharing and sign-in are paused.
  bool get pausesActions => mode == MaintenanceMode.readonly || mode == MaintenanceMode.block;

  /// The full-screen page replaces the app.
  bool get blocks => mode == MaintenanceMode.block;

  MaintenanceStatus copyWith({bool? checking, DateTime? startsAt}) => MaintenanceStatus(
        mode: mode,
        message: message,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt,
        checking: checking ?? this.checking,
      );

  @override
  bool operator ==(Object other) =>
      other is MaintenanceStatus &&
      other.mode == mode &&
      other.message == message &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.checking == checking;

  @override
  int get hashCode => Object.hash(mode, message, startsAt, endsAt, checking);
}

/// "Now" for the countdown, the end time and the first-seen start of a
/// window. Overridable in tests.
final maintenanceClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// How often the flag is re-read while the app is open. Overridable in tests.
final maintenancePollIntervalProvider = Provider<Duration>((_) => const Duration(minutes: 5));

/// The `maintenance` block of this brand's release manifest
/// (`/version/<brand>.json`), served from the web host rather than the API
/// server. Overridable in tests.
final maintenanceNoticeSourceProvider = Provider<ManifestMaintenanceSource>(
  (_) => ManifestMaintenanceSource(url: appVersionUrl(FlavorConfig.current.brand)),
);

/// Reads the maintenance state on first read, every
/// [maintenancePollIntervalProvider], on resume (the shell calls `check`) and on
/// "Check again", from two places at once:
///
/// - the release manifest's `maintenance` block — the primary switch. It lives
///   on the web host, so it still answers while the API server is down;
/// - `GET /api/v1/maintenance` — so a self-hosted server can announce its own.
///
/// The stricter answer wins (block > readonly > off). A source that does not
/// answer counts as off, so only an explicit announcement pauses anything.
/// With the `maintenance` flag off neither is read and the state stays
/// [MaintenanceMode.off].
final maintenanceProvider = NotifierProvider<MaintenanceController, MaintenanceStatus>(MaintenanceController.new);

class MaintenanceController extends Notifier<MaintenanceStatus> {
  Timer? _poll;
  Future<void>? _inFlight;

  /// The window this app is in — its mode and announced end — and when the
  /// app first saw it: the start of the progress bar when neither source
  /// says when maintenance began. A new mode or end starts a new window.
  (MaintenanceMode, DateTime?)? _window;
  DateTime? _firstSeen;

  @override
  MaintenanceStatus build() {
    _poll = Timer.periodic(ref.watch(maintenancePollIntervalProvider), (_) => check());
    ref.onDispose(() => _poll?.cancel());
    scheduleMicrotask(check);
    return const MaintenanceStatus();
  }

  /// Reads the flag once. Concurrent calls share one request. Any failure —
  /// offline, timeout, a 5xx — lands on [MaintenanceMode.unknown], never on a
  /// stale block.
  Future<void> check() => _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    if (!ref.read(featureFlagsProvider).isOn(AppFlags.maintenance)) {
      state = const MaintenanceStatus(mode: MaintenanceMode.off);
      return;
    }
    state = state.copyWith(checking: true);
    final (manifest, server) = await (_fromManifest(), _fromServer()).wait;
    if (!ref.mounted) return;
    state = _withStart(_stricter(manifest, server) ?? const MaintenanceStatus());
  }

  /// Fills in [MaintenanceStatus.startsAt] from when this app first saw the
  /// window, when the winning source did not say. Outside maintenance the
  /// remembered window is forgotten.
  MaintenanceStatus _withStart(MaintenanceStatus s) {
    if (!s.pausesActions) {
      _window = _firstSeen = null;
      return s;
    }
    final window = (s.mode, s.endsAt);
    if (window != _window) {
      _window = window;
      _firstSeen = ref.read(maintenanceClockProvider)().toUtc();
    }
    return s.startsAt == null ? s.copyWith(startsAt: _firstSeen) : s;
  }

  Future<MaintenanceStatus?> _fromManifest() async {
    final n = await ref.read(maintenanceNoticeSourceProvider).read();
    return n == null
        ? null
        : MaintenanceStatus(
            mode: MaintenanceMode.fromWire(n.mode),
            message: n.message,
            startsAt: n.startsAt,
            endsAt: n.endsAt,
          );
  }

  Future<MaintenanceStatus?> _fromServer() async {
    try {
      final res = await ref.read(maintenanceApiProvider).getStatus();
      return MaintenanceStatus(
        mode: MaintenanceMode.fromWire(res.mode),
        message: res.message,
        startsAt: res.updatedAt,
        endsAt: res.endsAt,
      );
    } on Object catch (_) {
      // Unreachable or refused: never block on a guess (see MaintenanceMode.unknown).
      return null;
    }
  }

  /// The answer that pauses more; on a tie the manifest's, which carries the
  /// platform-wide message. Null when neither source answered.
  static MaintenanceStatus? _stricter(MaintenanceStatus? manifest, MaintenanceStatus? server) {
    int rank(MaintenanceStatus? s) => switch (s?.mode) {
          MaintenanceMode.block => 3,
          MaintenanceMode.readonly => 2,
          MaintenanceMode.off => 1,
          _ => 0,
        };
    if (manifest == null && server == null) return null;
    return rank(server) > rank(manifest) ? server : manifest ?? server;
  }
}
