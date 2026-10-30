# Releasing

One long-lived branch, `main`, and tags. A tag names a build: which commit,
which version, which channel. There are no `develop` or `qa` branches; QA
approves a tag, and production is that same commit tagged again.

## Channels

| Tag | Channel | Backend | Goes to |
|---|---|---|---|
| `v0.2.0-alpha.N` | alpha | staging | Firebase `alpha-testers` (internal team, QA) |
| `v0.2.0-beta.N` | beta | staging | Firebase `beta-testers` (wider testers) |
| `v0.2.0` | production | prod | Firebase `production`, the stores, app.balsm.health |

`N` counts up from 1 for each version. The version in a tag is always the
`version:` in `app/pubspec.yaml` at that commit.

Only these releases build and upload: nothing is uploaded for a push to
`main` or a pull request. CI still builds each change to check it compiles.

## The flow

1. **Merge to `main`.** Pull requests raise the version as usual
   (`CODING_STANDARDS.md` §9). Unfinished work stays behind a feature flag, so
   `main` can be released at any commit.
2. **Send a build to QA.** Actions → **Promote** → Run workflow, channel
   `alpha`, source `main` (or a commit SHA on it). It tags the commit
   `v<version>-alpha.<next>` and starts the release build, which uploads to
   the `alpha-testers` group.
3. **QA finds a bug:** fix it on `main` with a pull request, then promote to
   alpha again. The new build is `alpha.<next>`.
4. **Wider testing (optional):** Promote, channel `beta`, source the alpha tag
   QA approved, e.g. `v0.2.0-alpha.3`. Same commit, tagged `v0.2.0-beta.1`.
5. **Release:** Promote, channel `production`, source the approved alpha or
   beta tag. The run waits for a reviewer of the `release-production`
   environment to approve, then tags the same commit `v0.2.0` and starts the
   production build.
6. **After the stores serve it,** change the version's changelog heading from
   `Unreleased` to the date, in a normal pull request.

The production build is compiled again, not copied from the tested one: the
backend URLs are fixed at build time, so the staging build QA had cannot go to
the stores. The code is the same commit. Give the production build a short
check before submitting it for store review.

## What is checked

Promote checks before it tags, and `release.yml` checks again on every tag,
so a tag pushed by hand is held to the same rules:

- The tag is exactly `vX.Y.Z-alpha.N`, `vX.Y.Z-beta.N` or `vX.Y.Z`. A typo
  such as `v0.2.0-alpa` fails instead of releasing to production.
- The version in the tag matches `app/pubspec.yaml` at the commit.
- A production tag sits on a commit that already has an alpha or beta release
  of the same version that finished (its GitHub Release exists, which happens
  only when every build succeeded), so nothing reaches the stores that testers
  never had.
- Promote only sends commits on `main` (or a `release/**` hotfix branch) to
  testers, and never reuses a tag that exists.

The build number is `release.yml`'s run number, so it rises with every
release and the stores never see one twice.

## Hotfixing a released version

Usually not needed: fix on `main`, raise the patch version, and release as
above. Only when `main` already holds work that must not ship yet:

```
git switch -c release/0.2.x v0.2.0      # branch from the released tag
# fix, raise the version to 0.2.1+<next build>, push, open a PR into release/0.2.x
```

Then Promote alpha with source `release/0.2.x`, and on to production as
above. Bring the fix to `main` with its own pull request, and delete the
branch once a newer release from `main` is live; the tag stays.

## Tagging by hand

Promote is the normal way. If you tag by hand, use the same shapes and let
the checks above catch mistakes:

```
git tag -s v0.2.0-alpha.4 <commit> -m "0.2.0 alpha 4" && git push origin v0.2.0-alpha.4
```

A hand-pushed production tag skips the `release-production` approval, which
only Promote asks for; the checks in `release.yml` still apply. A tag ruleset
(below) narrows hand tagging to its bypass list, but does not close it: those
actors can still create, move or delete release tags.

## Setup (once, repo admin)

- **Environment `release-production`**: Settings → Environments → New
  environment, add the required reviewers. Without reviewers, production
  promotions run without waiting.
- **Tag ruleset (recommended)**: Settings → Rules → New tag ruleset, target
  `v*`, restrict creations, updates and deletions, with the repository admins
  and the GitHub Actions app as bypass. The Actions bypass is what lets
  Promote create its tag (it uses the workflow's `GITHUB_TOKEN`). Everyone
  else then releases only through Promote; admins can still tag, move or
  delete by hand, so keep that list short.
- Firebase tester groups and signing secrets: `docs/ci-secrets.md`.
