import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// In-memory ring of recent log lines for the desktop Logs screen.
///
/// Captures what the app already prints — [debugPrint] output and framework
/// errors — nothing new is logged, so the existing no-PHI-in-logs discipline
/// is the only discipline. Debug/profile builds only: release keeps
/// [debugPrint] as a no-op and `install` leaves it that way.
/// Riverpod handle on the process-wide buffer. The singleton stays: install()
/// must hook debugPrint before the first frame, earlier than any provider
/// scope exists — the provider is how widgets subscribe to it.
final logBufferProvider = ChangeNotifierProvider<LogBuffer>((ref) => LogBuffer.instance);

class LogBuffer extends ChangeNotifier {
  LogBuffer._();
  static final instance = LogBuffer._();

  static const _cap = 500;
  final List<(DateTime, String)> _lines = [];
  List<(DateTime, String)> get lines => List.unmodifiable(_lines);

  bool _installed = false;

  void install() {
    if (_installed || kReleaseMode) return;
    _installed = true;
    final prior = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) add(message);
      prior(message, wrapWidth: wrapWidth);
    };
    final priorError = FlutterError.onError;
    FlutterError.onError = (details) {
      add('ERROR ${details.exceptionAsString()}');
      priorError?.call(details);
    };
  }

  void add(String line) {
    _lines.add((DateTime.now(), line));
    if (_lines.length > _cap) _lines.removeRange(0, _lines.length - _cap);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

/// Dev-facing log viewer (desktop menu → Logs). Deliberately unlocalized like
/// the server selector: it is a diagnostic surface, not patient UI.
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const LogsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: the list below re-renders on every appended line.
    final buf = ref.watch(logBufferProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all, size: 20),
            onPressed: () {
              final text = buf.lines.map((l) => '${l.$1.toIso8601String()} ${l.$2}').join('\n');
              unawaited(Clipboard.setData(ClipboardData(text: text)));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied')));
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: buf.clear,
          ),
        ],
      ),
      body: buf.lines.isEmpty
          ? const Center(child: Text('Nothing logged yet.', style: TextStyle(color: AppColors.textHint)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: buf.lines.length,
              itemBuilder: (context, i) {
                final (t, msg) = buf.lines[i];
                final isError = msg.startsWith('ERROR ');
                return SelectableText(
                  '${t.toIso8601String().substring(11, 19)}  $msg',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: FontSizes.meta,
                    height: 1.5,
                    color: isError ? AppColors.danger : AppColors.textPrimary,
                  ),
                );
              },
            ),
    );
  }
}
