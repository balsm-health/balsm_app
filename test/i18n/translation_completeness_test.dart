// T189 — i18n translation completeness.
//
// Pairs every `*.i69n.jsonc` bundle (English, the source of truth) with its
// `*_ar.i69n.jsonc` sibling across the app shell, core and every module, and
// asserts the Arabic side is complete, orphan-free and non-empty.
//
// The previous version of this test read `packages/core/assets/i18n/<locale>.json`
// for three Arabic locales. That directory does not exist — the repo moved to
// i69n bundles — so the test called `fail()` at load time, outside any `test()`,
// and died with OutsideTestException on every run. It had been giving no signal
// at all. Locating bundles by glob rather than by hardcoded path is what stops
// that recurring.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic is a first-class locale here, not a partial translation: the app is
/// Arabic-first. Anything less than complete is a bug, so the bar is 100%.
const _minimumBundlePairs = 10;

/// Resolves the repo root regardless of where the runner was launched from.
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    if (Directory('${dir.path}/modules').existsSync() && File('${dir.path}/melos.yaml').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  throw StateError('Could not locate the repo root from ${Directory.current.path}');
}

/// Strips `//` and `/* */` comments and trailing commas from JSONC.
///
/// String-aware on purpose: a naive regex eats the `//` inside every `https://`
/// URL in the bundles and turns a valid file into a parse error.
String stripJsonc(String source) {
  final out = StringBuffer();
  var inString = false;
  var escaped = false;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (inString) {
      out.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
      out.write(c);
      continue;
    }
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      out.write('\n');
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i++;
      continue;
    }
    out.write(c);
  }
  // replaceAllMapped, not replaceAll: `replaceAll` treats `$1` as a literal.
  return out.toString().replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m.group(1)!);
}

/// Every leaf key path in a bundle, dotted. i69n metadata keys (`@@…`) are not
/// translatable content and are skipped.
Set<String> leafPaths(Map<String, dynamic> bundle, [String prefix = '']) {
  final acc = <String>{};
  bundle.forEach((key, value) {
    if (key.startsWith('@@')) return;
    final path = '$prefix$key';
    if (value is Map<String, dynamic>) {
      acc.addAll(leafPaths(value, '$path.'));
    } else {
      acc.add(path);
    }
  });
  return acc;
}

Map<String, String> leafValues(Map<String, dynamic> bundle, [String prefix = '']) {
  final acc = <String, String>{};
  bundle.forEach((key, value) {
    if (key.startsWith('@@')) return;
    final path = '$prefix$key';
    if (value is Map<String, dynamic>) {
      acc.addAll(leafValues(value, '$path.'));
    } else if (value is String) {
      acc[path] = value;
    }
  });
  return acc;
}

Map<String, dynamic> parseBundle(File file) => jsonDecode(stripJsonc(file.readAsStringSync())) as Map<String, dynamic>;

void main() {
  final root = _repoRoot();

  // English bundle → Arabic sibling, for every package that has one.
  final pairs = <({String label, File en, File ar})>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path;
    if (!path.endsWith('.i69n.jsonc') || path.endsWith('_ar.i69n.jsonc')) continue;
    if (path.contains('/build/') || path.contains('/.dart_tool/') || path.contains('/node_modules/')) continue;
    final ar = File(path.replaceAll('.i69n.jsonc', '_ar.i69n.jsonc'));
    if (!ar.existsSync()) continue;
    pairs.add((label: path.substring(root.path.length + 1), en: entity, ar: ar));
  }
  pairs.sort((a, b) => a.label.compareTo(b.label));

  test('discovers the i18n bundles (a glob that finds nothing must fail loudly)', () {
    // Without this, a path change turns every assertion below into a no-op loop
    // that passes — which is exactly how the previous version of this file went
    // unnoticed while broken.
    expect(pairs.length, greaterThanOrEqualTo(_minimumBundlePairs),
        reason: 'Found only ${pairs.length} en/ar bundle pairs under ${root.path}');
  });

  for (final pair in pairs) {
    group(pair.label, () {
      test('Arabic bundle is complete and orphan-free vs English', () {
        final en = leafPaths(parseBundle(pair.en));
        final ar = leafPaths(parseBundle(pair.ar));

        expect(en, isNotEmpty, reason: 'English bundle parsed to zero keys');
        expect(en.difference(ar), isEmpty, reason: 'Keys missing from Arabic');
        // Key signatures carry their parameter list (`pv_authority_body(String
        // authority)`), so a mismatched signature surfaces here as one missing
        // key plus one orphan rather than silently compiling to a different
        // method.
        expect(ar.difference(en), isEmpty, reason: 'Arabic keys not present in English');
      });

      test('no empty translation values', () {
        for (final bundle in [pair.en, pair.ar]) {
          final empty = leafValues(parseBundle(bundle)).entries.where((e) => e.value.trim().isEmpty).map((e) => e.key);
          expect(empty, isEmpty, reason: 'Empty values in ${bundle.path}');
        }
      });
    });
  }
}
