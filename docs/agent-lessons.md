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

### A signing-team change moves the iOS keychain (2026-11-27)
- **Mistake:** for the App Store transfer I replaced the Apple Team ID everywhere (#171) and checked signing, entitlements
  and deep links, but not data. Keychain items are stored in an access group that starts with the Team ID, so builds of
  the new team cannot read the database key the old team's builds saved: the app could not open its database and hung
  after sign-in (#172), on the simulator and for every App Store user who updates.
- **Rule:** before changing the Team ID, bundle id, App ID prefix or keychain/app-group entitlements, list what the app
  keeps in the keychain (`SecureStorageWrapper`, the database and vault keys, sessions) and say what happens to each on
  an installed copy that updates. Test it by installing the old build, then the new one over it, before merging.

### Check the Riverpod 3 rules before touching a provider (2026-11-25)
- **Mistake:** I fixed a failing record test as "a stale assertion" and wrote `await _ref.refresh(...)` with no disposed
  check, without first reading what Riverpod 3 changed. The user had to remind me the project is on Riverpod 3. The
  failing test was a real bug: Riverpod 3 filters provider updates with `==`, and `RecordDocument` defined `==` as
  "same id", so an edit never reached the detail screen.
- **Rule:** before changing a provider, a notifier or a test that reads one, read CODING_STANDARDS §7 and the
  package's `CHANGELOG.md` (`~/.pub-cache/hosted/pub.dev/riverpod-<version>/`) for the behaviour involved: `==`
  filtering, `Ref.mounted` after every `await`, `ProviderException`, retry, pausing. A test that fails after the
  Riverpod 3 upgrade is a suspect for one of these before it is a stale assertion; reproduce it without widgets first.
  Do not add `riverpod_generator`/`riverpod_annotation`: the generator needs `analyzer >=13`, which the
  `balsm_boundary_lint` and `drift_dev` pins block. Write `Notifier`s by hand.

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

