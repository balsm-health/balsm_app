# Changelog

Every change to the app is recorded here, newest release first.

The top section is the release being built: its heading is the `version:` in
`app/pubspec.yaml`, marked `Unreleased` until a store serves it, then dated.
How to raise the version and what to write is in `CODING_STANDARDS.md` §9.

Entries are grouped as **Added**, **Changed**, **Fixed**, **Removed** and
**Security**, one line each, written so someone who was not there understands
what changed and why it matters.

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
- A "Beta" ribbon (Arabic: "إطلاق تجريبي") over every screen, behind the
  `beta_banner` flag.
- iOS privacy manifest, and the export-compliance declaration.
- Web: a home-screen icon for iOS and iPadOS, and the icons are declared
  maskable so Android launchers can shape them.
- Production builds are checked before they start and refuse an unsigned app
  bundle, a non-https Production server or a placeholder define.
- Building the production app bundle also produces the same build as an APK,
  for installing on a phone directly.

### Changed

- Care-team sync to Balsm Cloud is off. Only a provider's text ever synced;
  attached files and links stayed on the device.
- Social sign-in is off in the env template, which had it on with placeholder
  Google client ids.
- The iOS local-network prompt no longer mentions a development server.
- The splash screen shows the mark alone; the caption under it is gone (a
  screen reader still announces it).
- The app is Arabic and English only, everywhere. The language picker no
  longer lists French, Urdu, Persian and Turkish as unselectable "beta" rows,
  and the store builds no longer carry the dozens of other languages that
  bundled libraries brought with them, which the stores would have listed as
  supported.

### Fixed

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
