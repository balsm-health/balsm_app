// Documentation screenshot driver — captures the simulator's ACTUAL screen
// with `simctl io screenshot` while navigating the running app through its
// `ext.balsm.*` debug service extensions (shell.dart registers them in debug
// builds for design QA). This photographs what a user sees, immune to the
// blank-frame failures of integration_test's takeScreenshot channel.
//
// The app is driven signed-OUT (route jump only, no auth) — synthetic/empty
// state, so no PHI can appear in a capture.
//
// Works against an iOS simulator (`simctl`) or an Android device/emulator
// (`adb exec-out screencap`). The driver is identical; only the shutter differs.
//
// Usage (app running via `bin/balsm run balsm dev`):
//   fvm dart run tool/docshots.dart <vm-service-uri> <udid-or-serial> <out-dir>
//
// <out-dir> is required and is brand- and device-scoped, because this repo
// hosts every Balsm app rather than one: `screenshots/<brand>/<device>`, e.g.
// `screenshots/balsm/iphone`. There is no default — a driver that guessed
// would let the next brand's run overwrite balsm's captures.
//
// The target is detected from the id: an Android serial (`emulator-5554`, or
// anything `adb devices` lists) uses adb, everything else uses simctl. Force it
// with --ios / --android when the id is ambiguous.

import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.length < 3) {
    stderr.writeln('usage: dart run tool/docshots.dart <vm-service-uri> <udid-or-serial> <out-dir> [--ios|--android]');
    stderr.writeln('  <out-dir> is brand/device scoped, e.g. screenshots/balsm/iphone');
    exit(64);
  }
  final wsUri = positional[0].replaceFirst('http://', 'ws://') + (positional[0].endsWith('/') ? 'ws' : '/ws');
  final deviceId = positional[1];

  // adb serials are `emulator-NNNN` or a device serial; simulator UDIDs are
  // dashed UUIDs. Guessing wrong only costs one failed shutter, and the flags
  // override it.
  final android =
      flags.contains('--android') || (!flags.contains('--ios') && !RegExp(r'^[0-9A-Fa-f-]{36}$').hasMatch(deviceId));

  final vm = await vmServiceConnectUri(wsUri);
  final vmInfo = await vm.getVM();
  final isolateId = vmInfo.isolates!.first.id!;

  Future<void> ext(String method, Map<String, String> params) =>
      vm.callServiceExtension(method, isolateId: isolateId, args: params);

  // Output root: <out-dir>/<lang>/<name>.png. Docs and store captures share one
  // driver and differ only by where they are pointed — `screenshots/<brand>/
  // <device>` for the README and docs, the marketing tree's `captures/<device>`
  // for a store deck.
  final outRoot = positional[2];
  stdout.writeln('capturing ${android ? 'Android (adb)' : 'iOS (simctl)'} $deviceId -> $outRoot');

  Future<void> shot(String lang, String name) async {
    // 2s was enough for static screens but not for the map: raster tiles are
    // fetched over the network and 60 markers cluster on top of them, so the
    // capture landed on a grey, tileless canvas.
    await Future<void>.delayed(Duration(seconds: name.contains('map') ? 8 : 3));
    final dir = Directory('$outRoot/$lang');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/$name.png';

    if (android) {
      // `exec-out` streams the PNG on stdout; stdoutEncoding null keeps it
      // bytes, since any text decoding corrupts the image.
      final r = await Process.run(
        'adb',
        ['-s', deviceId, 'exec-out', 'screencap', '-p'],
        stdoutEncoding: null,
      );
      final bytes = r.stdout as List<int>;
      if (r.exitCode == 0 && bytes.isNotEmpty) {
        File(path).writeAsBytesSync(bytes);
        stdout.writeln('captured $lang/$name');
      } else {
        stdout.writeln('FAILED $lang/$name: ${r.stderr}');
      }
      return;
    }

    final r = await Process.run('xcrun', ['simctl', 'io', deviceId, 'screenshot', path]);
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

    // The two things a patient actually DOES in the app, rather than screens
    // they read. Both are modal flows, so each is opened from the shell and
    // closed again before the next one — leaving one open would photograph it
    // on top of whatever comes next.
    // Back to home first: the tab loop ends on Profile, and a sheet captured
    // over the profile screen shows an arbitrary backdrop.
    await ext('ext.balsm.setTab', {'tab': 'home'});
    await ext('ext.balsm.open', {'screen': 'quicklog'});
    await shot(lang, '11_self_log');
    await ext('ext.balsm.open', {'screen': 'close'});

    // Step 1 only. Advancing needs a mood selected — `Continue` is disabled
    // until one is, and `ext.balsm.checkinNext` goes through the same guard —
    // so steps 2-4 (BP, glucose, meds) cannot be reached from the driver as it
    // stands. Capturing them needs an extension that sets a step's value.
    await ext('ext.balsm.open', {'screen': 'checkin'});
    await shot(lang, '12_checkin_step1_mood');
    await ext('ext.balsm.open', {'screen': 'close'});
  }

  await vm.dispose();
}
