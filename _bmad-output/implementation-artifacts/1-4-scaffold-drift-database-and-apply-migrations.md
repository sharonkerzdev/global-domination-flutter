# Story 1.4: Scaffold Drift Database and Apply Migrations

Status: done

## Story

As a developer,
I want Drift configured with a minimal `AppDatabase` (empty or near-empty table list), code generation running via `build_runner`, and a `MigrationStrategy` wired,
so that future stories can add tables incrementally without re-scaffolding persistence.

## Acceptance Criteria

1. **Given** the project has `drift: ^2.26.1` and `sqlite3_flutter_libs: ^0.5.25` in `pubspec.yaml` **When** a developer runs `dart run build_runner build --delete-conflicting-outputs` **Then** `*.g.dart` files generate cleanly under `lib/data/database/` **And** no errors or warnings are produced.

2. **Given** `build.yaml` at the project root **When** Drift generates code **Then** it uses `store_date_time_values_as_text: true` and `named_parameters: true`.

3. **Given** the app launches for the first time on a fresh install **When** `AppDatabase` initializes **Then** the database opens at schema version 1 with zero rows in zero custom tables (only Drift's internal metadata is present) **And** no migration runs.

4. **Given** a schema version bump (e.g. v1 → v2) is introduced in a later story **When** the app launches against a v1 database **Then** a backup file `schema_backup_v1.sqlite` is written to app documents before the migration executes **And** the migration runs via Drift's typed `MigrationStrategy`.

## Tasks / Subtasks

- [x] Task 1: Create `build.yaml` at project root (AC: #2)
  - [x] 1.1 Create `build.yaml` with Drift options: `store_date_time_values_as_text: true`, `named_parameters: true`, `write_from_json_string_constructor: false`
- [x] Task 2: Create `AppDatabase` with `MigrationStrategy` (AC: #1, #3, #4)
  - [x] 2.1 Create `lib/data/database/app_database.dart` with `@DriftDatabase` annotation, empty table list, schema version 1
  - [x] 2.2 Use `LazyDatabase` + `NativeDatabase.createInBackground` with `path_provider` for file location and `sqlite3.tempDirectory` workaround for Android
  - [x] 2.3 Wire `MigrationStrategy` with `onCreate: (m) => m.createAll()` and `onUpgrade` placeholder
  - [x] 2.4 Implement `onUpgrade` callback that copies the existing database file to `schema_backup_v{fromVersion}.sqlite` before any migration runs (guarded by `File.exists()` check so v1 fresh installs are no-ops)
- [x] Task 3: Create `DecimalConverter` type converter (AC: #1)
  - [x] 3.1 Create `lib/data/database/converters/decimal_converter.dart` — a Drift `TypeConverter<Decimal, String>` that serializes `Decimal` to/from TEXT
  - [x] 3.2 This converter will be used by future stories when they add tables with big-number columns
- [x] Task 4: Run code generation (AC: #1)
  - [x] 4.1 Run `dart run build_runner build --delete-conflicting-outputs`
  - [x] 4.2 Verify `app_database.g.dart` generates cleanly with no errors
- [x] Task 5: Create `appDatabaseProvider` in providers (AC: #3)
  - [x] 5.1 Create `lib/providers/data_providers.dart` with a `Provider<AppDatabase>` that instantiates `AppDatabase()`
  - [x] 5.2 This provider is the single point of access — UI and services never instantiate `AppDatabase` directly
- [x] Task 6: Write tests (AC: #1, #3)
  - [x] 6.1 Create `test/data/database/app_database_test.dart` — test that `AppDatabase` opens at schema version 1 using `NativeDatabase.memory()`
  - [x] 6.2 Test that `migration.onCreate` runs `createAll()` without error on a fresh in-memory database
  - [x] 6.3 Test `DecimalConverter` round-trips: `Decimal.parse('1e38')` → TEXT → `Decimal` with zero precision loss
  - [x] 6.4 Test `DecimalConverter` handles edge cases: zero, negative, very large numbers
  - Note: AC #4 backup-before-migrate cannot be exercised at schema v1 (no prior version to upgrade from). It will be tested by the first story that bumps schemaVersion (Epic 6 / Story 6.5).
- [x] Task 7: Run full test suite and analyzer (AC: all)
  - [x] 7.1 Run `flutter analyze --fatal-infos` — zero issues (generated `*.g.dart` must be excluded via `analysis_options.yaml` which already has `lib/**/*.g.dart` in the exclude list)
  - [x] 7.2 Run `flutter test` — all existing tests (15 from Stories 1.1-1.3) plus new tests pass

## Dev Notes

### Architecture Compliance

This story creates the persistence foundation. Key rules from architecture:

- **UI never touches Drift directly** — UI → Riverpod provider → repository → database. This story creates the `appDatabaseProvider` as the entry point. [Source: project-context.md#Critical Implementation Rules, rule 3]
- **Never raw SQL** — always typed Drift DSL. [Source: game-architecture.md#Drift Typed Query Pattern]
- **Schema changes REQUIRE a new migration file** under `lib/data/database/migrations/`. Never mutate an existing version. [Source: project-context.md#Drift]
- **`schema_backup_v{n}.sqlite` must exist BEFORE running the migration**, not after. Ordering matters. [Source: project-context.md#Subtle gotchas]
- **Big numbers stored as TEXT via `DecimalConverter`** — serializes to string, preserves precision. [Source: game-architecture.md#Persistence — Drift 2.26]
- **Drift-generated `*.g.dart` files must be excluded from lint and committed** — they are part of the repo, not build-time-only. [Source: project-context.md#Subtle gotchas]
- **Write cadence is event-driven + 2s debounced snapshot. Never per-tick.** (Future stories — not this one — but the database must be designed to support this.) [Source: game-architecture.md#Persistence — Drift 2.26]

### Implementation Approach

**Minimal scaffold** — This story deliberately creates an `AppDatabase` with NO custom tables. The architecture defines tables (`meta`, `countries`, `leaders`, `upgrades`, `achievements`, `missions`, `boosts`, `goldens`, `crash_logs`, `tutorial_state`, `settings`, `event_log`) but those are added incrementally in future stories (Epic 6 primarily). Story 1.4 is about getting the Drift machinery running so future stories just add tables.

**`build.yaml`** — Required at project root. Per architecture: `store_date_time_values_as_text: true` (ISO8601 text for DateTime columns — needed for `meta.lastSavedAt` which is the offline clock source), `named_parameters: true` (for readability). Also add `write_from_json_string_constructor: false` per architecture spec.

**Database file location** — Use `LazyDatabase` wrapping `NativeDatabase.createInBackground(file)` where `file` is in `getApplicationDocumentsDirectory()`. The database file should be named `global_domination.sqlite`. Set `sqlite3.tempDirectory` to the app's temp directory on Android (required workaround — Android doesn't allow access to `/tmp`).

**Schema backup strategy** — The `beforeOpen` callback in `MigrationStrategy` fires after `onUpgrade`. For backup-before-migrate, use `onUpgrade` to copy the file BEFORE running migration steps. The implementation should:
1. In `onUpgrade`: before any schema changes, copy the database file to `schema_backup_v{from}.sqlite` in the same directory
2. Then proceed with migration steps

However, since Drift opens the database before calling `onUpgrade`, and we need to copy the file before changes happen — use a wrapper approach: the `LazyDatabase` opener checks the existing database version first, copies the backup file, THEN returns the opened database. Alternatively, implement the backup in the `onUpgrade` callback since Drift calls it within a transaction (the old data is still available). The simplest correct approach:

- In `onUpgrade`, before executing any migration statements, use `dart:io` to copy the database file to `schema_backup_v{from}.sqlite`. Since `onUpgrade` is called before the schema changes are committed, the file on disk still contains the old schema.

**Note:** For schema version 1 (this story), `onUpgrade` will never run — it only fires when upgrading from a previous version. The backup logic will be exercised by the first story that bumps the schema version (likely in Epic 6).

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `build.yaml` | Drift code generation options |
| CREATE | `lib/data/database/app_database.dart` | AppDatabase class with MigrationStrategy |
| GENERATED | `lib/data/database/app_database.g.dart` | Drift-generated code (committed) |
| CREATE | `lib/data/database/converters/decimal_converter.dart` | Decimal ↔ TEXT type converter |
| CREATE | `lib/providers/data_providers.dart` | `appDatabaseProvider` |
| CREATE | `test/data/database/app_database_test.dart` | Database scaffold tests |

### Technical Requirements

**Drift setup specifics (from latest docs):**

```dart
// lib/data/database/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Before any migration steps, back up the current database file
        await _backupDatabase(from);
        // Future stories add migration steps here
      },
    );
  }

  static Future<void> _backupDatabase(int fromVersion) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dbFolder.path, 'global_domination.sqlite'));
    if (await dbFile.exists()) {
      final backupPath = p.join(
        dbFolder.path,
        'schema_backup_v$fromVersion.sqlite',
      );
      await dbFile.copy(backupPath);
    }
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'global_domination.sqlite'));
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
      return NativeDatabase.createInBackground(file);
    });
  }
}
```

**Important:** The constructor accepts an optional `QueryExecutor` parameter — this is how tests inject `NativeDatabase.memory()` without touching the real filesystem.

**DecimalConverter pattern:**

```dart
// lib/data/database/converters/decimal_converter.dart
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}
```

**Provider pattern:**

```dart
// lib/providers/data_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
```

### Testing Standards

- Database tests use `NativeDatabase.memory()` — never touch the real filesystem
- Import `package:flutter_test/flutter_test.dart` (this is under `test/data/`, not `test/game/`)
- `DecimalConverter` tests should cover: zero (`Decimal.zero`), negative (`Decimal.parse('-42.5')`), large numbers (`Decimal.parse('1e38')`), precision preservation
- Database open/close test: create `AppDatabase(NativeDatabase.memory())`, verify `schemaVersion == 1`, close without error

### Anti-Patterns to Avoid

- Do NOT add any game tables yet — this story is scaffold only. Tables come in future stories.
- Do NOT use `drift_flutter` package (`driftDatabase()` helper) — the project uses `drift/native.dart` with manual `LazyDatabase` + `NativeDatabase` setup for full control over backup logic. The `drift_flutter` package is NOT in `pubspec.yaml`.
- Do NOT use `getApplicationSupportDirectory` — use `getApplicationDocumentsDirectory` per the architecture's backup strategy (documents directory is user-visible on some platforms, which helps with debugging).
- Do NOT import `package:sqlite3/sqlite3.dart` — import `package:sqlite3/sqlite3.dart` only for `sqlite3.tempDirectory`. The `sqlite3` package is a transitive dependency of `sqlite3_flutter_libs` and does not need to be added to `pubspec.yaml` directly.
- Do NOT put database opening logic in `main.dart` — it belongs in `app_database.dart` with the `LazyDatabase` pattern. `main.dart` only has global handlers + Riverpod scope.
- Do NOT skip committing `*.g.dart` files — they are part of the repo per architecture decision.
- Do NOT create a `migrations/` directory yet — the first migration file will be added by the story that bumps schema version. For v1, `onCreate: (m) => m.createAll()` handles fresh installs.

### Previous Story Intelligence

**From Story 1.3 (Enforce "No Flutter in `lib/game/`" Boundary):**
- `test/architecture/game_boundary_test.dart` created with 4 tests
- 15 total tests pass (11 from 1.1-1.2 + 4 new)
- `flutter analyze --fatal-infos`: zero issues
- No production code changes, no new dependencies
- `lib/game/` directory still does not exist

**From Story 1.1 (Wire Global Safety Net):**
- `lib/main.dart` wired with global error handlers, portrait lock, `ProviderScope`
- `lib/services/crash_reporter.dart` and `lib/ui/fallback_error_widget.dart` exist
- `logging: ^1.3.0` added to pubspec

**Key pattern from previous stories:** All Drift-related packages (`drift`, `sqlite3_flutter_libs`, `drift_dev`, `build_runner`, `path_provider`, `path`) are already in `pubspec.yaml` — no dependency changes needed.

### Git Intelligence

Recent commits are all project setup:
- `9c804f9` — planning artifacts and settings
- `6992c42` — MCP servers config
- `8d84ab1` — BMAD setup, Flutter deps
- `91edb72` — Initial Flutter scaffold

No feature code beyond Story 1.1's work. `lib/data/` directory does not exist yet — this story creates it.

### Project Structure Notes

- `lib/data/database/` is a new directory following the architecture's prescribed layout
- `lib/data/database/converters/` follows the architecture tree: `converters/ { decimal_converter, enum_converter }`
- `lib/providers/data_providers.dart` follows the architecture tree: `providers/ { data_providers.dart }` — houses `appDatabaseProvider`
- `test/data/database/` mirrors the `lib/data/database/` structure per testing conventions
- `build.yaml` goes at project root (same level as `pubspec.yaml`)

### References

- [Source: epics.md#Story 1.4] — Acceptance criteria and user story
- [Source: game-architecture.md#Persistence — Drift 2.26] — Schema design, DecimalConverter, write cadence, migration strategy, backup-before-migrate
- [Source: game-architecture.md#Drift Typed Query Pattern] — SaveRepository pattern, never raw SQL
- [Source: game-architecture.md#First-Time Setup Notes] — build.yaml configuration
- [Source: game-architecture.md#File Structure] — `lib/data/database/`, `lib/data/database/converters/`, `lib/data/database/migrations/`
- [Source: project-context.md#Technology Stack] — Drift 2.26.1, sqlite3_flutter_libs 0.5.25, path_provider 2.1.5, path 1.9.0
- [Source: project-context.md#Critical Implementation Rules] — UI never touches Drift directly, never raw SQL, migration file required for schema changes
- [Source: project-context.md#Subtle gotchas] — schema_backup BEFORE migration, g.dart files committed
- [Source: 1-3-enforce-no-flutter-in-lib-game-boundary.md] — Previous story: 15 passing tests, zero analyze issues

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Analyzer flagged `depend_on_referenced_packages` for `package:sqlite3/sqlite3.dart` (transitive dep). Resolved with `// ignore:` comment per story dev notes rather than adding sqlite3 as direct dependency (which caused drift version downgrade).

### Completion Notes List

- Created `build.yaml` with Drift code generation options (store_date_time_values_as_text, named_parameters, write_from_json_string_constructor)
- Created `AppDatabase` with empty table list, schema version 1, `LazyDatabase` + `NativeDatabase.createInBackground`, `MigrationStrategy` with backup-before-migrate in `onUpgrade`
- Created `DecimalConverter` (`TypeConverter<Decimal, String>`) for future big-number columns
- Code generation produced `app_database.g.dart` cleanly
- Created `appDatabaseProvider` as single access point for database
- 9 new tests: 2 database tests (schema version, onCreate) + 7 DecimalConverter tests (zero, negative, 1e38, very large, fractions, toSql, fromSql)
- All 24 tests pass (15 existing + 9 new), zero analyzer issues

### Change Log

- 2026-04-21: Implemented Story 1.4 — Drift database scaffold with AppDatabase, DecimalConverter, appDatabaseProvider, and tests
- 2026-04-21: Code review — 0 HIGH, 1 MEDIUM (AC4 test-coverage claim), 1 LOW (Task 2.4 `beforeOpen` vs `onUpgrade` mismatch). Both fixed: Task 6 scope corrected to `(AC: #1, #3)` with explicit note that AC #4 is deferred to Story 6.5; Task 2.4 reworded to match the `onUpgrade` implementation.

### File List

| Action | File |
|--------|------|
| CREATE | `build.yaml` |
| CREATE | `lib/data/database/app_database.dart` |
| GENERATED | `lib/data/database/app_database.g.dart` |
| CREATE | `lib/data/database/converters/decimal_converter.dart` |
| CREATE | `lib/providers/data_providers.dart` |
| CREATE | `test/data/database/app_database_test.dart` |
| MODIFIED | `pubspec.lock` |
