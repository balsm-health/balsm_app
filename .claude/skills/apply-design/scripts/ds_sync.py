#!/usr/bin/env python3
"""Snapshot/diff engine for the claude.ai/design "Balsm App" project.

The model fetches remote files with the DesignSync tool (get_file) and writes
them into .design-sync/current/. This script owns everything that does not need
the network: the baseline snapshot, hashing, drift detection, diffing, and the
design-file -> Dart-target map (derived from provenance comments in the Dart
source, so it cannot rot).

Layout, relative to the repo root:

  .design-sync/synced/<path>   last-ported snapshot; committed, this is the baseline
  .design-sync/current/<path>  freshly fetched; gitignored
  .design-sync/manifest.json   per-path sha + when it was last promoted

Subcommands: seed, index, status, diff, map, promote, paths
"""

from __future__ import annotations

import argparse
import base64
import binascii
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / ".design-sync"
SYNCED = BASE / "synced"
CURRENT = BASE / "current"
MANIFEST = BASE / "manifest.json"

# Dart trees searched for `<design file>` provenance comments.
DART_TREES = ("app/lib", "packages/core/lib", "modules")

# Design files whose Dart target is not discoverable from a provenance comment.
STATIC_MAP = {
    "_ds/brand/colors_and_type.css": [
        "app/lib/balsm_app/tokens.dart",
        "packages/core/lib/src/kit/_tokens.dart",
    ],
    "app.css": ["app/lib/balsm_app/tokens.dart", "app/lib/balsm_app/kit.dart"],
    "base.jsx": ["app/lib/balsm_app/kit.dart"],
    "data.jsx": ["app/lib/balsm_app/strings.dart", "app/lib/balsm_app/data.dart"],
    "ios-frame.jsx": ["app/lib/balsm_app/responsive.dart"],
    "dialcodes.jsx": ["packages/core/lib/src/value_objects/"],
    "walkthrough.css": ["app/lib/balsm_app/screens/walkthrough_screen.dart"],
    "metric-inputs.jsx": ["app/lib/balsm_app/screens/metric_log.dart"],
    "qrshare.jsx": [
        "app/lib/balsm_app/qr/",
        "app/lib/balsm_app/widgets/family_qr_scan.dart",
    ],
    "petalmark.jsx": ["app/lib/balsm_app/widgets/balsm_mark.dart"],
    "appointments.jsx": ["app/lib/balsm_app/screens/"],  # no Flutter screen yet
    "attachments.jsx": [
        "app/lib/balsm_app/widgets/attachment_thumb.dart",
        "app/lib/balsm_app/widgets/photo_attach.dart",
    ],
    "app.jsx": ["app/lib/balsm_app/shell.dart", "app/lib/balsm_app/app_state.dart"],
}

# Design files that are prototype plumbing with no Flutter counterpart.
NOT_PORTED = {
    "image-slot.js",
    "support.js",
    "dsloaders.jsx",
    "tweaks-panel.jsx",
    "_test-rx5.html",
}

TEXT_SUFFIXES = {".jsx", ".js", ".css", ".html", ".json", ".md", ".svg", ".txt"}


# ── helpers ──────────────────────────────────────────────────────────────────

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text())
    return {"project_id": "50dccb01-9a43-45e3-b077-cb8d0be4a1f3", "files": {}}


def save_manifest(m: dict) -> None:
    BASE.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(m, indent=2, sort_keys=True) + "\n")


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def rel_paths(base: Path) -> list[str]:
    if not base.exists():
        return []
    return sorted(
        str(p.relative_to(base)) for p in base.rglob("*") if p.is_file()
    )


def is_text(path: str) -> bool:
    return Path(path).suffix.lower() in TEXT_SUFFIXES


def read_text(p: Path) -> list[str]:
    return p.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)


# ── design file -> Dart targets ──────────────────────────────────────────────

def _grep_hits(name: str) -> dict[str, int]:
    trees = [str(ROOT / t) for t in DART_TREES if (ROOT / t).exists()]
    if not trees:
        return {}
    try:
        out = subprocess.run(
            ["grep", "-rn", "--include=*.dart", "-F", name, *trees],
            capture_output=True, text=True, check=False,
        ).stdout
    except OSError:
        return {}
    counts: dict[str, int] = {}
    for line in out.splitlines():
        try:
            rel = str(Path(line.split(":", 1)[0]).resolve().relative_to(ROOT))
        except ValueError:
            continue
        counts[rel] = counts.get(rel, 0) + 1
    return counts


def _norm(stem: str) -> str:
    return re.sub(r"[-_]", "", stem.lower())


