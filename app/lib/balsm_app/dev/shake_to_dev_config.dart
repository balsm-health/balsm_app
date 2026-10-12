import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
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

/// The whole app, in `MaterialApp.builder`: what Dev Config's Report bug tab
/// attaches as its screenshot, and what the desktop menu saves.
final appCaptureKey = GlobalKey(debugLabel: 'app-capture');

/// A PNG of the app as it is now, or null when there's nothing to capture.
/// Taken BEFORE Dev Config is pushed, so it shows the screen the bug is on.
Future<Uint8List?> captureApp({double pixelRatio = 1.5}) async {
  try {
    final boundary = appCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    // A boundary that hasn't painted yet can't be captured — report without one.
    return null;
  }
}

/// Opens the same Dev Config screen the shake gesture opens — the desktop
/// menu's trigger, since desktops don't shake. Same screen, same read-only
/// posture in prod.
Future<void> openDevConfig(BuildContext context) async {
  final controller = ProviderScope.containerOf(context).read(balsmApiControllerProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final screenshot = await captureApp();
  await navigator.push(MaterialPageRoute<void>(
    builder: (_) => ServerSelectorScreen(controller: controller, screenshot: screenshot),
  ));
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
    // A browser has no shake gesture, and asking sensors_plus for one throws
    // an uncaught MissingPluginException (it sets the sampling period over a
    // channel that does not exist on web). Dev Config stays reachable there
    // from the desktop menu.
    if (kIsWeb) return;
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

  Future<void> _openDevConfig() async {
    final nav = widget.navigatorKey.currentState;
    if (_open || nav == null) return;
    _open = true;
    final screenshot = await captureApp();
    await nav
        .push(MaterialPageRoute<void>(
          builder: (_) => ServerSelectorScreen(
            controller: ref.read(balsmApiControllerProvider),
            screenshot: screenshot,
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
