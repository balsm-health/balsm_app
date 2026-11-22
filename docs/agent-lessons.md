# Agent Lessons

Rules learned from corrections. Every AI agent reads this before touching code (see `CLAUDE.md`), and adds an
entry in the same change whenever the user corrects it.

Format — one entry per lesson, newest first:

```
### <short rule title> (YYYY-MM-DD)
- **Mistake:** what was done wrong
- **Rule:** what to do instead, stated so it can be followed without context
```

---

### Name for the reader, not for the source file (2026-11-22)
- **Mistake:** the colour roles `fg1…fg4` and the `…Bg` suffix were carried over from the prototype's CSS variables. They
  are the app's most-used colours and still say nothing without the stylesheet.
- **Rule:** a token name states its role in words (`textPrimary`, `dangerBackground`), never a rank number or an
  abbreviation. Do this when porting, not as a later cleanup.

### Port names from the design source, don't transliterate them (2026-11-22)
- **Mistake:** the CSS scale `--pt-2xs … --pt-4xl` was ported as `FS.xs2 … FS.xl4` because Dart names cannot start with a
  digit. The result reads backwards (`xs2` is smaller than `xs`, `xl2` larger than `xl`) and `FS` says nothing.
- **Rule:** when a source name cannot be used as is, redesign the name for Dart (ordered scale or role names, a full
  class name) instead of shuffling characters. Check that a scale reads small to large in one direction.

### A bad name usually means a bad shape — fix the shape, not the label (2026-11-22)
- **Mistake:** the user said the one-letter token class `T` needed a better name. I renamed it to `AppTokens`, which was
  still a single catch-all class holding colours, radii, shadows, layout and three features' palettes.
- **Rule:** when asked for a better name for something that holds unrelated things, split it by responsibility first
  (one class and file per concern, feature palettes in their own class) and name each part for what it is. A rename
  that leaves the grab-bag intact is not an answer. If the scope of the request is unclear ("this class" vs "this
  file"), ask before applying a repo-wide rename.

### The state rule existed but nothing enforced it, so `setState` crept in (2026-11-22)
- **Mistake:** CODING_STANDARDS §7 already limited `setState` to view-local state, yet ~500 calls had accumulated,
  including picker results and form drafts. The random-input e2e then found `setState() called after dispose()` in three
  sheets, because a picker answered after the sheet closed. I fixed each with `if (mounted)` and moved on, treating a
  design problem as three isolated bugs.
- **Rule:** when a bug class appears in several places, name the rule it breaks and say whether anything enforces it. Data
  that arrives through an `await` belongs in a provider; a `setState` after an `await` needs a `mounted` guard. Do not
  add new `setState` for data; migrate a screen's state when touching it. Propose enforcement (a lint with a baseline)
  instead of relying on the sentence in the standards.

