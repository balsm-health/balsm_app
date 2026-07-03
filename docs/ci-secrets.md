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

CI decodes it to `app/android/keystore.jks` and writes `app/android/key.properties`;
`build.gradle.kts` picks it up automatically. Neither file is committed
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

## Channel → tag cheatsheet

```
git tag v1.2.0-alpha && git push origin v1.2.0-alpha   # alpha  (staging backend)
git tag v1.2.0-beta  && git push origin v1.2.0-beta    # beta   (staging backend)
git tag v1.2.0       && git push origin v1.2.0         # production (prod backend)
```
