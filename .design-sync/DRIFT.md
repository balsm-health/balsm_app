# Design drift — claude.ai/design "Balsm App" vs Flutter

Baseline: live project fetched 2026-09-22 (`get_file`, byte-exact via the
persisted tool results; see `.claude/skills/apply-design/SKILL.md`).
Regenerate with `.claude/skills/apply-design/scripts/ds_sync.py status`.

30 of 31 source files compared; 29 clean, 1 outstanding on purpose.

## Ported this run (2026-09-23c) — the UX enhancement screens

| Design screen | Landed in |
|---|---|
| Full check-in — DS Steps | `checkin_shared.dart` `CheckInSteps`, `report_flow.dart` |
| Quick-log — undo after save | `quick_log.dart` (4s window, `_UndoToast`) |
| Nearby map — offline mode | `map_screen.dart` (ink-50 cached card, "Offline" badge) |
| Storage — sync status | `storage_sheet.dart` ("Backed up · synced 2m ago") |
| Records — bulk select | `records_screen.dart` (long-press, count bar, confirmed bulk delete) |
| Household — active-account accent | `home_screen.dart` `_ViewingBanner` — see below |

`Pill` gained an optional icon; `PCard`/`Pressable` gained long-press and a
border override.

### Household — active-account accent, applied by fixing the bug under it

Held back at first on the grounds that the design's chrome ("Karim's health",
"His readings, his streak") would label the signed-in patient's own PHI as
someone else's. Reading the screen settled it the other way: **home already
renamed its greeting and avatar to the selected member**, while every reading
below stayed the patient's own. The false claim was already shipped; refusing
the design left the bug in place.

So the design's intent — keep whose-data-is-this permanently visible — is
applied, told truthfully:

- the greeting and avatar name whoever's record is actually on screen, which
  is always the signed-in user (`selectFamilyMember` does not re-point the
  health profile);
- selecting a member raises a banner in that member's accent that names them
  and states the limit outright, with a way back.

It retires when profile switching really re-points the data (P00X).

### Not ported, with reasons

- **Storage ceiling warning** ("92% of 5 GB", the breakdown bar). No
  storage-metering provider exists. An earlier session removed a fabricated
  breakdown from this exact screen for this exact reason; re-adding invented
  numbers would undo that.
- **Bulk "Move N records to iCloud".** Cloud backup has no backend — the
  storage sheet deliberately shows cloud targets as unavailable. The button
  would move nothing.
- **Per-pin map freshness** ("cached 2 days ago" on each place). Staleness is
  tracked per result set, not per pin.
