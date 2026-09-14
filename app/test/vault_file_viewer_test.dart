import 'dart:typed_data';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/vault/memory_file_store.dart';
import 'package:app/balsm_app/widgets/vault_file_viewer.dart';
import 'package:core/core.dart' show userFileStoreProvider;
import 'package:core/core.dart' show KeyValueDataSource;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryKV implements KeyValueDataSource {
  final store = <String, Object?>{};
  @override
  Future<T?> get<T>(String key) async => store[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async => store[key] = value;
  @override
  Future<void> put<T>(String key, T value) async => store[key] = value;
  @override
  Future<bool> exists(String key) async => store.containsKey(key);
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> clear() async => store.clear();
}

// 1x1 transparent PNG.
final _pngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

void main() {
  group('vaultFileKind', () {
    test('pdf by extension, regardless of bytes', () {
      expect(vaultFileKind('rec-1.pdf', _pngBytes), VaultFileKind.pdf);
      expect(vaultFileKind('a/b/REC-2.PDF', _pngBytes), VaultFileKind.pdf);
    });

    test('pdf by %PDF header when the extension says nothing', () {
      final bytes = Uint8List.fromList('%PDF-1.7 rest'.codeUnits);
      expect(vaultFileKind('legacy-attachment', bytes), VaultFileKind.pdf);
    });

    test('everything else is an image', () {
      expect(vaultFileKind('rec-1.jpg', _pngBytes), VaultFileKind.image);
      expect(vaultFileKind('no-extension', _pngBytes), VaultFileKind.image);
    });
  });

  group('VaultFileViewer', () {
    Future<PatientAppState> state() async {
      final prefs = PatientAppPrefs(_MemoryKV());
      return PatientAppState.load(prefs, hasSession: false);
    }

    Future<void> pump(WidgetTester tester, MemoryUserFileStore store, String path) async {
      final s = await state();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [userFileStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: AppScope(state: s, child: VaultFileViewer(path: path, title: 'Scan')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('image bytes render zoomable in-memory image', (tester) async {
      final store = MemoryUserFileStore();
      final path = await store.save('scan.png', _pngBytes);

      await pump(tester, store, path);

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('missing blob shows the generic failure state, never throws', (tester) async {
      await pump(tester, MemoryUserFileStore(), 'mem/gone.png');

      expect(find.byType(Image), findsNothing);
      expect(find.text('Could not open this file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
