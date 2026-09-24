// Single source of truth for Flutter build/run/test commands across brands,
// environments, and platforms. Consumed by melos scripts, VS Code tasks, and
// CI/CD — so the flavor/target/dart-define wiring lives in ONE typed, validated
// place. Cross-platform (no bash dependency).
//
// Usage: dart run tool/build.dart <action> [brand] [env] [options] [-- extra]
//   action  : run | test | integration | gen
//             build --artifact=<key>   (or the artifact key as the action)
//             install                  push a collected artifact to a device
//   artifact: apk | aab | ipa | ipa-appstore | ipa-archive
//             web | macos | windows | linux
//   brand   : balsm (default)  — see tool/build_config.dart
//   env     : dev (default) | staging | prod
//   options : --artifact=<key>                what to build / install
//             --export=adhoc|appstore|none    ipa signing profile
//             --servers=shared|shared.tunnel  which server list to compile in
//             --device=<id>                   skip the device picker
//
// Every build collects its artifact into
//   output/<brand>/<platform>/<brand>-<version>-<env>[.<ext>]
// so the thing you just built is findable without digging through build/.
//
// Examples:
//   dart run tool/build.dart run balsm dev -d <device-id>
//   dart run tool/build.dart apk balsm prod
//   dart run tool/build.dart build balsm dev --artifact=macos
//   dart run tool/build.dart ipa balsm dev --servers=shared.tunnel
//   dart run tool/build.dart install balsm dev --artifact=ipa
//   dart run tool/build.dart gen           # build_runner across all packages

import 'dart:convert';
import 'dart:io';

import 'build_config.dart';

final _actions = {'run', 'test', 'integration', 'gen', 'install', 'build', ..._artifacts.keys};

/// One buildable artifact: what flutter is asked for, where it lands, and what
/// the collected copy is called.
///
/// `ext` null means the artifact IS a directory (web output, a desktop bundle)
/// and the whole thing is collected under a versioned folder name.
///
/// `flavor` is false where Flutter has no flavor concept — web and every
/// desktop platform. Passing --flavor there fails the build, and the brand is
/// carried by the entrypoint and dart-defines anyway, which is what actually
/// decides how the app behaves.
///
/// `needs` is the platform directory that must exist. Desktop platforms are
/// scaffolded per project, so a missing one is a setup step, not a bug.
typedef Artifact = ({
  String platform,
  List<String> build,
  String dir,
  String? ext,
  bool flavor,
  String needs,
  String? export,
});

const _artifacts = <String, Artifact>{
  'apk': (
    platform: 'android',
    build: ['apk'],
    dir: 'build/app/outputs/flutter-apk',
    ext: 'apk',
    flavor: true,
    needs: 'android',
    export: null,
  ),
  'aab': (
    platform: 'android',
    build: ['appbundle'],
    // One level deeper than the apk (`bundle/<flavor>Release/`); the collector
    // searches recursively rather than encoding that.
    dir: 'build/app/outputs/bundle',
    ext: 'aab',
    flavor: true,
    needs: 'android',
    export: null,
  ),
  'ipa': (
    platform: 'ios',
    build: ['ipa'],
    dir: 'build/ios/ipa',
    ext: 'ipa',
    flavor: true,
    needs: 'ios',
    export: 'adhoc',
  ),
  'ipa-appstore': (
    platform: 'ios',
    build: ['ipa'],
    dir: 'build/ios/ipa',
    ext: 'ipa',
    flavor: true,
    needs: 'ios',
    export: 'appstore',
  ),
  'ipa-archive': (
    platform: 'ios',
    build: ['ipa'],
    dir: 'build/ios/ipa',
    ext: 'ipa',
    flavor: true,
    needs: 'ios',
    export: 'none',
  ),
  'web': (
    platform: 'web',
    build: ['web'],
    dir: 'build/web',
    ext: null,
    flavor: false,
    needs: 'web',
    export: null,
  ),
  'macos': (
    platform: 'macos',
    build: ['macos'],
    dir: 'build/macos/Build/Products/Release',
    // A .app is a directory, not a file — the collector copies it as one so it
    // stays double-clickable.
    ext: 'app',
    flavor: false,
    needs: 'macos',
    export: null,
  ),
  'windows': (
    platform: 'windows',
    build: ['windows'],
    dir: 'build/windows/x64/runner/Release',
    ext: null,
    flavor: false,
    needs: 'windows',
    export: null,
  ),
  'linux': (
    platform: 'linux',
    build: ['linux'],
    dir: 'build/linux/x64/release/bundle',
    ext: null,
    flavor: false,
    needs: 'linux',
    export: null,
  ),
};

