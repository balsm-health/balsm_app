# Porting rules: prototype → Flutter

Read when applying a design delta. Every rule here exists because a
straight visual port breaks something this repo cares about.

## 1. Tokens before anything else

The prototype's CSS custom properties already have Dart homes. Never re-derive
a value; find the token.

| Prototype | Dart |
|---|---|
| `--hue-*`, `--ink-*`, `--cream-*`, `--sun-*` | `T.*` in `app/lib/balsm_app/tokens.dart` |
| the same, for shared kernel widgets | `BalsmColors.*` in `packages/core/lib/src/kit/_tokens.dart` |
| `--r-*` radii | `T.rXs … T.rPill` |
| `--shadow-*` | `T.shadowXs/Sm/Md`, `T.accentShadow` |
| `--dur-*`, `--ease-*` | `Motion.fast/base/slow`, `Motion.easeOut/In/InOut` |
| `--pt-*` type scale | `FS.*` in `kit.dart` |
| `--font-display/body/arabic/mono` | `Typo.display/title/heading/…` |
| accent rebinding (`--balsm-primary`) | `Accent` + `AccentScope` |

**A token that changed in the design must change in both token files.** They are
deliberate duplicates — `tokens.dart` serves the prototype port, `_tokens.dart`
serves the shared kernel — and they must not drift apart.

If a delta introduces a value that has no token, add the token; do not inline it.

## 2. Value conversions

| CSS | Dart |
|---|---|
| `#rrggbb` | `Color(0xFFrrggbb)` |
| `rgba(r,g,b,a)` | `Color(0xAARRGGBB)` — alpha first, `a*255` rounded, keep the original `rgba()` in a trailing comment |
| `box-shadow: x y blur spread c` | `BoxShadow(color:, offset: Offset(x,y), blurRadius: blur, spreadRadius: spread)` |
| `cubic-bezier(a,b,c,d)` | `Cubic(a,b,c,d)` |
| `border-radius: 999px` | `T.rPill` |
| `gap` / `margin` in flex | `Wrap`/`Column` spacing or `SizedBox`; do not fake it with `Padding` on children |
| `padding-inline-*`, `margin-inline-*` | `EdgeInsetsDirectional` — **never** `EdgeInsets.only(left:)` |
| `left`/`right` in a positioned rule | `PositionedDirectional` |
| `text-align: start` | `TextAlign.start` (not `.left`) |
| `env(safe-area-inset-bottom)` | `MediaQuery.paddingOf(context).bottom` |
| `@media (min-width: …)` | `BalsmWindow` / `BalsmWindowClass` from `package:core/core.dart` |

CSS `1px` is a logical pixel — port it as `1.0`, not a device-pixel calculation.

## 3. RTL is not optional

The prototype is RTL-native. Every ported layout uses directional widgets
(`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`,
`TextDirection`-aware icons). Charts and progress fills mirror — see
`widgets/line_chart.dart` for the established pattern.

Verify both directions before promoting.

## 4. Copy goes through i69n, never a ternary

New or changed strings land in the i69n bundles:

- app: `app/lib/balsm_app/i18n/strings.i69n.jsonc` (en) +
  `strings_ar.i69n.jsonc` (ar)
- shared kernel: core's `localization/i18n/`

Then regenerate in that package:

```bash
cd app && fvm dart run build_runner build --delete-conflicting-outputs
```

Inline `ar ? 'X' : 'Y'` is prohibited. If the prototype's Arabic copy is missing
for a new key, add the English key and flag the gap — `Strings_ar` extends
`Strings`, so a missing Arabic key falls back rather than crashing.

## 5. PHI — the hard line

The prototype ships a fake patient with fake medications, fake labs, and fake
vitals so it can demo. **None of that crosses into this repo.**

- Never copy prototype sample values into Dart, fixtures, or tests.
- Never add a print/log of a ported field that holds health data.
- Port the *shape* of a screen, and bind it to the existing data layer through
  the module's `application/ports/` contracts.
- Health data stays on-device (drift/SQLCipher). A design that implies a cloud
  round-trip for profiles, medications, dose history, or records is a product
  question, not a port — raise it instead of implementing it.

## 6. Architecture boundaries survive the port

- Modules depend on `core`, never on each other. A ported screen that needs
  another module's data reads it through a core contract.
- PHI persistence goes through `ProfileDataSource` / `UserDataSource`; domain
  and application layers never touch `Drift*` concretes.
- Reference data (countries, languages, dial codes) comes from core value
  objects — `LanguageCode`, `CountryCode`, `CountryRegistry`. `dialcodes.jsx`
  is **not** ported as a Dart list; reconcile it against `CountryRegistry`.

## 7. Dart style

- Named `Iterable` extensions over imperative `for` loops (repo convention).
- Prototype React state is not a design decision. Port the rendered result into
  the existing `PatientAppState` / riverpod wiring rather than transliterating
  `useState` into `setState`.
- `flutter`/`dart` always through **fvm**: `fvm flutter …`, `fvm dart …`.
- Keep the provenance doc comment current — `/// Meds tab (home.jsx MedsScreen).`
  It is what `ds_sync.py map` reads. A new Dart file ported from the design gets
  one on its first line of doc comment, naming the design file and component.

## 8. What is deliberately not ported

`image-slot.js`, `support.js`, `dsloaders.jsx`, `tweaks-panel.jsx`, and
`devconfig.jsx`'s prototype-only halves are scaffolding for the web prototype
(image placeholders, its own support chat, loading demos, the tweak panel).
They have no Flutter counterpart. `ds_sync.py` lists them in `NOT_PORTED`; if a
delta lands only there, promote and move on.

`_ds/` is the shared **Balsm Design System** project mirrored into this one. A
change there is upstream of the website and pharmacy POS too — port it into
`packages/core` tokens, and say so, rather than treating it as app-local.
