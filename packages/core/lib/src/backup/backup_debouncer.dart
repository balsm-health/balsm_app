import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import 'backup_adapter.dart';

final backupDebouncerProvider = Provider<BackupDebouncer>((ref) {
  final bus = ref.watch(eventBusProvider);
  final debouncer = BackupDebouncer(bus);
  ref.onDispose(debouncer.dispose);
  return debouncer;
});

class BackupDebouncer with WidgetsBindingObserver {
  BackupDebouncer(this._bus) {
    WidgetsBinding.instance.addObserver(this);
    _sub = _bus.events.listen(_onEvent);
  }

  final EventBus _bus;
  BackupAdapter? adapter;
  StreamSubscription<AppEvent>? _sub;
  Timer? _debounce;

  static const _window = Duration(hours: 1);
  static const _criticalEvents = {'dose_taken', 'medication_added', 'deletion_requested'};

  void _onEvent(AppEvent event) {
    if (_criticalEvents.contains(event.eventName)) {
      _flush();
    } else {
      _debounce?.cancel();
      _debounce = Timer(_window, _flush);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _flush();
  }

  void _flush() {
    _debounce?.cancel();
    // adapter.upload() called by the caller once they have the blob
    _bus.publish(_BackupFlushRequested());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _sub?.cancel();
  }
}

class _BackupFlushRequested extends AppEvent {
  @override
  String get eventName => 'backup_flush_requested';
  @override
  Map<String, dynamic> toJson() => {};
}
