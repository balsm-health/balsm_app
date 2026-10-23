# The web app

The browser build is the full signed-in app, not only the public pages
(emergency QR, account deletion). Each browser is its own device: data entered
there stays in that browser unless a sync or backup carries it elsewhere.

## What is different from the phone

| Concern | Phone | Browser |
| --- | --- | --- |
| Database | SQLCipher file | SQLite3 Multiple Ciphers (WebAssembly), pages in IndexedDB `balsm.db` |
| Secrets (tokens, database key, file keys) | OS keychain / keystore | IndexedDB `balsm.secure`, AES-GCM under a non-extractable key |
| Attached files | Encrypted files on disk | Encrypted records in IndexedDB `balsm.files` |
| Save QR image | Photo library | Browser download |
| Contacts import, offline map packs | Available | Hidden |
| Google sign-in | Android, macOS | Off until the Google Identity Services button is wired |

Code: `packages/core/lib/src/db/database_connection_web.dart`,
`src/secure_storage/web_secure_storage.dart`,
`src/data_source/impl/web_encrypted_file_store.dart`, `src/web/idb.dart`.

## Security model

- The database key and file keys are random and never leave the browser.
  They are encrypted with an AES-GCM key created by WebCrypto as
  **non-extractable**: script on the origin can use it, nothing can read it.
- This protects a copied browser profile or a storage dump.
- It does **not** protect against script injected into the origin, or a person
  at an unlocked browser. A passphrase lock is the planned next layer.
- The database refuses to open if the encrypted SQLite build is not the one
  loaded, so health data is never written unencrypted.

## Limits to know

- **Browsers can evict the data.** Safari clears site storage after about
  seven days without a visit. Treat web data as losable unless it is synced or
  backed up.
- **One tab at a time.** The database runs on the main thread and a second tab
  would overwrite the first one's pages. A second tab shows "Balsm is open in
  another tab" with a retry button and never opens the database. The public
  pages (emergency QR, account deletion) are not affected.
- **Phone data does not appear.** Only the care team syncs to Balsm Cloud
  today; everything else is per device.

## The SQLite WebAssembly file

`app/web/sqlite3mc.wasm` comes from the
[sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases) and
must match the `sqlite3` version in `app/pubspec.lock`.

| sqlite3 | sha256 |
| --- | --- |
| 3.3.3 | `e0f94ac7342b7bc030e6fb241534424e21b7a6072d04435f4d64f9ccd9e8e679` |

When `sqlite3` is upgraded, download the matching `sqlite3mc.wasm` from the
`sqlite3-<version>` release and update this table.
