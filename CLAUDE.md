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
- **Every code change adds a changelog note**, in the same change and without
  being asked: a pull request that touches shipped code under `app/`,
  `packages/` or `modules/` adds one file,
  `changelog.d/<pr or issue>.<group>[.major|.minor].md` (group: added,
  changed, fixed, removed, security), whose text is the changelog line ending
  with its ticket as a link,
  `([#99](https://github.com/balsm-health/balsm_app/issues/99))` (the PR's
  `/pull/` link when there is no issue). See `changelog.d/README.md` and
  `CODING_STANDARDS.md` §9.
- **Never change `version:` in `app/pubspec.yaml` or add lines to
  `CHANGELOG.md` in a pull request.** The Promote workflow collects the notes
  and raises the version when the team releases. CI's **Changelog note** check
  requires the note and refuses a changed version, and the Claude
  changelog-note workflow writes a missing note on the pull request. Never add a version to the live
  `app/web/version/<brand>.json` outside a release.
- A feature that may need switching off without a release goes behind a flag
  (`CODING_STANDARDS.md` §8, `docs/feature-flags.md`).
- Reference data comes from core value objects: `LanguageCode`,
  `CountryCode` (structural), `CountryRegistry` (account jurisdictions).
  No private country/language lists in screens.