def _name_matches(design_file: str) -> list[str]:
    """Dart files whose basename echoes the design stem.

    Matches on word boundaries, not raw substrings: home.jsx reaches
    home_screen.dart and home_widgets.dart, bodymap.jsx reaches body_map.dart,
    and map.jsx does not drag in body_map.dart.
    """
    want = _norm(Path(design_file).stem)
    if len(want) < 3:
        return []
    hits = []
    for tree in DART_TREES:
        base = ROOT / tree
        if not base.exists():
            continue
        for f in base.rglob("*.dart"):
            tokens = f.stem.lower().split("_")
            prefixes = {"".join(tokens[:i]) for i in range(1, len(tokens) + 1)}
            if want in prefixes:
                hits.append(str(f.relative_to(ROOT)))
    return sorted(set(hits))


def dart_targets(design_file: str) -> list[tuple[str, int, str]]:
    """Dart files this design file feeds, as (path, provenance refs, how it was found).

    Three independent signals, unioned so a target is never missed because the
    Dart file happens not to name its source: provenance comments citing the
    design file, basename echo, and the static map for files neither can reach.
    """
    name = Path(design_file).name
    if name in NOT_PORTED:
        return []

    found: dict[str, tuple[int, str]] = {}
    for dart, hits in _grep_hits(name).items():
        found[dart] = (hits, "cited")
    for dart in _name_matches(design_file):
        hits, _ = found.get(dart, (0, ""))
        found[dart] = (hits, "cited+name" if hits else "name")
    for dart in STATIC_MAP.get(design_file, STATIC_MAP.get(name, [])):
        if dart not in found:
            found[dart] = (0, "static")

    return sorted(
        ((d, h, how) for d, (h, how) in found.items()),
        key=lambda r: (-r[1], r[0]),
    )


# ── subcommands ──────────────────────────────────────────────────────────────

def cmd_seed(args) -> int:
    """Decode a base64 `{path: b64}` export into the baseline or the fetch cache.

    `--into synced` (default) sets the porting baseline; `--into current` loads a
    fresh export as the fetched side, which is how a full sweep should be done:
    one export beats hundreds of get_file round-trips and cannot mistranscribe.
    """
    export = Path(args.export)
    if not export.is_absolute():
        export = ROOT / export
    if not export.exists():
        print(f"error: export not found: {export}", file=sys.stderr)
        return 1
    data = json.loads(export.read_text())
    if not isinstance(data, dict):
        print("error: export must be a {path: base64} object", file=sys.stderr)
        return 1

    dest_root = CURRENT if args.into == "current" else SYNCED
    manifest = load_manifest()
    written = 0
    for path, b64 in sorted(data.items()):
        try:
            raw = base64.b64decode(b64, validate=True)
        except (binascii.Error, ValueError):
            print(f"  skip (not base64): {path}", file=sys.stderr)
            continue
        dest = dest_root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
        entry = manifest["files"].setdefault(path, {})
        if args.into == "current":
            entry["current_sha"] = sha(raw)
            entry["fetched_at"] = now()
        else:
            entry["synced_sha"] = sha(raw)
            entry["synced_at"] = now()
        entry["source"] = f"export:{export.name}"
        written += 1
    manifest[f"{args.into}_seeded_at"] = now()
    save_manifest(manifest)
    print(f"seeded {written} files into {dest_root.relative_to(ROOT)}")
    if args.into == "current":
        print("run `ds_sync.py status` for the drift report")
    return 0


def cmd_index(args) -> int:
    """Hash everything under current/ and report what drifted."""
    files = rel_paths(CURRENT)
    if not files:
        print(f"nothing fetched yet — write files into {CURRENT.relative_to(ROOT)}")
        return 0
    manifest = load_manifest()
    for path in files:
        cur = sha((CURRENT / path).read_bytes())
        entry = manifest["files"].setdefault(path, {})
        entry["current_sha"] = cur
        entry["fetched_at"] = now()
    save_manifest(manifest)
    print(f"indexed {len(files)} fetched files")
    return cmd_status(args)


def _classify(path: str) -> tuple[str, str | None]:
    cur = CURRENT / path
    syn = SYNCED / path
    if not syn.exists():
        return "NEW", None
    a, b = syn.read_bytes(), cur.read_bytes()
    if a == b:
        return "clean", None
    if not is_text(path):
        return "DRIFTED", f"binary, {len(a)} -> {len(b)} bytes"
    added = removed = 0
    for line in difflib.unified_diff(
        a.decode("utf-8", "replace").splitlines(),
        b.decode("utf-8", "replace").splitlines(),
        n=0,
        lineterm="",
    ):
        if line.startswith("+") and not line.startswith("+++"):
            added += 1
        elif line.startswith("-") and not line.startswith("---"):
            removed += 1
    return "DRIFTED", f"+{added} -{removed}"


