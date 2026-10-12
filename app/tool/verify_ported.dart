// One-off visual check for the screens ported in this design sweep.
//
// Drives the running docshots build through its `ext.balsm.*` debug extensions
// and photographs the simulator with `simctl io screenshot`, the same way
// tool/docshots.dart does. Signed-out / seeded synthetic state only — the
// docshots entrypoint is the one sanctioned source of sample data and is
// tree-shaken from shipped builds, so no real PHI can reach a capture.
//
//   fvm dart run tool/verify_ported.dart <vm-service-uri> <sim-udid> [out-dir]

import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/verify_ported.dart <vm-uri> <sim-udid> [out-dir]');
    exit(64);
  }
  final wsUri = args[0].replaceFirst('http://', 'ws://') + (args[0].endsWith('/') ? 'ws' : '/ws');
  final udid = args[1];
  final outRoot = args.length > 2 ? args[2] : 'verify-shots';

  final vm = await vmServiceConnectUri(wsUri);
  final isolateId = (await vm.getVM()).isolates!.first.id!;

  Future<void> ext(String method, [Map<String, String> params = const {}]) async {
    try {
      await vm.callServiceExtension(method, isolateId: isolateId, args: params);
    } catch (e) {
      stderr.writeln('  ! $method $params -> $e');
    }
  }

  Future<void> shot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    Directory(outRoot).createSync(recursive: true);
    final path = '$outRoot/$name.png';
    final r = await Process.run('xcrun', ['simctl', 'io', udid, 'screenshot', path]);
    stdout.writeln(r.exitCode == 0 ? '  shot $path' : '  ! shot $name: ${r.stderr}');
  }

  // Each entry is one ported surface from this sweep.
  final steps = <(String label, Future<void> Function())>[
    (
      'home-hero-watermark',
      () async {
        await ext('ext.balsm.go', {'route': 'app'});
        await ext('ext.balsm.setTab', {'tab': 'home'});
      }
    ),
    ('profile-qr-entry', () async => ext('ext.balsm.setTab', {'tab': 'profile'})),
    ('care-team-edit-and-directions', () async => ext('ext.balsm.open', {'screen': 'care'})),
    (
      'community-follow-row',
      () async {
        await ext('ext.balsm.setTab', {'tab': 'profile'});
        await ext('ext.balsm.open', {'screen': 'ecosystem'});
        await ext('ext.balsm.scroll', {'to': '1'});
      }
    ),
    (
      'feedback-rating',
      () async {
        await ext('ext.balsm.setTab', {'tab': 'profile'});
        await ext('ext.balsm.open', {'screen': 'feedback'});
      }
    ),
    (
      'quicklog-symptom-rows',
      () async {
        await ext('ext.balsm.setTab', {'tab': 'home'});
        await ext('ext.balsm.open', {'screen': 'quicklog'});
      }
    ),
  ];

  for (final (label, run) in steps) {
    stdout.writeln('· $label');
    await run();
    await shot(label);
  }

  await vm.dispose();
  stdout.writeln('done -> $outRoot');
}
