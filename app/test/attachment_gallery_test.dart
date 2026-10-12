import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/vault/memory_file_store.dart';
import 'package:app/balsm_app/widgets/attachment_thumb.dart';
import 'package:core/core.dart' show KeyValueDataSource, userFileStoreProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

class _MemoryKV implements KeyValueDataSource {
  final store = <String, Object?>{};
  @override
  Future<T?> get<T>(String key) async => store[key] as T?;
  @override
  Future<void> put<T>(String key, T value) async => store[key] = value;
  @override
  Future<bool> exists(String key) async => store.containsKey(key);
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> clear() async => store.clear();
}

/// Design `attachments.jsx AttachmentGallery`: a lead thumb, the rest as a
/// tile grid, an optional add tile, and a file count.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<String> paths,
    VoidCallback? onAdd,
    ValueChanged<int>? onRemove,
  }) async {
    final prefs = PatientAppPrefs(_MemoryKV());
    final s = await PatientAppState.load(prefs, hasSession: false);
    await tester.pumpWidget(ProviderScope(
      overrides: [userFileStoreProvider.overrideWithValue(MemoryUserFileStore())],
      child: MaterialApp(
        home: AppScope(
          state: s,
          child: Scaffold(
            body: SingleChildScrollView(
              child: VaultAttachmentGallery(paths: paths, onAdd: onAdd, onRemove: onRemove),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('nothing to show and nothing to add renders nothing', (tester) async {
    await pump(tester, paths: const []);
    expect(find.byType(VaultAttachmentThumb), findsNothing);
    expect(find.byIcon(LucideIcons.paperclip), findsNothing);
  });

  testWidgets('an empty gallery still offers the add tile', (tester) async {
    await pump(tester, paths: const [], onAdd: () {});
    expect(find.byIcon(LucideIcons.plus), findsOne);
    // No files yet, so no count line.
    expect(find.byIcon(LucideIcons.paperclip), findsNothing);
  });

  testWidgets('one file is the lead, and counts as one', (tester) async {
    await pump(tester, paths: const ['v/a.pdf']);
    expect(find.byType(VaultAttachmentThumb), findsOne);
    expect(find.text('1 file'), findsOne);
  });

  testWidgets('the rest follow the lead as tiles, all counted', (tester) async {
    await pump(tester, paths: const ['v/a.pdf', 'v/b.pdf', 'v/c.pdf']);
    expect(find.byType(VaultAttachmentThumb), findsExactly(3));
    expect(find.text('3 files'), findsOne);
  });

  testWidgets('remove is offered per index, lead included', (tester) async {
    final removed = <int>[];
    await pump(tester, paths: const ['v/a.pdf', 'v/b.pdf'], onRemove: removed.add);
    expect(find.byIcon(LucideIcons.x), findsExactly(2));

    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.pump();
    expect(removed, [0]);
  });

  testWidgets('without onRemove there is no remove affordance', (tester) async {
    await pump(tester, paths: const ['v/a.pdf', 'v/b.pdf']);
    expect(find.byIcon(LucideIcons.x), findsNothing);
  });

  testWidgets('the add tile fires its callback', (tester) async {
    var added = 0;
    await pump(tester, paths: const ['v/a.pdf'], onAdd: () => added++);
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    expect(added, 1);
  });
}
