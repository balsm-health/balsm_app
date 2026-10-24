# balsm_app — documentation index

- [architecture.md](architecture.md) — the monorepo in one page: PHI boundary,
  layers, module rules, persistence tiers
- [balsm-cli.md](balsm-cli.md) — the `bin/balsm` CLI: every action, artifact,
  option, and where builds get collected
- [`superpowers/specs/`](superpowers/specs/) — approved feature designs
  (dated; the design history of the app)
- [`superpowers/plans/`](superpowers/plans/) — implementation plans built from
  those specs
- [feature-flags.md](feature-flags.md) — switching features on and off without
  a release: the flags that exist, how a value is resolved, adding a flag,
  adding a flag tool (PostHog today)
- [releasing.md](releasing.md) — how a commit becomes an alpha, beta and
  production release: tags, the Promote workflow, hotfixes
- [ci-secrets.md](ci-secrets.md) — what CI needs and where it lives
- [google-drive-backup-setup.md](google-drive-backup-setup.md) — OAuth setup
  for the encrypted Drive backup
- [`store/listing-copy.md`](store/listing-copy.md) — store listing copy

Setup/run/test commands: repo [README](../README.md). Binding agent +
coding rules: [CLAUDE.md](../CLAUDE.md), [CODING_STANDARDS.md](../CODING_STANDARDS.md),
`../Balsm-Core/agents/rules/`.
