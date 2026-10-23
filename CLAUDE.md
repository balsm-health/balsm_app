# Claude Code Instructions

Read and follow the agent instructions in the Roadmap repo: [AGENTS.md](../Balsm-Core/agents/rules/AGENTS.md), the shared standards in [Balsm-Core/agents/rules/CODING_STANDARDS.md](../Balsm-Core/agents/rules/CODING_STANDARDS.md), and this repo's own [CODING_STANDARDS.md](./CODING_STANDARDS.md) (Dart style, melos structure, localization, performance).

## Patient-App-Specific Notes

- **This is the PHI-heaviest repo.** Health data (profiles, medications, dose
  history, records) lives ON-DEVICE ONLY (drift/SQLCipher) and never goes to
  the cloud; the one exception is field-encrypted DOB. Never log, print, or
  transmit PHI; never fabricate sample PHI in code or fixtures.
- Melos monorepo: `packages/core` (shared kernel) + bounded-context modules
  under `modules/` + `app/` shell. Modules depend on core, never on each
  other; cross-module reads go through core contracts/ports
  (`application/ports/` in each module).
- PHI persistence goes through the scoped data-source contracts
  (`ProfileDataSource` — partitioned by `health_profile_id`;
  `UserDataSource` — by account). Domain/application layers depend on the
  module's port, never on `Drift*` concretes.
- Flutter runs via **fvm** (`fvm flutter …`, `fvm dart …`); version pinned in `.fvmrc`.
- UI strings live in i69n bundles (`app/lib/balsm_app/i18n/*.json`, core's
  `localization/i18n/`); after editing JSON run `dart run build_runner build`
  in that package. No inline bilingual `ar ? … : …` ternaries.
- **Every code change keeps the version and the changelog current**, in the
  same change and without being asked: every pull request that touches
  shipped code under `app/`, `packages/` or `modules/` raises `version:` in
  `app/pubspec.yaml` above the base branch, by the rule in
  `CODING_STANDARDS.md` §9 (fix → patch, feature → minor, breaking → major,
  build number +1; packages carry no version), and opens a new
  `## [<version>] - Unreleased` section at the top of `CHANGELOG.md` for its
  lines; older sections are never renamed. CI's **Version raised** check
  enforces the raise, and the Claude version-bump workflow commits it to the
  pull request when it is missing. Never add a version to the live
  `app/web/version/<brand>.json` outside a release.
- A feature that may need switching off without a release goes behind a flag
  (`CODING_STANDARDS.md` §8, `docs/feature-flags.md`).
- Reference data comes from core value objects: `LanguageCode`,
  `CountryCode` (structural), `CountryRegistry` (account jurisdictions).
  No private country/language lists in screens.
