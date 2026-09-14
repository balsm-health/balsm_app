# Flutter Local-Database Benchmark — Design Spec

**Date:** 2026-07-04
**Status:** Approved (design), pending implementation plan
**Artifact:** standalone repo `~/Dev/Balsm/db_benchmark` (NOT a dependency of `balsm_app`)
**Motivation:** pick the local persistence engine for the Balsm patient app on evidence, not vendor claims. Balsm ships all six Flutter platforms, stores PHI (encryption mandatory), and is read-heavy over small relational datasets. See the storage architecture spec (`2026-07-02-storage-layer-design.md`) for the tier taxonomy this feeds.
**Prior art:** [PowerSync Flutter DB comparison](https://powersync.com/blog/flutter-database-comparison-sqlite-async-sqflite-objectbox-isar) — the classic 16-test SQLite suite across sqlite_async / sqflite / ObjectBox / Isar. Headline finding: *batching/transactions matter more than which engine you pick.* Caveat: INSERT-SELECT tests favor SQL engines. No encryption tested. This benchmark mirrors their row counts and rigor (for comparability) and **extends** with Floor / Hive CE / sembast and an encryption dimension.

## Goal

A throwaway evaluation harness that runs an identical CRUD workload across seven Flutter local-DB engines, on all six platforms, in plaintext and encrypted configurations, and emits comparable timing numbers. Output informs a single decision: does the app stay on drift, or is there a defensible reason to switch?

Non-goal: a reusable library, a production abstraction, or a general ORM shim. It is deliberately disposable.

## Engines under test (7)

| Engine | Family | Encrypted via | Notes |
|--------|--------|---------------|-------|
| **drift** | sqlite (relational) | SQLCipher (`sqlcipher_flutter_libs` + cipher pragma) | current Balsm choice |
| **sqflite** | sqlite (relational) | `sqflite_sqlcipher` | raw plugin baseline |
| **floor** | sqlite (relational) | `sqflite_sqlcipher` open callback | annotation codegen over sqflite |
| **objectbox** | nosql (mmap) | **N/A — commercial license** | encrypted cell = explicit gap, never 0 |
| **isar** | nosql | AES `encryptionKey` (only if the resolved build exposes it) | maintenance risk noted, still measured |
| **hive** (Hive CE fork) | key-value | `HiveAesCipher` | no indexed query — see below |
| **sembast** | key-value / document | `SembastCodec` (encrypt codec) | no indexed query — see below |

**KV limitation (measured, not hidden):** Hive and sembast have no indexed `WHERE`. Their `queryIndexed` implementation loads the store and filters in Dart. That is their real cost for this access pattern and is timed as-is, flagged in output as a structural limitation rather than a tuning gap.

## Architecture — common interface, per-engine adapter

```
abstract class BenchDb {
  String get name;
  bool supportsEncryption(Platform);        // false → encrypted run marked N/A
  Future<void> open({required bool encrypted});
  Future<void> clear();                     // truncate between iterations
  Future<void> close();

  Future<void> insertBulk(int n);           // idiomatic fast path (txn / putMany)
  Future<void> insertSingle(int n);         // n separate commits, no batching
  Future<int>  readAll();                   // full scan, returns count
  Future<int>  queryIndexed(int threshold); // WHERE indexed_int > threshold (or KV filter)
  Future<void> updateAll(int n);            // update n rows by key
  Future<void> deleteAll(int n);            // delete n rows by key
}
```

**Fixed record shape** (identical across every engine — fairness):

| field | type | role |
|-------|------|------|
| `id` | text (uuid v7) | primary key |
| `indexedInt` | int | **indexed** — drives `queryIndexed` |
| `text` | string (~32 chars) | payload |
| `value` | double | payload |
| `flag` | bool | payload |
| `createdAt` | int (epoch ms) | payload |

**Components**
- `bench_db.dart` — the `BenchDb` interface, the record model, `BenchResult` / `RunConfig` value types.
- `engines/*_engine.dart` — one adapter per engine implementing `BenchDb`.
- `registry.dart` — platform-aware: returns only engines available on the current platform; the rest are reported `skipped(unsupported)` so the gap is visible, not silent.
- `runner.dart` — orchestrates `engines × ops × {plain, encrypted} × iterations`, times each op, handles warmup, aggregates.
- `report.dart` — renders console table + writes JSON / CSV / markdown.
- `main.dart` — app entry: run on launch, render progress + results, persist files.

Each unit is independently understandable: an engine adapter knows only its own package; the runner knows only `BenchDb`; the report knows only `BenchResult`. Adding an eighth engine = one new file in `engines/` + one registry line.

## Platform matrix (6) — registry skips per platform

| Engine | macOS | Linux | Windows | iOS | Android | Web |
|--------|:-----:|:-----:|:-------:|:---:|:-------:|:---:|
| drift | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (wasm+OPFS) |
| sqflite | ✅¹ | ✅¹ | ✅¹ | ✅ | ✅ | ⚠️ (ffi-web) |
| floor | ✅¹ | ✅¹ | ✅¹ | ✅ | ✅ | ⚠️ |
| objectbox | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ **no web** |
| isar | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ flaky/excluded |
| hive | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| sembast | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (sembast_web) |

¹ desktop sqflite requires `sqflite_common_ffi`.

The web column is a deliverable, not a footnote: it shows ObjectBox and Isar failing the all-platform bar directly.

## Methodology (mirrors PowerSync for comparability)

- **Release mode only.** Runner detects debug mode and prints a loud warning; debug numbers are meaningless.
- **Warmup:** one discarded run per (engine, op, crypto) before timing.
- **Iterations:** ≥3; report **median and min** (min = best-case, median = typical).
- **Row counts** (from the SQLite benchmark suite the PowerSync post uses): single-insert 1,000; bulk-insert 25,000; readAll over 25,000; indexed query over 25,000; update 25,000; delete 25,000.
- **Timing:** wall-clock `Stopwatch` around async APIs only. Synchronous engines (ObjectBox) run their work in a background isolate so blocking the UI thread is not mistaken for speed.
- **Determinism:** seeded `Random(seed)` data generator; identical dataset per engine per iteration.
- **Isolation:** `clear()` between iterations; fresh DB file per (engine, crypto) run.

## Output

- **On-screen** (the app): progress per engine + a results table (op × engine, plain/encrypted, median ms).
- **Persisted** (`results/{platform}-{timestamp}.{json,csv,md}`): JSON for tooling, CSV for spreadsheets, markdown table for pasting into a report. Desktop/mobile write to disk; web emits to console + triggers a file download.
- Cells that did not run carry a reason: `N/A (encryption unsupported)`, `skipped (platform)` — never a blank or a zero that reads as "instant".

## Fairness rules (baked in, cited)

1. Identical record shape, row counts, indexed field across all engines.
2. Bulk path uses each engine's idiomatic fast path (drift `batch`, ObjectBox `putMany`, sqflite/Floor single transaction). Single-insert path is deliberately naive (per-row commit) to expose the batching gap PowerSync highlights.
3. KV engines' `queryIndexed` = documented Dart-side filter (their true cost).
4. ObjectBox encrypted = `N/A (commercial)`; Isar encrypted only if the build supports it, else `N/A`.
5. Sync engines run in an isolate.
6. Every result banner states: *measures this workload on this device — not a universal ranking.*

## Testing

The harness is itself throwaway, but three correctness checks prevent garbage numbers:
- **Round-trip test** per engine: `insertBulk(k)` then `readAll()` returns `k`; `queryIndexed(t)` returns the arithmetically-expected count; `deleteAll(k)` empties the store. A fast engine that silently drops writes must fail here, not post a fake win.
- **Encryption smoke test**: after an encrypted write, the raw DB file (where a file exists) does not contain a known plaintext payload token. Guards against "encrypted" configs that silently no-op.
- **Registry test**: on each platform, the registry's available-engine set matches the matrix above (unavailable engines are skipped, not crashed).

## Out of scope (YAGNI)

- `sqlite_async` / PowerSync engine (not requested; add later as one more adapter if wanted).
- Concurrency / multi-isolate contention benchmarks.
- Memory-footprint and binary-size measurement (worth a follow-up, not this pass).
- Any production abstraction extracted from the harness.

## Deliverable

A committed `db_benchmark` repo that a developer clones, runs `flutter run --release -d <platform>` on each of the six targets, and collects `results/` from. The numbers + the encryption/web gaps decide whether Balsm stays on drift.
