import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import 'metric_drafts.dart';

/// What the quick-log sheet's open flow holds: the capture its form reports,
/// the capture it opened on, and whether it may be saved. The sheet header's
/// Save and the discard prompt read it (quicklog.jsx `FlowSubmit` binds them
/// to the sheet). PHI — never log these values.
@immutable
class QuickLogEntry {
  const QuickLogEntry({this.initial, this.capture, this.valid = false});

  /// The flow as it opened: the form's first report, not an edit.
  final MetricLogCapture? initial;
  final MetricLogCapture? capture;
  final bool valid;

  /// The form reported [c]. The first report becomes [initial].
  QuickLogEntry report(MetricLogCapture c, {required bool valid}) =>
      QuickLogEntry(initial: initial ?? c, capture: c, valid: valid);

  /// Leaving asks first only once the entry differs from how it opened, so
  /// undoing an edit needs no prompt.
  bool get dirty => capture != null && initial != null && capture != initial;

  /// What Save stores; null until the entry is complete.
  MetricLogCapture? get saveable => valid ? capture : null;

  @override
  bool operator ==(Object other) =>
      other is QuickLogEntry && other.initial == initial && other.capture == capture && other.valid == valid;

  @override
  int get hashCode => Object.hash(initial, capture, valid);
}

class QuickLogEntryNotifier extends Notifier<QuickLogEntry> {
  QuickLogEntryNotifier(this.flow);

  /// A token the sheet creates each time it opens a flow, so a flow opened
  /// again starts empty.
  final Object flow;

  @override
  QuickLogEntry build() => const QuickLogEntry();

  void report(MetricLogCapture c, {required bool valid}) => state = state.report(c, valid: valid);
}

/// Auto-disposing: the entry is gone as soon as the sheet stops watching its
/// flow (back to the list, or closed).
final NotifierProviderFamily<QuickLogEntryNotifier, QuickLogEntry, Object> quickLogEntryProvider =
    NotifierProvider.autoDispose.family<QuickLogEntryNotifier, QuickLogEntry, Object>(QuickLogEntryNotifier.new);
