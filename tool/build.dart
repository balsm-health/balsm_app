// Single source of truth for Flutter build/run/test commands across brands,
// environments, and platforms. Consumed by melos scripts, VS Code tasks, and
// CI/CD — so the flavor/target/dart-define wiring lives in ONE typed, validated
// place. Cross-platform (no bash dependency).
//
// Usage: dart run tool/build.dart <action> [brand] [env] [options] [-- extra]
//   action  : run | apk | aab | ipa | ios | web | test | integration | gen
//   brand   : balsm (default)  — see tool/build_config.dart
//   env     : dev (default) | staging | prod
//   options : --export=adhoc|appstore|none   (ipa signing profile)
//             --servers=shared|shared.tunnel (which server list to compile in)
//
// Every build action collects its artifact into
//   output/<brand>/<platform>/<brand>-<version>-<env>.<ext>
// so the thing you just built is findable without digging through build/.
//
// Examples:
//   dart run tool/build.dart run balsm dev -d <device-id>
//   dart run tool/build.dart apk balsm prod
//   dart run tool/build.dart ipa balsm dev --export=adhoc --servers=shared.tunnel
//   dart run tool/build.dart web balsm prod
//   dart run tool/build.dart gen           # build_runner across all packages
import 'dart:io';

import 'build_config.dart';

const _actions = {'run', 'apk', 'aab', 'ipa', 'ios', 'web', 'test', 'integration', 'gen'};

/// Where each build action leaves its artifact and what the collected copy is
/// called. Searched by extension rather than an exact path: Flutter nests
/// flavored outputs differently per platform (and has moved them between
/// versions), so a hardcoded filename is a silent break waiting to happen.
const _artifacts = <String, ({String platform, String dir, String ext})>{
  'apk': (platform: 'android', dir: 'build/app/outputs/flutter-apk', ext: 'apk'),
  'aab': (platform: 'android', dir: 'build/app/outputs/bundle', ext: 'aab'),
  'ipa': (platform: 'ios', dir: 'build/ios/ipa', ext: 'ipa'),
};

/// iOS export profiles — `ios/signing/<name>.plist`. `none` archives without
/// signing, for export from the Xcode Organizer.
const _exports = {'adhoc', 'appstore', 'none'};

Never _fail(String msg) {
  stderr.writeln('build: $msg');
  exit(2);
}

