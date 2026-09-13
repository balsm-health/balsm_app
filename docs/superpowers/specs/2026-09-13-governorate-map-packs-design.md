# Governorate Map Packs — Design

**Status:** approved for implementation
**Date:** 2026-09-13
**Scope:** `balsm_app` + `Balsm-API-DotNet` + object storage. Follows
`2026-09-13-offline-resilient-reads-design.md`, which this depends on only for
its connectivity signal.

## Problem

The map is the one screen that still needs a network. Offline-resilient reads
retained the *pins* — the dots and their details survive a relaunch — but the
basemap under them is fetched live from `tile.openstreetmap.org` and renders
grey without a connection. Pins floating on nothing is not a usable map.

It cannot be fixed by caching harder. OSM's tile usage policy permits caching
what a user actually viewed and forbids bulk pre-download, so "have Egypt
available before you travel" is not reachable from that tile source at all.

## Goal

A user downloads the governorates they care about, and inside those the map —
basemap and places — works with the radio off.

## Non-goals

- **Whole-country auto-download.** Packs are opt-in per governorate.
- **Routing or navigation.** Rendering and search only.
- **Offline write.** Unchanged: mutations fail fast.
- **Replacing the online map.** Online stays the default; a pack is consulted
  when it covers the viewport.

## Decisions already taken

Recorded here because the design does not re-argue them:

- **Governorate packs**, not a user-drawn bbox and not one national file.
  Prebuilt, so they are CDN-cacheable; 27 of them, so no pack is Cairo-sized.
- **Places ship as their own artifact, not inside the basemap pack.** Measured
  against the real directory, a governorate's places are ~1% of its pack —
  Cairo is 1.0 MB of places against 25 MB of basemap, and all 27 governorates
  together are 3 MB against 297 MB. The two also change at completely
  different rates: street geometry barely moves, while the provider list
  changes daily once onboarding is live. Bundling forces a bad trade — rebuild
  297 MB nightly to refresh 3 MB, or let places go stale at the basemap's
  cadence. Split, each is versioned and refreshed on its own schedule.
- **Object storage + CDN** serves the packs. The API serves only a manifest.

## Where places come from

**The database is the single source of truth.** Every provider that joins
writes a row; `/care/entities`, `/care/pins` and `/care/entities/{id}` read it
live, so a provider who registered an hour ago is findable immediately.

The Overture extract is a **one-time seed into that table**, not a parallel
source and not a recurring import. That distinction matters: the importer keys
on `ExternalId` alone and `UpdateFromImport` overwrites name, address,
coordinates and phone unconditionally, so a recurring import would silently
revert any correction a provider had made to their own claimed listing. Making
the seed one-time removes that failure mode rather than guarding against it.

Offline packs are a **dated snapshot** of that table, never an authority. The
app prefers the API whenever it has a connection; a snapshot is what it falls
back to, labelled with its date. Staleness therefore stops being a bug and
becomes a property the user can see.

## Where the tiles come from

Not from OSM's tile servers — proxying those breaks the same policy that rules
out bulk download, just with an extra hop. Tiles are a **Produced Work** under
ODbL: generated from OSM data, redistributable with attribution, no
share-alike on the output.

