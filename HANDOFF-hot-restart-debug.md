# Handoff: hot-restart error investigation (split from architecture thread)

**Status: symptom still NOT reproduced. One real defect on the restart path found and fixed (below); the user's actual error text is STILL the missing piece.**

## Symptom (user report)
"I always made a hot restart, and the error occurs." Every hot restart of the
Flutter app (VS Code, `Debug Balsm` launch config) surfaces an error. Exact
error text/location NOT yet captured — unknown whether it is:
(a) the Dart Analysis Server crash notification (see below), or
(b) a runtime error in the app's debug console after restart.
→ First step: ask for / screenshot the exact error text and where it appears.

## Related finding: Dart Analysis Server SIGKILL (maybe the same "error")
- Log: `/var/folders/ry/fy58htz14l9_rt_0kssxv_0r0000gn/T/log-14a0.txt`
- `Analysis server exited (null, SIGKILL)` ×3 within 3 min, killed ~instantly
  after spawn, NO Dart exception → external kill, not a crash.
- Machine has 128 GB, memory was fine (44% free) → not classic OOM.
- Working hypothesis: DAS binary runs from the fvm SDK cache
  (`~/fvm/versions/3.41.9/bin/cache/dart-sdk/bin/dart`); concurrent CLI
  `fvm flutter analyze/test/build_runner` runs at the same timestamps may
  have invalidated the running binary (macOS kills on signature/binary
  change). Unproven.
- Amplifier: VS Code multi-root workspace analyzes 22 Dart projects incl.
  unrelated `/Volumes/Dev/Git/ynmo-revamp-flutter/*`. Recommend
  `dart.analysisExcludedFolders` or separate window.
- Stale tab: deleted file `packages/core/lib/src/domain/value_objects/app_locale.dart`
  still open in editor (harmless; close it).

## Repro attempt (negative result)
- Ran app on booted iPhone 17 sim (EF7A6E0C-8E4C-4390-A2E5-24B64AA39529):
  `fvm flutter run -d <sim> --flavor balsm --dart-define-from-file=env/balsm/dev.json
   --dart-define-from-file=env/shared.json -t lib/brands/balsm/main_balsm.dart`
  from `balsm_app/app`, `--pid-file`, hot restart via `kill -USR2 <pid>`.
- Result: "Restarted application in 417ms", no errors. Fresh install,
  signed-OUT state. User's error may require a signed-in session, an open
  DB connection, or a specific screen.

## Recently landed changes most likely implicated if it's a runtime error
(all in balsm_app, commits 834c49d, 85a5f18, 02d1c01, 1680e6b, e6b639d)
- `AppDatabase.ensureSelfHealthProfile` + `activeProfileProvider` /
  `currentProfileIdProvider` (core auth_context) — runs at session start,
  watches `appDatabaseProvider` (throws UnimplementedError if a scope misses
  the bootstrap override).
- PHI stores ported to ScopedDataSource contract (profile-keyed):
  `DriftMedicationsDataSource`, `DriftProfileDataSource` + ports.
- Suspects on hot restart: double DB open (drift NativeDatabase on same file),
  DevLogBuffer.install() re-run, provider container re-init racing
  ensureSelfHealthProfile.

## Next steps
1. Get exact error text + where it shows (debug console / toast / DAS popup).
2. If runtime: repro with a signed-in session on the sim, hot restart, read
   stack trace; check the suspects above.
3. If DAS popup: correlate timestamps with any running CLI dart/fvm
   processes; consider excluding ynmo repos from the workspace.


## 2026-09-23 — one real defect found and fixed; symptom still not reproduced

**Confirmed:** the user runs from the IDE (`Debug Balsm`), and their session
keeps showing pre-change UI. Three rounds of "the changes aren't applied" have
now been traced to this, not to missing code — a cold `flutter run` of the very
same launch config renders every ported screen.

**Fixed: unguarded `developer.registerExtension` in `shell.dart`.**
`dart:developer` throws `ArgumentError` on a duplicate name (pinned by
`app/test/debug_extensions_test.dart`, which fails loudly if that ever stops
being true). The shell binds six `ext.balsm.*` names in `initState`, and
`initState` runs again on every remount — sign out and back in, `go('welcome')`
and back — WITHOUT the isolate restarting. Unguarded, the second bind threw and
took the rest of `initState` with it, boot-splash timer included. Now routed
through `registerExtensionOnce`; the name set is isolate-local, so a real hot
restart (new isolate) still rebinds — verified by calling `ext.balsm.setTab`
after a restart and getting `{ok: true}`.

Whether this was *the* user-visible error is unproven: it needs a remount, not
a plain restart.

**Repro attempt 2 (negative, but closer than the first).**
`flutter run -t lib/brands/balsm/main_balsm.dart --flavor balsm` on iPhone 17
Pro, this time with the shell actually mounted and a populated on-device DB
(docshots-seeded meds + care team) — the first attempt was signed-out on the
walkthrough, where the shell never mounts and the extensions never bind.
Restarted via `kill -USR2 <pid>`: "Restarted application in 487ms", no
exception, nothing in the console.

**What is still untested — and is now the most likely difference.** Every
repro so far has been CLI `flutter run`. The user is on the VS Code Dart debug
adapter, which attaches a debugger. A *caught* exception that the CLI never
prints will still pause VS Code if "All Exceptions" / "Uncaught Exceptions" is
ticked in the Breakpoints pane — and a paused restart leaves stale code
running, which is exactly the reported symptom. Next repro should be from VS
Code, not the CLI.

## Next steps (revised)
1. **Still the first job: the exact error text**, and where it appears —
   debug console, a red VS Code toast, or the debugger stopping on a line.
2. Check the VS Code Breakpoints pane for "All Exceptions".
3. If it is a debugger pause rather than a crash, the app is not broken and
   the fix is the breakpoint setting, not the code.
