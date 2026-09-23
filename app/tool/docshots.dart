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
//   fvm dart run tool/docshots.dart <vm-service-uri> <simulator-udid> [out-dir]

import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/docshots.dart <vm-service-uri> <sim-udid> [out-dir]');
    exit(64);
  }
  final wsUri = args[0].replaceFirst('http://', 'ws://') + (args[0].endsWith('/') ? 'ws' : '/ws');
  final udid = args[1];

  final vm = await vmServiceConnectUri(wsUri);
  final vmInfo = await vm.getVM();
  final isolateId = vmInfo.isolates!.first.id!;

  Future<void> ext(String method, Map<String, String> params) =>
      vm.callServiceExtension(method, isolateId: isolateId, args: params);

  // Output root: screenshots/<lang>/<name>.png. A third argument redirects the
  // whole run somewhere else (the marketing capture writes into the store
  // screenshot tree), so docs and store captures share one driver.
  final outRoot = args.length > 2 ? args[2] : 'screenshots';

  Future<void> shot(String lang, String name) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final dir = Directory('$outRoot/$lang');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/$name.png';
    final r = await Process.run('xcrun', ['simctl', 'io', udid, 'screenshot', path]);
    stdout.writeln(r.exitCode == 0 ? 'captured $lang/$name' : 'FAILED $lang/$name: ${r.stderr}');
  }

  // Mount the shell first: the debug extensions are registered by the shell's
  // initState, and on a fresh install the app opens on the walkthrough.
  await ext('ext.balsm.go', {'route': 'app'});
  await Future<void>.delayed(const Duration(seconds: 3));

  // Every supported language, one app run. Arabic is not a translation pass of
  // the English capture — RTL mirrors the whole layout, so each locale needs
  // its own photograph of every screen.
  for (final lang in const ['en', 'ar']) {
    await ext('ext.balsm.setLang', {'lang': lang});

    await ext('ext.balsm.go', {'route': 'welcome'});
    await shot(lang, '01_welcome');

    await ext('ext.balsm.go', {'route': 'app'});
    await Future<void>.delayed(const Duration(seconds: 3)); // boot splash
    for (final (tab, name) in const [
      ('home', '04_home'),
      ('map', '05_care_map'),
      ('meds', '06_medications'),
      ('rx', '07_prescriptions'),
      ('records', '08_records'),
      ('trends', '09_trends'),
      ('profile', '10_profile'),
    ]) {
      await ext('ext.balsm.setTab', {'tab': tab});
      await shot(lang, name);
    }
  }

  await vm.dispose();
}