/// iOS export profiles — `ios/signing/<name>.plist`. `none` archives without
/// signing, for export from the Xcode Organizer.
const _exports = {'adhoc', 'appstore', 'none'};

/// Artifacts that can be pushed to a device, and how.
const _installable = {'apk', 'ipa'};

Never _fail(String msg) {
  stderr.writeln('build: $msg');
  exit(2);
}

Future<void> main(List<String> argv) async {
  final args = [...argv];
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _fail('usage: dart run tool/build.dart <action> [brand] [env] [options] [-- extra]\n'
        '  action  : run | test | integration | gen | install | build | <artifact>\n'
        '  brand   : ${brands.keys.join(' | ')} (default: ${brands.keys.first})\n'
        '  env     : dev | staging | prod (default: dev)\n'
        '  artifact: ${_artifacts.keys.join(' | ')}\n'
        '  options : --artifact=<key> --export=${_exports.join('|')} '
        '--servers=<name> --device=<id>');
  }

  var action = args.removeAt(0);
  // Kept for callers that predate the artifact registry.
  if (action == 'ios') action = 'ipa-archive';
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

  // Installing needs no flutter invocation — it pushes an artifact that a
  // previous build already collected.
  if (action == 'install') {
    await _install(brandKey, env, args);
    return;
  }

  // Named options are pulled out of the passthrough list before it reaches
  // flutter, which would reject them.

  // `build --artifact=x` and the bare `x` action are the same thing; the first
  // exists so a VS Code task can drive everything from one picker.
  final artifactKey = action == 'build' ? (_takeOption(args, 'artifact') ?? 'apk') : action;
  final artifact = _artifacts[artifactKey];
  if (action == 'build' && artifact == null) {
    _fail("unknown artifact '$artifactKey' (${_artifacts.keys.join(' | ')})");
  }

  // An explicit --export overrides the artifact's own default, so `ipa
  // --export=appstore` keeps working alongside the `ipa-appstore` key.
  final export = _takeOption(args, 'export') ?? artifact?.export ?? 'adhoc';
  if (artifact?.platform == 'ios' && !_exports.contains(export)) {
    _fail("unknown export '$export' (${_exports.join(' | ')})");
  }

  // Which server list gets compiled in. `shared.tunnel` adds the devtunnel and
  // LAN presets for testing against a machine on the desk.
  final servers = _takeOption(args, 'servers') ?? 'shared';
  final serversFile = File.fromUri(Platform.script.resolve('../app/env/$servers.json'));
  if (!serversFile.existsSync()) {
    _fail("no server list 'app/env/$servers.json' — these are git-ignored, so a "
        'fresh clone creates its own.\n'
        '  cp app/env/shared.example.json app/env/$servers.json\n'
        '  then edit it; see app/env/README.md');
  }

  final appDirEarly = Platform.script.resolve('../app').toFilePath();
  if (artifact != null && !Directory('$appDirEarly/${artifact.needs}').existsSync()) {
    _fail('no app/${artifact.needs} — this project has not been scaffolded for '
        '${artifact.platform}.\n'
        '  enable it:  (cd app && fvm flutter create --platforms=${artifact.needs} .)\n'
        '  then check `git status` — flutter create also drops a template\n'
        '  lib/main.dart and test/widget_test.dart this project does not use,\n'
        '  and rewrites the platform list in .metadata rather than adding to it.');
  }

  // --device=<id> is documented for every action; flutter itself only takes
  // -d, so translate here (previously it worked for `install` but leaked
  // through to `flutter run` verbatim, which rejects it).
  final device = _takeOption(args, 'device');
  if (device != null) args.addAll(['-d', device]);

  final extra = args; // remaining args pass straight through to flutter
  final target = 'lib/brands/$brandKey/main_$brandKey.dart';
  final defines = [
    '--dart-define-from-file=env/$brandKey/$env.json',
    '--dart-define-from-file=env/$servers.json',
  ];
  // Omitted where Flutter has no flavor concept — see [Artifact.flavor].
  final flavor = (artifact?.flavor ?? true) ? ['--flavor', brand.flavor] : const <String>[];
  final exportOptions = export == 'none' ? ['--no-codesign'] : ['--export-options-plist=ios/signing/$export.plist'];

  final flutterArgs = <String>[
    ...switch (action) {
      'run' => ['run', ...flavor, '-t', target, ...defines],
      'test' => ['test'],
      'integration' => ['test', 'integration_test', ...flavor],
      // Every artifact builds the same way; only the sub-command, the flavor
      // rule and the iOS export options differ, and all three come from the
      // registry rather than a case per artifact.
      _ => [
          'build',
          // Non-null here: every action that reaches this arm is an artifact
          // key, and `build` without a valid --artifact already failed above.
          ...artifact!.build,
          '--release',
          ...flavor,
          '-t',
          target,
          ...defines,
          if (artifact.platform == 'ios') ...exportOptions,
          if (artifact.platform == 'web' && env == 'prod') ...[
            // Hosted at https://balsm.health/apps/balsm — asset URLs must be
            // prefixed or flutter.js 404s under the site's locale router.
            '--base-href=/apps/balsm/',
            // Local canvaskit — gstatic.com is blocked by the site CSP.
            '--no-web-resources-cdn',
          ],
        ],
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
  // run/test/integration produce no artifact to collect.
  if (code == 0 && artifact != null) _collect(artifact, brandKey, env, appDir);
  exit(code);
}

/// Extracts `--name=value` from [args] and removes it, so the rest can pass
/// through to flutter untouched. Returns null when absent.
String? _takeOption(List<String> args, String name) {
  final i = args.indexWhere((a) => a.startsWith('--$name='));
  if (i < 0) return null;
  return args.removeAt(i).substring(name.length + 3);
}

/// Copies what was just built to
/// `output/<brand>/<platform>/<brand>-<version>-<env>[.<ext>]`.
///
/// A copy, not a move: `flutter build` prints the path under `build/`, and
/// tooling that expects it there (an Xcode Organizer upload, a CI step written
/// against the default layout) keeps working.
///
/// Collection failing never fails the build — the artifact exists either way,
/// and turning a good build red over a file copy would be worse than a warning.
void _collect(Artifact artifact, String brand, String env, String appDir) {
  final root = Directory.fromUri(Platform.script.resolve('..'));
  final version = _appVersion(appDir);
  final stem = '$brand-$version-$env';
  final outDir = Directory('${root.path}/output/$brand/${artifact.platform}');
  final src = Directory('$appDir/${artifact.dir}');

  // ext == null: the artifact IS this directory (web output, a desktop
  // bundle). Collected whole, under a versioned folder name — the web build is
  // deployed by serving these files and a desktop bundle is run in place, so
  // archiving either would only mean unarchiving it again.
  if (artifact.ext == null) {
    if (!src.existsSync()) {
      stderr.writeln('build: warning — built ok but ${artifact.dir} is missing');
      return;
    }
    final dest = Directory('${outDir.path}/$stem');
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    _copyDir(src, dest);
    stderr.writeln('build: collected → ${_rel(dest.path, root.path)}');
    return;
  }

  final found = _newestWithExtension(src, artifact.ext!);
  if (found == null) {
    stderr.writeln('build: warning — built ok but no .${artifact.ext} found under ${artifact.dir}');
    return;
  }

  final dest = '${outDir.path}/$stem.${artifact.ext}';
  outDir.createSync(recursive: true);
  // A macOS .app carries the right extension but is a directory.
  if (found is Directory) {
    final d = Directory(dest);
    if (d.existsSync()) d.deleteSync(recursive: true);
    _copyDir(found, d);
  } else {
    (found as File).copySync(dest);
  }
  stderr.writeln('build: collected → ${_rel(dest, root.path)}');
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

/// Newest entity named `*.[ext]` anywhere under [dir].
///
/// Recursive because Flutter nests the app bundle one level deeper
/// (`bundle/<flavor>Release/`) than the APK. Returns an entity rather than a
/// File because a macOS `.app` is a directory.
FileSystemEntity? _newestWithExtension(Directory dir, String ext) {
  if (!dir.existsSync()) return null;
  final hits = dir.listSync(recursive: true, followLinks: false).where((e) => e.path.endsWith('.$ext')).toList();
  if (hits.isEmpty) return null;
  hits.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return hits.first;
}

/// Recursively copies [src] to [dest], preserving symlinks.
///
/// On macOS this shells out to `ditto`, which is the only thing that gets a
/// `.app` right: a bundle is full of symlinks (84 in this app's) plus the
/// extended attributes codesign reads. Copying it entry-by-entry flattens the
/// links — measured at 80MB becoming 239MB — and invalidates the signature, so
/// the collected bundle refuses to launch.
///
/// Elsewhere (web output, a Linux/Windows bundle) a plain recursive copy is
/// enough, but it still walks with `followLinks: false` and recreates links as
/// links, for the same reason in miniature.
void _copyDir(Directory src, Directory dest) {
  if (Platform.isMacOS) {
    dest.parent.createSync(recursive: true);
    final res = Process.runSync('ditto', [src.path, dest.path]);
    if (res.exitCode == 0) return;
    stderr.writeln('build: ditto failed, falling back to a plain copy\n${res.stderr}');
  }
  _copyDirDart(src, dest);
}

void _copyDirDart(Directory src, Directory dest) {
  dest.createSync(recursive: true);
  // followLinks: false — otherwise a symlinked directory is walked into and
  // copied as real files, which is the bug this whole function exists to avoid.
  for (final entity in src.listSync(followLinks: false)) {
    final name = entity.path.substring(src.path.length + 1);
    final target = '${dest.path}/$name';
    // Link first: with followLinks off, a link to a directory is a Link, but
    // ordering this last would still be a trap worth not setting.
    if (entity is Link) {
      Link(target).createSync(entity.targetSync(), recursive: true);
    } else if (entity is Directory) {
      _copyDirDart(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
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

/// A device this machine can install onto.
typedef Device = ({String id, String name, String platform});

/// Installs a collected artifact onto a connected device.
///
/// Installs what a previous build left in `output/`, rather than building: the
/// common loop is build once and install onto several devices, and rebuilding
/// each time would cost minutes for nothing. The VS Code task that wants both
/// chains this after a build task.
///
/// Picks the device when there is exactly one, and asks when there are
/// several — a static VS Code picker cannot enumerate what is plugged in right
/// now, so the choice has to happen here.
Future<void> _install(String brand, String env, List<String> args) async {
  final wanted = _takeOption(args, 'artifact') ?? 'ipa';
  if (!_installable.contains(wanted)) {
    _fail("install: cannot push '$wanted' to a device (${_installable.join(' | ')})");
  }

  final artifact = _artifacts[wanted]!;
  final root = Directory.fromUri(Platform.script.resolve('..'));
  final appDir = Platform.script.resolve('../app').toFilePath();
  final version = _appVersion(appDir);
  final file = File('${root.path}/output/$brand/${artifact.platform}/$brand-$version-$env.${artifact.ext}');

  if (!file.existsSync()) {
    _fail('install: no ${_rel(file.path, root.path)}\n'
        '  build it first:  dart run tool/build.dart $wanted $brand $env');
  }

  final explicit = _takeOption(args, 'device');
  final device = explicit != null
      ? (id: explicit, name: explicit, platform: artifact.platform)
      : await _pickDevice(artifact.platform);

  stderr.writeln('install: ${device.name} ← ${_rel(file.path, root.path)}');

  final cmd = switch (artifact.platform) {
    'ios' => ('xcrun', ['devicectl', 'device', 'install', 'app', '--device', device.id, file.path]),
    // -r reinstalls over an existing copy instead of failing on a signature or
    // version clash, which is what iterating on a debug build always hits.
    'android' => ('adb', ['-s', device.id, 'install', '-r', file.path]),
    _ => _fail('install: no installer for ${artifact.platform}'),
  };

  final proc = await Process.start(cmd.$1, cmd.$2, mode: ProcessStartMode.inheritStdio);
  final code = await proc.exitCode;
  if (code != 0) {
    // Listed, not asserted: the tool's own error above says which one it is,
    // and claiming a single cause here would be wrong more often than right.
    stderr.writeln('install: failed. Usual causes:\n'
        '  - the device is locked, unpaired, or not trusted by this machine\n'
        "  - (iOS) the device's UDID is not in the provisioning profile the ipa\n"
        '    was signed with; an ad-hoc build only installs on devices in it\n'
        '  - (iOS) a build signed for the App Store, which never installs directly\n'
        '  - (Android) a different signing key than the installed copy — uninstall first');
  }
  exit(code);
}

/// The connected device for [platform]: the only one, or whichever the user
/// picks from a numbered list.
Future<Device> _pickDevice(String platform) async {
  final devices = platform == 'ios' ? await _iosDevices() : await _androidDevices();

  if (devices.isEmpty) {
    _fail('install: no connected ${platform == 'ios' ? 'iPhone' : 'Android device'}.\n'
        '  Plug it in (or have it on the same network), unlock it, and make sure\n'
        '  it is paired and trusted with this machine.');
  }
  if (devices.length == 1) return devices.single;

  stderr.writeln('install: several devices connected —');
  for (var i = 0; i < devices.length; i++) {
    stderr.writeln('  [${i + 1}] ${devices[i].name}  (${devices[i].id})');
  }
  stderr.write('  choose [1-${devices.length}]: ');

  final answer = stdin.readLineSync()?.trim();
  final choice = int.tryParse(answer ?? '');
  if (choice == null || choice < 1 || choice > devices.length) {
    _fail("install: '$answer' is not one of 1-${devices.length}. "
        'Non-interactively, pass --device=<id>.');
  }
  return devices[choice - 1];
}

/// Connected iPhones, via devicectl.
///
/// JSON rather than parsing the table `devicectl list devices` prints: the
/// table is for humans and its columns shift with device name length.
Future<List<Device>> _iosDevices() async {
  if (!Platform.isMacOS) _fail('install: iOS install is macOS only — devicectl ships with Xcode');

  final tmp = File('${Directory.systemTemp.path}/balsm-devicectl-$pid.json');
  try {
    final res = await Process.run('xcrun', ['devicectl', 'list', 'devices', '--json-output', tmp.path]);
    if (res.exitCode != 0 || !tmp.existsSync()) {
      _fail('install: could not list devices — is Xcode 15+ installed?\n${res.stderr}');
    }
    final parsed = jsonDecode(tmp.readAsStringSync()) as Map<String, dynamic>;
    return ((parsed['result'] as Map<String, dynamic>?)?['devices'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((d) => (d['hardwareProperties'] as Map?)?['platform'] == 'iOS')
        .where((d) => (d['connectionProperties'] as Map?)?['tunnelState'] == 'connected')
        .map((d) => (
              id: d['identifier'] as String,
              name: (d['deviceProperties'] as Map?)?['name'] as String? ?? 'iPhone',
              platform: 'ios',
            ))
        .toList();
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

/// Connected Android devices, via `adb devices -l`.
///
/// Only rows marked `device` count: `unauthorized` means the trust prompt has
/// not been accepted and `offline` means adb can see it but cannot talk to it,
/// and installing onto either fails with a worse message than this one.
Future<List<Device>> _androidDevices() async {
  final res = await Process.run('adb', ['devices', '-l']);
  if (res.exitCode != 0) {
    _fail('install: adb failed — is the Android SDK platform-tools on PATH?\n${res.stderr}');
  }
  final devices = <Device>[];
  for (final line in const LineSplitter().convert(res.stdout as String).skip(1)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts[1] != 'device') continue;
    final model = parts.firstWhere((p) => p.startsWith('model:'), orElse: () => '');
    devices.add((
      id: parts[0],
      name: model.isEmpty ? parts[0] : model.substring('model:'.length).replaceAll('_', ' '),
      platform: 'android',
    ));
  }
  return devices;
}
