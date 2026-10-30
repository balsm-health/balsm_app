#!/usr/bin/env python3
"""Changelog notes in changelog.d/, and the release that collects them.

A pull request that changes what ships adds one note file; it never touches the
version. Promote runs `collect` when it sends a build to testers: the notes go
into CHANGELOG.md, the version in app/pubspec.yaml rises by the largest change
among them, and the notes are deleted. See CODING_STANDARDS.md §9.

  changelog.py check <base-sha>   gate for a pull request or merge-queue entry
  changelog.py collect            fold the notes into a release (edits files)

A note is changelog.d/<name>.<group>[.<raise>].md:
  group  added | changed | fixed | removed | security  (its CHANGELOG group)
  raise  major | minor  (optional; added defaults to minor, the rest to patch)
Its text is the changelog line, ending with its ticket as a link.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

NOTES = Path('changelog.d')
PUBSPEC = Path('app/pubspec.yaml')
CHANGELOG = Path('CHANGELOG.md')
GROUPS = ['added', 'changed', 'fixed', 'removed', 'security']
RAISES = ['patch', 'minor', 'major']
NAME = re.compile(r'^[A-Za-z0-9._-]+?\.(' + '|'.join(GROUPS) + r')(?:\.(major|minor))?\.md$')
# Ends with its ticket(s): ([#99](https://github.com/…/issues/99)), several
# separated by ", ".
TICKET = re.compile(r'\((\[#\d+\]\(https://github\.com/[^)\s]+/(?:issues|pull)/\d+\)(?:, )?)+\)\s*$')
VERSION_LINE = re.compile(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', re.M)
# What ships: everything under app/, packages/ and modules/ except tests and docs.
SHIPPED = ['app', 'packages', 'modules',
           ':(exclude)**/test/**', ':(exclude)**/integration_test/**', ':(exclude)**/*.md']


def git(*args):
    return subprocess.run(['git', *args], check=True, capture_output=True, text=True).stdout


def fail(msg):
    print(f'::error::{msg}')
    sys.exit(1)


def note_files():
    if not NOTES.is_dir():
        return []
    return sorted(p for p in NOTES.iterdir() if p.is_file() and p.name != 'README.md')


def parse_note(path):
    """(group, raise, text) for a note, or an error message."""
    m = NAME.match(path.name)
    if not m:
        return f'{path}: name it <name>.<{"|".join(GROUPS)}>[.major|.minor].md'
    text = path.read_text().strip()
    text = re.sub(r'^- ', '', text)
    if not text:
        return f'{path} is empty'
    if not TICKET.search(text):
        return (f'{path} must end with its ticket as a link, e.g. '
                '([#99](https://github.com/balsm-health/balsm_app/issues/99))')
    group = m.group(1)
    raise_ = m.group(2) or ('minor' if group == 'added' else 'patch')
    return group, raise_, text


def version():
    m = VERSION_LINE.search(PUBSPEC.read_text())
    if not m:
        fail(f'no MAJOR.MINOR.PATCH+BUILD version in {PUBSPEC}')
    return tuple(int(x) for x in m.groups()[:3]), int(m.group(4))


def bump(v, raise_):
    major, minor, patch = v
    if raise_ == 'major':
        return major + 1, 0, 0
    if raise_ == 'minor':
        return major, minor + 1, 0
    return major, minor, patch + 1


def fmt(v):
    return '.'.join(map(str, v))


def check(base):
    errors = []
    notes = note_files()
    for p in notes:
        r = parse_note(p)
        if isinstance(r, str):
            errors.append(r)

    old = re.search(r'^version:.*$', git('show', f'{base}:{PUBSPEC}'), re.M)
    new = re.search(r'^version:.*$', PUBSPEC.read_text(), re.M)
    if old and new and old.group(0) != new.group(0):
        errors.append(f'{PUBSPEC} version changed ({old.group(0)} → {new.group(0)}). '
                      'Leave it: Promote raises it from the changelog notes when it releases.')

    shipped = git('diff', '--name-only', f'{base}...HEAD', '--', *SHIPPED).split()
    added = [n for n in git('diff', '--name-only', '--diff-filter=A', f'{base}...HEAD', '--', str(NOTES)).split()
             if Path(n).name != 'README.md']
    # The merge queue re-checks the notes but cannot see the PR's labels; the
    # PR already had to add one.
    needs_note = shipped and not added and os.environ.get('GITHUB_EVENT_NAME') != 'merge_group' \
        and os.environ.get('SKIP_CHANGELOG') != 'true'
    if needs_note:
        errors.append('This changes what ships but adds no note to changelog.d/. Add '
                      'changelog.d/<name>.<group>.md (see changelog.d/README.md), or label the '
                      'pull request skip-changelog if a patient would notice nothing (a pure refactor).')
        print('Changed shipped files:')
        print('\n'.join(shipped[:20]))

    if errors:
        for e in errors:
            print(f'::error::{e}')
        sys.exit(1)
    print(f'Changelog notes OK: {", ".join(added) or "none needed"}.')


def released_versions():
    """Production versions (vX.Y.Z tags) already in this commit's history."""
    out = []
    for tag in git('tag', '-l', 'v*', '--merged', 'HEAD').split():
        m = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)', tag)
        if m:
            out.append(tuple(int(x) for x in m.groups()))
    return out


