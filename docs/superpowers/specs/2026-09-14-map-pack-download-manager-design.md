# Map Pack Download Manager — Design

**Status:** approved, pending implementation plan
**Repo:** balsm_app (app shell — `app/lib/balsm_app/care/`)
**Backend counterpart:** Balsm-API-DotNet `GET /care/packs`, table-backed
manifest, nightly export job (see that repo's
`docs/architecture/c4/care-directory/context-map-packs.md` and
`dynamic-map-pack-export.md`)

## Context

The backend publishes, per Egyptian governorate, two independently-versioned
offline artifacts on `cdn.balsm.health`:

- a **basemap** (`.pmtiles`, vector tiles, rebuilt monthly)
- a **places snapshot** (`.ndjson.gz`, the same non-PHI fields as
  `GET /care/entities`, rebuilt nightly)

`GET /care/packs` returns the current manifest — one entry per governorate
that has both artifacts, each carrying `version`, `size_bytes`, `sha256`,
and `url`. Nothing in the app consumes this yet: no download, no local
storage, no way to see what (if anything) is available offline.

This is the first of two sub-projects that close that gap. This one gets
packs onto the device, verified, and manageable. **It does not render
anything offline** — that is a second spec, once this one is real (see
Non-Goals).

## Goals

- Fetch the manifest and show, per governorate, whether its basemap/places
  are not-downloaded, downloading, downloaded, update-available, or failed.
- Download a governorate's pair of artifacts, verify each against its
  declared SHA-256, and persist them to local storage.
- Delete a downloaded governorate to reclaim space.
- Survive app restart (downloaded state is durable), survive being offline
  (falls back to local state), survive a failed/interrupted download
  (never leaves a corrupt file at a path the app would trust).

## Non-Goals (deferred to sub-project 2)

- Rendering a `.pmtiles` basemap (needs a vector tile renderer —
  `flutter_map` is on 7.0.2 today with a raster `TileLayer`; PMTiles needs a
  different pipeline entirely).
- Wiring `map_screen.dart`'s tile source to a downloaded pack.
- Rendering the downloaded places snapshot as pins without a network call.
- Offline-mode OSM attribution (the current raster layer already has
  `RichAttributionWidget`; the vector/offline path needs its own, once it
  exists).

## API contract