Future<void> main(List<String> argv) async {
  final args = [...argv];
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _fail('usage: dart run tool/build.dart <action> [brand] [env] [options] [-- extra]\n'
        '  action  : ${_actions.join(' | ')}\n'
        '  brand   : ${brands.keys.join(' | ')} (default: ${brands.keys.first})\n'
        '  env     : dev | staging | prod (default: dev)\n'
        '  options : --export=${_exports.join('|')}  --servers=<name>');
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

  // Named options are pulled out of the passthrough list before it reaches
  // flutter, which would reject them.
  final export = _takeOption(args, 'export') ?? 'adhoc';
  if (action == 'ipa' && !_exports.contains(export)) {
    _fail("unknown export '$export' (${_exports.join(' | ')})");
  }
  // Which server list gets compiled in. `shared.tunnel` adds the devtunnel and
  // LAN presets for testing against a machine on the desk.
  final servers = _takeOption(args, 'servers') ?? 'shared';
  final serversFile = File.fromUri(Platform.script.resolve('../app/env/$servers.json'));
  if (!serversFile.existsSync()) {
    _fail("no server list 'env/$servers.json' — it is git-ignored, so a fresh "
        'clone has to create it before this option works');
  }

  final extra = args; // remaining args pass straight through to flutter
  final target = 'lib/brands/$brandKey/main_$brandKey.dart';
  final defines = [
    '--dart-define-from-file=env/$brandKey/$env.json',
    '--dart-define-from-file=env/$servers.json',
  ];
  final flavor = ['--flavor', brand.flavor];
  final exportOptions = export == 'none' ? ['--no-codesign'] : ['--export-options-plist=ios/signing/$export.plist'];

  final flutterArgs = <String>[
    ...switch (action) {
      'run' => ['run', ...flavor, '-t', target, ...defines],
      'apk' => ['build', 'apk', '--release', ...flavor, '-t', target, ...defines],
      'aab' => ['build', 'appbundle', '--release', ...flavor, '-t', target, ...defines],
      'ipa' => ['build', 'ipa', '--release', ...flavor, '-t', target, ...defines, ...exportOptions],
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
  final code = await proc.exitCode;
  if (code == 0) _collect(action, brandKey, env, appDir);
  exit(code);
}

/// Extracts `--name=value` from [args] and removes it, so the rest can pass
/// through to flutter untouched. Returns null when absent.
String? _takeOption(List<String> args, String name) {
  final i = args.indexWhere((a) => a.startsWith('--$name='));
  if (i < 0) return null;
  return args.removeAt(i).substring(name.length + 3);
}

/// Copies the artifact this action produced to
/// `output/<brand>/<platform>/<brand>-<version>-<env>.<ext>`.
///
/// A copy, not a move: `flutter build` prints the path under `build/`, and
/// tooling that expects it there (an Xcode Organizer upload, a CI step that
/// was written against the default layout) keeps working.
///
/// Collection failing never fails the build — the artifact exists either way,
/// and turning a good build into a red one over a file copy would be worse
/// than a warning.
void _collect(String action, String brand, String env, String appDir) {
  final root = Directory.fromUri(Platform.script.resolve('..'));
  final version = _appVersion(appDir);

  if (action == 'web') {
    final src = Directory('$appDir/build/web');
    if (!src.existsSync()) return;
    // A directory, not an archive: the web build is deployed by serving these
    // files, so zipping it would only mean unzipping it again.
    final dest = Directory('${root.path}/output/$brand/web/$brand-$version-$env');
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    _copyDir(src, dest);
    stderr.writeln('build: collected → ${_rel(dest.path, root.path)}');
    return;
  }

  final spec = _artifacts[action];
  if (spec == null) return; // run/test/integration/ios produce nothing to collect

  final found = _newestWithExtension(Directory('$appDir/${spec.dir}'), spec.ext);
  if (found == null) {
    stderr.writeln('build: warning — built ok but no .${spec.ext} found under ${spec.dir}');
    return;
  }

  final dest = File('${root.path}/output/$brand/${spec.platform}/$brand-$version-$env.${spec.ext}');
  dest.parent.createSync(recursive: true);
  found.copySync(dest.path);
  stderr.writeln('build: collected → ${_rel(dest.path, root.path)}');
}

/// The `version:` line from app/pubspec.yaml, e.g. `0.1.0+1`.
///
/// The build number is kept: two builds of one version are different
/// artifacts, and dropping it would have the second silently overwrite the
/// first.
String _appVersion(String appDir) {
  final pubspec = File('$appDir/pubspec.yaml');
  if (!pubspec.existsSync()) return 'unknown';
  final line = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec.readAsStringSync());
  return line?.group(1) ?? 'unknown';
}

/// Newest file with [ext] anywhere under [dir]. Recursive because Flutter nests
/// the app bundle one level deeper (`bundle/<flavor>Release/`) than the APK.
File? _newestWithExtension(Directory dir, String ext) {
  if (!dir.existsSync()) return null;
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.$ext')).toList();
  if (files.isEmpty) return null;
  files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return files.first;
}

void _copyDir(Directory src, Directory dest) {
  dest.createSync(recursive: true);
  for (final entity in src.listSync(recursive: true)) {
    final suffix = entity.path.substring(src.path.length);
    if (entity is Directory) {
      Directory('${dest.path}$suffix').createSync(recursive: true);
    } else if (entity is File) {
      final out = File('${dest.path}$suffix');
      out.parent.createSync(recursive: true);
      entity.copySync(out.path);
    }
  }
}

String _rel(String path, String root) => path.startsWith(root) ? path.substring(root.length + 1) : path;

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
