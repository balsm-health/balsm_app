# CI/CD Secrets

GitHub Actions secrets consumed by `.github/workflows/ci.yml` and
`release.yml`. **Every signing/Firebase step is guarded** — if a secret is
absent the step is skipped and an *unsigned* artifact is still built, so the
pipeline stays green before these are wired.

Add under **Repo → Settings → Secrets and variables → Actions**.

## Coverage

| Secret | What | How to get |
|---|---|---|
| `CODECOV_TOKEN` | Upload token | codecov.io → add the repo → copy the token |

## Server list (release builds)

| Secret | What |
|---|---|
| `SHARED_ENV_JSON` | Contents of a real `app/env/shared.json` (server list + Sentry DSN + PostHog project token) |

Optional. `release.yml` writes it to `app/env/shared.json` before building;
absent, the tracked `shared.example.json` template is used instead (builds
work, but with placeholder servers, no Sentry DSN and no product analytics —
both keys are empty in the template, which disables each SDK cleanly). CI builds
always use the template.

## Web deploy (app.balsm.health)

| Secret | What | How to get |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Lets `release.yml` deploy the `balsm-app-web` Worker | Cloudflare dashboard → My Profile → API Tokens → Create Token → **Edit Cloudflare Workers** template, scoped to the Balsm account and the `balsm.health` zone |

Optional. With it, a production tag (`v1.2.0`, no `-alpha`/`-beta`) builds the
web app for the domain root and deploys it with the Worker and the update
manifests, then smoke-checks the live site. Without it the `deploy-web` job
is skipped and the release still passes; deploy by hand as in
`docs/app-update.md`.

The job runs in the `web-production` environment. Add required reviewers
under **Repo → Settings → Environments** to make each deploy wait for approval.

## Android signing (release APK)

| Secret | What |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i upload-keystore.jks` (the whole file) |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_STORE_PASSWORD` | keystore password |

Generate a keystore once:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -i upload-keystore.jks | pbcopy   # → ANDROID_KEYSTORE_BASE64
```

CI decodes it to `app/android/keystore.jks` and writes `app/android/key.properties`
with `storeFile=../keystore.jks`; `build.gradle.kts` picks it up automatically.
The `../` matters: Gradle resolves `storeFile` from `app/android/app/`, one
folder below where the keystore is written. Neither file is committed
(`.gitignore`).

## iOS signing (IPA)

| Secret | What |
|---|---|
| `APPLE_CERT_P12` | base64 of the distribution `.p12` (cert + private key) |
| `APPLE_CERT_PASSWORD` | password used when exporting the `.p12` |
| `APPLE_PROVISIONING_PROFILE` | base64 of the `.mobileprovision` |
| `APPLE_TEAM_ID` | 10-char Apple Team ID |
| `IOS_EXPORT_METHOD` | `ad-hoc` (default), `development`, or `app-store` |

Ad-hoc distributes to registered device UDIDs (fits Firebase). Use an App
Store Connect distribution cert + a matching profile whose bundle id is
`app.balsm.health`.

## Firebase App Distribution (Android + iOS)

| Secret | What |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | JSON of a service account with the *Firebase App Distribution Admin* role |
| `FIREBASE_APP_ID_ANDROID` | e.g. `1:1234567890:android:abcdef` |
| `FIREBASE_APP_ID_IOS` | e.g. `1:1234567890:ios:abcdef` |

Create tester groups in the Firebase console named exactly: `alpha-testers`,
`beta-testers`, `production`.

## Store uploads (environment secrets)

The store jobs in `release.yml` read their secrets from the
**`release-production` environment**, not the repository: **Repo → Settings →
Environments → release-production**, then add each secret there. Store
signing is production, so every upload waits for a reviewer. Each job
warns and passes when its secrets are missing. What each upload does and what
a person finishes in each console: `docs/releasing.md` → Store uploads.

They reuse the repository-level `ANDROID_*` signing secrets above (the AAB
and APK are built in the `android` job) and `SHARED_ENV_JSON`.

### App Store Connect / TestFlight

| Secret | What | Where to create it |
|---|---|---|
| `APPLE_DIST_CERT_P12` | base64 of an **Apple Distribution** certificate + private key, exported as `.p12` (`base64 -i dist.p12 \| pbcopy`) | developer.apple.com → Certificates → + → Apple Distribution; install, then Keychain Access → export as `.p12` |
| `APPLE_DIST_CERT_PASSWORD` | the `.p12` export password | chosen when exporting |
| `APPSTORE_PROVISIONING_PROFILE` | base64 of an **App Store** provisioning profile for `app.balsm.health` signed with that certificate | developer.apple.com → Profiles → + → App Store Connect |
| `APPLE_TEAM_ID` | 10-character Team ID (same value as the repository secret) | developer.apple.com → Membership details |
| `ASC_KEY_ID` | App Store Connect API key id | App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → + (role **App Manager**) |
| `ASC_ISSUER_ID` | the issuer id shown above the key list | same page |
| `ASC_PRIVATE_KEY` | the whole `AuthKey_<id>.p8` file, as text | downloaded once when the key is made |

The job builds its own App Store IPA (`balsm ipa-appstore`), imports the
certificate into a temporary keychain that it deletes afterwards, and uploads
with `xcrun altool --upload-app` and the API key. altool ships with Xcode, so
the runner needs no Ruby or fastlane; `notarytool` only notarises software
distributed outside the store and cannot upload to App Store Connect. The app
record must already exist in App Store Connect.

### Google Play

| Secret | What | Where to create it |
|---|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON key of a Google Cloud service account | Google Cloud console → IAM → Service accounts → create → Keys → Add key (JSON); then Play Console → Users and permissions → Invite the account's email with **Release to testing tracks** and **Release to production / manage releases** for this app |

Uploaded with `r0adkll/upload-google-play` (pinned to a commit). Package
`app.balsm.health`. Tracks: alpha → `internal`, beta → `alpha` (closed
testing), production → `production` as a **draft**. Play App Signing must be
on and the first AAB uploaded by hand once, so Play knows the upload key.

### Huawei AppGallery

| Secret | What | Where to create it |
|---|---|---|
| `HUAWEI_CLIENT_ID` | AppGallery Connect API client id | AppGallery Connect → Users and permissions → API key → Connect API → Create (project: N/A, role **App administrator**) |
| `HUAWEI_CLIENT_SECRET` | that client's secret | shown with the client id |
| `HUAWEI_APP_ID` | the app's numeric id | AppGallery Connect → My apps → the app → App information |

Uploaded by `tool/appgallery_upload.sh` (bash, curl, python3): token → upload
URL → upload → attach to the app. It never submits for review. Run
`tool/appgallery_upload.sh --file <apk> --dry-run` to see the requests
without network or secrets. The APK is signed with the same upload key as the
Play build; the app record must exist in AppGallery Connect first.

## Channel → tag cheatsheet

Release with the **Promote** workflow (Actions → Promote), which picks the tag
for you; the full flow is in `docs/releasing.md`. The tags it makes:

```
v1.2.0-alpha.N   # alpha       (staging backend, alpha-testers)
v1.2.0-beta.N    # beta        (staging backend, beta-testers)
v1.2.0           # production  (prod backend), only on a commit already
                 #             tagged alpha or beta
```

Branch pushes build every platform too, but upload no artifacts, make no
release, send nothing to Firebase and deploy nothing:

```
git push origin main            # builds against the prod backend
git push origin release/1.0     # builds against the staging backend
```

A newer push to the same branch cancels the build still running for it.
