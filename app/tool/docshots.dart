// Documentation screenshot driver — captures the simulator's ACTUAL screen
// with `simctl io screenshot` while navigating the running app through its
// `ext.balsm.*` debug service extensions (shell.dart registers them in debug
// builds for design QA). This photographs what a user sees, immune to the
// blank-frame failures of integration_test's takeScreenshot channel.
//
// The app is driven signed-OUT (route jump only, no auth) — synthetic/empty
// state, so no PHI can appear in a capture.
//
// Usage (app running on a simulator via `bin/balsm run balsm dev`):
//   fvm dart run tool/docshots.dart <vm-service-uri> <simulator-udid>

import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/docshots.dart <vm-service-uri> <sim-udid>');
    exit(64);
  }
  final wsUri = args[0].replaceFirst('http://', 'ws://') + (args[0].endsWith('/') ? 'ws' : '/ws');
  final udid = args[1];

  final vm = await vmServiceConnectUri(wsUri);
  final vmInfo = await vm.getVM();
  final isolateId = vmInfo.isolates!.first.id!;

  Future<void> ext(String method, Map<String, String> params) =>
      vm.callServiceExtension(method, isolateId: isolateId, args: params);

  Future<void> shot(String name) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final r = await Process.run('xcrun', ['simctl', 'io', udid, 'screenshot', 'screenshots/$name.png']);
    stdout.writeln(r.exitCode == 0 ? 'captured $name' : 'FAILED $name: ${r.stderr}');
  }

  // Signed-out welcome, then jump straight into the shell (QA route hop).
  await ext('ext.balsm.go', {'route': 'welcome'});
  await shot('01_welcome');

  await ext('ext.balsm.go', {'route': 'app'});
  await Future<void>.delayed(const Duration(seconds: 3)); // boot splash
  for (final (tab, name) in [
    ('home', '04_home'),
    ('map', '05_care_map'),
    ('meds', '06_medications'),
    ('rx', '07_prescriptions'),
    ('records', '08_records'),
    ('trends', '09_trends'),
    ('profile', '10_profile'),
  ]) {
    await ext('ext.balsm.setTab', {'tab': tab});
    await shot(name);
  }

  await vm.dispose();
}