def sections(text):
    return list(re.finditer(r'^## \[([^\]]+)\] - (.+)$', text, re.M))


def render_groups(groups):
    out = []
    for g in GROUPS:
        if groups.get(g):
            out.append(f'### {g.capitalize()}\n\n' + '\n'.join(groups[g]) + '\n')
    return '\n'.join(out)


def as_entry(text):
    lines = text.splitlines()
    return '\n'.join(['- ' + lines[0]] + ['  ' + l.strip() if l.strip() else '' for l in lines[1:]])


def split_groups(body):
    """A section's body → {group: [entry, …]}, keeping each entry's text."""
    groups, current = {}, None
    for chunk in re.split(r'^### (\w+)\s*$', body, flags=re.M)[1:]:
        if current is None:
            current = chunk.strip().lower()
            if current not in GROUPS:
                fail(f'CHANGELOG.md has an unknown group "### {chunk.strip()}"')
            continue
        entries = re.split(r'(?m)^(?=- )', chunk.strip())
        groups.setdefault(current, []).extend(e.rstrip() for e in entries if e.strip())
        current = None
    return groups


def collect():
    notes = []
    errors = []
    for p in note_files():
        r = parse_note(p)
        (errors.append(r) if isinstance(r, str) else notes.append((p, *r)))
    if errors:
        for e in errors:
            print(f'::error::{e}')
        sys.exit(1)

    current, build = version()
    if not notes:
        print(f'version={fmt(current)}')
        print('changed=false')
        return

    largest = max((n[2] for n in notes), key=RAISES.index)
    released = [v for v in released_versions() if v <= current]
    last = max(released) if released else None
    if last is None:
        # Nothing released yet: the version being built takes the notes.
        target = current
    elif current <= last:
        target = bump(last, largest)
    else:
        # current is built for testers but not released: it takes the notes
        # unless they need a bigger raise over the last release.
        target = max(current, bump(last, largest))

    text = CHANGELOG.read_text()
    secs = sections(text)
    if not secs:
        fail('CHANGELOG.md has no "## [x.y.z] - …" section')
    new_entries = {}
    for _, group, _, body in notes:
        new_entries.setdefault(group, []).append(as_entry(body))

    if target == current:
        top = secs[0]
        if top.group(1) != fmt(current) or top.group(2) != 'Unreleased':
            fail(f'CHANGELOG.md top section is "{top.group(0)}", expected "## [{fmt(current)}] - Unreleased"')
        end = secs[1].start() if len(secs) > 1 else len(text)
        groups = split_groups(text[top.end():end])
        for g, es in new_entries.items():
            groups.setdefault(g, []).extend(es)
        text = text[:top.end()] + '\n\n' + render_groups(groups) + '\n' + text[end:]
    else:
        head = f'## [{fmt(target)}] - Unreleased\n\n' + render_groups(new_entries) + '\n'
        text = text[:secs[0].start()] + head + text[secs[0].start():]
    CHANGELOG.write_text(text)

    PUBSPEC.write_text(VERSION_LINE.sub(f'version: {fmt(target)}+{build + 1}', PUBSPEC.read_text(), count=1))
    for p, *_ in notes:
        p.unlink()

    print(f'version={fmt(target)}')
    print('changed=true')
    print(f'notes={len(notes)}', file=sys.stderr)
    print(f'{fmt(current)}+{build} → {fmt(target)}+{build + 1} ({largest}, {len(notes)} notes)', file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == 'check':
        check(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == 'collect':
        collect()
    else:
        print(__doc__)
        sys.exit(2)
