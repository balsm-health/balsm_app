---
name: flutter-use-asset-constants
description: Route every Flutter asset path through the `Assets` constants class (lib/balsm_app/assets.dart) instead of hardcoding 'assets/…' strings. Use when adding, bundling, or referencing any asset — SVG, image/PNG, icon, font, JSON, Lottie — or when you see or are about to write SvgPicture.asset('assets/…'), Image.asset, AssetImage, or rootBundle.load with a literal path.
metadata:
  type: convention
---

# Use Asset Path Constants

Every bundled asset in this app is referenced through **one source of truth** —
the `Assets` class in `lib/balsm_app/assets.dart`. Do **not** hardcode
`'assets/…'` string literals anywhere in `lib/`.

## Why

- One place to rename/move a file — call sites don't break.
- Typos become compile errors, not silent runtime "asset not found".
- Easy to see, at a glance, every asset the app ships.

## When you add or use an asset

1. **Place the file** under `app/assets/<group>/` (e.g. `assets/brand/`,
   `assets/body/`).
2. **Register the folder** in `app/pubspec.yaml` under `flutter.assets` — once
   per folder, not per file:
   ```yaml
   flutter:
     assets:
       - assets/body/
       - assets/brand/
   ```
3. **Add a constant** to `Assets`:
   - Fixed path → `static const` in **snake_case** (`brand_icon`, `body_muscles_male`).
   - Path built from runtime values → `static String helper(args) => …` (a method,
     so keep it lowerCamelCase — e.g. `bodyFigure`).
4. **Reference it** at the call site — never a literal:
   ```dart
   SvgPicture.asset(Assets.brand_icon);
   SvgPicture.asset(Assets.bodyFigure(gender, view));
   Image.asset(Assets.some_bitmap);
   ```
5. Run `flutter pub get` if a **new folder** was added to `pubspec.yaml`.

## The `Assets` class shape

```dart
// ignore_for_file: constant_identifier_names

/// Bundled asset paths — the single source of truth for every `assets/…`
/// reference. Keep in sync with `flutter.assets` in pubspec.yaml.
class Assets {
  Assets._();

  static const _brand = 'assets/brand';
  static const _body = 'assets/body';

  static const brand_icon = '$_brand/icon.svg';

  /// Dynamic path — parameterized by runtime values.
  static String bodyFigure(String gender, String view) => '$_body/${gender}_$view.svg';
}
```

- Asset constants are **snake_case** — the file carries
  `// ignore_for_file: constant_identifier_names` at the top so the analyzer
  stays quiet. Dynamic-path helpers are methods, so they stay lowerCamelCase.
- Group folders as `static const _name = 'assets/<group>'` and build leaves
  from them, so the base path lives in exactly one spot.
- Name constants by meaning (`brand_icon`), not by filename.

## Do / Don't

| Do | Don't |
|----|-------|
| `SvgPicture.asset(Assets.brand_icon)` | `SvgPicture.asset('assets/brand/icon.svg')` |
| Add a `static String` helper for names with variables | Interpolate `'assets/…/$x.svg'` at the call site |
| Register the folder once in `pubspec.yaml` | List each file individually |
| Add the constant + use it in the same change | Leave a literal "to clean up later" |

## Checklist

- [ ] File under `app/assets/<group>/`.
- [ ] Folder registered in `pubspec.yaml` `flutter.assets`.
- [ ] `static const` (or helper) added to `Assets`.
- [ ] Every call site uses `Assets.*` — no `'assets/…'` literal remains in `lib/`.
- [ ] `flutter pub get` run if a new folder was registered.
- [ ] `flutter analyze` clean.
