import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/widgets/photo_attach.dart';
import 'package:core/core.dart' show KeyValueDataSource, noProviderRetry;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

/// An image picker whose every request fails with [code], the way the Android
/// and iOS implementations report a refused permission.
class _RefusingPicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  _RefusingPicker(this.code);

  final String code;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      throw PlatformException(code: code);
}

/// A refused camera or photo permission used to be swallowed: the patient
/// tapped "Take photo" and nothing happened (issue #56). It now says why and
/// offers Settings.
void main() {
  late PatientAppState state;
  final original = ImagePickerPlatform.instance;

  setUp(() async {
    state = await PatientAppState.load(PatientAppPrefs(_MemoryKV()), hasSession: false);
  });

  tearDown(() => ImagePickerPlatform.instance = original);

  Future<void> tapPick(WidgetTester tester, {required String code, required bool camera}) async {
    ImagePickerPlatform.instance = _RefusingPicker(code);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        child: MaterialApp(
          home: AppScope(
            state: state,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => pickImageAttach(context, camera: camera),
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a refused camera says so and offers Settings', (tester) async {
    await tapPick(tester, code: 'camera_access_denied', camera: true);

    final c = state.strings.common;
    expect(find.text(c.perm_camera_denied), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, c.perm_settings), findsOneWidget);
  });

  testWidgets('a refused photo library says so and offers Settings', (tester) async {
    await tapPick(tester, code: 'photo_access_denied', camera: false);

    final c = state.strings.common;
    expect(find.text(c.perm_photos_denied), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, c.perm_settings), findsOneWidget);
  });

  testWidgets('any other picker error stays silent', (tester) async {
    await tapPick(tester, code: 'invalid_image', camera: false);

    expect(find.byType(SnackBar), findsNothing);
  });
}
