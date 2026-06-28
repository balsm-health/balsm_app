# Patient App (design port)

Flutter port of the claude.ai/design **Patient App** prototype
(`https://claude.ai/design/p/50dccb01-...`, file `Patient App.html`).
Self-contained, token-accurate to the locked Balsm brand. No dependency on the
`core`/`auth`/`medications`/… runtime packages — it ships its own state,
i18n, sample data, and design kit so it can be iterated on independently.

## Run

```
flutter run -t lib/main_patient.dart --flavor dev --dart-define-from-file=env/dev.json -d <device>
```

or `melos run run:patient`, or the **"Balsm Patient App (design)"** VS Code launch config.

## Layout

| File | Role |
|------|------|
| `tokens.dart` | brand colors, radii, shadows, accent petals |
| `strings.dart` | en/ar i18n dictionary + `tr()` |
| `data.dart` | models + sample data (patient, meds, doctors, records, entities…) |
| `kit.dart` | typography + shared widgets (buttons, cards, pills, avatar, rings…) |
| `app_state.dart` | `PatientAppState` (ChangeNotifier) + `AppScope` |
| `shell.dart` | tab bar, FAB, routing, `AdaptiveFrame` (responsive device frame) |
| `screens/` | home, trends, meds, prescriptions, profile, personal-details, map, auth flow, records, appointments, quicklog, report flow |
| `widgets/` | mood face, line chart, num pad, body map, balsm flower, badges, account switcher |

## Adaptive
Full-bleed on phones; centered phone-proportioned device card on
tablet/desktop/web. Dynamic-Type clamped; RTL-native (Arabic) throughout.

## Integration boundary
This is the **design source of truth**. Wiring it onto the real data layer
(drift DB, riverpod auth, go_router) means swapping each screen's sample data
for the corresponding providers — done screen-by-screen, not wholesale.
