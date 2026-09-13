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
- **Places ship inside the pack**, not fetched separately. One download gives
  a working map, and the pack's version stamp is what lets the UI say how old
  the data is.
- **Object storage + CDN** serves the packs. The API serves only a manifest.

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

**Places.** Each governorate's rows come from the same `CarePlaces` table the
`/care` endpoints read, filtered by point-in-polygon against that governorate.
The projection matches `CareEntityResponse` so the app decodes packs and API
responses with one mapper.

**Versioning.** `<governorate>-<YYYYMMDD>`, from the **date of the OSM data** —
the archive's `planetiler:osm:osmosisreplicationtime`, not its
`planetiler:buildtime`. The latter is inherited from the Protomaps build image
and reads `2026-03-28` on an archive whose data is from `2026-09-13`; versioning
on it would tell users their map is six months old when it is hours old.

The manifest carries a SHA-256 per pack; the app verifies after download,
because a truncated pack that renders half a city is worse than a failed one.

**Measured** (2026-09-13, z0–15): Egypt is 254 MB in one 4m48s remote pull;
the 27 packs total 297 MB and cut locally in 2.4s. Giza 26 MB and Cairo 25 MB
are the largest, Port Said 2 MB the smallest. `--maxzoom 14` roughly halves
each (Cairo 25 → 12 MB) and still renders past z14 by over-zooming.

## Manifest

`GET /care/packs` — anonymous, cacheable, small.

```json
{
  "packs": [
    {
      "id": "cairo",
      "name_en": "Cairo",
      "name_ar": "القاهرة",
      "version": "20260913",
      "size_bytes": 48210944,
      "sha256": "…",
      "url": "https://cdn.balsm.health/packs/cairo-20260913.pack",
      "bounds": [31.15, 29.95, 31.95, 30.35],
      "place_count": 4821
    }
  ]
}
```

`bounds` lets the app decide whether a pack covers the current viewport
without opening it. `place_count` is shown before download so the size means
something.

The API does not proxy pack bytes. Hundreds of megabytes through the app
servers would compete with the request budget of every other endpoint, and
resumable range requests are something a CDN already does correctly.

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

**Places.** Pack places are read into the same `CareEntity` shape and take
precedence inside a pack's bounds when offline. Online, the API still wins —
it is fresher than any pack.

**Pack management screen.** Lists governorates with size, place count and
state (not downloaded / downloading / installed / update available). Download,
cancel, delete. Downloads are resumable and survive backgrounding; a download
over cellular asks first.

## Testing

- Pipeline: a governorate extract contains only tiles intersecting its
  boundary; a pack's place count matches the point-in-polygon query; the
  manifest's SHA-256 matches the bytes.
- Manifest endpoint: shape, anonymity, cache headers.
- App: pack covering the viewport is preferred to the network; a corrupt pack
  is rejected on checksum rather than rendered; deleting a pack falls back to
  online; sign-out does not delete packs.
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
- **Stale packs.** A pack pins places at build time. The manifest's version is
  compared on launch and the UI offers an update; the pack's date is shown
  wherever its places are.
