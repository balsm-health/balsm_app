# App-update tests

A patient who updates from the store keeps everything the old version left on
the phone. These tests start today's code on that old state, the way the
first launch after an update does, and fail when the update would:

- **crash on open**: a schema change with no patch for existing databases,
  or a patch that runs in the wrong order;
- **lose data**: a dropped table, a rebuild that does not copy its rows, a
  value changed on the way;
- **drift**: a column, index or trigger that a fresh install has and an
  updated phone does not, or an old required column that makes new inserts
  fail;
- **reset settings**: a preference key renamed or retyped with no migration
  step, so the patient's choice reads back as the default;
- **sign patients out** or lose the database key: a keychain key renamed, or
  a boot clean-up that deletes what the old version wrote.

| Where | What |
|---|---|
| `packages/core/test/upgrade/db_upgrade_test.dart` | the encrypted database, from every `fixtures/db/<version>.sql` |
| `app/test/upgrade/device_state_upgrade_test.dart` | settings and session, from every `fixtures/device_<version>.json`, plus the shipped key names in `fixtures/persisted_keys_<version>.txt` |

Both run in CI's blocking **Tests** job.

## When a version ships

Freeze what it leaves on phones, so every later build is tested against it.

1. Database schema, from `packages/core`:

       BALSM_FREEZE_DB_SCHEMA=<version> fvm flutter test test/upgrade/freeze_db_schema_test.dart

2. Stored key names, from the repository root:

       git grep -hoE "'balsm\.[a-z0-9_.]+" <tag> -- 'packages/*/lib/**.dart' 'modules/*/lib/**.dart' 'app/lib/**.dart' \
         | sed "s/^'//" | grep -vx 'balsm.health' | sort -u

   into `app/test/upgrade/fixtures/persisted_keys_<version>.txt`, with the
   same header as the existing ones.

3. Settings and session: copy the latest `device_<version>.json` to the new
   version and add any key the release introduced, with a value that differs
   from its default. Add the matching accessor to the test.

Never edit a fixture of a version that has shipped. It records what is on
patients' phones; changing it hides the very break it exists to catch.

## When a test fails

- **Missing after the update**: the column is in a `CREATE TABLE` but not
  patched onto existing tables. Add an `_ensureColumn` call (and create any
  index on it after the patches) in `app_database.dart`.
- **Lost or gained rows / values changed**: an upgrade step rewrote a table.
  Copy every row across, or explain in the PR why the data is safe to drop.
- **A setting reads back as its default, or a key nothing reads**: add a
  migration step to that `ModulePreferences` group (`rename`, `transform`)
  and bump its `schemaVersion`.
- **A stored key is no longer used**: move its value under the new name and
  list the old key in `retired` in `device_state_upgrade_test.dart`.

All fixture values are synthetic. Never put real patient data in them.
