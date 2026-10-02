# Body-map anatomy attribution

`bones_front.svg`, `bones_back.svg`, `joints_front.svg`, and
`joints_back.svg` are adapted from public-domain skeleton diagrams by
Mariana Ruiz Villarreal (LadyofHats) and Mikael Häggström:

- https://commons.wikimedia.org/wiki/File:Human_skeleton_front_-_no_labels.svg
- https://commons.wikimedia.org/wiki/File:Human_skeleton_back_no-text_no-color.svg

`nerves_front.svg` is adapted from *Nervous system diagram unlabeled.svg* by
Medium69 and Jmarchn:

- https://commons.wikimedia.org/wiki/File:Nervous_system_diagram_unlabeled.svg
- Licensed under CC BY-SA 4.0:
  https://creativecommons.org/licenses/by-sa/4.0/

Changes: resized for the Balsm 200×384 body-map coordinate system, removed
labels/backgrounds, and added transparent selectable region overlays.
Flattened each file's nested `<svg>` into an equivalent `<g transform>` (and,
in `nerves_front.svg`, inlined one gradient's `xlink:href`-referenced stops)
so `flutter_svg` renders bones, joints and nerves instead of leaving them
blank; no visual change.

The remaining body-map layer artwork is original to this project or derived
from the existing project muscle atlas.

- `nerves_front.svg`: removed 29 tiny nerve-root `<text>` labels (C1–S5). flutter_svg drew them as solid black blocks over the spinal cord; at body-map scale they carried no information. Artwork and region ids unchanged.
