# App screenshots

Current UI, captured from the real app on an iOS simulator running the
**docs entrypoint** (`lib/brands/balsm/main_docshots.dart`): the same fake
APIs as e2e plus a pre-seeded synthetic session, so the shell renders
signed-in as a synthetic persona (`docshots_persona.dart`).

Captured in **both supported languages**. Arabic is not a translation pass over
the English capture: RTL mirrors the whole layout, so each locale needs its own
photograph of every screen.

## Layout

    app/screenshots/<brand>/<device>/<lang>/<screen>.png

These are **downscaled web copies**, 480px wide for phone and 720px for tablet,
not the raw captures. A full-resolution 1320x2868 PNG is ~3.4MB and many
Markdown previewers fail to draw one, so the doc appeared to hold corrupt
images. Rebuild them from the raw captures after a new run:

```sh
for dev in iphone ipad; do
  w=$([ $dev = ipad ] && echo 720 || echo 480)
  for loc in en ar; do
    for f in app/screenshots/balsm/$dev/$loc/*.png; do
      magick "marketing/app-store-screenshots/captures/$dev/$loc/$(basename $f)" \
        -filter Lanczos -resize "${w}x" -strip \
        -define png:exclude-chunk=date,time "$f"
    done
  done
done
```

The full-resolution originals stay in `marketing/app-store-screenshots/captures/`,
which is what the store decks are cut from. Because the docs copies are
downscaled they share no bytes with that tree, so neither is a duplicate of the
other.

This repo hosts **every Balsm app**, not just the patient one, so the tree is
brand-scoped from the top. `balsm` is the only brand captured today; a new
brand adds `app/screenshots/<brand>/` beside it and its own section below,
and nothing has to move.

`<device>` separates iPhone from iPad because the tablet is a different layout
rather than the same one scaled: the tab bar becomes a side rail and the
content column widens. The iPad `05_care_map` is the one screen deliberately
absent — full-bleed map tiles at 2064x2752 weigh 6.5MB per locale, and the
iPhone capture already shows the populated map.

> **Synthetic clinical data.** `docshots_seed.dart` writes a fabricated
> medication regimen into the on-device DB so the clinical screens capture with
> content instead of empty states. It is the one sanctioned exception to the
> repo's no-invented-PHI rule, is referenced only by the docshots entrypoint
> (tree-shaken out of shipped builds), and is never uploaded. Read the header of
> that file before reusing anything in it.

Regenerate (booted simulator, from `app/`):

```sh
UDID=<booted-simulator-udid>
xcrun simctl uninstall $UDID app.balsm.health; xcrun simctl keychain $UDID reset
fvm flutter run --flavor balsm -t lib/brands/balsm/main_docshots.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json -d $UDID
# once running: grant location AND set one (the map searches around the
# device's position — permission alone leaves it with no centre and it
# captures empty), then drive the captures
xcrun simctl privacy $UDID grant location app.balsm.health
xcrun simctl location $UDID set 30.0444,31.2357   # Downtown Cairo
fvm dart run tool/docshots.dart <vm-service-uri-from-run-output> $UDID \
  screenshots/balsm/iphone
# The out-dir is required and brand/device scoped — screenshots/<brand>/<device>.
# Point it at the marketing tree instead for a store deck.
```

The map fixture (`docshots_places.dart`) is 60 real Cairo facilities generated
from OpenStreetMap. Regenerate it with:

```sh
curl -H 'User-Agent: balsm-docshots/1.0' --data-urlencode 'data=
[out:json][timeout:60];
( node["amenity"~"^(hospital|clinic|doctors|pharmacy|dentist)$"]["name"]
       (29.98,31.18,30.11,31.30); );
out body 400;' https://overpass-api.de/api/interpreter
```

Captures use `simctl io screenshot` while `tool/docshots.dart` navigates via
the app's `ext.balsm.*` debug extensions — add a `shot()` step there when a
new screen should appear here. `ext.balsm.setLang` switches locale in-place, so
one run produces every language.