`GET /care/packs?lang=en|ar`, anonymous. `lang` is optional — omitted or
unrecognised defaults to `en`, resolved server-side (see
Balsm-API-DotNet's `fe8cca6`). The app sends its current display language
(`prefs.dart`'s `lang()`, already `'en'`/`'ar'`) on every fetch. Response
(already live):

```json
{
  "data": [
    {
      "id": "cairo",
      "name": "Cairo",
      "bounds": [31.21, 29.75, 31.91, 30.32],
      "basemap": {
        "version": "20260913",
        "size_bytes": 27145146,
        "sha256": "…64 hex chars…",
        "url": "https://cdn.balsm.health/packs/cairo-20260913.pmtiles",
        "count": null
      },
      "places": {
        "version": "20260914",
        "size_bytes": 1051648,
        "sha256": "…64 hex chars…",
        "url": "https://cdn.balsm.health/places/cairo-20260914.ndjson.gz",
        "count": 10920
      }
    }
  ]
}
```

A governorate only ever appears with both `basemap` and `places` present —
the backend never advertises half a pack.

**Names, across a locale switch.** Only one `name` comes back per request,
in whatever `lang` was sent — the wire never carries a language the app
isn't displaying. But the app's language setting can change between
sessions, and showing a governorate's name offline (in the sheet, before
anything is downloaded) shouldn't require a network round-trip just
because the user switched from English to Arabic since the last fetch. So
local storage keeps every name the app has ever fetched, per language —
see `map_pack_name` below — not just the one from the most recent request.

## Architecture

New directory `app/lib/balsm_app/care/map_packs/`, alongside the existing
`care/infrastructure/` and `care/ports/`:

| Component | Responsibility |
|---|---|
| `CareDirectoryApi.packs({required String lang})` — new method on the existing interface (`packages/balsm_api/lib/src/care_directory/`), implemented by `DioCareDirectoryApi` the same way `nearby()`/`pins()` are | Fetch and parse the manifest via the existing `NetworkManager` (JSON, envelope-wrapped, same as every other CareDirectory call), sending the app's current language as `lang` |
| `MapPackFileDownloader` (new, `packages/balsm_api/lib/src/transport/file_downloader.dart`, next to `network_manager.dart`) | Download one URL to a local path with progress, using a **separate plain `Dio`** — CDN downloads are anonymous, unenveloped bytes, a different host than the API; `NetworkManager` is typed for JSON API responses and is the wrong tool here. Transport-tier and generic (not care-directory-specific), so it lives beside `NetworkManager` rather than under `care_directory/` |
| `MapPackDownloadStore` (new, `app/lib/balsm_app/care/map_packs/`) | Raw-SQL DAO over the new `map_pack_download` table in `AppDatabase` — same style as `DriftCacheStore`, not generated drift tables (this codebase's DAOs are all raw SQL over drift's connection; see `app_database.dart`) |
| `MapPackDownloadController` (Riverpod `Notifier`, new) | Orchestrates: merge catalogue + local rows, drive downloads through `MapPackFileDownloader`, verify SHA-256, write terminal state to `MapPackDownloadStore`, hold in-memory per-governorate progress |
| `map_packs_sheet.dart` (new screen file) | Bottom sheet UI, opened from a new icon on `map_screen.dart`; house style matches `storage_sheet.dart` |

## Data model

New table, added to the schema-constant list pattern in
`packages/core/lib/src/db/app_database.dart` (alongside `_phiSchema` and
`_cacheSchema` — raw SQL, `CREATE TABLE IF NOT EXISTS`, applied in
`beforeOpen`, not a generated drift `Table` class):

```sql
CREATE TABLE IF NOT EXISTS map_pack_download (
  governorate_id TEXT    NOT NULL,
  kind           TEXT    NOT NULL CHECK (kind IN ('basemap', 'places')),
  version        TEXT    NOT NULL,
  sha256         TEXT    NOT NULL,
  size_bytes     INTEGER NOT NULL,
  local_path     TEXT    NOT NULL,
  downloaded_at  INTEGER NOT NULL,
  PRIMARY KEY (governorate_id, kind)
);
```

This table holds **terminal state only** — a row exists if and only if that
artifact is verified and on disk. It is written once per successful
download/update, not per progress tick. Like `cache_entry`, this is
non-PHI, participates in no backup, and every row is safely
re-downloadable — it must never appear in `SnapshotService._tables`,
matching the existing comment convention for `cache_entry`.

A second table, populated on every successful catalogue fetch regardless
of download state (a name is worth caching for browsing the list, not only
for what's already downloaded):

```sql
CREATE TABLE IF NOT EXISTS map_pack_name (
  governorate_id TEXT NOT NULL,
  lang           TEXT NOT NULL,
  name           TEXT NOT NULL,
  PRIMARY KEY (governorate_id, lang)
);
```

Upserted per `(governorate_id, lang)` on every fetch — the language that
was not requested this time keeps whatever it already had, rather than
being overwritten with nothing. A governorate the app has only ever seen
in English has no Arabic row until a fetch happens to run in Arabic; the
sheet falls back to the id (or the language it does have) for a row it
has no name for yet, rather than blocking on a fetch.

**In-memory, not persisted:** live download progress (0.0–1.0) and
"downloading"/"failed-this-session" transience live in the
`MapPackDownloadController`'s Riverpod state, not the database. Writing a
progress row to SQLite every few hundred milliseconds during a 27MB
download is wasted I/O and battery for state nothing needs after the app
restarts — on restart, "no row" and "was mid-download" are
indistinguishable anyway, and both correctly resolve to "not downloaded."

## File storage

`getApplicationSupportDirectory()/map_packs/<governorate_id>/<kind>-<version>.<ext>`
(`.pmtiles` / `.ndjson.gz`). Application Support, not Documents: this is
re-downloadable CDN content with no reason to consume iCloud/Files-app
backup quota, the same reasoning already applied to where the care
directory's own import artifact lives.

## Download flow

1. Sheet opens → `MapPackDownloadController` fetches the catalogue
   (`CareDirectoryApi.packs(lang: currentLang)`), upserts `map_pack_name`
   for the fetched language, and reads local rows
   (`MapPackDownloadStore.all()`), merging by `(governorateId, kind)` into a
   per-governorate status. The name shown is read from `map_pack_name` for
   the app's current language, not from the catalogue response directly —
   the two agree right after a successful fetch, but the table is what
   still has an answer offline or after a locale switch:
   - **Not downloaded** — no local row for either kind
   - **Downloaded** — local rows exist and their `version` matches the
     catalogue's current `version` for both kinds
   - **Update available** — local rows exist but at least one kind's
     `version` differs from the catalogue
   - **Downloading N%** — controller has an in-flight download for this
     governorate (in-memory state)
   - **Failed** — the most recent attempt this session ended in a
     verification or network failure (in-memory only; a fresh app launch
     shows "not downloaded"/"update available" again, not "failed")
2. User taps download/update on a governorate → controller downloads
   **basemap then places, serially**, and **one governorate at a time
   app-wide** — no parallel downloads, simplest network/battery story for
   v1 and consistent with the backend's own framing of a governorate's two
   artifacts as one logical pack.
3. Per artifact:
   a. `MapPackFileDownloader` streams the URL to `<final path>.tmp`,
      reporting progress; controller combines both artifacts' bytes into
      one governorate-level percentage, weighted by `size_bytes`.
   b. On download completion, hash the `.tmp` file (SHA-256) and compare
      to the manifest's declared value.
      - **Mismatch** → delete the `.tmp` file, do not touch any existing
        good file at the final path, mark this governorate `failed` for
        the session. Never store or serve unverified bytes — the same
        rule the backend enforces at publish time.
      - **Match** → rename `.tmp` over the final path (atomic on the same
        filesystem), upsert the `map_pack_download` row
        (`version`, `sha256`, `size_bytes`, `local_path`,
        `downloaded_at = now`).
   c. An **update** follows the same a/b steps — the old file at the final
      path is only ever replaced by a verified rename, so a failed update
      leaves the previous good version in place and its row untouched.
      Basemap and places verify independently: if one succeeds and the
      other fails, the governorate ends the attempt with one kind updated
      and the other on its previous version — a real, visible "Update
      available" state (per the status rule in step 1), not a bug.
4. **Delete** removes both files under `map_packs/<governorate_id>/` and
   both rows for that governorate.
5. **Cancel** aborts the in-flight `Dio` request via `CancelToken`, deletes
   any partial `.tmp` file, and leaves durable state exactly as it was
   before the attempt.

## Error handling

| Failure | Behaviour |
|---|---|
| Manifest fetch fails (offline, API down) | Sheet shows local rows only (whatever is already downloaded) plus a "couldn't check for updates" notice — reuses the `onlineProvider`/offline-banner plumbing already built for the rest of the app |
| Download network failure mid-transfer | `.tmp` file discarded, governorate marked `failed` this session, retry available; no partial file ever sits at the final path |
| SHA-256 mismatch | Same as above — treated identically to a network failure, not a special case the user needs to understand |
| Disk write failure (e.g. out of space) | Caught, marked `failed`; message is generic unless the platform exception clearly indicates no space, in which case say so |
| App killed mid-download | On next launch there is no in-memory state and no durable row for the interrupted artifact — resolves to "not downloaded," and any leftover `.tmp` file is orphaned; controller sweeps `map_packs/**/*.tmp` older than a few minutes on startup to reclaim the space |

## UI

An icon on `map_screen.dart` (exact placement is an implementation-plan
detail, not a design decision) opens `map_packs_sheet.dart` — a
`showModalBottomSheet`, same house pattern as `storage_sheet.dart`: one row
per governorate (name, combined size, status badge, action button).
Tapping a row's action button downloads, updates, or offers delete
depending on status; a failed row shows a retry action.

## Testing

- **`MapPackDownloadStore`** — CRUD against an in-memory SQLite `AppDatabase`
  (existing test harness), including the `(governorate_id, kind)` primary
  key rejecting a duplicate insert.
- **`map_pack_name` upsert** — fetching in `en` then `ar` leaves both rows
  present (second fetch does not erase the first); re-fetching the same
  language overwrites only that language's row.
- **`MapPackDownloadController`** — against a fake `MapPackCatalogueApi` and
  a fake `MapPackFileDownloader`: successful download upserts the correct
  row; SHA-256 mismatch leaves no row and no file at the final path; an
  update that fails verification leaves the previous good file and row
  untouched; cancel leaves no `.tmp` file and no row change.
- **`map_packs_sheet.dart`** — widget test per status
  (not-downloaded/downloading/downloaded/update-available/failed) using a
  fixed controller state, no real network or filesystem.

No PHI, no golden network calls — packs are public, non-PHI, CDN-hosted
data, same classification as the rest of the care directory.
