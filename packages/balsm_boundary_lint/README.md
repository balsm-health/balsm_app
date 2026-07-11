---
context: tooling
plane: cross-plane
features:
  - "P001: custom_lint rules — no module→module imports; core never depends on modules; domain never imports Flutter; no aggregate leak into presentation; no test_kit in release"
---

# balsm_boundary_lint

Module-boundary lint rules (constitutional CI gate) — tooling, not a bounded context. Candidate extension: validate module README frontmatter `context:` values against the canonical 20-context inventory in `Balsm-Core/architecture/bounded-contexts/README.md`.
