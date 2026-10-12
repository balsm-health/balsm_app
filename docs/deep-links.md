# Deep links

A URL opens the app on a specific screen, with that screen's arguments.

**Route table:** `app/lib/balsm_app/deep_links.dart` — the single source of truth,
shared by Android, iOS and the web shell. `app/test/deep_link_config_test.dart`
fails if the Android manifest or the iOS association file stops matching it.

## Link formats

Every route works in both forms:

- `https://app.balsm.health/<path>` — App Links (Android) / Universal Links (iOS).
  Opens the app if installed, otherwise the web app.
- `balsm://<path>` — custom scheme. Always opens the app, with no domain
  verification. Use it for QA, and as a fallback when a mail client rewrites
  https links.

| Path | Opens | Arguments | Session |
|---|---|---|---|
| `/t/{jti}#k={key}` | Profile QR resolve | `jti` = token id, `k` = AES key (fragment) | public |
| `/emergency/{jti}#k={key}` | same (legacy alias) | same | public |
| `/delete-account` | Account deletion | — | public |
| `/delete-account-cancel` | Cancel pending deletion | — | public |
| `/auth/link?t={token}` | Magic sign-in | `t` = single-use token | public |
| `/map?type={types}` | Care map, pre-filtered | `type` = one or more of `hospital` `clinic` `dentist` `pharmacy` `lab` `scan` `store` — comma list or repeated; unknown values ignored; none = All | signed in |
| `/home` `/meds` `/profile` `/rx` `/records` `/trends` | That tab | — | signed in |
| `/profile/medical` | Medical profile | — | signed in |
| `/profile/privacy` | Privacy & data | — | signed in |
| `/profile/emergency-numbers` | Emergency numbers | — | signed in |
| `/profile/care-team` | Care team | — | signed in |
| `/profile/details` | Personal details | — | signed in |
| `/checkin` | Daily check-in | — | signed in |

- **Signed-in routes are held while signed out**, then opened as soon as the
  patient reaches the app (after sign-in, and after the disclosure gate).
- **Campaign params** (`utm_source`, `utm_campaign`, …) can go on any link. They
  don't change the destination; they're recorded on the `deep_link_opened` event.
- **Paths are a public contract.** Renaming one breaks links that have already
  been sent in emails, QR codes and ads. Add an alias instead.

## Adding a route

1. Add the destination to `deep_links.dart`: a new `AppScreen` value, or a new
   target class if it takes arguments. Then handle it in `_applyInShell` in
   `deep_link_handler.dart`.
2. Add the path to the App Links `<intent-filter>` in `AndroidManifest.xml`.
3. Add a component to `web/.well-known/apple-app-site-association`.

If you forget step 2 or 3, `deep_link_config_test.dart` fails.

## Testing on a device

```bash
# Android — custom scheme (always works)
adb shell am start -a android.intent.action.VIEW -d "balsm://meds"
adb shell am start -a android.intent.action.VIEW -d "balsm://map?type=pharmacy,lab"
# Android — App Link (needs a verified domain, see below)
adb shell am start -a android.intent.action.VIEW -d "https://app.balsm.health/profile/privacy"
adb shell pm get-app-links app.balsm.health        # verification state per domain

# iOS simulator
xcrun simctl openurl booted "balsm://checkin"
xcrun simctl openurl booted "https://app.balsm.health/meds"
```

End to end, both platforms (e2e build, fake API): `maestro test app/.maestro/deep_links.yaml`.
It covers warm and cold links, a link held through sign-in, and the map filter.

**Don't re-enable Flutter's built-in deep linking** (`FlutterDeepLinkingEnabled`
in Info.plist, `flutter_deeplinking_enabled` on the Android activity). It pushes
every link as a second copy of the whole app over the real one.
`ios/Runner/SceneDelegate.swift` hands cold-start links to app_links. Under
UIScene, app_links can't see them any other way.

## Domain verification

The OS only lets the https form open the app after it has fetched and verified a
file on the domain:

| | File (served from `app/web/.well-known/`) | Status |
|---|---|---|
| iOS | `https://app.balsm.health/.well-known/apple-app-site-association` | Team `8F78S7D344`, bundle `app.balsm.health` |
| Android | `https://app.balsm.health/.well-known/assetlinks.json` | **Fingerprint still a placeholder.** Paste the SHA-256 of the *Play App Signing* key (Play Console → Test and release → App integrity), not the upload key. |

Both files must be served over HTTPS as `application/json`, with no redirect.
They're deployed with the web app, as a Worker on `app.balsm.health`:
`npx wrangler deploy -c deploy/web/wrangler.jsonc` after `balsm web balsm <env>`.
`app/web/_headers` sets the content type. The
`balsm://` scheme needs neither file, so it works now.

Free personal-team iOS signing (`Runner-Personal.entitlements`) has no associated
domains, so Universal Links can't work in those builds. Use `balsm://` there.
