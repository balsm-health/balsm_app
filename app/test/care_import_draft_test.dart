import 'package:app/balsm_app/screens/care_import_draft.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// The contact-import sheet's draft. Every contact is invented by the test.
class _FakePicker implements ContactPicker {
  _FakePicker(this.result);
  final List<ImportedContact>? result;

  @override
  bool get isAvailable => true;

  @override
  Future<List<ImportedContact>?> pick() async => result;
}

void main() {
  ImportedContact contact(String name, {String? phone}) =>
      ImportedContact(id: 'c-$name', name: name, phones: phone == null ? const [] : [phone]);

  final a = contact('A', phone: '+1 555 0100');
  final b = contact('B', phone: '+1 555 0101');

  test('picked contacts come in ticked, and a repeat is listed once', () {
    final d = CareImportDraft().add([a, b]).add([a, contact('A2', phone: '+15550100')]);
    expect(d.picked.map((c) => c.id), ['c-A', 'c-B']);
    expect(d.selected, {'c-A', 'c-B'});
  });

  test('a tick toggles; select all and clear act on the given rows only', () {
    final d = CareImportDraft().add([a, b]);
    expect(d.toggle('c-A').selected, {'c-B'});
    expect(d.toggleAll(['c-A'], allOn: true).selected, {'c-B'});
    expect(d.toggle('c-A').toggle('c-B').toggleAll(['c-A', 'c-B'], allOn: false).selected, {'c-A', 'c-B'});
  });

  test('a retyped contact is a different draft, though its id is the same', () {
    final d = CareImportDraft().add([a]);
    final retyped = d.withType('c-A', CareProviderType.nurse);
    expect(retyped.picked.single.type, CareProviderType.nurse);
    expect(retyped, isNot(d));
  });

  test('pick adds what the picker returned; a cancelled pick changes nothing', () async {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        contactPickerProvider.overrideWithValue(_FakePicker([a])),
      ],
    );
    addTearDown(c.dispose);
    final form = Object();
    c.listen(careImportProvider(form), (_, __) {});
    expect(await c.read(careImportProvider(form).notifier).pick(), isTrue);
    expect(c.read(careImportProvider(form)).picked, [a]);

    final cancelled = ProviderContainer(
      retry: noProviderRetry,
      overrides: [contactPickerProvider.overrideWithValue(_FakePicker(null))],
    );
    addTearDown(cancelled.dispose);
    cancelled.listen(careImportProvider(form), (_, __) {});
    expect(await cancelled.read(careImportProvider(form).notifier).pick(), isFalse);
    expect(cancelled.read(careImportProvider(form)).picked, isEmpty);
  });
}
