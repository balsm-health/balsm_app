# App update check

Every installed app asks one URL what it should be running — its own brand's:

| Brand | Manifest |
|---|---|
| Balsm | `https://app.balsm.health/version/balsm.json` |
| Balsm Pro | `https://pro.balsm.health/version/balsm_pro.json` |

```
installed app ──▶ <brand host>/version/<brand>.json   (Worker: deploy/web/worker.js)
                        │
                        ├─▶ GitHub: balsm-health/balsm_app  feature/mvp  app/web/version/<brand>.json   ← edit this to release
                        └─▶ fallback: the copy bundled at the last web deploy
```

## Web hosts

Each brand's web app has a host of its own (`AppBrand.webHost`), never a path
under a shared one — browsers isolate storage, sessions and service workers by
host, and two apps holding different people's health data must not share them.

| Brand | Host | Deploy config |
|---|---|---|
| Balsm | `app.balsm.health` | `deploy/web/wrangler.jsonc` |
| Balsm Pro | `pro.balsm.health` | `deploy/web/wrangler.balsm_pro.jsonc` |

Every host has the same layout, served by the same Worker: the app at `/`,
`/t/{id}` public links, `/.well-known/*`, `/version/{brand}.json`,
`/whats-new`. `app.balsm.health` cannot move — printed permanent QR codes and
shipped deep links point at it.

One file per brand, so a release — or a forced update — for one brand can
never reach the other's installs. `<brand>` is the `AppBrand` name.

The apps only know our domain. GitHub sits behind it (`VERSION_SOURCE_BASE` in
`deploy/web/wrangler.jsonc`), so the source can move without touching a shipped
build. If GitHub is unreachable or returns anything but a JSON object, the
Worker serves the bundled copy; a brand with no file at all gets a 404, which
the app treats as "nothing to do".

## The manifest

```json
{
  "stores": {
    "ios": "https://apps.apple.com/app/id…",
    "android": "https://play.google.com/store/apps/details?id=app.balsm.health",
    "macos": "https://balsm.health/download"
  },
  "min": { "ios": "1.2.0" },
  "versions": {
    "1.4.0": {
      "force": false,
      "platforms": ["ios", "android"],
      "date": "2026-10-09T14:30:00Z",
      "notes": {
        "en": [
          { "title": "Smarter dose reminders", "body": "Snooze a dose and Balsm reminds you again, even offline." },
          "Fixes and polish"
        ],
        "ar": [
          { "title": "تذكيرات أذكى للجرعات" }
        ]
      }
    }
  }
}
```

- `versions` — one entry per release. Keep old entries: they are the history a
  patient several versions behind is shown.
- `platforms` — where that release exists. Omit it (or leave it empty) for all.
- `force` — this release must be installed. `true` forces it on every
  platform it is on; a list forces it only where named —
  `"force": ["ios"]` — for when one store has the build and the other is
  still in review. It stays in force for everyone below it even after later,
  optional releases are added.
- `min` — optional per-platform floor. Anything below it is forced, whatever
  the release entries say. Use it to retire old builds in bulk. It only binds
  when the file lists a release for that platform that satisfies it — a floor
  above everything on offer is ignored, so a typo cannot lock everyone out
  with nothing to install.