The build starts from [Protomaps' daily planet basemap](https://maps.protomaps.com/builds),
itself an ODbL Produced Work of OSM. Two consequences the pipeline is shaped
around:

1. **Attribution is required.** "© OpenStreetMap contributors" ships in the
   app, visible on the map, not buried in a licence screen.
2. **Protomaps asks that builds not be hotlinked.** So the pipeline pulls
   **once** — one remote extract of Egypt — and every governorate is then cut
   from that local file. A rebuild is one remote read, not 27.

Planetiler was the obvious alternative and is rejected: it means a JVM, a
~200MB Geofabrik extract, hours of build time and owning a tile schema, in
exchange for control this project does not need. Protomaps' schema already has
renderers and styles. Revisit only if the schema proves insufficient.

## Pipeline

A script in `Balsm-API-DotNet/tools/map-packs/`, beside the existing
`care-directory` extractor it borrows places from.

```
  protomaps planet (remote, ~120GB)
        │  pmtiles extract --region=egypt.geojson      ← ONE remote read
        ▼
  egypt.pmtiles (local)
        │  pmtiles extract --region=<gov>.geojson       ← ×27, local
        ▼
  <gov>.pmtiles ── + places.json ── zip ──▶ <gov>-<version>.pack
```

**Boundaries.** Egypt's 27 governorates are OSM `admin_level=4` relations,
pulled via Overpass and cached in the repo as GeoJSON. Cached rather than
fetched at build time: boundaries change on the order of years, an Overpass
outage should not break a build, and a boundary silently changing between
builds would silently change what a pack covers.

**Places are built elsewhere, on a different clock.** They cannot come from
this pipeline: CI has no database, and the directory it would need lives on the
API's host. A scheduled job inside the .NET app exports each governorate's rows
— point-in-polygon against the same committed boundaries — gzips them, and
uploads to R2 beside the basemaps.

| artifact | rebuilt | size |
|---|---|---|
| basemap | monthly | 297 MB (all 27) |
| places | **nightly** | 3 MB (all 27) |

Nightly is affordable precisely because the split makes it 3 MB rather than
297 MB. The projection matches `CareEntityResponse`, so the app decodes a
snapshot and an API response with one mapper.

**Versioning.** Both artifacts are `<governorate>-<YYYYMMDD>`, but the date
means a different thing in each and they move independently.

A **basemap** is dated by the **OSM data it contains** — the archive's
`planetiler:osm:osmosisreplicationtime`, not its `planetiler:buildtime`. The latter is inherited from the Protomaps build image
and reads `2026-03-28` on an archive whose data is from `2026-09-13`; versioning
on it would tell users their map is six months old when it is hours old.

A **places snapshot** is dated by the night it was exported, which is also
what the UI shows as "places as of …".

The manifest carries a SHA-256 for each artifact; the app verifies after
download, because a truncated basemap that renders half a city — or a
truncated snapshot missing half a governorate's pharmacies — is worse than a
failed download.

**Measured** (2026-09-13, z0–15). Basemaps: Egypt is 254 MB in one 4m48s
remote pull; the 27 packs total 297 MB and cut locally in 2.4s. Giza 26 MB and
Cairo 25 MB are the largest, Port Said 2 MB the smallest. `--maxzoom 14`
roughly halves each (Cairo 25 → 12 MB) and still renders past z14 by
over-zooming.

Places, from the 38,395-row seed: 3 MB gzipped for all 27 governorates. Cairo
is 10,920 places at 1.0 MB, Giza 0.5 MB, Alexandria 0.4 MB. Every place fell
inside exactly one governorate.

The 100:1 ratio between the two is what makes a nightly places build and a
monthly basemap build the obvious split.

## Manifest

`GET /care/packs` — anonymous, cacheable, small.

Two artifacts per governorate, versioned independently so refreshing places
never re-downloads the basemap:

```json
{
  "packs": [
    {
      "id": "cairo",
      "name_en": "Cairo",
      "name_ar": "القاهرة",
      "bounds": [31.21, 29.75, 31.91, 30.32],
      "basemap": {
        "version": "20260913",
        "size_bytes": 27145146,
        "sha256": "…",
        "url": "https://cdn.balsm.health/packs/cairo-20260913.pmtiles"
      },
      "places": {
        "version": "20260914",
        "size_bytes": 1051648,
        "sha256": "…",
        "count": 10920,
        "url": "https://cdn.balsm.health/places/cairo-20260914.json.gz"
      }
    }
  ]
}
```

`bounds` sits at the top because it describes the governorate, not either
artifact, and lets the app decide whether a pack covers the viewport without
opening anything.

The nesting is what makes the two clocks work. A nightly places build bumps
only `places.version`, so an app holding `basemap 20260913` sees one 1 MB
download rather than 26 MB. The alternative — one flat `version` — would have
every places refresh invalidate the basemap too, which is the whole problem the
split exists to avoid.

`places.count` is shown before download so the size means something, and
`places.version` is what the UI displays as "places as of …".

### Where the manifest comes from

A table, written by the nightly job; `GET /care/packs` is a plain query against
it. Not a committed artifact, and not read from R2 on the request path.

A committed artifact was the original design and worked while packs rebuilt
monthly. Nightly places builds break it: the version and checksum change every
night, so serving a committed file would mean a commit and an API redeploy
every night, and the pull-request gate it bought would become 365
rubber-stamps a year.

Reading the manifest from R2 per request was the obvious alternative and is
worse. It puts R2 on the user's request path, so a failed read breaks
`/care/packs`, and a cached copy can advertise a version that does not match
what is actually on the CDN.

A table avoids both, and gains a property neither has: **a row is written only
after its upload succeeds**, in the same job, so the manifest cannot describe
a file that is not there.

```
nightly job (inside the API, background)
  ├─ export places per governorate → gzip → upload to R2
  ├─ on success, upsert that governorate's places row
  └─ list basemaps in the bucket, upsert those rows

GET /care/packs → query. No network, no cache-coherence problem, no fallback.
```

Basemaps are built by CI rather than the API, so the job discovers them by
listing the bucket. That read still happens — but in a background job where
failure is retryable and invisible, never on a request.

This deletes `data/map-packs/manifest.json` and `MapPackCatalogue`. The
`[OutputCache]` on the endpoint stays and matters more, now that it is backed
by a query rather than a file read.

**The lost review gate is deliberate.** Reviewing a nightly checksum diff is
theatre. The real safety property is that versioned filenames mean a new set
cannot disturb an installed one. What replaces it is a guard in the job: a
governorate whose place count falls sharply between nights is what a truncated
export looks like, so the job refuses to publish a snapshot that lost more
than a set fraction of its places and leaves the previous row standing.

The API does not proxy artifact bytes. Hundreds of megabytes through the app
servers would compete with the request budget of every other endpoint, and
resumable range requests are something a CDN already does correctly. The
manifest itself is served by the API rather than the CDN, because it is small
and it is the one thing that must be invalidated the instant a build lands.

## App

**Storage.** Packs unpack to the app documents directory, one folder each,
outside any backup set — they are re-downloadable and would otherwise dominate
an iCloud backup. Registered in `cache_entry` (namespace `packs`) so the
existing sign-out clear does *not* drop them: packs are public reference data,
not per-account, and re-downloading 50MB on every sign-out would be hostile.

**Rendering.** `flutter_map` moves 7 → 8, unlocking
`flutter_map_vector_tiles` 2.8.1 — actively maintained, with PMTiles and
offline disk caching built in. The stale alternative
(`vector_map_tiles` 8.0.0, last published ~2 years ago) pins to flutter_map 7
and avoids the migration, but puts unmaintained rendering code at the centre
of a core screen. The migration is contained: only `map_screen.dart` and
`care_entity.dart` import `flutter_map`, across ~11 API types.

Layer selection, in order: a downloaded pack covering the viewport centre;
otherwise the online raster layer; otherwise an empty state with the offline
banner already built.

**Places.** A snapshot is read into the same `CareEntity` shape and used only
when the API cannot be reached. Online the API always wins: it is the source of
truth, and a provider who joined since last night exists there and not in the
snapshot. Wherever snapshot places are shown, `places.version` is shown with
them.

**Pack management screen.** Lists governorates with size, place count and
state (not downloaded / downloading / installed / update available). Download,
cancel, delete. Downloads are resumable and survive backgrounding; a download
over cellular asks first.

## Testing

- Pipeline: a governorate extract contains only tiles intersecting its
  boundary; the manifest's SHA-256 matches the bytes on the CDN.
- Nightly export: a snapshot that lost a large fraction of its places is
  refused and the previous row survives; a row is never written when its
  upload failed; every place falls in exactly one governorate (verified
  against the seed data — all 38,395 matched one, none orphaned, none
  double-counted); a provider row created after the last export appears in the
  next one; `count` matches the rows written.
- Independent versions: bumping `places.version` leaves `basemap.version`
  untouched, and an app holding the current basemap downloads only the places
  artifact.
- Manifest endpoint: shape, anonymity, cache headers.
- App: a downloaded basemap covering the viewport is preferred to the network
  for TILES; the API is preferred to a snapshot for PLACES whenever reachable;
  a corrupt artifact is rejected on checksum rather than rendered; deleting a
  pack falls back to online; sign-out does not delete packs.
- Migration: the existing map suite passes on flutter_map 8 unchanged.

## Risks

- ~~Pack size is unmeasured.~~ **Resolved.** Measured at 2–26 MB per pack,
  297 MB for all 27 — an order of magnitude below the concern that motivated
  per-governorate packs in the first place. That weakens the case against a
  single national pack, but packs stay per-governorate: 297 MB is still a
  hostile download on Egyptian mobile data, and the split costs nothing now
  that it is built.
- **Protomaps is a third-party dependency** for the source build. Mitigated by
  pulling once per build rather than at runtime, and by the output being a
  file on storage we own. If it disappears, Planetiler becomes the fallback at
  the cost of the build complexity declined above.
- **flutter_map 8 migration** may surface breaking changes beyond the 11 types
  counted. Contained to two files; the map suite is the gate.
- **Stale snapshots.** A snapshot pins places at build time. Nightly rebuilds
  bound it to a day, the manifest's version is compared on launch, and the date
  is shown wherever snapshot places are. Online, the API is always preferred,
  so this only affects a user who is offline in a governorate they have
  downloaded.
- **The nightly job writes to R2 from the API host**, which means R2
  credentials in the API's configuration — a second place that holds them
  besides CI. Scope that token to object writes on the one bucket, as CI's is.
- **The nightly job is now the only thing standing between a bad export and
  every user.** With the review gate gone, its guards are the safety net: it
  publishes only after a successful upload, and refuses a snapshot that lost a
  large fraction of its places. Those two checks deserve tests of their own
  rather than being incidental.