**Uninstall first, every time.** The account read-model is served from a
`CachedValue` and the seeded DB persists across launches, so a re-run against an
existing install captures the previous run's identity and data. (integration_test's takeScreenshot channel
returned blank frames on iOS and a queued location-permission dialog blanks
everything — hence the external-capture design and the pre-grant step.)

## Balsm — patient app

Brand `balsm`, entrypoint `lib/brands/balsm/main_docshots.dart`.

### Onboarding

| Welcome (en) | Welcome (ar) |
|---|---|
| <img src="../app/screenshots/balsm/iphone/en/01_welcome.png" width="170" alt="Welcome"> | <img src="../app/screenshots/balsm/iphone/ar/01_welcome.png" width="170" alt="Welcome"> |

### Main shell

#### English

| Home | Care map | Medications | Prescriptions |
|---|---|---|---|
| <img src="../app/screenshots/balsm/iphone/en/04_home.png" width="170" alt="Home"> | <img src="../app/screenshots/balsm/iphone/en/05_care_map.png" width="170" alt="Care map"> | <img src="../app/screenshots/balsm/iphone/en/06_medications.png" width="170" alt="Medications"> | <img src="../app/screenshots/balsm/iphone/en/07_prescriptions.png" width="170" alt="Prescriptions"> |

| Records | Trends | Profile |
|---|---|---|
| <img src="../app/screenshots/balsm/iphone/en/08_records.png" width="170" alt="Records"> | <img src="../app/screenshots/balsm/iphone/en/09_trends.png" width="170" alt="Trends"> | <img src="../app/screenshots/balsm/iphone/en/10_profile.png" width="170" alt="Profile"> |

#### العربية

| Home | Care map | Medications | Prescriptions |
|---|---|---|---|
| <img src="../app/screenshots/balsm/iphone/ar/04_home.png" width="170" alt="Home"> | <img src="../app/screenshots/balsm/iphone/ar/05_care_map.png" width="170" alt="Care map"> | <img src="../app/screenshots/balsm/iphone/ar/06_medications.png" width="170" alt="Medications"> | <img src="../app/screenshots/balsm/iphone/ar/07_prescriptions.png" width="170" alt="Prescriptions"> |

| Records | Trends | Profile |
|---|---|---|
| <img src="../app/screenshots/balsm/iphone/ar/08_records.png" width="170" alt="Records"> | <img src="../app/screenshots/balsm/iphone/ar/09_trends.png" width="170" alt="Trends"> | <img src="../app/screenshots/balsm/iphone/ar/10_profile.png" width="170" alt="Profile"> |

### iPad

The tab bar moves to a side rail and the content column widens; Trends fits
four charts plus the past-reports list without scrolling.

#### English

| Welcome | Home | Records |
|---|---|---|
| <img src="../app/screenshots/balsm/ipad/en/01_welcome.png" width="240" alt="Welcome"> | <img src="../app/screenshots/balsm/ipad/en/04_home.png" width="240" alt="Home"> | <img src="../app/screenshots/balsm/ipad/en/08_records.png" width="240" alt="Records"> |

| Trends | Prescriptions | Profile |
|---|---|---|
| <img src="../app/screenshots/balsm/ipad/en/09_trends.png" width="240" alt="Trends"> | <img src="../app/screenshots/balsm/ipad/en/07_prescriptions.png" width="240" alt="Prescriptions"> | <img src="../app/screenshots/balsm/ipad/en/10_profile.png" width="240" alt="Profile"> |

#### العربية

| Welcome | Home | Records |
|---|---|---|
| <img src="../app/screenshots/balsm/ipad/ar/01_welcome.png" width="240" alt="Welcome"> | <img src="../app/screenshots/balsm/ipad/ar/04_home.png" width="240" alt="Home"> | <img src="../app/screenshots/balsm/ipad/ar/08_records.png" width="240" alt="Records"> |

| Trends | Prescriptions | Profile |
|---|---|---|
| <img src="../app/screenshots/balsm/ipad/ar/09_trends.png" width="240" alt="Trends"> | <img src="../app/screenshots/balsm/ipad/ar/07_prescriptions.png" width="240" alt="Prescriptions"> | <img src="../app/screenshots/balsm/ipad/ar/10_profile.png" width="240" alt="Profile"> |
