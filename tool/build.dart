// Single source of truth for Flutter build/run/test commands across brands,
// environments, and platforms. Consumed by melos scripts, VS Code tasks, and
// CI/CD — so the flavor/target/dart-define wiring lives in ONE typed, validated
// place. Cross-platform (no bash dependency).
//
// Usage: dart run tool/build.dart <action> [brand] [env] [-- extra flutter args]
//   action : run | apk | aab | ios | web | test | integration
//   brand  : balsm (default)  — see tool/build_config.dart
//   env    : dev (default) | staging | prod
//
// Examples:
//   dart run tool/build.dart run balsm dev -d <device-id>
//   dart run tool/build.dart apk balsm prod
//   dart run tool/build.dart web balsm prod
import 'dart:io';

import 'build_config.dart';

const _actions = {'run', 'apk', 'aab', 'ios', 'web', 'test', 'integration'};

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
      'web' => ['build', 'web', '--release', '-t', target, ...defines], // web: no flavor
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