def cmd_status(args) -> int:
    fetched = rel_paths(CURRENT)
    if not fetched:
        print("no fetched files; run the fetch step first")
        return 0
    drift: list[tuple[str, str, str]] = []
    clean = 0
    for path in fetched:
        state, detail = _classify(path)
        if state == "clean":
            clean += 1
        else:
            drift.append((state, path, detail or ""))

    print(f"fetched {len(fetched)}  ·  clean {clean}  ·  needs porting {len(drift)}\n")
    if not drift:
        print("no drift — Flutter is in sync with the fetched design files")
        return 0
    for state, path, detail in sorted(drift, key=lambda r: (r[0] != "NEW", r[1])):
        print(f"{state:8} {path}  ({detail})" if detail else f"{state:8} {path}")
        if Path(path).name in NOT_PORTED:
            print("           -> not ported (prototype-only plumbing)")
            continue
        targets = dart_targets(path)
        if not targets:
            print("           -> NO DART TARGET FOUND — decide where it lands")
        for dart, hits, how in targets[: args.max_targets]:
            suffix = f"[{how}, {hits} refs]" if hits else f"[{how}]"
            print(f"           -> {dart}  {suffix}")
        if len(targets) > args.max_targets:
            print(f"           -> ... {len(targets) - args.max_targets} more (ds_sync.py map {path})")
        print()
    return 0


def cmd_diff(args) -> int:
    path = args.path
    syn, cur = SYNCED / path, CURRENT / path
    if not cur.exists():
        print(f"error: not fetched: {path}", file=sys.stderr)
        return 1
    if not syn.exists():
        print(f"# {path} is NEW — no baseline, whole file is the delta")
        if is_text(path):
            sys.stdout.write(cur.read_text(encoding="utf-8", errors="replace"))
        return 0
    if not is_text(path):
        print(f"# {path} is binary; {syn.stat().st_size} -> {cur.stat().st_size} bytes")
        return 0
    out = difflib.unified_diff(
        read_text(syn), read_text(cur),
        fromfile=f"synced/{path}", tofile=f"current/{path}",
        n=args.context,
    )
    sys.stdout.writelines(out)
    return 0


def cmd_map(args) -> int:
    targets = dart_targets(args.design_file)
    if Path(args.design_file).name in NOT_PORTED:
        print("not ported — prototype-only plumbing")
        return 0
    if not targets:
        print("no Dart target found")
        return 1
    for dart, hits, how in targets:
        print(f"{hits:4}  {dart}  [{how}]")
    return 0


def cmd_promote(args) -> int:
    """Mark design files as ported: current -> synced, record the Dart targets."""
    manifest = load_manifest()
    for path in args.paths:
        cur = CURRENT / path
        if not cur.exists():
            print(f"error: not fetched: {path}", file=sys.stderr)
            return 1
        dest = SYNCED / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cur, dest)
        entry = manifest["files"].setdefault(path, {})
        entry["synced_sha"] = sha(cur.read_bytes())
        entry["synced_at"] = now()
        if args.ported_to:
            entry["ported_to"] = args.ported_to
        print(f"promoted {path}")
    save_manifest(manifest)
    return 0


def cmd_paths(args) -> int:
    """Source files worth fetching, filtered out of a full remote listing."""
    listing = json.loads(Path(args.listing).read_text()) if args.listing else None
    paths = listing if isinstance(listing, list) else rel_paths(SYNCED)
    skip = re.compile(r"^(screenshots/|uploads/|assets/samples/|\.bundles/|\.thumbnail)")
    keep = [
        p for p in paths
        if not skip.search(p)
        and Path(p).suffix.lower() in {".jsx", ".js", ".css", ".html"}
    ]
    for p in sorted(keep):
        print(p)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("seed", help="decode a base64 export into the baseline or the fetch cache")
    p.add_argument("--export", default="balsm-claude-design-files.json")
    p.add_argument("--into", choices=("synced", "current"), default="synced",
                   help="synced = set the porting baseline; current = load a fresh export to diff")
    p.set_defaults(func=cmd_seed)

    p = sub.add_parser("index", help="hash fetched files, then print status")
    p.add_argument("--max-targets", type=int, default=4)
    p.set_defaults(func=cmd_index)

    p = sub.add_parser("status", help="drift report with Dart targets")
    p.add_argument("--max-targets", type=int, default=4)
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("diff", help="unified diff of one design file")
    p.add_argument("path")
    p.add_argument("-c", "--context", type=int, default=3)
    p.set_defaults(func=cmd_diff)

    p = sub.add_parser("map", help="Dart files that cite a design file")
    p.add_argument("design_file")
    p.set_defaults(func=cmd_map)

    p = sub.add_parser("promote", help="mark design files as ported")
    p.add_argument("paths", nargs="+")
    p.add_argument("--ported-to", nargs="*", default=None)
    p.set_defaults(func=cmd_promote)

    p = sub.add_parser("paths", help="source paths worth fetching")
    p.add_argument("--listing", help="JSON array from DesignSync list_files")
    p.set_defaults(func=cmd_paths)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
