import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'set_state_baseline.dart';

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
            if (f.text.contains('package:$other/')) {
              offenders.add('${f.rel(root)} imports package:$other/');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'cross-module reads go through core contracts/ports, never a '
            'direct import:\n${offenders.join('\n')}',
      );
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
      expect(
        offenders,
        isEmpty,
        reason: 'the domain layer must not know about storage, use cases, '
            'widgets or DI:\n${offenders.join('\n')}',
      );
    });

    test("nothing outside a module names that module's Drift classes", () {
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
          // The composition root is the one place whose job IS naming
          // concretes — it binds implementations into ports so that nothing
          // else has to. Exempting it does not widen the blast radius: every
          // consumer still types against the port, which is what the rule
          // protects. Narrow by design — `brands/<brand>/main_<brand>.dart`
          // only, not the whole shell.
          if (RegExp(r'/brands/[^/]+/main_[^/]+\.dart$').hasMatch(f.path)) continue;
          if (owner != null && f.path.endsWith('/$owner.dart')) continue; // the barrel
          for (final hit in drift.allMatches(_stripCommentsAndImports(f.text))) {
            offenders.add('${f.rel(root)}: ${hit.group(0)}');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('telemetry goes through the facade', () {
    // Everything that logs goes through core's `AnalyticsLogger`, so the
    // composition root decides which backends run and no call site can bypass
    // the PHI scrub the adapters apply on the way out. Same shape as the Drift
    // rule above: name the concretes in exactly one place.
    //
    // This lives here rather than in balsm_boundary_lint because custom_lint is
    // commented out of every package's analysis_options.yaml (isolate leak,
    // 2026-07-31), so a rule added there would never run.
    const vendors = ['sentry_flutter', 'sentry', 'posthog_flutter', 'firebase_analytics', 'mixpanel_flutter'];

    /// The adapters and SDK inits — an `AnalyticsLogger` implementation, or the
    /// setup the composition root calls. Extending this list is the review
    /// moment where a new backend's scrub and consent gate get checked.
    const adapters = [
      '/packages/core/lib/src/telemetry/sentry_analytics_logger.dart',
      '/packages/core/lib/src/telemetry/posthog_analytics_logger.dart',
      '/packages/core/lib/src/telemetry/posthog_init.dart',
      '/packages/core/lib/src/crash/sentry_init.dart',
      // Reads Sentry's own client state for the Dev Config diagnostics screen.
      '/packages/core/lib/src/dev/dev_diagnostics.dart',
      // PostHog as a feature-flag source, behind FeatureFlagSource.
      '/packages/core/lib/src/flags/posthog_flag_source.dart',
      // Choice-only, consent-gated PostHog surveys and their context observer.
      '/packages/core/lib/src/telemetry/survey_guard.dart',
    ];

    test('no vendor SDK is imported outside its adapter', () {
      final offenders = <String>[];
      final roots = <String>[
        '${root.path}/app/lib',
        '${root.path}/packages/core/lib',
        for (final m in modules) '${root.path}/modules/$m/lib',
      ];
      for (final dir in roots) {
        for (final f in _dartFiles(dir)) {
          if (adapters.any(f.path.endsWith)) continue;
          for (final vendor in vendors) {
            if (f.text.contains('package:$vendor/')) {
              offenders.add('${f.rel(root)} imports package:$vendor/');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'use ref.watch(analyticsLoggerProvider), or add a new backend '
            'adapter to the `adapters` list above:\n${offenders.join('\n')}',
      );
    });

    test('the adapter list is real, so the rule cannot pass vacuously', () {
      for (final adapter in adapters) {
        expect(File('${root.path}$adapter').existsSync(), isTrue, reason: 'stale exemption: $adapter');
      }
    });
  });

  test('session credentials have one secure store', () {
    // On Android the FlutterSecureStorage options pick the backing file. Sign-in
    // wrote through SecureStorageWrapper while boot and the auth interceptor
    // built their own default-options store — a different, empty file — so
    // every Android restart looked signed out. Found by the deep-link device run.
    final tokenKey = RegExp(r"'balsm\.(user_id|refresh_token|access_token)'");
    final offenders = <String>[
      for (final dir in [
        '${root.path}/app/lib',
        '${root.path}/packages/core/lib',
        for (final m in modules) '${root.path}/modules/$m/lib',
      ])
        for (final f in _dartFiles(dir))
          if (tokenKey.hasMatch(f.text) && f.text.contains('FlutterSecureStorage(')) f.rel(root),
    ];
    expect(offenders, isEmpty, reason: 'use SecureStorageWrapper.storage:\n${offenders.join('\n')}');
  });

  test('setState stays at or below its baseline', () {
    // CODING_STANDARDS §7 limits setState to view-local state, but nothing
    // enforced it and ~500 calls crept in (agent-lessons 2026-11-22). Data goes
    // into a Notifier; this ratchet keeps the backlog from growing back.
    final call = RegExp(r'\bsetState\(');
    final counts = <String, int>{
      for (final dir in [
        '${root.path}/app/lib',
        '${root.path}/packages/core/lib',
        for (final m in modules) '${root.path}/modules/$m/lib',
      ])
        for (final f in _dartFiles(dir))
          if (call.allMatches(_stripCommentsAndImports(f.text)).length case final n when n > 0) f.rel(root): n,
    };
    final paths = {...counts.keys, ...setStateBaseline.keys};
    final offenders = paths
        .map((path) => _setStateOffence(path, counts[path] ?? 0, setStateBaseline[path] ?? 0))
        .nonNulls
        .toList();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

/// The message for one file whose `setState` count breaks the ratchet in
/// `set_state_baseline.dart`, or null when [count] is acceptable for [baseline].
String? _setStateOffence(String path, int count, int baseline) {
  if (count > baseline && baseline == 0) {
    return '$path adds $count setState: data belongs in a Notifier (CODING_STANDARDS §7)';
  }
  if (count > baseline) {
    return '$path has $count setState, baseline $baseline: move the new state into a Notifier (§7)';
  }
  // Strict in both directions, so the headroom a migration frees cannot be
  // spent again later without anyone noticing.
  if (count < baseline) {
    return count == 0
        ? '$path has no setState left: remove it from set_state_baseline.dart'
        : '$path has $count setState, baseline $baseline: lower it in set_state_baseline.dart';
  }
  return null;
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
