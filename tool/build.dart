// Single source of truth for Flutter build/run/test commands across brands,
// environments, and platforms. Consumed by melos scripts, VS Code tasks, and
// CI/CD — so the flavor/target/dart-define wiring lives in ONE typed, validated
// place. Cross-platform (no bash dependency).
//
// Usage: dart run tool/build.dart <action> [brand] [env] [-- extra flutter args]
//   action : run | apk | aab | ios | web | test | integration | gen
//   brand  : balsm (default)  — see tool/build_config.dart
//   env    : dev (default) | staging | prod
//
// Examples:
//   dart run tool/build.dart run balsm dev -d <device-id>
//   dart run tool/build.dart apk balsm prod
//   dart run tool/build.dart web balsm prod
//   dart run tool/build.dart gen           # build_runner across all packages
import 'dart:io';

import 'build_config.dart';

const _actions = {'run', 'apk', 'aab', 'ios', 'web', 'test', 'integration', 'gen'};

Never _fail(String msg) {
  stderr.writeln('build: $msg');
  exit(2);
}

Future<void> main(List<String> argv) async {
  final args = [...argv];
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _fail('usage: dart run tool/build.dart <action> [brand] [env] [-- extra]\n'
        '  action : ${_actions.join(' | ')}\n'
        '  brand  : ${brands.keys.join(' | ')} (default: ${brands.keys.first})\n'
        '  env    : dev | staging | prod (default: dev)');
  }

  final action = args.removeAt(0);
  if (!_actions.contains(action)) {
    _fail("unknown action '$action' (${_actions.join(' | ')})");
  }

  // Code generation is workspace-wide (not a single flutter command): run
  // build_runner in every package that depends on it. Handled before the
  // brand/env parsing below, which does not apply.
  if (action == 'gen') {
    await _codegen(args);
    return;
  }

  // brand/env are optional positionals; anything starting with '-' is passthrough.
  final brandKey = args.isNotEmpty && !args.first.startsWith('-') ? args.removeAt(0) : brands.keys.first;
  final brand = brands[brandKey];
  if (brand == null) {
    _fail("unknown brand '$brandKey' (valid: ${brands.keys.join(', ')})");
  }

  final env = args.isNotEmpty && !args.first.startsWith('-') ? args.removeAt(0) : brand.envs.first;
  if (action != 'test' && !brand.envs.contains(env)) {
    _fail("unknown env '$env' for brand '$brandKey' "
        '(valid: ${brand.envs.join(', ')})');
  }

  final extra = args; // remaining args pass straight through to flutter
  final target = 'lib/brands/$brandKey/main_$brandKey.dart';
  final defines = [
    '--dart-define-from-file=env/$brandKey/$env.json',
    '--dart-define-from-file=env/shared.json',
  ];
  final flavor = ['--flavor', brand.flavor];

  final flutterArgs = <String>[
    ...switch (action) {
      'run' => ['run', ...flavor, '-t', target, ...defines],
      'apk' => ['build', 'apk', '--release', ...flavor, '-t', target, ...defines],
      'aab' => ['build', 'appbundle', '--release', ...flavor, '-t', target, ...defines],
      'ios' => ['build', 'ios', '--release', '--no-codesign', ...flavor, '-t', target, ...defines],
      'web' => [
          'build',
          'web',
          '--release',
          '-t',
          target,
          ...defines,
          // Hosted at https://balsm.health/apps/balsm — asset URLs must be
          // prefixed or flutter.js 404s under the site's locale router.
          if (env == 'prod') '--base-href=/apps/balsm/',
          // Local canvaskit — gstatic.com is blocked by the site CSP.
          if (env == 'prod') '--no-web-resources-cdn',
        ], // web: no flavor
      'test' => ['test'],
      'integration' => ['test', 'integration_test', ...flavor],
      _ => const <String>[],
    },
    ...extra,
  ];

  // Paths above are app-relative — run flutter from the app package, wherever
  // the caller's cwd is (repo root under melos/CI, or elsewhere).
  final appDir = Platform.script.resolve('../app').toFilePath();
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';

  stderr.writeln('\$ (cd app && flutter ${flutterArgs.join(' ')})');
  final proc = await Process.start(
    flutter,
    flutterArgs,
    workingDirectory: appDir,
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  exit(await proc.exitCode);
}

/// Runs build_runner across every workspace package that depends on it (i69n
/// bundles, drift, json/freezed). Packages without build_runner are skipped
/// (running it there errors). Cross-platform; independent of melos wiring.
///
/// Pass `--watch` to rebuild on change. Watch spawns one long-running process
/// per package and streams their output together (Ctrl-C stops them all); a
/// one-shot `build` runs sequentially and fails fast on the first error.
Future<void> _codegen(List<String> extra) async {
  final watch = extra.remove('--watch') || extra.remove('-w');
  final root = Directory.fromUri(Platform.script.resolve('..'));
  final dart = Platform.isWindows ? 'dart.bat' : 'dart';
  final sub = watch ? 'watch' : 'build';

  // Collect candidate package dirs: app + packages/* + modules/* (stable order).
  final candidates = <Directory>[Directory.fromUri(root.uri.resolve('app'))];
  for (final group in const ['packages', 'modules']) {
    final dir = Directory.fromUri(root.uri.resolve(group));
    if (!dir.existsSync()) continue;
    final children = dir.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
    candidates.addAll(children);
  }

  // Keep only packages that actually depend on build_runner.
  final targets = candidates.where((d) {
    final pubspec = File.fromUri(d.uri.resolve('pubspec.yaml'));
    return pubspec.existsSync() && pubspec.readAsStringSync().contains('build_runner');
  }).toList();
  if (targets.isEmpty) _fail('codegen: no packages depend on build_runner');

  Future<Process> start(Directory d) {
    stderr.writeln('\$ (cd ${d.path} && dart run build_runner $sub)');
    return Process.start(dart, ['run', 'build_runner', sub],
        workingDirectory: d.path, mode: ProcessStartMode.inheritStdio, runInShell: true);
  }

  if (watch) {
    // Long-running: one process per package, all streaming; Ctrl-C stops all.
    final procs = await Future.wait(targets.map(start));
    final codes = await Future.wait(procs.map((p) => p.exitCode));
    exit(codes.firstWhere((c) => c != 0, orElse: () => 0));
  }

  // One-shot: sequential, fail fast on the first package that errors.
  for (final d in targets) {
    final code = await (await start(d)).exitCode;
    if (code != 0) exit(code);
  }
  stderr.writeln('build: codegen complete (${targets.length} packages)');
}
