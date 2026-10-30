# Changelog notes

A pull request that changes what ships adds one file here instead of editing
`CHANGELOG.md` or the version. When the team sends a build to testers, the
Promote workflow collects every note into `CHANGELOG.md`, raises `version:`
in `app/pubspec.yaml` by the largest change among them, and deletes the notes.
See `CODING_STANDARDS.md` §9.

## The file

`changelog.d/<name>.<group>[.<raise>].md`, for example
`changelog.d/142.fixed.md`. Use the pull request or issue number as the name,
so two pull requests never write the same file.

| Part | Values |
|---|---|
| `group` | `added`, `changed`, `fixed`, `removed`, `security`: the `CHANGELOG.md` group it goes under |
| `raise` | optional. `major` for a breaking change (data the previous version cannot read, a removed feature, a raised minimum OS); `minor` for new behaviour a patient can notice that is not under `added` |

Without a `raise`, `added` is a minor raise and every other group a patch.

The text is the changelog line: what changed and why it matters, written for
someone who was not there, ending with its ticket as a link.

```
Pulse readings show a trend line under the day's records, so a change
over the week is visible at a glance.
([#142](https://github.com/balsm-health/balsm_app/issues/142))
```

## Checks

The **Changelog note** check fails a pull request that changes shipped code
without adding a note, has a malformed one, or changes the version. A change a
patient would not notice, such as a pure refactor, can carry the
`skip-changelog` label instead. On every push, `claude-changelog-note.yml`
writes a missing note for you; pull before your next push.
