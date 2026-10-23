import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `CHANGELOG.md` and the version being built must agree: every change adds a
/// line under the top section, and that section is the release in
/// `app/pubspec.yaml`. See CODING_STANDARDS.md, "Versioning and the changelog".
void main() {
  final changelog = File('../CHANGELOG.md').readAsStringSync();
  // The version this checkout builds, without the build number.
  final building =
      RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  final sections = RegExp(r'^## \[([^\]]+)\] - (.+)$', multiLine: true).allMatches(changelog).toList();

  test('the top section is the version being built', () {
    expect(sections, isNotEmpty, reason: 'no "## [x.y.z] - …" heading in CHANGELOG.md');
    expect(sections.first.group(1), building,
        reason: 'raise app/pubspec.yaml and the top heading of CHANGELOG.md together');
  });

  test('every version says something', () {
    for (var i = 0; i < sections.length; i++) {
      final end = i + 1 < sections.length ? sections[i + 1].start : changelog.length;
      final entries = RegExp(r'^- ', multiLine: true).allMatches(changelog.substring(sections[i].end, end));
      expect(entries, isNotEmpty, reason: '${sections[i].group(1)} has nothing in its changelog');
    }
  });

  test('each version appears once, newest first', () {
    final versions = sections.map((m) => m.group(1)!).toList();
    expect(versions.toSet().length, versions.length, reason: 'a version listed twice');
    for (var i = 1; i < versions.length; i++) {
      expect(_compare(versions[i - 1], versions[i]), greaterThan(0),
          reason: '${versions[i - 1]} sits above ${versions[i]} but is not newer');
    }
  });

  test('a version is Unreleased or dated, and nothing unreleased sits below a release', () {
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    var released = false;
    for (final m in sections) {
      final status = m.group(2)!;
      expect(status == 'Unreleased' || date.hasMatch(status), isTrue,
          reason: '${m.group(1)}: "$status" is neither Unreleased nor a date');
      if (date.hasMatch(status)) {
        released = true;
      } else {
        expect(released, isFalse,
            reason: '${m.group(1)} is Unreleased below a released version; date it with the release that shipped it');
      }
    }
  });
}

/// Compares two `MAJOR.MINOR.PATCH` versions numerically.
int _compare(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}
