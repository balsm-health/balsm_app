# Body-map anatomy attribution

Every body-map plate is adapted from openly licensed anatomical art on
Wikimedia Commons. Common changes to all files: fitted to the Balsm 200×384
viewBox (head-to-sole frame shared by all layers), coordinates rounded and
editor metadata/labels stripped for size, and transparent `region-*` hit
areas added on top of the art for tapping and selection colouring. Files
derived from CC BY-SA material are themselves licensed CC BY-SA 4.0.

## Skin — `male_front.svg`, `male_back.svg`, `female_front.svg`, `female_back.svg`

- Source: *Male front / Male back / Female front / Female back 3d-shaded human
  illustration.svg* by Goran_tek-en
  - https://commons.wikimedia.org/wiki/File:Male_front_3d-shaded_human_illustration.svg
  - https://commons.wikimedia.org/wiki/File:Male_back_3d-shaded_human_illustration.svg
  - https://commons.wikimedia.org/wiki/File:Female_front_3d-shaded_human_illustration.svg
  - https://commons.wikimedia.org/wiki/File:Female_back_3d-shaded_human_illustration.svg
- Licence: CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/
- Changes: rescaled/positioned, rounded, plain grey-blue underwear added over
  the figures (and a band top on the female front), hit areas added.

## Muscles — `muscles_front.svg`, `muscles_back.svg`

- Source: *Muscles front and back.svg* by OpenStax, Tomáš Kebert and
  umimeto.org — https://commons.wikimedia.org/wiki/File:Muscles_front_and_back.svg
- Licence: CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/
- Changes: anterior and posterior figures split into separate plates,
  rescaled, rounded, hit areas added. `muscles_male.svg` is an unmodified copy
  of this source file (same licence).

## Tendons — `tendons_front.svg`, `tendons_back.svg`

- Source and licence: as the muscle plates above (CC BY-SA 4.0).
- Changes: as the muscle plates, then recoloured. Muscle bellies are muted
  and tendons/aponeuroses are drawn in a darker blue-grey so they stand out.

## Bones and joints — `bones_front.svg`, `bones_back.svg`, `joints_front.svg`, `joints_back.svg`

- Source: public-domain skeleton diagrams by Mariana Ruiz Villarreal
  (LadyofHats) and Mikael Häggström
  - https://commons.wikimedia.org/wiki/File:Human_skeleton_front_-_no_labels.svg
  - https://commons.wikimedia.org/wiki/File:Human_skeleton_back_no-text_no-color.svg
- Licence: public domain.
- Changes: removed labels/backgrounds. Replaced the nested `<svg>` viewport
  with a group transform, because flutter_svg does not draw nested viewports.
  Rounded coordinates. The bone hit areas now follow the skeleton, and joint
  hit areas carry their own paint so selection colouring applies.

## Nerves — `nerves_front.svg`, `nerves_back.svg`

- Source: *Nervous system diagram unlabeled.svg* by Medium69 and Jmarchn —
  https://commons.wikimedia.org/wiki/File:Nervous_system_diagram_unlabeled.svg
- Licence: CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/
- Changes: removed vertebra-number labels and recoloured the peripheral
  nerves to textbook yellow with a neutral body outline. Flattened the nested
  viewport and rounded coordinates. Hit areas now follow the figure.
  `nerves_back.svg` is the same diagram mirrored for the posterior view.

## Organs — `organs_front.svg`, `organs_back.svg`

- Organs: *202403 human anatomy organs.svg* by DataBase Center for Life
  Science (DBCLS) — https://commons.wikimedia.org/wiki/File:202403_human_anatomy_organs.svg
- Kidneys (back): *202501 Normal Kidney.svg* by DBCLS —
  https://commons.wikimedia.org/wiki/File:202501_Normal_Kidney.svg
- Organ art licence: CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
- Body outline: traced from the male skin plates above (Goran_tek-en,
  CC BY-SA 4.0), so the combined organ plates are CC BY-SA 4.0.
- Changes: viscera separated from the source body and fitted into the shared
  outline. The front plate is mirrored to match the app's side convention, so
  the heart and stomach sit on the viewer's left like the catalog. The back
  plate shows faded lungs and the kidneys. Organ-shaped hit areas added.
