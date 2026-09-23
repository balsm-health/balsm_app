#!/usr/bin/env python3
"""Copy a brand SVG out of Balsm-Core into this app, in the dialect
`flutter_svg` reads.

    app/tool/sync_brand_svg.py <core-svg> <dest-svg> [<dest-svg> …]

Balsm-Core's brand files are the canonical mark (and are themselves what the
claude.ai/design project ships as `assets/icon.svg`). They are authored in
SVG 2, which the browser resolves and `vector_graphics_compiler` does not:

  * `<linearGradient id="a" href="#axis">` inherits the referenced gradient's
    geometry. The compiler keeps the stops and drops the inherited
    `gradientUnits` / `x1,y1,x2,y2`, so every ribbon paints from a default
    object-box axis instead of the shared one — the ring loses its single
    sweep. Each gradient gets the axis written onto it here.
  * `fill="url(#a) #02BBB5"` is the SVG-2 paint fallback. The compiler parses
    the whole attribute as one reference, fails to match it, and drops the
    fill. The fallback colour is dropped here; the gradient always resolves
    because it is inlined above.

Nothing else is touched, so the geometry stays byte-identical to Core's and a
re-run after the mark changes is a clean overwrite.
"""

from __future__ import annotations

import pathlib
import re
import sys

# `<linearGradient id="x" href="#y">` — the axis carriers have no stops of
# their own, so only the referencing gradients match.
_INHERITING = re.compile(r'<linearGradient\s+id="(?P<id>[^"]+)"\s+href="#(?P<axis>[^"]+)"\s*>')
# The axis definitions: id plus the geometry the others need. Core writes these
# self-closing, so the capture has to stop before the `/` — carrying it over
# would self-close the gradient it is copied into and orphan its `</…>`.
_AXIS = re.compile(r'<linearGradient\s+id="(?P<id>[^"]+)"\s+(?P<geometry>gradientUnits="[^"]*"[^>]*?)\s*/?>')
# `fill="url(#x) #rrggbb"` → the reference alone.
_PAINT_FALLBACK = re.compile(r'(fill="url\(#[^)]+\))\s+#[0-9A-Fa-f]{3,8}"')


def flatten(svg: str) -> str:
    axes = {m.group("id"): m.group("geometry").strip() for m in _AXIS.finditer(svg)}

    def inline(m: re.Match[str]) -> str:
        axis = axes.get(m.group("axis"))
        if axis is None:
            raise SystemExit(f'gradient "{m.group("id")}" references unknown axis "{m.group("axis")}"')
        return f'<linearGradient id="{m.group("id")}" {axis}>'

    out = _INHERITING.sub(inline, svg)
    out = _PAINT_FALLBACK.sub(r'\1"', out)

    # The compiler asserts rather than reports on malformed nesting, so check
    # the rewrite kept every element balanced before it reaches Flutter.
    body = re.sub(r"<!--.*?-->", "", out, flags=re.S)
    opened = re.findall(r"<([a-zA-Z]+)(?=[\s>])(?![^>]*/>)", body)
    closed = re.findall(r"</([a-zA-Z]+)>", body)
    if sorted(opened) != sorted(closed):
        extra = sorted(set(closed) - set(opened)) or sorted(set(opened) - set(closed))
        counts = {tag: (opened.count(tag), closed.count(tag)) for tag in set(opened) | set(closed)}
        unbalanced = {tag: n for tag, n in counts.items() if n[0] != n[1]}
        raise SystemExit(f"rewrite unbalanced the document: {unbalanced or extra}")

    if 'href="#' in out and "<use" not in out.split("<defs>")[0]:
        # `<use href>` is fine — the compiler resolves it. A leftover gradient
        # href is not, so fail loudly rather than shipping a flat mark.
        leftover = re.findall(r'<linearGradient[^>]*href="#[^"]+"', out)
        if leftover:
            raise SystemExit(f"unflattened gradient inheritance: {leftover[0]}")
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        raise SystemExit(__doc__)
    source = pathlib.Path(argv[1])
    svg = flatten(source.read_text(encoding="utf-8"))
    for target in argv[2:]:
        path = pathlib.Path(target)
        path.write_text(svg, encoding="utf-8")
        print(f"{source} -> {path} ({len(svg.encode())} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
