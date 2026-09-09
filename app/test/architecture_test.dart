import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layering rules from CLAUDE.md, enforced instead of documented.
///
/// These held when written. They are the kind of rule that rots silently — a
/// single convenience import is invisible in review and only shows up later as
/// a module that cannot be tested or replaced. Failing here costs one line to
/// read; finding it after the fact costs a refactor.
void main() {
  final root = _repoRoot();
  final modules = Directory('${root.path}/modules')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .toList()
    ..sort();

  test('the module list was actually discovered', () {
    expect(modules, isNotEmpty, reason: 'repo root resolved to ${root.path}');
    expect(modules, contains('records'));
  });

  group('modules are independent', () {
    test('no module imports another module', () {
      final offenders = <String>[];
      for (final m in modules) {
        for (final f in _dartFiles('${root.path}/modules/$m/lib')) {
          for (final other in modules) {
            if (other == m) continue;
            if (f.text.contains("package:$other/")) {
              offenders.add('${f.rel(root)} imports package:$other/');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'cross-module reads go through core contracts/ports, never a '
              'direct import:\n${offenders.join('\n')}');
    });

    test('no module declares another module as a dependency', () {
      final offenders = <String>[];
      for (final m in modules) {
        final pubspec = File('${root.path}/modules/$m/pubspec.yaml');
        if (!pubspec.existsSync()) continue;
        final deps = pubspec.readAsStringSync();
        for (final other in modules) {
          if (other == m) continue;
          if (RegExp('^  $other:', multiLine: true).hasMatch(deps)) {
            offenders.add('modules/$m/pubspec.yaml declares $other');
          }
        }
      }
      // A declared-but-unused dependency is worse than a used one: it makes the
      // boundary look optional and lets the next import in without review.
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('layers point inward', () {
    test('domain depends on nothing above it', () {
      final banned = RegExp(
        r"import\s+'[^']*(?:infrastructure|application|presentation)/|import\s+'package:flutter_riverpod/",
      );
      final offenders = <String>[];
      for (final m in modules) {
        for (final f in _dartFiles('${root.path}/modules/$m/lib/src/domain')) {
          if (banned.hasMatch(f.text)) offenders.add(f.rel(root));
        }
      }
      expect(offenders, isEmpty,
          reason: 'the domain layer must not know about storage, use cases, '
              'widgets or DI:\n${offenders.join('\n')}');
    });

    test('nothing outside a module names that module\'s Drift classes', () {
      // Each module's barrel deliberately exports its own `Drift*` class so the
      // module's own tests can construct one against an in-memory database.
      // That is the whole permitted blast radius: application, presentation and
      // the app shell type against the port, per CLAUDE.md.
      final drift = RegExp(r'\bDrift[A-Z]\w*\b');
      final offenders = <String>[];
      final roots = <String>[
        '${root.path}/app/lib',
        for (final m in modules) '${root.path}/modules/$m/lib',
      ];
      for (final dir in roots) {
        final owner = dir.contains('/modules/') ? dir.split('/modules/')[1].split('/').first : null;
        for (final f in _dartFiles(dir)) {
          if (f.path.contains('/infrastructure/')) continue;
          if (owner != null && f.path.endsWith('/$owner.dart')) continue; // the barrel
          for (final hit in drift.allMatches(_stripCommentsAndImports(f.text))) {
            offenders.add('${f.rel(root)}: ${hit.group(0)}');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}

/// Walks up from the test's working directory to the melos workspace root.
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/modules').existsSync() && Directory('${dir.path}/packages').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  fail('could not locate the workspace root above ${Directory.current.path}');
}

class _Source {
  _Source(this.path, this.text);
  final String path;
  final String text;
  String rel(Directory root) => path.replaceFirst('${root.path}/', '');
}

Iterable<_Source> _dartFiles(String dir) sync* {
  final d = Directory(dir);
  if (!d.existsSync()) return;
  for (final e in d.listSync(recursive: true).whereType<File>()) {
    if (!e.path.endsWith('.dart') || e.path.endsWith('.g.dart')) continue;
    yield _Source(e.path, e.readAsStringSync());
  }
}

/// Drops `//` comments and import/export lines so prose about a class and the
/// one wiring import that binds it are not mistaken for type coupling.
String _stripCommentsAndImports(String source) => source.split('\n').where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('import ') && !t.startsWith('export ') && !t.startsWith('show ');
    }).join('\n');
