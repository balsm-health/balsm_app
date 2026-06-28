# Google Drive backup — OAuth setup

The encrypted backup pipeline (`packages/core/lib/src/backup/`) uploads the
end-to-end-encrypted PHI blob to the user's **private** Google Drive
`appDataFolder`. The Dart code is complete; this is the one-time platform/console
configuration that makes `GoogleSignIn.signInSilently()` return a usable,
Drive-scoped account. Until this is done, the app behaves as **"Local only"**
(uploads fail gracefully; nothing crashes).

## 1. Google Cloud Console

1. Create / select a project at <https://console.cloud.google.com>.
2. **APIs & Services → Enable APIs** → enable **Google Drive API**.
3. **OAuth consent screen**:
   - User type: External.
   - Add scope **`https://www.googleapis.com/auth/drive.appdata`** (this is
     `drive.DriveApi.driveAppdataScope`, already requested in
     `drive_backup_adapter.dart`).
   - Add test users while unverified.
4. **Credentials → Create OAuth client ID** — one per platform:
   - **iOS**: bundle id `health.balsm.app` (+ the `.dev` / `.staging` variants).
   - **Android**: package name + **SHA-1** of each signing key
     (`./gradlew signingReport` or `keytool`), for debug, dev, staging, prod.
   - **Web** (only if Flutter Web backup is needed).

## 2. iOS (`app/ios`)

1. Download the iOS OAuth client's `GoogleService-Info.plist` (or copy the
   `REVERSED_CLIENT_ID`).
2. In `ios/Runner/Info.plist` add a URL scheme = the **reversed client id**:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>com.googleusercontent.apps.XXXXXXXX-YYYYYYYY</string></array>
     </dict>
   </array>
   ```
3. Per flavor, the bundle id differs (`health.balsm.app.dev` etc.) — register a
   client + URL scheme for each, or use a single shared id for non-prod.

## 3. Android (`app/android`)

1. Place `google-services.json` (with the OAuth client + SHA-1s) at
   `app/android/app/` per flavor (`src/dev`, `src/staging`, `src/prod`).
2. No code change needed — `google_sign_in` reads it. Ensure each build
   variant's SHA-1 is registered or `signInSilently()` returns null.

## 4. Grant the scope at runtime

`drive_backup_adapter.dart` already calls `requestScopes([driveAppdataScope])`.
The **first** time a Google user enables backup they must accept the consent
prompt (it cannot be silent). Trigger it from **Settings → Backup & sync →
Back up now**, which provisions the recovery code and performs the first upload.

## 5. Verify

- Sign in with Google → Settings → Backup & sync → **Back up now**.
- Status badge → "Synced · just now".
- In the account's Drive: *Settings → Manage apps* shows Balsm holding hidden
  app data (the blob lives in `appDataFolder`, invisible in the normal Drive UI).
- New device → sign in with the same Google account → restore prompt → enter
  recovery code → data returns.

## Notes

- **Email-OTP / Apple users** have no Google session → backup is unavailable
  (status "Local only"). A future iCloud adapter covers iOS-native backup.
- The recovery code is the **only** key. Losing it = unrecoverable data
  (by design — zero-knowledge). Surface this clearly in onboarding.
