# Changelog

Every change to the app is recorded here, newest release first.

The top section is the release being built: its heading is the `version:` in
`app/pubspec.yaml`, marked `Unreleased` until a store serves it, then dated.
How to raise the version and what to write is in `CODING_STANDARDS.md` §9.

Entries are grouped as **Added**, **Changed**, **Fixed**, **Removed** and
**Security**, one line each, written so someone who was not there understands
what changed and why it matters.

## [0.5.2] - Unreleased

### Fixed

- Dropdown menus — medication frequency, duration and dose unit, the body
  map's layer picker — open white, like the field they drop out of, instead
  of the pale lilac Material gives an app that does not say otherwise.
  ([#128](https://github.com/balsm-health/balsm_app/issues/128))
- The date and time pickers open white as well, instead of lilac.
  ([#128](https://github.com/balsm-health/balsm_app/issues/128))

## [0.5.1] - Unreleased

### Fixed

- Adding someone to your care team from your phone's contacts on Android
  asked you to find and tap the same person twice. It asks once now.
  ([#127](https://github.com/balsm-health/balsm_app/issues/127))

## [0.5.0] - Unreleased

### Added

- Pulse can be logged from the quick-log sheet, under Vitals after Oxygen.
  Type the rate in beats per minute, or tap "Count with me" and tap each
  beat for 15 seconds; Balsm multiplies the count by four. Only 30 to 220
  bpm saves. Saved readings show in the day's records.
  ([#134](https://github.com/balsm-health/balsm_app/pull/134))

### Changed

- The quick-log sheet groups lab, scan and report shortcuts as "Add a
  document", right after Vitals, and lists symptoms A to Z in the app's
  language. ([#134](https://github.com/balsm-health/balsm_app/pull/134))

## [0.4.2] - Unreleased

### Fixed

- Nearby care no longer shows you in central Cairo when Balsm can't read
  your location. The map's own-position dot appears only for a real fix,
  and the locate button asks for permission again; when location is off or
  refused it says so, with a button to the setting that fixes it.
  ([#125](https://github.com/balsm-health/balsm_app/pull/125))

## [0.4.1] - Unreleased

### Fixed

- On the screen that closes a check-in, the grey "saved on this device"
  note no longer runs off the right edge of the phone. It wraps onto a
  second line instead, in both languages and at every text size.
  ([#129](https://github.com/balsm-health/balsm_app/issues/129))
- Service status in Profile shows whether Balsm's servers are working again:
  it always said the status was unknown, even when everything was up. It now
  speaks the app's language, so in Arabic it reads in Arabic instead of
  English laid out right to left. Devices & sessions is hidden from Profile
  for now. ([#124](https://github.com/balsm-health/balsm_app/pull/124))

## [0.4.0] - Unreleased

### Changed

- The quick-log sheet follows the new design. Save sits in the header as a
  tick and again under the note, with a hint while the entry is incomplete,
  and Cancel below it. Leaving an entry that has changed asks before
  discarding it. Back steps out of an entry before closing the sheet, and
  after a save the sheet returns to the list with a "Saved" message instead
  of closing. ([#123](https://github.com/balsm-health/balsm_app/pull/123))

### Fixed

- The five mood faces fit on narrower phones. On a 360dp-wide screen the
  labels overflowed their squares, and the first four faces were drawn
  smaller than the fifth.
  ([#123](https://github.com/balsm-health/balsm_app/pull/123))
- An account kept on this device only can sign out again. Sign out in
  Profile now locks the app and returns to the Unlock screen, with nothing
  deleted; the password set on this device opens it again. Before, the only
  way out was removing the account and all its data. Remove this account
  from this phone is still there, as a separate choice.
  ([#122](https://github.com/balsm-health/balsm_app/issues/122))
- Home's latest readings keep blood pressure, glucose and oxygen after a
  mood or pain check-in. Each reading now shows the newest value logged for
  it; before, the card showed only the newest check-in, so logging mood
  alone blanked the vitals.
  ([#123](https://github.com/balsm-health/balsm_app/pull/123))

## [0.3.0] - Unreleased

### Changed

- Home has a new look. Today's check-in is one card with your streak and
  a strip of dots for the last seven days; your latest readings sit in one
  card, blood pressure large with whether it is in range; care team, nearby
  care and records are three tiles with their counts. On a tablet, Home
  uses two columns. Everything shown is your own data.
  ([#121](https://github.com/balsm-health/balsm_app/pull/121))
- The welcome screen's language switch moved to the top corner as a light
  pill, and the check-in button in the tab bar is a dark disc level with
  the tabs, as in the latest design. Switching language no longer moves the
  welcome screen's logo and buttons. In dev and staging builds, the server
  pill on the welcome screen shows only on emulators, simulators, desktop
  and web; on a real phone or tablet, shake the device to open Dev Config.
  ([#121](https://github.com/balsm-health/balsm_app/pull/121))

## [0.2.4] - Unreleased

### Fixed

- On Android phones that use the Back / Home / Recents buttons, the bottom
  tabs (Home, Map, +, Meds, Profile) sit fully above those buttons again.
  Since Android 15 the app draws under them, and the tabs' labels were
  partly hidden. The grey band Android drew behind those buttons is gone
  too, so the app runs to the bottom edge instead of looking raised, and the
  welcome screen no longer pushes the logo up under the status bar on
  shorter phones such as the Galaxy A17. iPhone
  and gesture navigation look the same as before.
  ([#120](https://github.com/balsm-health/balsm_app/pull/120))

## [0.2.3] - Unreleased

### Fixed

- Resend code on the sign-up code step sends a new code again. Before, it
  only restarted the countdown and no email came. If the server refuses
  (too many requests, for example), the reason shows and Resend stays
  available. ([#116](https://github.com/balsm-health/balsm_app/issues/116))
- A sign-in link from an email that has already been used, was replaced by
  a newer code, or has expired now says so and asks for a new code, in
  English and Arabic. Before, it said "Authentication required. Please
  sign in again.", which pointed at the wrong problem. ([#117](https://github.com/balsm-health/balsm_app/issues/117))

## [0.2.2] - Unreleased

### Fixed

- The emailed code can be pasted on the Enter your code step and in Go
  online: long-press the boxes for Paste, or paste from the keyboard. A
  copied `123 456` or a whole sentence like "Your code is 123456" fills the
  six boxes and submits, and the keyboard offers the code from the email
  where the phone supports it. Before, copying the code from the email app
  was no help, and the code had to be typed by hand. ([#99](https://github.com/balsm-health/balsm_app/issues/99))

## [0.2.1] - Unreleased

### Fixed

- The emergency contact number in Personal details has room again: the
  relationship picker now sits on its own line above it, instead of
  sharing the row and squeezing the number into half the width. ([#113](https://github.com/balsm-health/balsm_app/pull/113))

## [0.2.0] - Unreleased

### Changed

- Welcome offers three ways in: Create an account, Sign in, and Use on this
  device only. Creating an account asks for an email and a new password, then
  a 6-digit code confirms the email; signing in is email and password, with
  Forgot password beside it. A refused sign-in now just says so, instead of
  offering to email a code, and a link at the foot switches between the two.
  The Online / Device only switch on the credential screen is gone: the
  Welcome button decides it.
- The code step now says that an email which already has an account is
  signed in to it, the same words for everyone. When the server switches
  sign-up to strict (email quota or abuse), Create an account says the email
  is already registered and points to Sign in, with no app update needed.
  Older servers keep working unchanged.

## [0.1.4] - Unreleased

### Fixed

- The keyboard on the Enter your code step opens again after switching to
  the email app to copy the code: coming back reopens it, and tapping the
  code boxes, or the gaps between them, always does. Before, it stayed
  closed until the screen was left and opened again. The same tap fix
  applies to the Go online code step.
- The six code boxes no longer overflow on narrower phones such as the
  Galaxy A17; they shrink to fit.
- The 6-digit code reads left to right in Arabic too, on the sign-in code
  step and in Go online: the first digit lands in the leftmost box, as it is
  written in the email.

## [0.1.3] - Unreleased

### Changed

- Releases go through a Promote workflow in Actions: it tags a commit for
  alpha, beta or production, numbers test builds (`v0.2.0-alpha.3`) itself,
  and holds a production release for approval. A mistyped tag no longer
  releases to production, a tag whose version differs from the app's fails,
  and production can only ship a commit testers already had.

### Fixed

- Dev Config no longer crashes when a custom server is entered without
  `http://` (such as `192.168.8.3:5050`): the scheme is added, an address that
  still cannot work is refused with a message, and an older saved server that
  cannot be used shows an error instead of closing the app.
- An app that saved such an address as its server no longer stays on the
  splash screen at every launch: the address is repaired, or dropped for the
  default server, and the server is now saved only after it has been applied.
- Dev Config shows Local as selected again once the app has found the
  machine serving it, instead of no server at all.

## [0.1.2] - Unreleased

### Fixed

- Opening Account details no longer throws "setState() called during build":
  the loaded gender now reaches the app state after the first frame.

## [0.1.1] - Unreleased

### Changed

- Pull request CI re-runs analyze, tests and coverage only for Dart changes;
  a change to native Android, iOS or web platform code alone just rebuilds.
- Pull request CI skips analyze, tests and the web, Android and iOS builds when
  nothing they depend on changed since the last green run, such as a docs,
  changelog or version-only push, and cancels a run a newer push replaced.

### Security

- Product analytics (PostHog) no longer receives the text that comes with an
  app error. Flutter's error description names the failing widget and its key,
  and a key can hold patient data, such as the symptom on the quick-log screen.
- Product analytics drops every `$` property set by the app except the screen
  name, and clears person properties. `$set` would have written data onto the
  identified patient's profile, past the allowlist.

## [0.1.0] - Unreleased

First release of the Balsm patient app.

### Added

- The web build is the full signed-in app. Each browser is its own device,
  with an encrypted database and file store, open in one tab at a time.
- Update check: a release can be withdrawn, and a forced update lifts by
  itself once the release behind it is rolled back.
- Feature flags behind one interface, served by PostHog or a build-time
  define, with a Dev Config section to force one on a device
  (`docs/feature-flags.md`).
- A flag per data type for cloud sync, all off by default.
- Dev Config's "Check connection" shows the backend's deployed version
  next to the result, and every field of its health response under it.
- Crash reports carry `flavor` and `brand` tags, the same fields product
  analytics already sends, so both portals filter builds the same way.
- A "Beta" ribbon (Arabic: "إطلاق تجريبي") over every screen, behind the
  `beta_banner` flag.
- iOS privacy manifest, and the export-compliance declaration.
- One build setting, `HOST_SUFFIX`, names an environment's hosts: `stg` gives
  `app-stg.balsm.health` and `api-stg.balsm.health`, none gives the production
  names. `deploy/web/deploy.sh <env>` builds and deploys the web app to the
  matching host.
- Web: a home-screen icon for iOS and iPadOS, and the icons are declared
  maskable so Android launchers can shape them.
- Production builds are checked before they start and refuse an unsigned app
  bundle, a non-https Production server or a placeholder define.
- Building the production app bundle also produces the same build as an APK,
  for installing on a phone directly.

### Changed

- Each app version now keeps its own changelog section, newest first, so the
  changelog lists every version built instead of folding them into one.
- Every pull request that changes the shipped app now raises the app version
  above the branch it merges into. Claude raises it on the pull request when
  the author has not, and a CI check blocks one that still does not, so each
  merged build is identifiable by its version alone.
- Care-team sync to Balsm Cloud is off. Only a provider's text ever synced;
  attached files and links stayed on the device.
- Social sign-in is off in the env template, which had it on with placeholder
  Google client ids.
- The iOS local-network prompt no longer mentions a development server.
- The code email is asked for in the app's language and by purpose. Deleting
  an account now requests its own code, whose email says a deletion was asked
  for instead of looking like a sign-in, and whose link opens the deletion
  screen on its confirmation step.
- Photos are kept and shown at the size they are used. A photo taken or picked
  as an attachment is scaled down to 2560 px on its long side, and the
  full-screen viewer decodes to twice the screen's width rather than the whole
  camera frame, which took about 48 MB of memory per photo. Photos already
  saved are not changed.
- The splash screen shows the mark alone; the caption under it is gone (a
  screen reader still announces it).
- The app is Arabic and English only, everywhere. The language picker no
  longer lists French, Urdu, Persian and Turkish as unselectable "beta" rows,
  and the store builds no longer carry the dozens of other languages that
  bundled libraries brought with them, which the stores would have listed as
  supported.

### Removed

- Android no longer asks for the two exact-alarm permissions. Nothing in the
  app schedules an alarm, and Google Play restricts one of them to alarm and
  calendar apps.

### Fixed

- Claude's version raise and its `@claude` changes now reach the pull request
  as signed commits; the raise used to stop short of committing.
- The update manifest listed a 0.2.0 that was never built, so every install
  was offered an update that did not exist.
- A minimum version above every release on offer no longer blocks all
  installs with nothing to move to.
- The account-deletion link required by Google Play pointed at a host that
  does not resolve.
- CI analyzed and measured nothing: its package list still named folders
  that had moved from `packages/` to `modules/`, so both jobs stopped at
  their first step and the build jobs behind them were skipped. The list now
  matches the repo and covers every module.
- CI's iOS job built the app and then failed to find it: it looked under
  `build/ios/iphoneos`, but the build is an archive. The release workflow's
  unsigned fallback had the same wrong path.
- After signing out and registering a different account on the same device,
  Home, Profile and the account switcher still showed the previous person's
  name and handle until the app was restarted. The account summary was
  fetched once and kept; it now follows whoever is signed in. Sign-out also
  clears a name left over from social sign-in and returns to the Home tab.
- App Store Connect rejected the iOS upload: the Info.plist registered a
  Google sign-in URL scheme that was still a `REPLACE_ME` placeholder. iOS
  offers no Google sign-in, so the entry is gone, and a production iOS build
  now refuses to start while such a placeholder is in the Info.plist.
- App Store Connect also asked for two permission texts the Info.plist did
  not have: for contacts (the care-team import uses the system contact
  picker) and for "always" location (the app only asks while in use, but the
  location library can ask for more). All iOS permission texts now have
  Arabic versions.
- The release workflow wrote the Android keystore one folder away from where
  Gradle looks for it, so a signed build would not have found it.

### Security

- Staging and production builds are obfuscated; the files that undo it are
  kept beside the build and never shipped (`docs/balsm-cli.md`).
- A production build can no longer be made readable by accident: turning
  obfuscation off, or passing flutter a flag that undoes the protection
  (source maps, no shrinking, a debug build), stops the build, and a finished
  build is checked before it is collected. R8 is stated in the Android build
  instead of inherited, and web builds are told not to write source maps.
- Android: backup and device-to-device transfer of app data are off.
- Android: no plain HTTP, and only the system's certificate authorities are
  trusted, stated in the manifest rather than left to defaults.
