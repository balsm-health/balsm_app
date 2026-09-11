# iOS signing config

`adhoc.plist` and `appstore.plist` are the export options the VS Code build
tasks pass to `flutter build ipa`.

They are **tracked as templates** with placeholders, and marked `skip-worktree`
so the real values you fill in stay on your machine and never appear as a git
change.

## Set up a machine

Fill in the placeholders in both files:

| placeholder | where it comes from |
|---|---|
| `YOUR_TEAM_ID` | Apple Developer portal → Membership |
| `YOUR_BUNDLE_ID` | the app's bundle identifier |
| `YOUR_ADHOC_PROFILE_NAME` | the ad-hoc provisioning profile's **name**, not its file name or UUID |
| `YOUR_APPSTORE_PROFILE_NAME` | the App Store distribution profile's name |

Then tell git to stop tracking your edits:

```bash
git update-index --skip-worktree app/ios/signing/adhoc.plist app/ios/signing/appstore.plist
```

To edit the template itself later, reverse it, commit, and re-apply:

```bash
git update-index --no-skip-worktree app/ios/signing/adhoc.plist
```

## Why signing is manual

Both files set `signingStyle: manual` and name the profile explicitly.
Automatic signing fails from the CLI with *"No Accounts / No profiles for
&lt;bundle id&gt; were found"* on a machine where nobody has signed into Xcode —
the usual state on a build box, and what happens on a fresh clone.

## What else belongs here

The folder is gitignored apart from these two templates and this file, so a
`.p12`, a `.mobileprovision`, or an App Store Connect key dropped here is
ignored by default rather than needing a new rule.
