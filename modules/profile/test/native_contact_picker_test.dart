import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Which fields the adapter asks the OS picker for, and why it is not a free
/// choice on Android.
///
/// The Android plugin starts `ACTION_PICK` first and only checks
/// `READ_CONTACTS` once the patient has chosen someone, so asking for phones
/// and emails without the permission fails *after* the choice is made. The old
/// recovery was to open the picker a second time, which made the patient find
/// and tap the same person twice on every import — the app holds no
/// `READ_CONTACTS`, so the check never passed.
///
/// These drive the plugin's `permissions.check` channel directly: the picker
/// call itself cannot run off-device (`NativeApi` rejects any host that is not
/// a phone), but the decision this guards is made before that call.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_contacts');
  const wanted = {ContactProperty.phone, ContactProperty.email};

  final calls = <MethodCall>[];

  /// Answers `permissions.check` with [status]; `null` makes the channel throw,
  /// standing in for a host with no plugin registered.
  void mockPermission(String? status) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (status == null) throw PlatformException(code: 'unavailable');
      return status;
    });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Android without the permission asks for nothing beyond the name', () async {
    mockPermission('denied');

    expect(await NativeContactPicker.propertiesFor(TargetPlatform.android), isEmpty);
    expect(calls.single.method, 'permissions.check');
    expect((calls.single.arguments as Map)['type'], PermissionType.read.name);
  });

  test('Android that was granted the permission asks for the number and email', () async {
    mockPermission('granted');

    expect(await NativeContactPicker.propertiesFor(TargetPlatform.android), wanted);
  });

  test('iOS asks for the number and email without checking a permission', () async {
    mockPermission('denied');

    expect(await NativeContactPicker.propertiesFor(TargetPlatform.iOS), wanted);
    expect(calls, isEmpty, reason: 'iOS returns the fields with no permission of its own');
  });

  test('a failed check costs the fields, not the pick', () async {
    mockPermission(null);

    expect(await NativeContactPicker.propertiesFor(TargetPlatform.android), isEmpty);
  });
}