- **First-run tour.** Its two "surprises" are already covered by the shipped
  walkthrough, which came from `wt-treatments.jsx`: slide 3 is the data-
  sovereignty card ("Your data stays yours. Saved on your phone by design, and
  it works offline") and slide 2 already demos Nearby care. The tour's one
  novel claim — "your appointments are still one tap away" — is false here;
  that screen was removed. Nothing honest left to add.

## Ported this run (2026-09-23b) — the backlog, cleared

`attachments.jsx` was the last design file never ported. It and the three
remaining backlog items are now in.

| Design | Change | Landed in |
|---|---|---|
| `auth.jsx` `SplashScreen` + `app.css` `.splash-*` | The boot splash becomes the design's `bloom`: a five-hue aura scaling up behind the mark, the mark blooming from 0.86, the 208px wrap breathing, the promise line and footer rising on their delays, and five hue dots lifting in sequence. | `widgets/splash_bloom.dart` (new), `shell.dart` `_BootSplash`, `boot.boot_promise` |
| `attachments.jsx` `AttachmentGallery` | Lead thumb, `minmax(108px, 1fr)` tile grid, dashed add tile, file count. | `widgets/attachment_thumb.dart` `VaultAttachmentGallery` |
| `attachments.jsx` `AttachmentThumb` `compact` | The square grid tile — cover image, or a centred icon over its kind. | `VaultAttachmentThumb(compact: true)` |
| `attachments.jsx` `AttachmentViewer` | The viewer pages a set in place: prev/next discs, an `i/n` counter, and a 54px thumb strip with the current chip ringed. | `widgets/vault_file_viewer.dart` (`openAll`) |
| `home.jsx` care-team files | The per-provider drawer the card's Files button opens — business card and attachments, backed by a real table. | `care_team_screen.dart`, `care_provider_file` + port/DAO |
| `quicklog.jsx` `QuickSymptomDetail` | Urine gains colour swatches, a 50ml stepper and a blood flag; stool gains the blood flag. What was observed is appended to the saved summary. | `metric_log.dart` `_SymptomDetailCard`, `SymptomDetail` / `UrineColor`, `check_in_symptom` columns |

`urine` and `stool` join `SymptomId.catalog` — they were not in it, so the
detail had nothing to hang off.

**Three deliberate non-ports inside these.** The viewer's **Download** and
**Open in new tab** buttons stay out: decrypted vault bytes never touch disk,
which is the whole point of the viewer's in-memory path. The splash's six
alternate variants (aurora, stagger, spin, shimmer, orbit, pulse, float) stay
out: `splashAnim` is set only by `tweaks-panel.jsx`, a dev overlay that is
prototype scratch — `bloom` is what the product shows. And the urine detail is
recorded verbatim with no hydration scale or interpretation; self-report is a
journal, not a symptom checker.

Records and prescriptions keep the single thumb rather than the gallery: they
store exactly one file by schema (`health_record.file_path`,
`prescription.attachment_path`), so a gallery would render a one-item set with
a "1 file" line underneath and nothing else. Giving them real sets is a records
data change, not pixel drift.

Verified: `fvm dart analyze` clean; 324 app tests and 39 self-report +
32 profile module tests. Two real bugs were caught by tests written alongside:
a PDF in the gallery laid out at infinite width (a Stack of only positioned
children has no intrinsic size), and a three-digit volume overflowed the
stepper's fixed-width box (the design uses `min-width`, not `width`).

## Ported this run (2026-09-23) — care team, and the rest of the profile branch

| Design | Change | Landed in |
|---|---|---|
| `home.jsx` `CareTeamScreen` + `PROVIDER_TYPES` | The care team becomes real: add/remove providers, search across every field (type label included), and type chips that appear only for types actually present. Two empty states — an unfilled team vs. a search with no hits. | `screens/care_team_screen.dart` (new); `profile/` gains `CareProvider`, `CareProviderType`, `care_provider` table, add/remove use cases |
| `home.jsx` care-team shortcut | Subtitle now counts the real team (`4 providers following your care`), falling back to the static line at zero rather than showing one. | `home_screen.dart` `_CareTeamShortcut`, `home.care_team_n` |
| `qrshare.jsx` (+6 −6) | Sheet intro now names the family-link use. The mark in the QR centre had already moved to `icon.svg`; the drag handle and sheet classes are the kit's. | `emergency.eqr_help_empty` (en/ar) — baseline promoted |

The care team is PHI-adjacent, so it follows the profile module's existing
shape: `care_provider` rows under `health_profile_id`, cascading with the
profile, in `SnapshotService._tables` for backup, and never leaving the device.

**The prototype's seeded roster does not cross over.** `DOCTORS` is fabricated
clinical data; the screen starts empty and shows only what the patient typed.
The one synthetic team lives in `docshots_seed.dart` — the sanctioned
screenshot exception, tree-shaken from `main_balsm.dart`.

Three deliberate deviations:

- **Card header is top-aligned**, not `align-items: center`. With a variable
  number of lines (specialty, place, phones, email, notes) centring a 52px
  avatar against six lines reads as a mistake.
- **No Message button.** The design shows Call *or* Message; Message has
  nowhere to go, so a provider with no number gets no button rather than a
  dead one.
- **No per-provider file drawer.** Still blocked on `attachments.jsx` —
  see the backlog below.

Verified: `fvm dart analyze` clean; 288 app tests (+13 care team) and 27
profile-module tests (+13 care provider, including the FK cascade and the
NULL-vs-empty-string rule); iPhone 17 Pro capture in en + ar — chips, cards,
type badges and the live home count. The Arabic pass caught a real bug: an LTR
phone run inside an RTL card was stranded at the far end of a full-width box
(`Expanded` → `Flexible`).

## Ported (2026-09-22)

| Design | Change | Landed in |
|---|---|---|
| `app.css` `.app-sheet` @ ≥600 | Every sheet becomes a centred dialog — `min(460px, 100% − 48px)` (640 for `--lg`), `100% − 48px` tall, radius-xl, `.sheet-grab` hidden. | `kit.dart` `showAppSheet` / `SheetPresentation` / `SheetGrab`; all 15 sheet call sites; `test/app_sheet_test.dart` |
| `app.css` `.tabbar` | Solid `--balsm-surface`, no backdrop blur. | `shell.dart` `_TabBar` |
| `app.css` rail / sidebar (≥600 / ≥1440) | 72px rail (`--shell-rail-w`) with brand mark and the quick-log disc leading the tabs; 240px sidebar with the 22/17px wordmark, 44px rows, 48px labelled quick-log. | `shell.dart` `_SideNav`, `_NavBrand`, `_RailItem`, `_QuickLog` |
| `app.css` `.app-body` @ ≥1024 | Screens contained at `--content-max` 1024 on the cream canvas with inline hairlines; the shell contains its main pane so the rail keeps the window edge. | `shell.dart` `AdaptiveFrame` (threshold 1024, `T.contentMax`), `_MainApp` |
| `home.jsx` care-team shortcut | Card between the hero and nearby-care. Subtitle is static copy — P001 has no care-team backend to count. | `home_screen.dart` `_CareTeamShortcut`, `home.care_team_sub` (en/ar) |
| `app.css` `.splash-bg` | `background-position: 78% top`, matching the welcome crop. | `shell.dart` `_BootSplash` |
| `app.css` `.flow` @ ≥600 | The check-in stops being a full-screen route and becomes a centred `min(640, 100%−48) × min(820, 100%−48)` card, radius-xl, on the 0.38 scrim. Below 600 it still fills the screen. | `report_flow.dart` `openCheckin` |
| `app.css` chrome allowances | `.pad-top` 64→20 at ≥600 and →12 when short; `.appbar` bottom padding →6 when short; `.flow-foot` bottom 38→20 in a dialog; `.rec-fab` drops the safe-area term at ≥600. | `kit.dart` `PadTop` / `AppBarRow` / `sheetBottomInset`, `records_screen.dart` |
| `app.css` `.metric-grid` | `1fr 1fr` → `repeat(auto-fit, minmax(150px, 1fr))` at ≥600 (4 tracks on an 834 iPad). | `home_widgets.dart` `MetricGrid` |
| `app.css` `.emergency-grid` | Two thumb targets per row → `repeat(4, minmax(0, 1fr))` at ≥600. | `profile_subscreens.dart` |
| `app.css` welcome retune | 168px lockup, 34ch sub, gradient stops, trust strip padding. | `auth_flow.dart`, `balsm_welcome_background.dart` (landed before this sweep, verified) |

Verified: `fvm dart analyze` clean; 266 app tests pass (251 + `app_sheet_test`,
`adaptive_frame_test`, `window_class_test`); iPad Air 11" docshots capture,
en + ar — rail, brand mark, leading quick-log disc, care-team card, quick-log
and storage dialogs, the check-in dialog and the 4-up emergency grid.

Two rules in the window-class layer are deliberately not literal ports:

- **`.pad-top: 20px`** at ≥600 is the design's *allowance*, measured in a
  browser frame with no status bar. A real iPad reports a top inset, so the
  spacer is `max(inset, 20)` — a flat 20 would paint under the clock.
- **Density (`--row-h`)** — `.list-row/.med-row/.history-row` read 52 at
  compact and 40 from medium. Both are `min-height` floors and every ported
  row already exceeds them on its own padding, so wiring
  `BalsmWindow.densityFor` in would change no pixels. Left for when a row
  gets tighter than 52.

## Already in Flutter — baseline was behind the port

Earlier sessions ported from the live design without promoting, so most of
the 800-line `home.jsx` delta was already here: account switcher with QR
scan / link requests / pending rows, hero disclaimer, trends metrics
dropdown, records search + tags + skeleton + empty states, prescriptions
frequency/duration, `DateTimeWhen`, map type dropdown + offline packs +
recenter, walkthrough day-demo, profile completion card, default accent
violet, body-map `min(320px, 40vh)`. All promoted.

## Backlog — in the design, not in Flutter (product-shaped, not pixel drift)

- **Multi-file records and prescriptions** — the gallery and the paging viewer
  are built and wired to the care team; records and prescriptions still store
  one file each, so they show a single thumb. Giving them sets means a records
  data change (a child table, the add-record sheet, the vault, backup), which
  is a module change rather than a port.
- **`metric-inputs.jsx` `SymptomAddList`** — per-symptom rows each with their
  own body map and timestamp inside the full check-in. The one-symptom quick
  log now carries detail; the multi-symptom step still captures a set without
  per-row timestamps.

## Deliberately NOT ported — left drifted on purpose

**`report.jsx`** — the prototype cut the check-in from 7 steps to 4, deleting
the pain, symptoms and note steps. Porting that delta would *remove* working,
tested features. Flutter builds steps from the `CheckInMetric` catalog
(`fullCheckInSteps()`, tested); this is a product decision, not a port, and it
is the one file `ds_sync status` still reports as drifted.

**`qrshare.jsx`'s handle deep-link** — the design's QR encodes
`balsm.health/@handle`, a public profile link. Flutter's QR is the encrypted
Emergency QR with a TTL and the key in the `#k=` fragment; the handle still
appears under the code, but it is not what the QR carries. The look, the copy
and the centre mark are ported; the payload deliberately is not.

## The HTML canvases — all eight read, 2026-09-23c

**This section used to be wrong, and the mistake cost three rounds of "still
not updated".** It dismissed every `.html` in the project as an "exploration
board, not the product" on the strength of the filenames. Nobody had opened
one. `UX Enhancement Screens.html` holds seven designed screens.

All eight are now read. What each actually is:

| File | Verdict |
|---|---|
| `UX Enhancement Screens.html` | **Seven designed screens.** Five ported (see above); two held back for stated reasons. |
| `Balsm App.html` | Entry point. Loads the `.jsx` files; no UI of its own. The `?file=` the design URL opens on — i.e. "the app", which is the `.jsx` set. |
| `Walkthrough Options.html` | Entry point for `wt-core/wt-treatments/wt-compare.jsx`. All three already clean. |
| `_test-rx5.html` | Harness rendering `PrescriptionsScreen` alone. Already clean. |
| `Canvas.dc.html` | Empty `<x-dc>` stub. Nothing in it. |
| `UX Enhancements.html` | Prioritization board of 17 ideas; says "Proposal only — no changes have been made to the app". |
| `New Design Direction - Warm.html` | An **alternative visual direction**. Measured against the app, it is three changes — see below. |
| `App Store Screenshots.html`, `Store Screenshots.html` | ASO marketing compositions and a store-submission size checklist. Ops, not product. |

So there is no unported product UI left in the canvases.

### `New Design Direction - Warm.html`, measured

Its own note lists exactly what it changes: "cream surfaces instead of
cool-white cards, larger rounder radii, editorial Montserrat display type, and
real photography ... Petal colors, button shapes and voice stay as-is."

Taken one at a time:

| Change | Status |
|---|---|
| Editorial Montserrat display type | **Already applied.** `Typo._familyDisplay` is `'Montserrat'` and the variable font is bundled in `pubspec.yaml`. |
| Cream surfaces instead of white cards | `--balsm-surface: #FFFFFF` is defined in `_ds/…/brand/colors_and_type.css`. |
| Larger, rounder radii | `--radius-lg: 14px` / `--radius-xl: 20px`, same file. `app.css` only consumes them — it never redefines them. |
| Real photography | Every image is an `image-slot` placeholder ("A calm, human moment", "Cover photo"). The assets do not exist. |

The two outstanding changes are **Balsm Design System tokens, not app tokens**.
`_ds/` is the shared design system mirrored into this repo — the porting rules
name "treating `_ds/` as this project's own files" as a mistake precisely
because changes there reach the website and every other Balsm surface. Editing
`T.surface` and `T.rLg/rXl` in Flutter alone would desync this app from the
design system it is supposed to implement: the app would be Warm and every
other Balsm product would not.

So this is not a Flutter port at all. It lands in Balsm-Core's design system
first (a new token set or a themed variant), and mirrors out from there. Doing
it app-side would also be a ~36-file change — `Colors.white` appears 195 times
against 4 uses of `T.surface` — so the surface colour is not even centralised
here yet; that refactor is a prerequisite, and its own piece of work.

Prototype-only (`NOT_PORTED`): `image-slot.js`, `support.js`, `dsloaders.jsx`,
`tweaks-panel.jsx`, `devconfig.jsx` (the app has its own dev overlay under
`dev/`).

**Why `status` never flagged any of this.** It only reports what is in
`current/`, and these files were never fetched — so they were invisible rather
than listed as unknown. `ds_sync.py paths --listing` does cover `.html`; the
process, not the tool, was the hole. Each canvas now sits in `NOT_PORTED` with
a note saying what it is, and that set carries a warning: a name goes in there
only after somebody has opened the file.

## Assets (2026-09-23)

`ds_sync.py` only tracks `.jsx/.js/.css/.html`, so the brand files were never
under drift control and had gone stale by several mark revisions.

The chain is **Balsm-Core/brand → app**, not design → app: `assets.dart`
already names `Balsm-Core/brand/icon.svg` as the source, and Core is
byte-identical to what the design ships as `assets/icon.svg`. Core was already
current; only the app's copies were behind.

| Asset | Was | Now |
|---|---|---|
| `app/assets/brand/icon.svg` | head `cy=73.655`, viewBox `21.64 15 705.72 676.92` | head `cy=70.08`, viewBox `18.24 11.42 712.52 683.39` |
| `app/assets/brand/logo-vertical.svg`, core's copy | same stale mark inside the lockup | current mark |
| `packages/core/assets/brand/balsm-background.png` | 87992 B (design upload `…-4ecfb5a5`) | 90229 B, Core's current |
| 30 native launcher icons (iOS/Android/macOS/web) | old mark | regenerated via `tool/gen_app_icons.sh` |

The old viewBox was not just older, it was **wrong**: the mark's own geometry
puts the outer heads at x 18.27→730.73, so a frame starting at 21.64 clipped
~3.4 units off the extreme heads.

Core authors in SVG 2 and `vector_graphics_compiler` silently mis-renders two
of its features, so the app copy is a rewrite, not a copy —
`app/tool/sync_brand_svg.py`, re-runnable:

- `<linearGradient href="#axis">` inheritance is inlined. Left alone the
  compiler keeps the stops and drops the axis, so each ribbon paints from its
  own box and the ring loses its single sweep.
- `fill="url(#a) #02BBB5"` loses the SVG-2 fallback. Left alone the whole
  attribute reads as one unmatched reference and the shape goes unpainted.

Verified: `rsvg-convert` renders the rewritten file pixel-identical to Core's
(`compare -metric AE` → 0), and `test/brand_assets_test.dart` pins the
geometry, the dialect and a real `flutter_svg` parse. That parse assertion
earned its place immediately — the first version of the sync script
self-closed ten gradients and the compiler failed on an `assert`, not an
error, which would otherwise have shipped as a blank mark.

## Tokens

`_ds/…/brand/colors_and_type.css` unchanged; `_ds/…/responsive.css` (new
Tier 5 layer) is `BalsmWindow` / `BalsmWindowClass` / `BalsmDensity` in
`packages/core/lib/src/kit/_tokens.dart`. Upstream still says `--petal-*`;
this repo says `hue*` (naming only). `app.jsx` `ACCENTS.violet` is `#8350DE`
while the DS token is `#724DD0` — the DS wins (`T.hueViolet`).
