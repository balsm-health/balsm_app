# Claude Code Instructions

Read and follow the agent instructions in the Roadmap repo: [AGENTS.md](../Balsm-Core/agents/rules/AGENTS.md), including the Dart rules in [CODING_STANDARDS.md](../Balsm-Core/agents/rules/CODING_STANDARDS.md) §2.2 (`.map` over collection-`for`; typed value objects in state; `fromCode`/`tryFromCode` boundary parsing; `snake_case` static consts).

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
- Flutter runs via **puro** (`puro flutter …`, `puro dart …`).
- UI strings live in i69n bundles (`app/lib/patient_app/i18n/*.json`, core's
  `localization/i18n/`); after editing JSON run `dart run build_runner build`
  in that package. No inline bilingual `ar ? … : …` ternaries.
- Reference data comes from core value objects: `LanguageCode`,
  `CountryCode` (structural), `CountryRegistry` (account jurisdictions).
  No private country/language lists in screens.
