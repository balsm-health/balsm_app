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

  test('the top section says something', () {
    final start = sections.first.end;
    final end = sections.length > 1 ? sections[1].start : changelog.length;
    final entries = RegExp(r'^- ', multiLine: true).allMatches(changelog.substring(start, end));
    expect(entries, isNotEmpty, reason: 'a release with nothing in its changelog');
  });

  test('each release appears once, and a released one carries its date', () {
    final versions = sections.map((m) => m.group(1)).toList();
    expect(versions.toSet().length, versions.length, reason: 'a version listed twice');
    for (final m in sections.skip(1)) {
      expect(m.group(2), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          reason: '${m.group(1)} is below the top section, so it is released and needs its date');
    }
  });
}
