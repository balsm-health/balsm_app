import 'dart:developer' as developer;

import 'package:app/balsm_app/shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shell binds `ext.balsm.*` VM hooks in `initState`, and `initState` runs
/// again every time the shell remounts — signing out and back in, or
/// `go('welcome')` and back — without the isolate restarting.
void main() {
  setUp(boundDebugExtensions.clear);

  test('dart:developer rejects a duplicate registration', () {
    // The reason the guard exists. If this ever stops throwing, the guard is
    // no longer load-bearing and can go.
    developer.registerExtension('ext.balsm.test.dup', (_, __) async {
      return developer.ServiceExtensionResponse.result('{}');
    });
    expect(
      () => developer.registerExtension('ext.balsm.test.dup', (_, __) async {
        return developer.ServiceExtensionResponse.result('{}');
      }),
      throwsArgumentError,
    );
  });

  test('binding the same name twice is a no-op, not a throw', () {
    Future<developer.ServiceExtensionResponse> handler(String _, Map<String, String> __) async {
      return developer.ServiceExtensionResponse.result('{}');
    }

    registerExtensionOnce('ext.balsm.test.once', handler);
    // A remount must not take down the rest of initState.
    expect(() => registerExtensionOnce('ext.balsm.test.once', handler), returnsNormally);
    expect(boundDebugExtensions, contains('ext.balsm.test.once'));
  });

  test('distinct names all bind', () {
    Future<developer.ServiceExtensionResponse> handler(String _, Map<String, String> __) async {
      return developer.ServiceExtensionResponse.result('{}');
    }

    registerExtensionOnce('ext.balsm.test.a', handler);
    registerExtensionOnce('ext.balsm.test.b', handler);
    expect(boundDebugExtensions, containsAll(['ext.balsm.test.a', 'ext.balsm.test.b']));
  });
}
