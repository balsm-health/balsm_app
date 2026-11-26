# Releasing

One long-lived branch, `main`, and tags. A tag names a build: which commit,
which version, which channel. There are no `develop` or `qa` branches; QA
approves a tag, and production is that same commit tagged again.

## Channels

| Tag | Channel | Backend | Goes to |
|---|---|---|---|
| `v0.2.0-alpha.N` | alpha | staging | Firebase `alpha-testers` (internal team, QA) |
| `v0.2.0-beta.N` | beta | staging | Firebase `beta-testers` (wider testers) |
| `v0.2.0` | production | prod | Firebase `production`, the stores (as drafts, see [Store uploads](#store-uploads)), app.balsm.health |

`N` counts up from 1 for each version. The version in a tag is always the
`version:` in `app/pubspec.yaml` at that commit, and only Promote raises it.

Every push to `main` also builds every platform, to prove it still builds.
It uploads nothing and makes no release: only a release the team starts
does.

## The flow

1. **Merge to `main`.** Each pull request adds a changelog note in
   `changelog.d/` and leaves the version alone (`CODING_STANDARDS.md` §9).
   Unfinished work stays behind a feature flag, so `main` can be released at
   any commit.
2. **Send a build to QA.** Actions → **Promote** → Run workflow, channel
   `alpha`, source `main`. It collects the notes into `CHANGELOG.md`, raises
   the version in `app/pubspec.yaml` by the largest change among them (from
   the last production release), and commits that to `main` as
   `[Release] <version>: collect the changelog`. Then it tags that commit
   `v<version>-alpha.<next>` and starts the release build, which uploads to
   the `alpha-testers` group. A commit SHA as the source works only when
   there are no notes left to collect.
3. **QA finds a bug:** fix it on `main` with a pull request and its note,
   then promote to alpha again. The fix joins the same version (it is not
   released yet), and the new build is `alpha.<next>`.
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

## Store uploads

Every release tag also sends its build to the three stores, once the GitHub
Release exists (every build of the tag succeeded). Nothing is submitted for
review and no rollout starts on its own: a person finishes each upload in the
store's console. Branch pushes and pull requests never upload.

| Channel | App Store Connect | Google Play | Huawei AppGallery |
|---|---|---|---|
| alpha | TestFlight build | **internal testing**, released to the track | package on the version being edited |
| beta | TestFlight build | **closed testing (`alpha` track)**, released to the track | package on the version being edited |
| production | TestFlight build | **production, as a draft release** | package on the version being edited |

Alpha and beta builds talk to the staging backend. Keep them to internal
testers in each console; never promote one to production, which Promote
builds again against prod.

The jobs (`testflight`, `google-play`, `appgallery` in `release.yml`) run in
the environments `store-ios`, `store-android` and `store-huawei`, which hold
their secrets (`docs/ci-secrets.md`). A job whose secrets are missing warns
and passes, as the signing steps do.

**Production waits for a second approval.** Before any production upload,
the `store-gate` job asks a reviewer of `release-production` again: Promote's
approval let the tag be made, this one lets the finished builds reach the
stores. It also covers a production tag pushed by hand, which never went
through Promote.

### What a person still does

- **App Store Connect:** wait for the build to finish processing (an email
  arrives), answer the export-compliance question if asked, and add it to a
  TestFlight group. For production, add the build to the App Store version,
  check the listing (`docs/store/listing-copy.md`) and submit for review.
- **Google Play Console:** alpha and beta reach their testers on their own.
  For production, open the draft release under Production, set the rollout
  percentage, add release notes, and send it for review. While the app has
  never been published, Play accepts only draft releases on every track: the
  alpha and beta uploads fail until the first release is out, or until the
  status in `release.yml` is changed to `draft` for that period.
- **AppGallery Connect:** open the app, check the package on the version
  information page, fill in what is new, and submit for review. AppGallery
  has no testing tracks in this flow, so alpha and beta packages replace the
  package on the draft version; only submit the production one.

### Huawei: phones without Google services

Huawei phones sold since 2019 have no Google Mobile Services (GMS). The app
uses no Firebase or FCM SDK (Firebase is used only by CI to hand builds to
testers), and this change adds no HMS SDK. On those phones:

- **Sign in with Google does not work** (`google_sign_in` needs Play
  services). Email sign-in and the offline account still work; Sign in with
  Apple is iOS-only.
- **Google Drive backup does not work**: it signs in through the same Google
  account (`docs/google-drive-backup-setup.md`). The app stays "Local only".
- **Location** (`geolocator`) falls back from the fused provider to Android's
  own location manager: it works, but a first fix can be slower.
- **QR scanning** (`mobile_scanner`) uses the ML Kit model bundled in the
  app, which needs no Play services; check it on a Huawei device before the
  first submission.
- Local reminders, the encrypted on-device data, Sentry and PostHog do not
  depend on Google services.

Check the store listing does not promise Google sign-in or Drive backup to
AppGallery users.

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
  testers, never reuses a tag that exists, and refuses an alpha of a version
  already released when there are no notes to raise it.

The build number is `release.yml`'s run number, so it rises with every
release and the stores never see one twice.

## Hotfixing a released version

Usually not needed: fix on `main` with a note, and release as above. Only
when `main` already holds work that must not ship yet:

```
git switch -c release/0.2.x v0.2.0      # branch from the released tag
git push origin release/0.2.x
# fix with a changelog note, open a PR into release/0.2.x
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

- **Promote commits to `main`**: Settings → Rules → the `main` ruleset →
  Bypass list → add **GitHub Actions** (always allow). Promote pushes the
  collected changelog and raised version straight to the branch; without the
  bypass the ruleset refuses it and Promote stops before tagging. Do the same
  for any `release/**` ruleset. Every workflow with `contents: write` can then
  push to `main`, so keep that permission to Promote and Release.
- **Environment `release-production`**: Settings → Environments → New
  environment, add the required reviewers. Without reviewers, production
  promotions run without waiting.
- **Tag ruleset (recommended)**: Settings → Rules → New tag ruleset, target
  `v*`, restrict creations, updates and deletions, with the repository admins
  and the GitHub Actions app as bypass. The Actions bypass is what lets
  Promote create its tag (it uses the workflow's `GITHUB_TOKEN`). Everyone
  else then releases only through Promote; admins can still tag, move or
  delete by hand, so keep that list short.
- **Store environments**: Settings → Environments → create `store-ios`,
  `store-android` and `store-huawei`, add their secrets
  (`docs/ci-secrets.md`), and under Deployment branches and tags allow only
  tags matching `v*`. Production uploads already wait for
  `release-production`; reviewers on a store environment would make alpha
  and beta wait too.
- Firebase tester groups and signing secrets: `docs/ci-secrets.md`.
