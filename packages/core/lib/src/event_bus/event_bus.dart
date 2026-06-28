import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/events/app_event.dart';

class EventBus {
  final _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get events => _controller.stream;

  Stream<T> on<T extends AppEvent>() =>
      events.where((e) => e is T).cast<T>();

  void publish(AppEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}

final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
