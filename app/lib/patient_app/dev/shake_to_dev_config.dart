import 'dart:async';
import 'dart:math';

import 'package:core/core.dart'
    show ServerSelectorScreen, balsmApiControllerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Wraps the app so a phone shake opens the Dev Config screen in EVERY flavor.
/// The screen itself is read-only in prod (server switching is dev/staging
/// only), so exposing the shake everywhere is safe.
class ShakeToDevConfig extends ConsumerStatefulWidget {
  const ShakeToDevConfig({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The app's root navigator — this widget lives ABOVE it (in
  /// MaterialApp.builder), so `Navigator.of(context)` can't reach it.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<ShakeToDevConfig> createState() => _ShakeToDevConfigState();
}

class _ShakeToDevConfigState extends ConsumerState<ShakeToDevConfig> {
  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _open = false;

  // userAccelerometer excludes gravity → ~0 at rest, spikes high on a shake.
  static const _thresholdMs2 = 14.0;

  @override
  void initState() {
    super.initState();
    _sub = userAccelerometerEventStream().listen(_onEvent, onError: (_) {});
  }

  void _onEvent(UserAccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (mag < _thresholdMs2) return;
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(seconds: 1)) return; // debounce
    _last = now;
    _openDevConfig();
  }

  void _openDevConfig() {
    final nav = widget.navigatorKey.currentState;
    if (_open || nav == null) return;
    _open = true;
    nav
        .push(MaterialPageRoute<void>(
          builder: (_) => ServerSelectorScreen(
            controller: ref.read(balsmApiControllerProvider),
          ),
        ))
        .whenComplete(() => _open = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
