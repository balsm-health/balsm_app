import 'package:flutter/foundation.dart';

/// One captured diagnostic line. [message] is retained in memory only — the Dev
/// Config UI never renders it (it may contain PHI); it is surfaced solely
/// through the redacted-and-encrypted export paths.
class DevLogEntry {
  DevLogEntry(this.level, this.message, this.ts);
  final String level; // 'log' | 'info' | 'warn' | 'error'
  final String message;
  final DateTime ts;
}

/// In-memory ring buffer that mirrors the design's `console.*` interceptor:
/// it captures app log output, Flutter framework errors, and uncaught async
/// errors so the Dev Config overlay can report counts and export a diagnostic
/// bundle. Dev-tooling only — a process-wide singleton is deliberate.
///
/// PHI stance (matches devconfig.jsx "Log content is never shown here"): raw
/// text is held only in memory and never displayed; every export path redacts
/// before it leaves the device.
class DevLogBuffer extends ChangeNotifier {
  DevLogBuffer._();
  static final DevLogBuffer instance = DevLogBuffer._();

  static const _maxEntries = 600;
  static const _trimBy = 60;

  final List<DevLogEntry> _entries = [];
  bool _installed = false;

  List<DevLogEntry> get entries => List.unmodifiable(_entries);
  int get total => _entries.length;
  int get errorCount => _entries.where((e) => e.level == 'error').length;
  int get warnCount => _entries.where((e) => e.level == 'warn').length;
  DateTime? get lastAt => _entries.isEmpty ? null : _entries.last.ts;

  void add(String level, String message) {
    _entries.add(DevLogEntry(level, message, DateTime.now()));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _trimBy);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Idempotently hook the framework's output/error channels. Call once at app
  /// boot. Chains — never replaces — any handler already installed.
  void install() {
    if (_installed) return;
    _installed = true;

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) add('log', message);
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };

    final priorFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      add('error', details.exceptionAsString());
      priorFlutterError?.call(details);
    };

    final priorPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      add('error', 'Uncaught: $error');
      return priorPlatformError?.call(error, stack) ?? false;
    };
  }
}