- `withdrawn` — this release was pulled. `true`, or a list of platforms like
  `force`. See [Rolling back](#rolling-back).
- `stores` — where "Update" goes. Must be `https://`.
- `date` — when the release went out, shown beside "What's new". Optional.
  A day (`2026-10-09`) or a date and time (`2026-10-09T14:30:00Z`,
  `…T17:30:00+03:00`). A time is shown in the reader's own time zone in the
  app and in UTC on the web page; written without a zone it is read as UTC.
- `notes` — per language, falling back to `en`: a list where each entry is
  `{ "title": "…", "body": "…" }` (`body` optional) or just a string. Plain
  text only — there is no markup; a `\n` in a body is a line break.

| Installed build | What the patient sees |
|---|---|
| Newest for its platform | Nothing |
| Behind, nothing newer is forced, at or above `min` | The update sheet, dismissible. Close (or the scrim) hides it until the next launch; "Skip this version" until a newer release. |
| Behind a forced release, or below `min` | The same sheet as "Required update": no close, no skip, the scrim does not dismiss |

The sheet is the design's `update.jsx`: mark, headline, Current → New, what's
new, "Update now". The design's download bar and "Restart now" step are not
built — a store app cannot replace itself, so "Update now" opens the store.

The version compared is `version:` in `app/pubspec.yaml` without the build
number (`0.1.0+7` is `0.1.0`).

## Full release notes page

`https://app.balsm.health/whats-new?brand=balsm&from=1.2.0&platform=ios&lang=ar`

The Worker builds this from the same manifest: every release newer than
`from` for that platform, newest first. Without `from` it lists them all, so
the website can link to it too. The sheet's "Full release notes" link opens it
in the browser, already filled in for that install.

The sheet stays native on purpose — it has to work offline, forced updates
included. The page shows the same notes, for the whole history.

It shares an origin with the web app, so it is locked down: every value from
the manifest is escaped, and the response's Content-Security-Policy allows no
script at all. `node --test deploy/web/worker.test.mjs` covers both.

A manifest can send the link elsewhere with a top-level
`"more": "https://…"`; the same query parameters are appended.

## Releasing

1. Ship the build and wait until the store actually serves it.
2. Add the release to that brand's `app/web/version/<brand>.json` on the
   source branch (`feature/mvp` today; `main` once mvp is merged there —
   see `VERSION_SOURCE_BASE`) (a commit on GitHub is
   enough — no web build, no deploy). It is live within about five minutes.

Stores rarely approve on the same day. Either list a platform in `platforms`
only once its store has the build, or list both and force just the one that
is ready: `"force": ["ios"]` now, `"force": true` once Android is out too.

Someone several versions behind is forced if **any** release between theirs
and the newest is forced on their platform — a later optional release does
not cancel it.

Set `force` only when older builds are broken or unsafe. A forced
update locks the patient out of the whole app — their records and emergency
information included — until they update. Never force a version that is not
yet downloadable on that platform; list only the platforms that have it.

Protect the source branch: whoever can change these files can block every installed app.

## Rolling back

A store build cannot be un-installed from someone's phone, so "rollback"
means: stop sending people to a bad release, and lift any block it caused.

| Situation | Edit | Effect |
|---|---|---|
| A release is broken, the store still has the previous one | `"withdrawn": true` on it (or `["ios"]`) | Nobody is offered it or forced to it; its notes disappear. People who already installed it see nothing. |
| A forced release was a mistake | Set its `force` to `false`, or withdraw it | The block lifts on the next check. |
| `min` was raised too far | Lower or remove it | Same. |
| The whole edit was wrong | `git revert` the commit | The previous file is live again. |
| People on the bad release need the fix | List the fix as a **new** version, forced if needed | They are taken to it; people below skip the bad one. |

Keep a withdrawn entry in the file rather than deleting it: it records what
happened, and deleting it has the same effect on the apps anyway.

Always fix forward with a new version number. Re-using a withdrawn number
does not reach people who installed or skipped the first build with it.

How fast it lands: the Worker and its cache hold a manifest for up to five
minutes each, and an app re-reads it on launch and on every return to the
foreground. A blocked phone that is offline stays blocked until it is online
once — the block is held from its last good copy on purpose.

## Compatibility

Every build ever shipped keeps reading this file, so the format only grows.

- **Adding** a key, a platform, a language or a note field is always safe:
  every build ignores what it does not know.
- **Never** rename or remove a key, or change the type of its value. A build
  treats a value of an unexpected type as absent — so `force` written in a
  new shape forces nobody on old builds, silently.
- A change that cannot be made by adding goes in a **new file**
  (`/version/<brand>.v2.json`) read by new builds, while the old file keeps
  being maintained for the builds that read it — until `min` in the old file
  has retired them.
- The same holds for `/whats-new` query parameters: shipped builds link to it.

`packages/core/test/update/app_update_test.dart` pins this: unknown keys,
values of new types, and the first manifest ever served must keep reading the
same.

## Behaviour worth knowing

- Checked on launch and on every return to the foreground. Web is skipped.
- Fails open: an unreachable or malformed manifest, a platform it does not
  mention, or a build it does not list (dev builds) shows nothing.
- The last good manifest is cached on the device, so a forced update still
  holds offline.
- `--dart-define=APP_VERSION_URL=…` points a build at a different manifest
  (a brand on its own domain, or a test file).

## Deploying the Worker

The Worker and the bundled manifests go out with the web app:

- **On a production tag** (`v1.2.0`): `release.yml`'s `deploy-web` job builds
  the web app, deploys, and checks the live site — if `CLOUDFLARE_API_TOKEN`
  is set (`docs/ci-secrets.md`). Alpha and beta tags never deploy.
- **By hand**, for a Worker change between releases:
  ```bash
  mkdir -p app/build/web/version && cp app/web/version/*.json app/build/web/version/
  cd deploy/web && npx wrangler deploy -c wrangler.jsonc
  ```
  `app/build/web` must hold a build made for the domain root
  (`balsm web balsm <env> --base-href=/`); the CLI's default prod build is
  for `balsm.health/apps/balsm` and would break the site here.

Nothing deploys on an ordinary push. Manifest edits do not need a deploy.

## Adding a brand

1. Give it a host in `AppBrand.webHost` and a deploy config
   (`deploy/web/wrangler.<brand>.jsonc`, copy the Pro one: its own Worker
   name, route and `DEFAULT_BRAND`).
2. Add `app/web/version/<brand>.json` (copy `balsm.json`). Nothing changes in
   the Worker: it serves any `<brand>.json` it finds.
3. In the brand's app shell, mount `UpdateGate` in `MaterialApp.builder` with
   `brand: AppBrand.<brand>`, an `AppUpdatePrefs`, the app language, and an
   `UpdateLook` — its accent, its mark, and an `UpdateCopy` filled from its
   own strings (`AppBrand.nameIn(lang)` gives the product name). The patient
   app's `_updateGate` in `app/lib/balsm_app/shell.dart` is the example.

The gate depends on no shell's state, so nothing else is needed.

## Code

- `packages/core/lib/src/update/app_update.dart` — manifest rules, per-brand
  URL, fetch + on-device cache. Brand- and UI-free.
- `app/lib/update/` — the sheet, shared by every brand's shell.
- `deploy/web/` — the Worker (manifests and the release-notes page) and its
  tests.
