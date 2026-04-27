# Story 6.3: Typed Migrations and `schema_backup_v{n}.sqlite`

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want each schema-version bump implemented as its own typed migration step file under `lib/data/database/migrations/`, wired through a single `MigrationRegistry` that Drift's `MigrationStrategy.onUpgrade` composes, with `schema_backup_v{n}.sqlite` written before any migration runs and a 3-launch retention policy for those backups, plus a Save Recovery screen that captures runtime migration failures,
So that every schema change ships as a reviewable, testable, isolated unit, the player has a forensic snapshot of the pre-migration state, and a corrupt or failed migration cannot silently brick the app on launch.

## Acceptance Criteria

1. **Given** the project's `lib/data/database/migrations/` folder after this story
   **When** examined
   **Then** it contains exactly: `migration_registry.dart` (the typed registry/composer), `v1_to_v2.dart` (extracted from the inline branch added by Story 1-4), `v2_to_v3.dart` (extracted from the inline branch added by Story 6-1), AND a per-step migration file follows the contract:
   ```dart
   class V2ToV3 extends MigrationStep {
     const V2ToV3();
     @override int get fromVersion => 2;
     @override int get toVersion => 3;
     @override Future<void> migrate(Migrator m, AppDatabase db) async { ... }
   }
   ```
   No raw SQL inside any step (typed Drift DSL only); each step is `@immutable` and has no instance state.

2. **Given** `AppDatabase.migration` in `app_database.dart`
   **When** read
   **Then** the `onUpgrade` body is reduced to: (a) `await _backupDatabase(from)`; (b) `await MigrationRegistry.run(m, this, from: from, to: to)`; (c) catch `Object e, StackTrace s` and rethrow as `MigrationFailureException(fromVersion: from, toVersion: to, cause: e.toString(), stackTrace: s)` (a NEW unsealed `Exception` class added under `lib/data/database/migrations/migration_failure_exception.dart`). NO `if (from == 1)` / `if (from <= 2 && to >= 3)` branches remain inline — every version step lives in its own file.

3. **Given** the `MigrationRegistry`
   **When** `run(m, db, from: from, to: to)` is called
   **Then** it iterates `_steps` (a `const List<MigrationStep>` ordered ASC by `fromVersion`), executes every step whose `fromVersion >= from && toVersion <= to`, awaits each step in sequence, AND throws `StateError('Missing migration step from vX to vX+1')` if a contiguous version chain is broken (e.g. registry has v1→v2 and v3→v4 but no v2→v3 when a v1→v4 upgrade is requested). The registry is closed for modification by feature stories — a new step is added via a single one-line `const V3ToV4()` insertion in `_steps`.

4. **Given** a v1 database file on disk at app launch (i.e. `schemaVersion == 1` per Drift's `_drift_meta` table)
   **When** `AppDatabase` opens
   **Then** the typed `MigrationStrategy.onUpgrade` (a) writes `schema_backup_v1.sqlite` into the application documents directory via the existing `_backupDatabase` helper, (b) runs `V1ToV2().migrate(m, db)` then `V2ToV3().migrate(m, db)` in that order, (c) the database lands at `schemaVersion == 3`, (d) existing `crash_logs` rows are preserved, (e) the singleton `meta` row is NOT seeded (per Story 6-1 Task 3.4 — `SaveRepository`'s first write inserts it).

5. **Given** a step migration throws (e.g. `SqliteException` on a `createTable`, `Exception('synthetic'`) in tests)
   **When** caught by `AppDatabase.migration`'s `onUpgrade` body
   **Then** the exception is rewrapped as `MigrationFailureException(fromVersion, toVersion, cause)`, the `LazyDatabase` factory in `app_database.dart` propagates it out to the caller (Riverpod's `appDatabaseProvider` first read), AND a NEW provider `databaseBootstrapProvider = FutureProvider<AppDatabase>` exposed via `lib/providers/data_providers.dart` catches the exception, logs it via `CrashReporter.instance.reportZonedError(e, s)` AND returns an `AsyncError(MigrationFailureException, stack)`. **`appDatabaseProvider` is REPLACED**: it now `ref.watch(databaseBootstrapProvider).requireValue`, so any consumer (`CrashLogRepository`, `SaveRepository`) gets the open DB only when bootstrap succeeds.

6. **Given** `databaseBootstrapProvider` resolves to `AsyncError(MigrationFailureException)`
   **When** `app.dart`'s root widget builds
   **Then** in addition to the existing `contentRegistryProvider.when(loading, error, data)` gate, a new `databaseBootstrapProvider.when(...)` gate runs FIRST. On `AsyncError(MigrationFailureException error, _)`, the app shows the NEW `SaveRecoveryScreen(error)` widget (under `lib/ui/save_recovery_screen.dart`) with the screen's three CTAs: **Restore from `schema_backup_v{fromVersion}.sqlite`** (visible only if the backup file exists — checked via `File.exists()` at screen build), **Start Fresh** (always visible — confirmed twice), **Copy Crash Log** (always visible — copies `error.toString() + stackTrace` to clipboard via `Clipboard.setData`). On other `AsyncError` (non-migration, e.g. opening a corrupt DB unrelated to migration), the same screen is shown with all three CTAs and the error message visible.

7. **Given** the `SaveRecoveryScreen` "Restore from Backup" button is tapped
   **When** the user confirms once (single tap; the dire-confirmation pattern is reserved for "Start Fresh" per Story 6-6)
   **Then** the screen calls a NEW pure-Dart `SaveRecoveryActions.restoreFromBackup(int fromVersion)` helper (under `lib/data/database/migrations/save_recovery_actions.dart`) that: (a) renames the corrupt `global_domination.sqlite` to `app_v{toVersion}_corrupt_{epochMillis}.sqlite` using `File.rename`, (b) copies `schema_backup_v{fromVersion}.sqlite` to `global_domination.sqlite`, (c) calls `ref.invalidate(databaseBootstrapProvider)`, retriggering `AppDatabase` open. **Story 6-6 owns the full corruption-recovery UX surface** — this story implements the migration-failure subset only (single-tap restore; no double-confirm; no non-migration corruption flow beyond showing the error). The `start fresh` CTA is wired to a stub that calls `restoreFromBackup` is NOT — instead Start Fresh is a `// TODO(Story 6-6): full start-fresh flow` placeholder that throws `UnimplementedError` and shows a SnackBar `'Start Fresh available in Story 6-6'`.

8. **Given** a successful migration completes (any `from`→`to`)
   **When** the next 3 cold launches occur AFTER that migration
   **Then** `schema_backup_v{from}.sqlite` continues to exist on disk in app documents directory. On the 4th cold launch (and beyond), the file MAY be pruned. Implementation: a NEW pure-Dart helper `BackupRetentionPolicy.prune(Directory dir, {int retainMostRecent = 3})` (under `lib/data/database/migrations/backup_retention_policy.dart`) scans all files matching `RegExp(r'^schema_backup_v\d+\.sqlite$')`, sorts by modification time DESC, keeps the most-recent `retainMostRecent`, deletes the rest. **NOT a per-launch counter** — a launch-count bookkeeping mechanism is over-engineered; "keep 3 most recent backup files in the directory" is the simpler discipline that satisfies the AC's intent (a 3-launch safety net). `BackupRetentionPolicy.prune` is invoked exactly once per app boot from `app.dart`'s `initState` AFTER `databaseBootstrapProvider` resolves to `AsyncData` (success — pruning never runs while a migration is failing). Pruning errors are caught and logged via `Logger('BackupRetentionPolicy')`; pruning is fire-and-forget (`unawaited`).

9. **Given** the architectural boundary `lib/data/ → lib/game/` (one-way) established by Story 6-1's `data_boundary_test.dart`
   **When** any new file under `lib/data/database/migrations/` is examined
   **Then** **no migration step file imports `package:global_domination/game/...`** (migration steps are pure persistence DDL — they manipulate Drift tables only). `migration_failure_exception.dart` imports nothing from `lib/game/` either (the runtime error type lives in `lib/data/`; the sim-layer `GameError.internalMigrationFailure` factory in `lib/game/game_error.dart` already exists and is unaffected — `MigrationFailureException` is the data-layer wire-format, `MigrationFailure` is the sim-layer error envelope; they are deliberately separate). `data_boundary_test.dart` (extended in Story 6-2) is extended again here to assert the entire `lib/data/database/migrations/` subtree obeys the no-game-imports invariant; the dual-import allowlist (mapper + save_repository) is unchanged.

10. **Given** `BackupRetentionPolicy.prune` is implemented
    **When** invoked on a directory containing 5 files (`schema_backup_v1.sqlite` through `schema_backup_v5.sqlite`, modification times v1 oldest → v5 newest)
    **Then** after `prune(dir, retainMostRecent: 3)` returns: v3, v4, v5 remain on disk; v1 and v2 are deleted. Non-matching files (e.g. `global_domination.sqlite`, `app_v3_corrupt_1735000000.sqlite`) are NEVER touched. Verified by a unit test using `dart:io` against a `Directory.systemTemp.createTempSync()` scratch directory.

11. **Given** all unit and widget tests authored for this story
    **When** `flutter test test/data/database/migrations/ test/data/database/app_database_test.dart test/ui/save_recovery_screen_test.dart test/architecture/data_boundary_test.dart` runs
    **Then** every Drift test uses `NativeDatabase.memory()` AND `await db.close()` in `tearDown`; every filesystem test uses `Directory.systemTemp.createTempSync()` AND deletes the temp dir in `tearDown`; new tests cover at minimum: each `MigrationStep` constructs without error and exposes correct `fromVersion`/`toVersion` (1 test per step, 2 tests now); `MigrationRegistry.run` executes steps in order (1 test using a recording fake `Migrator`); `MigrationRegistry.run` throws on missing step (1 test); v1→v2 migration via in-memory open path lands at v2 (1 test, deferred-pattern note for true v1-on-disk per `app_database_test.dart` lines 1-3); v1→v2→v3 chained migration (1 test); migration-failure-exception wrapping path (1 test using a `_FailingMigrationStep`); `BackupRetentionPolicy.prune` 5→3 file retention (1 test); `BackupRetentionPolicy.prune` ignores non-matching filenames (1 test); `BackupRetentionPolicy.prune` empty-dir no-op (1 test); `SaveRecoveryScreen` renders error message + restore button hidden when backup missing (1 widget test); `SaveRecoveryScreen` restore button visible when backup present (1 widget test); `SaveRecoveryScreen` start-fresh CTA shows SnackBar placeholder (1 widget test); `SaveRecoveryScreen` copy-log button writes to `Clipboard` (1 widget test, `MockClipboard`); `databaseBootstrapProvider` resolves to `AsyncError(MigrationFailureException)` when migration step throws (1 widget/integration test using `ProviderContainer`); `data_boundary_test.dart` rejects a new file under `lib/data/database/migrations/` that imports `lib/game/` (1 negative test using a temp file).

## Tasks / Subtasks

- [ ] Task 1: Define `MigrationStep` contract + `MigrationFailureException` (AC: #1, #2, #5, #9)
  - [ ] 1.1 Create `lib/data/database/migrations/migration_step.dart`:
    ```dart
    import 'package:drift/drift.dart';
    import 'package:meta/meta.dart';
    import '../app_database.dart';

    @immutable
    abstract class MigrationStep {
      const MigrationStep();
      int get fromVersion;
      int get toVersion;
      Future<void> migrate(Migrator m, AppDatabase db);
    }
    ```
    Pure interface; concrete implementations live in their own files. **No `lib/game/` imports.**
  - [ ] 1.2 Create `lib/data/database/migrations/migration_failure_exception.dart`:
    ```dart
    import 'package:meta/meta.dart';

    @immutable
    class MigrationFailureException implements Exception {
      final int fromVersion;
      final int toVersion;
      final String cause;
      final StackTrace? originalStackTrace;
      const MigrationFailureException({
        required this.fromVersion,
        required this.toVersion,
        required this.cause,
        this.originalStackTrace,
      });

      @override
      String toString() =>
          'MigrationFailureException(from: v$fromVersion → to: v$toVersion, cause: $cause)';
    }
    ```
    **Why a new exception type when `lib/game/game_error.dart` already has `MigrationFailure`?** The sim-layer `GameError.MigrationFailure` is the `Result.failure` envelope used by `Result<T, GameError>` consumers. The data layer is allowed to surface raw `Exception` subtypes — wrapping into `MigrationFailure` happens at the boundary (in this story: at `databaseBootstrapProvider`'s catch site if a future story wires it to `Result`; for 6-3, the exception bubbles to the UI via `AsyncError`).

- [ ] Task 2: Implement `V1ToV2` and `V2ToV3` step files (AC: #1, #4)
  - [ ] 2.1 Create `lib/data/database/migrations/v1_to_v2.dart`. Body migrates the lone Story 1-4 change (creates `crash_logs`):
    ```dart
    import 'package:drift/drift.dart';
    import '../app_database.dart';
    import 'migration_step.dart';

    class V1ToV2 extends MigrationStep {
      const V1ToV2();
      @override int get fromVersion => 1;
      @override int get toVersion => 2;

      @override
      Future<void> migrate(Migrator m, AppDatabase db) async {
        await m.createTable(db.crashLogs);
      }
    }
    ```
  - [ ] 2.2 Create `lib/data/database/migrations/v2_to_v3.dart`. Body migrates Story 6-1's batch of new tables. **DEPENDENCY**: this file can be authored only AFTER Story 6-1 lands as `done`. If Story 6-1 is still `ready-for-dev` when this story is implemented, the dev agent MUST verify and HALT. If 6-1 is `done`, the body is exactly the inline branch from 6-1 Task 3.3 (lines 130–148 of 6-1 story spec):
    ```dart
    import 'package:decimal/decimal.dart';
    import 'package:drift/drift.dart';
    import '../app_database.dart';
    import 'migration_step.dart';

    class V2ToV3 extends MigrationStep {
      const V2ToV3();
      @override int get fromVersion => 2;
      @override int get toVersion => 3;

      @override
      Future<void> migrate(Migrator m, AppDatabase db) async {
        await m.createTable(db.meta);
        await m.createTable(db.countries);
        await m.createTable(db.continents);
        await m.createTable(db.continentMilestones);
        await m.createTable(db.earnedAchievements);
        await m.createTable(db.activeGlobalUpgrades);
        await m.createTable(db.activeGoldens);
        await m.createTable(db.activeGoldenEffect);
        // NOTE: meta singleton row is intentionally NOT seeded here — per Story 6-1
        // Task 3.4, SaveRepository's first write inserts it (insert-or-update fallback).
      }
    }
    ```
    **Cross-cutting note:** Story 6-1's spec describes seeding a `meta` row inside the v2→v3 branch (6-1 Task 3.3 sample code lines 140–146). Story 6-1 then deliberately reverses that decision in Task 3.4 ("Decision: do NOT seed meta in onCreate; let the empty-DB → `initialSeed` flow drive the first save's INSERT in Story 6-2"). The 6-1 dev should have implemented the Task 3.4 decision; this story 6-3 step body MUST match the actual implementation. **Verify before authoring `v2_to_v3.dart`**: open `lib/data/database/app_database.dart` post-6-1 and copy the actual `from <= 2 && to >= 3` branch verbatim into the step file, dropping the `if` wrapper.

- [ ] Task 3: Implement `MigrationRegistry` (AC: #1, #3)
  - [ ] 3.1 Create `lib/data/database/migrations/migration_registry.dart`:
    ```dart
    import 'package:drift/drift.dart';
    import '../app_database.dart';
    import 'migration_step.dart';
    import 'v1_to_v2.dart';
    import 'v2_to_v3.dart';

    class MigrationRegistry {
      MigrationRegistry._();

      // Ordered ASC by fromVersion. New steps append here — single insertion point.
      static const List<MigrationStep> _steps = [
        V1ToV2(),
        V2ToV3(),
      ];

      static Future<void> run(
        Migrator m,
        AppDatabase db, {
        required int from,
        required int to,
      }) async {
        var cursor = from;
        while (cursor < to) {
          final step = _steps.firstWhere(
            (s) => s.fromVersion == cursor,
            orElse: () => throw StateError(
              'Missing migration step from v$cursor to v${cursor + 1}',
            ),
          );
          await step.migrate(m, db);
          cursor = step.toVersion;
        }
      }
    }
    ```
    The cursor-walk pattern composes contiguous single-step migrations. A future v3→v4 step from Story 5-2 just appends `V3ToV4()` to `_steps` — no other change.
  - [ ] 3.2 **Do NOT** add multi-step jumps (e.g. `V1ToV3`). Each step is a single contiguous version bump. If a feature legitimately needs to skip a version (impossible per project rule "Schema changes REQUIRE a new migration file under `lib/data/database/migrations/`. Never mutate an existing version."), revisit the design.

- [ ] Task 4: Refactor `app_database.dart` to delegate to the registry (AC: #2, #5)
  - [ ] 4.1 Open `lib/data/database/app_database.dart`. Replace the entire `migration` getter body with:
    ```dart
    @override
    MigrationStrategy get migration {
      return MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          try {
            await _backupDatabase(from);
            await MigrationRegistry.run(m, this, from: from, to: to);
          } catch (e, s) {
            throw MigrationFailureException(
              fromVersion: from,
              toVersion: to,
              cause: e.toString(),
              originalStackTrace: s,
            );
          }
        },
      );
    }
    ```
    Add the imports:
    ```dart
    import 'migrations/migration_failure_exception.dart';
    import 'migrations/migration_registry.dart';
    ```
  - [ ] 4.2 Confirm `_backupDatabase` and `_openConnection` are unchanged. `schemaVersion` getter unchanged (still returns whatever 6-1 bumped it to — this story does NOT bump the schema version).
  - [ ] 4.3 The `LazyDatabase`'s factory closure does NOT need `try/catch` — `MigrationFailureException` propagates naturally through the `Future<NativeDatabase>` that `LazyDatabase` returns. Drift's open path surfaces the exception to the first `await`-ing query (which is the bootstrap provider in Task 5).

- [ ] Task 5: Wire `databaseBootstrapProvider` and refactor `appDatabaseProvider` (AC: #5, #6)
  - [ ] 5.1 Open `lib/providers/data_providers.dart`. Add:
    ```dart
    final databaseBootstrapProvider = FutureProvider<AppDatabase>((ref) async {
      final db = AppDatabase();
      ref.onDispose(() async { await db.close(); });
      // Force migration to run by issuing a trivial query.
      // The migration runs on first DB access — opening alone is lazy.
      await db.customSelect('SELECT 1').get();
      return db;
    });
    ```
    The `customSelect('SELECT 1')` is the canonical Drift-blessed way to force `LazyDatabase` to open. **`customSelect` is the lone exception to the no-raw-SQL rule** in this story — it's a Drift API call with a literal `'SELECT 1'`, not a query against a real table. (`crash_log_repository.dart` precedent: `_db.customSelect('SELECT 1')` is already used in `app_database_test.dart` at the time of writing.)
  - [ ] 5.2 **Replace** `appDatabaseProvider`'s body:
    ```dart
    final appDatabaseProvider = Provider<AppDatabase>((ref) {
      return ref.watch(databaseBootstrapProvider).requireValue;
    });
    ```
    Remove the `ref.onDispose(() => db.close())` line — disposal lives on `databaseBootstrapProvider` now; `appDatabaseProvider` is just a sync read of the bootstrapped DB.
  - [ ] 5.3 **Verify downstream consumers still work**:
    - `crashLogRepositoryProvider` reads `appDatabaseProvider` — works (sync `.requireValue` succeeds once bootstrap is `AsyncData`).
    - `crashLogsProvider` (FutureProvider) reads `crashLogRepositoryProvider` — chains through correctly.
    - Story 6-2's `saveRepositoryProvider` reads `appDatabaseProvider` — chains through correctly.
    - `main.dart`'s `container.read(crashLogRepositoryProvider)` runs BEFORE `runApp`. The first `appDatabaseProvider` read will throw `StateError` if the bootstrap is still `AsyncLoading` at boot. **Fix**: in `main.dart`, before `CrashReporter.instance.attach(...)`, `await container.read(databaseBootstrapProvider.future);` (suppress and log on error — CrashReporter falls back to in-memory if attach fails).
  - [ ] 5.4 Update `lib/main.dart`:
    ```dart
    // ... existing setup ...
    final container = ProviderContainer();
    try {
      await container.read(databaseBootstrapProvider.future);
      CrashReporter.instance.attach(container.read(crashLogRepositoryProvider));
    } catch (e, s) {
      // Migration failure or DB corruption — CrashReporter stays detached;
      // app.dart's databaseBootstrapProvider gate will show SaveRecoveryScreen.
      // Log via direct Logger since CrashReporter isn't wired yet.
      Logger('main').severe('database bootstrap failed', e, s);
    }
    runApp(...);
    ```
    Add `import 'package:logging/logging.dart';` if not already present. **The migration failure does NOT block `runApp`** — the user MUST land on the `SaveRecoveryScreen` rather than seeing a frozen splash.

- [ ] Task 6: Implement `BackupRetentionPolicy` (AC: #8, #10)
  - [ ] 6.1 Create `lib/data/database/migrations/backup_retention_policy.dart`:
    ```dart
    import 'dart:io';

    import 'package:logging/logging.dart';

    class BackupRetentionPolicy {
      BackupRetentionPolicy._();

      static final _log = Logger('BackupRetentionPolicy');
      static final _backupPattern = RegExp(r'^schema_backup_v\d+\.sqlite$');

      static Future<void> prune(
        Directory dir, {
        int retainMostRecent = 3,
      }) async {
        if (!await dir.exists()) return;
        try {
          final entries = await dir.list().toList();
          final backups = entries.whereType<File>().where(
            (f) => _backupPattern.hasMatch(p.basename(f.path)),
          ).toList();
          backups.sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
          final toDelete = backups.skip(retainMostRecent).toList();
          for (final f in toDelete) {
            await f.delete();
            _log.fine('pruned ${f.path}');
          }
        } catch (e, s) {
          _log.warning('prune failed', e, s);
        }
      }
    }
    ```
    Add `import 'package:path/path.dart' as p;` (already a project dependency per pubspec).
  - [ ] 6.2 Wire the prune call in `lib/app.dart`. Convert `GlobalDominationApp` to `ConsumerStatefulWidget` (if Story 6-2 has not already done so):
    ```dart
    @override
    void initState() {
      super.initState();
      _runPostBootCleanup();
    }

    Future<void> _runPostBootCleanup() async {
      try {
        await ref.read(databaseBootstrapProvider.future);
        final dbFolder = await getApplicationDocumentsDirectory();
        unawaited(BackupRetentionPolicy.prune(dbFolder));
      } catch (_) {
        // Bootstrap failure path — SaveRecoveryScreen will handle UX.
      }
    }
    ```
    Add `import 'dart:async';` for `unawaited` and `import 'package:path_provider/path_provider.dart';`. **If Story 6-2 already converted `GlobalDominationApp` to ConsumerStatefulWidget**, append `_runPostBootCleanup()` inside the existing `initState`; do NOT duplicate the conversion.

- [ ] Task 7: Implement `SaveRecoveryActions` helper (AC: #7)
  - [ ] 7.1 Create `lib/data/database/migrations/save_recovery_actions.dart`:
    ```dart
    import 'dart:io';

    import 'package:path/path.dart' as p;
    import 'package:path_provider/path_provider.dart';

    class SaveRecoveryActions {
      SaveRecoveryActions._();

      static const _dbFileName = 'global_domination.sqlite';

      static Future<bool> backupExists(int fromVersion) async {
        final dir = await getApplicationDocumentsDirectory();
        final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
        return backup.exists();
      }

      static Future<void> restoreFromBackup({
        required int fromVersion,
        required int toVersion,
      }) async {
        final dir = await getApplicationDocumentsDirectory();
        final live = File(p.join(dir.path, _dbFileName));
        final backup = File(p.join(dir.path, 'schema_backup_v$fromVersion.sqlite'));
        if (!await backup.exists()) {
          throw StateError('Backup schema_backup_v$fromVersion.sqlite not found');
        }
        if (await live.exists()) {
          final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
          await live.rename(p.join(dir.path, 'app_v${toVersion}_corrupt_$ts.sqlite'));
        }
        await backup.copy(live.path);
      }
    }
    ```
    **Pure helper** — no Riverpod, no Flutter imports. Caller (the `SaveRecoveryScreen` widget) invokes and then triggers `ref.invalidate(databaseBootstrapProvider)`.

- [ ] Task 8: Implement `SaveRecoveryScreen` widget (AC: #6, #7)
  - [ ] 8.1 Create `lib/ui/save_recovery_screen.dart`. The screen receives a `MigrationFailureException` (or generic `Object error` for non-migration corruption). Three buttons:
    - **Restore from Backup v$fromVersion**: visible iff `SaveRecoveryActions.backupExists(fromVersion)` returns true. On tap: invoke `restoreFromBackup`, then `ref.invalidate(databaseBootstrapProvider)`. Spinner during restore.
    - **Start Fresh** (placeholder for Story 6-6): tap shows a SnackBar `'Start Fresh available in Story 6-6'` and does nothing else. **Do NOT throw `UnimplementedError`** — that's a UX antipattern in production. The button is rendered (so the screen looks complete) but stubs out cleanly.
    - **Copy Crash Log**: copies `error.toString()\n\n${error.originalStackTrace ?? ''}` to clipboard via `Clipboard.setData(ClipboardData(text: ...))`. Shows a SnackBar `'Copied'`.
  - [ ] 8.2 Skeleton:
    ```dart
    class SaveRecoveryScreen extends ConsumerStatefulWidget {
      final Object error;
      const SaveRecoveryScreen({required this.error, super.key});
      @override ConsumerState<SaveRecoveryScreen> createState() => _S();
    }

    class _S extends ConsumerState<SaveRecoveryScreen> {
      bool? _backupExists;
      bool _restoring = false;

      @override
      void initState() {
        super.initState();
        _checkBackup();
      }

      Future<void> _checkBackup() async {
        final err = widget.error;
        if (err is MigrationFailureException) {
          final exists = await SaveRecoveryActions.backupExists(err.fromVersion);
          if (mounted) setState(() => _backupExists = exists);
        } else {
          if (mounted) setState(() => _backupExists = false);
        }
      }

      @override
      Widget build(BuildContext context) { ... }
    }
    ```
    Pattern matches `BootErrorScreen` for layout (centered column, error icon, message text, button stack). Use `MaterialApp` wrapper since this is a top-level screen invoked before the real app shell.
  - [ ] 8.3 The `Restore from Backup` button is shown only when `_backupExists == true` AND `widget.error is MigrationFailureException`. While loading (`_backupExists == null`) show a small `CircularProgressIndicator` placeholder. While restoring (`_restoring == true`), disable all buttons and show a centered spinner.

- [ ] Task 9: Update `lib/app.dart` to gate on `databaseBootstrapProvider` (AC: #6)
  - [ ] 9.1 The current `GlobalDominationApp.build` has a single `registryAsync.when(...)` gate. **Wrap** it with a `databaseBootstrapProvider.when(...)` gate:
    ```dart
    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final bootAsync = ref.watch(databaseBootstrapProvider);
      return bootAsync.when(
        loading: () => const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        error: (error, stack) => SaveRecoveryScreen(error: error),
        data: (_) {
          final registryAsync = ref.watch(contentRegistryProvider);
          return registryAsync.when(
            loading: () => const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            ),
            error: (error, stack) => BootErrorScreen(message: error.toString()),
            data: (registry) => MaterialApp(theme: _theme, home: const _GameScreen()),
          );
        },
      );
    }
    ```
  - [ ] 9.2 If Story 6-2 already converted `GlobalDominationApp` to `ConsumerStatefulWidget` (Task 6.4 in 6-2), preserve that conversion; just edit the `build` body. The `_runPostBootCleanup` from Task 6.2 of THIS story coexists with 6-2's lifecycle observer wiring.

- [ ] Task 10: Extend `data_boundary_test.dart` (AC: #9)
  - [ ] 10.1 Open `test/architecture/data_boundary_test.dart` (created by Story 6-1; extended by Story 6-2). Add a third group `'lib/data/database/migrations/ purity'`:
    ```dart
    group('lib/data/database/migrations/ purity', () {
      test('no migration step file imports lib/game/', () {
        final files = findDartFiles(Directory('lib/data/database/migrations'));
        if (files.isEmpty) return;
        final pattern = RegExp(r'''import\s+['"]package:global_domination/game/''');
        final violations = findViolations(files, pattern);
        expect(violations, isEmpty);
      });
    });
    ```
  - [ ] 10.2 Confirm the existing dual-import allowlist (mapper + save_repository, set in Story 6-2 Task 7.2) is unchanged. Migration step files do NOT import from `lib/data/database/...` cross-folder either — they import only `../app_database.dart` (sibling) which IS under `lib/data/database/`; if the allowlist test misclassifies migrations folder under `lib/data/database/...`, ensure the predicate scopes to file path `lib/data/repositories/` for the dual-import check (the test's intent is "the only file ROUTING events from sim layer to DB"; migrations don't route, they declare DDL).

- [ ] Task 11: Tests for `MigrationRegistry`, `MigrationStep`, `MigrationFailureException` (AC: #1, #3, #5, #11)
  - [ ] 11.1 Create `test/data/database/migrations/migration_registry_test.dart`. Use `flutter_test` (touches `Migrator` from `package:drift/drift.dart`).
  - [ ] 11.2 Tests:
    - `'V1ToV2 has fromVersion=1, toVersion=2'`
    - `'V2ToV3 has fromVersion=2, toVersion=3'`
    - `'MigrationRegistry.run executes steps in order for v1→v3'`: use a `_RecordingMigrator` test double that records every `createTable` call; assert order matches `crash_logs` first, then `meta`, `countries`, ... (Story 6-1's order).
    - `'MigrationRegistry.run is no-op for from==to'`: pass `from: 3, to: 3`; assert no step ran.
    - `'MigrationRegistry.run throws StateError on missing step'`: call with `from: 4, to: 5` while no V4ToV5 step exists; assert `StateError` thrown with the expected message.
  - [ ] 11.3 Create `test/data/database/migrations/migration_failure_exception_test.dart`:
    - `'toString includes from/to versions and cause'`: trivial.
    - `'preserves stackTrace'`: trivial.

- [ ] Task 12: Tests for `BackupRetentionPolicy` (AC: #8, #10, #11)
  - [ ] 12.1 Create `test/data/database/migrations/backup_retention_policy_test.dart`. Use `package:test/test.dart` — pure Dart, `dart:io` only.
  - [ ] 12.2 Helper: `setUp` creates `Directory.systemTemp.createTempSync('backup_retention_test_')`; `tearDown` calls `dir.deleteSync(recursive: true)`.
  - [ ] 12.3 Tests:
    - `'retains 3 most recent of 5 backups by mtime'`: create 5 files; manipulate `setLastModifiedSync` to space them apart by 1 second (oldest to newest = v1..v5); call `prune(dir, retainMostRecent: 3)`; assert v3, v4, v5 remain; v1, v2 gone.
    - `'ignores non-matching files'`: create `global_domination.sqlite`, `app_v2_corrupt_1234.sqlite`, `schema_backup_v1.sqlite`; call `prune(dir, retainMostRecent: 3)`; assert all three remain (only one matches the regex; retention >= count).
    - `'is no-op on empty directory'`: empty temp dir; call `prune`; assert no error.
    - `'is no-op on non-existent directory'`: pass a path that doesn't exist; assert no throw.
    - `'with retainMostRecent=0 deletes all matching'`: 3 backup files; `prune(dir, retainMostRecent: 0)`; assert dir empty of backups.
    - `'sort is stable across equal mtimes'`: 2 files with identical mtime; `prune(dir, retainMostRecent: 1)`; assert exactly 1 file remains (which one is implementation-defined; document in test).

- [ ] Task 13: Tests for `SaveRecoveryActions` (AC: #7, #11)
  - [ ] 13.1 Create `test/data/database/migrations/save_recovery_actions_test.dart`. Use `flutter_test` because `getApplicationDocumentsDirectory` requires `path_provider` test setup.
  - [ ] 13.2 Use `path_provider_platform_interface`'s test helper (or override via `PathProviderPlatform.instance`) to redirect `getApplicationDocumentsDirectory` to a temp dir for the test. **Reference**: existing `app_database_test.dart` does NOT do this because `NativeDatabase.memory()` bypasses path_provider; we DO need it here.
  - [ ] 13.3 Tests:
    - `'backupExists returns true when file present'`: write `schema_backup_v2.sqlite` to temp dir; call `backupExists(2)`; assert `true`.
    - `'backupExists returns false when file missing'`: empty temp dir; call `backupExists(2)`; assert `false`.
    - `'restoreFromBackup renames live db and copies backup'`: write live `global_domination.sqlite` and `schema_backup_v2.sqlite`; call `restoreFromBackup(fromVersion: 2, toVersion: 3)`; assert: (a) live file content equals backup content, (b) a file matching `app_v3_corrupt_*.sqlite` exists, (c) backup file still present (not consumed).
    - `'restoreFromBackup throws StateError when backup missing'`: empty temp dir; expect throw.
    - `'restoreFromBackup is idempotent for live-file-missing path'`: only backup present, no live; call → live file copied from backup, no rename of nonexistent file (no throw).

- [ ] Task 14: Widget tests for `SaveRecoveryScreen` (AC: #6, #7, #11)
  - [ ] 14.1 Create `test/ui/save_recovery_screen_test.dart`. Use `flutter_test`.
  - [ ] 14.2 Tests:
    - `'renders error message + restore hidden when backup missing'`: pump screen with `MigrationFailureException(from: 99, to: 100, cause: 'test')`; expect `find.text(...)` for the error text; expect restore button NOT present (or disabled).
    - `'restore button visible when backup present'`: stub `path_provider` to a temp dir; write `schema_backup_v2.sqlite`; pump screen with `MigrationFailureException(from: 2, ...)`; pump-and-settle; expect restore button present.
    - `'restore tap invokes SaveRecoveryActions and invalidates provider'`: same setup; tap restore; assert `databaseBootstrapProvider` invalidated (use a `ProviderContainer` with a counter).
    - `'start fresh button shows SnackBar placeholder'`: tap; expect SnackBar text `'Start Fresh available in Story 6-6'`.
    - `'copy crash log writes to clipboard'`: use `MockMethodChannel` to intercept the clipboard channel; assert payload contains the error text.
    - `'renders for non-migration error (generic Object)'`: pump with `Exception('boom')`; expect screen renders without throw; restore button NOT present.

- [ ] Task 15: Tests for `app_database.dart` migration delegation (AC: #4, #5, #11)
  - [ ] 15.1 Open `test/data/database/app_database_test.dart`. Add a new group `'migration delegation'`:
    - `'migration failure rewraps as MigrationFailureException'`: use `_FailingMigrator` test double passed via a `_TestableAppDatabase` subclass that overrides the `migration` getter; assert the thrown exception is `MigrationFailureException` with correct fromVersion/toVersion. **Alternate approach**: register a temporary `V99ToV100` step that throws, set `schemaVersion` higher via subclass; this is more invasive than a `_FailingMigrator` mock. **Pick `_FailingMigrator`** — it's the lower-blast-radius approach.
    - `'v1→v2→v3 chained migration produces same end-state as fresh v3'`: open two in-memory DBs — one with `schemaVersion: 1` baseline (somehow — Drift in-memory always starts at the current `schemaVersion`, so this test is a deferred-pattern: assert the chain runs as expected via `_RecordingMigrator` instead).
  - [ ] 15.2 Update the existing comment block at lines 1–3 of `app_database_test.dart` to reference Story 6-3 explicitly (it already does — confirm it still mentions "deferred to Story 6-3" or similar).

- [ ] Task 16: Tests for `databaseBootstrapProvider` failure path (AC: #5, #6, #11)
  - [ ] 16.1 Create `test/providers/database_bootstrap_provider_test.dart`. Use `flutter_test`.
  - [ ] 16.2 Test `'bootstrap resolves to AsyncError when migration step throws'`: override `appDatabaseProvider` to construct an `AppDatabase` whose schemaVersion is one higher than current (forcing onUpgrade to run a step that doesn't exist); assert `await container.read(databaseBootstrapProvider.future)` throws `MigrationFailureException`.
  - [ ] 16.3 Test `'bootstrap resolves to AsyncData on healthy open'`: trivial; assert no throw and `db.schemaVersion` matches expected.

- [ ] Task 17: Run code generation, format, analyze, full test suite (AC: all)
  - [ ] 17.1 No `build_runner` re-run required (no schema change). If Story 6-1 stale, run once.
  - [ ] 17.2 `flutter analyze` — 0 warnings, 0 errors.
  - [ ] 17.3 `dart format --set-exit-if-changed .`.
  - [ ] 17.4 `flutter test` — full suite green. Expected new tests: ≈ 25–30. Full suite should land at ≈ 630–655 (assuming 6-1 + 6-2 already added their counts).
  - [ ] 17.5 Update `Status` to `review`. Append a Change Log entry and File List.

## Dev Notes

### Why this story is the safety-net story for the entire persistence epic

Story 6-1 owns the **schema and mapping**. Story 6-2 owns the **write strategy**. Story 6-3 owns **change-discipline + crash-safety**: every future schema bump (Story 5-2's `totalIntel` v3→v4, Story 5-3's missions tables v4→v5, etc.) ships as a single new file in `lib/data/database/migrations/` plus a one-line append to `MigrationRegistry._steps`. The `MigrationFailureException` + `SaveRecoveryScreen` path means a buggy migration in any future feature story can never silently brick the app — the worst case is a forensic SnackBar and a backup-restore.

### Out of scope (do NOT expand)

- **Full corruption-recovery UX (Story 6-6).** This story implements a minimal `SaveRecoveryScreen` that handles `MigrationFailureException` with restore + start-fresh placeholder + copy-log. Story 6-6 owns: the dual confirm-twice "Start Fresh" dialog, non-migration `SqliteException` corruption detection in `LazyDatabase`, the post-restore healthcheck loop, crash log forensics integration. **Do NOT implement those here.** The "Start Fresh" button's SnackBar placeholder is the explicit handoff.
- **Per-launch backup retention counter.** Use file mtime as a proxy. Implementation note (Task 6): "keep the 3 most-recent backup files" satisfies the AC's intent (3-launch safety net). A precise per-launch counter would require a new table or KV — over-engineered.
- **Multi-step migrations / version skipping.** Each step is a single contiguous bump. If a v3→v5 migration is ever requested, the registry walks v3→v4 then v4→v5 — no `V3ToV5` direct step.
- **Down-migrations.** Drift does not support them; the registry's signature is `from <= to`-only. A future story that needs to roll back a schema change ships a NEW forward migration that reverts the prior change.
- **Telemetry of migration durations.** Out of scope; Logger.fine timestamps suffice.
- **Encryption-at-rest of backup files.** Out of scope; the backup files inherit the underlying app-sandbox protection. Story 12 (security pass) may revisit.
- **A "view backups" admin screen.** Out of scope; backups are forensic artifacts, not user-facing.
- **Backup retention beyond the schema_backup_v{n}.sqlite naming convention.** The corrupt-rename file (`app_v{n}_corrupt_{ts}.sqlite`) is NOT pruned by `BackupRetentionPolicy.prune` (regex doesn't match). Story 6-6 may add a separate policy for those.

### Critical decisions worth restating in code

- **`MigrationFailureException` is in `lib/data/`, not `lib/game/`.** The sim layer's `GameError.MigrationFailure` (already in `lib/game/game_error.dart`) is for `Result<T, GameError>` envelopes. The data layer surfaces a raw `Exception` to its caller — which in this story is the Riverpod bootstrap provider. If a future story adopts a `Result<AppDatabase, GameError>` shape for the bootstrap, that story would map exception → `MigrationFailure` at the boundary. Today, the boundary is the `AsyncValue.error` shape — exception is sufficient.
- **`MigrationRegistry` is `const`-only.** No constructor injection of test steps. Tests use a `_RecordingMigrator` test double that observes calls; they do NOT register custom steps into the registry (which would mutate global state). The registry's purity is the contract.
- **`BackupRetentionPolicy.prune` runs on every app boot, NOT only after a successful migration.** Reasoning: most boots have no migration (schema unchanged); pruning still keeps the backup directory tidy if older backups were left over from prior versions. Cost: one `Directory.list()` call + `statSync()` per backup file — sub-millisecond on typical mobile filesystems.
- **`databaseBootstrapProvider` is a `FutureProvider`, not a `StateNotifierProvider`.** A migration runs once per app launch (or zero times if schemaVersion matches); a stream of migration events is over-engineered. `ref.invalidate(databaseBootstrapProvider)` is the canonical way to retrigger after a `restoreFromBackup`.
- **`appDatabaseProvider`'s `.requireValue` access is safe** because every consumer (`crashLogRepositoryProvider`, `saveRepositoryProvider`) is read AFTER `databaseBootstrapProvider` resolves to `AsyncData` — either via the `app.dart` gate (UI consumers) or via the `await container.read(databaseBootstrapProvider.future)` in `main.dart` (boot-time consumers). If a consumer reads `appDatabaseProvider` before bootstrap resolves, `requireValue` throws — that's a programmer error and DESIRED behavior (no silent partial open).
- **The `SaveRecoveryScreen.error` parameter is `Object` (not `MigrationFailureException`)** so the screen also handles non-migration boot errors. Pattern matching at runtime (`if (err is MigrationFailureException) ...`) drives whether the restore button is offered.
- **`unawaited(BackupRetentionPolicy.prune(...))`**: pruning is fire-and-forget. A failed delete is a logged warning, never a UX-blocking error. The user never sees a "deleting old backups..." spinner.

### Architecture compliance (non-negotiable)

- **`lib/game/` has ZERO new imports under this story.** The sim layer is unchanged. `GameError.MigrationFailure` already exists; this story does not invoke it.
- **`lib/data/database/migrations/` is a new folder.** All seven new files live in it (`migration_step.dart`, `migration_failure_exception.dart`, `migration_registry.dart`, `v1_to_v2.dart`, `v2_to_v3.dart`, `backup_retention_policy.dart`, `save_recovery_actions.dart`). NO file in this folder may import `lib/game/...`. Architecture test (Task 10) enforces.
- **No raw SQL.** The lone exception is `db.customSelect('SELECT 1')` in `databaseBootstrapProvider` (Task 5.1) — a Drift-blessed force-open primitive, not a query against a real table; precedent: `app_database_test.dart` already uses it. The migration step files use only typed `Migrator` API (`m.createTable`, `m.addColumn`, `m.dropTable`).
- **No `dart:io` in `lib/game/`.** This story uses `dart:io` extensively in `BackupRetentionPolicy` and `SaveRecoveryActions` — but those live in `lib/data/database/migrations/`, where `dart:io` is permitted (already used by `app_database.dart` `_backupDatabase`).
- **`schema_backup_v{n}.sqlite` is created BEFORE the migration runs.** Story 6-1 already wired `_backupDatabase(from)` at the top of `onUpgrade`; this story preserves that ordering inside the new try/catch.
- **No `print()` anywhere.** `Logger('BackupRetentionPolicy')` and `Logger('main')` are the new log sites.
- **Sealed-switch exhaustiveness**: this story does NOT add a new `GameCommand` or `GameEvent`. The exhaustive-switch in Story 6-2's `SaveRepository._handleEvent` is unaffected.
- **No new dependencies.** `path_provider`, `path`, `logging` are all already pinned.
- **Riverpod composition root** (project-context.md line 65): `lib/providers/data_providers.dart` is the only file allowed to wire `data/`, `game/`, and `services/` together. The new `databaseBootstrapProvider` lives there. `appDatabaseProvider` body is rewritten there.

### Library / framework requirements

- `drift: ^2.26.1` (already pinned) — `MigrationStrategy`, `Migrator`, `customSelect`.
- `path_provider: ^2.1.5` (already pinned) — `getApplicationDocumentsDirectory` in `BackupRetentionPolicy` and `SaveRecoveryActions`.
- `path: ^1.9.0` (already pinned) — `p.join`, `p.basename` in retention policy and recovery actions.
- `logging` (transitive) — new `Logger` instances. No new direct dep.
- `flutter_riverpod: ^2.6.1` — `FutureProvider`, `ref.invalidate`, `ConsumerStatefulWidget`.
- `package:flutter/services.dart` — `Clipboard.setData` in `SaveRecoveryScreen`.
- **NO new dependencies.**

### File structure requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/data/database/migrations/migration_step.dart` | Abstract `MigrationStep` contract |
| `lib/data/database/migrations/migration_registry.dart` | Registry + `run()` composer |
| `lib/data/database/migrations/migration_failure_exception.dart` | Wrapped exception type |
| `lib/data/database/migrations/v1_to_v2.dart` | Crash-logs table creation (extracted from Story 1-4) |
| `lib/data/database/migrations/v2_to_v3.dart` | Story 6-1 batch (extracted from inline branch) — depends on 6-1 done |
| `lib/data/database/migrations/backup_retention_policy.dart` | Top-N retention pruner |
| `lib/data/database/migrations/save_recovery_actions.dart` | `restoreFromBackup`, `backupExists` pure helpers |
| `lib/ui/save_recovery_screen.dart` | UI for migration-failure / boot-error recovery |
| `test/data/database/migrations/migration_registry_test.dart` | Registry composition + ordering + missing-step tests |
| `test/data/database/migrations/migration_failure_exception_test.dart` | Exception toString / fields |
| `test/data/database/migrations/backup_retention_policy_test.dart` | Pruning behaviour + edge cases |
| `test/data/database/migrations/save_recovery_actions_test.dart` | Restore + backup-exists tests |
| `test/ui/save_recovery_screen_test.dart` | Widget tests for the recovery screen |
| `test/providers/database_bootstrap_provider_test.dart` | Bootstrap success + failure path |

**Modify:**

| File | Change |
|---|---|
| `lib/data/database/app_database.dart` | `migration` getter delegates to `MigrationRegistry.run` inside try/catch that wraps in `MigrationFailureException` |
| `lib/providers/data_providers.dart` | Add `databaseBootstrapProvider`; rewrite `appDatabaseProvider` body to `requireValue` from bootstrap |
| `lib/main.dart` | `await container.read(databaseBootstrapProvider.future)` before `CrashReporter.attach`; catch + log + continue |
| `lib/app.dart` | Wrap `build` with `databaseBootstrapProvider.when(...)` gate; ConsumerStatefulWidget conversion if not already; add `_runPostBootCleanup()` calling `BackupRetentionPolicy.prune` |
| `test/data/database/app_database_test.dart` | New `'migration delegation'` group; update comment block reference if needed |
| `test/architecture/data_boundary_test.dart` | New `'lib/data/database/migrations/ purity'` group |

**Do NOT modify:**

- `lib/game/**` — sim layer untouched.
- `lib/data/database/tables/**`, `lib/data/database/converters/**` — Story 6-1's domain.
- `lib/data/mappers/**` — Story 6-1's domain.
- `lib/data/repositories/save_repository.dart` — Story 6-2's domain.
- `lib/services/**` — `GameLifecycleObserver` from 6-2 is orthogonal; `crash_reporter.dart` already swallows persistence errors and is unaffected.
- `lib/data/repositories/crash_log_repository.dart`, `crash_log_entry.dart` — orthogonal; they read `appDatabaseProvider` which now chains through bootstrap, fully transparent.
- `assets/**`, `pubspec.yaml`, `build.yaml`, `analysis_options.yaml` — no asset / dep / lint changes.

### Testing requirements

- **Drift in-memory tests** use `flutter_test` + `NativeDatabase.memory()` + `await db.close()` in `tearDown`. Match existing patterns.
- **Filesystem tests** (`backup_retention_policy_test`, `save_recovery_actions_test`) use `Directory.systemTemp.createTempSync()` and `tearDown` that deletes recursively. Pure Dart only (`package:test/test.dart`) where possible; use `flutter_test` only when `path_provider` overrides are needed.
- **`path_provider` overrides**: use `PathProviderPlatform.instance = _FakePathProvider(tempDir)` in `setUpAll`; restore in `tearDownAll`. Reference: `path_provider_platform_interface` exposes the override seam.
- **Widget tests for `SaveRecoveryScreen`** wrap in `ProviderScope` + `MaterialApp` since the screen is itself a `MaterialApp` in production; in tests, prefer the inner `Scaffold` body to avoid double-`MaterialApp` warnings.
- **Clipboard testing**: use `Clipboard.setData` channel mock via `defaultBinaryMessenger.setMockMethodCallHandler`. Reference: standard Flutter widget-test pattern.
- **Architecture test extension** (Task 10): mirrors the existing import-regex pattern. No new infrastructure.
- **Test count expectation:** ≈ 25–30 new tests; full suite lands at ≈ 630–655 (assuming 6-1's ~30 and 6-2's ~28 already merged).
- **Deferred-pattern reminder** (per Story 1-4 / 6-1 precedent): a true v1-on-disk → v3 migration cannot be exercised by `NativeDatabase.memory()`; assert via the recording-migrator pattern. Document the deferral in the test file's top-of-file comment, naming Story 6-3's own scope.

### Previous story intelligence

- **Story 6-1 (sibling, ready-for-dev)**: ESTABLISHES schema v3 + the inline `from <= 2 && to >= 3` migration branch. **This story extracts that branch into `v2_to_v3.dart`**. The dev agent MUST verify Story 6-1 is `done` before authoring `v2_to_v3.dart` Task 2.2; if not done, the file copy is wrong. Halt-and-report if 6-1 is not yet done.

- **Story 6-2 (sibling, ready-for-dev)**: Introduces the `data_boundary_test.dart` allowlist mechanism (Task 7.2) and converts `GlobalDominationApp` to `ConsumerStatefulWidget` (Task 4.2). This story 6-3 EXTENDS the architecture test (adding the migrations-folder purity group) and reuses the `ConsumerStatefulWidget` conversion. **Do NOT undo 6-2's conversion**; if 6-2 is `done` first, skip the conversion in Task 6.2; if 6-3 is implemented before 6-2 (unlikely given dependency order), do the conversion here and note the redundancy for 6-2's dev to discover.

- **Story 1-4 (done)**: Established the inline `if (from == 1) await m.createTable(crashLogs);` branch and the `_backupDatabase(from)` helper. The deferred-test pattern (`NativeDatabase.memory()` cannot exercise real-file backup) is documented in `test/data/database/app_database_test.dart` lines 1–3. **This story EXTRACTS the v1→v2 branch** (Task 2.1) into `v1_to_v2.dart` while preserving the `_backupDatabase` call ordering inside the new `onUpgrade` try/catch.

- **Story 1-10 (done)**: `CrashReporter` writes to `crash_logs` via `CrashLogRepository`. The `attach()` call in `main.dart` requires `appDatabaseProvider` to be readable. With this story's refactor, `appDatabaseProvider`'s body becomes `ref.watch(databaseBootstrapProvider).requireValue` — a `StateError` on un-resolved bootstrap. **`main.dart` must await bootstrap before attaching** (Task 5.4). If bootstrap fails, `CrashReporter.attach` is skipped — the global error handlers still log via `Logger.severe` (the in-memory listener is the fallback path for the boot session).

- **Story 1-1 (done)**: `runZonedGuarded` + global handlers wrap the entire app. A `MigrationFailureException` thrown during `databaseBootstrapProvider` resolution is caught by Riverpod's async machinery and surfaced as `AsyncError` — it does NOT escape to `runZonedGuarded` unless the app explicitly rethrows. Pattern: `app.dart`'s `databaseBootstrapProvider.when(error: ...)` is the single handling site.

- **Story 5-1 / 4-3 / 4-1 (done)**: deterministic-ordering tie-break by string ASC pattern. Not directly applicable here (migration step files have an integer `fromVersion` that gives natural ordering); preserved for completeness in future migration steps that need stable ordering of within-step DDL operations.

- **`GameStateBuilder` from project-context.md line 289**: introduced by Story 6-1 Task 8.10. **Not used by 6-3** — this story's tests don't construct `GameState` directly. (`SaveRecoveryScreen` is `GameState`-agnostic.)

### Project structure notes

- **`lib/data/database/migrations/` is a new folder** — architecture line 596 (`_bmad-output/game-architecture/project-structure.md` if sharded, otherwise gathered from project-context.md line 198: `migrations/  # migration_strategy + vN_to_vN+1`). Naming convention: `v{from}_to_v{to}.dart` for steps; descriptive names for the registry/exception/policy helpers.
- **`lib/ui/save_recovery_screen.dart`** lives at the same level as `lib/ui/boot_error_screen.dart` — both are top-level boot-time error screens, NOT under `ui/features/`. They render their own `MaterialApp` because they execute before the real app shell is constructed.
- **Test mirror discipline:** `test/data/database/migrations/` mirrors `lib/data/database/migrations/`; `test/ui/save_recovery_screen_test.dart` mirrors `lib/ui/save_recovery_screen.dart`; `test/providers/database_bootstrap_provider_test.dart` mirrors the new provider in `lib/providers/data_providers.dart`.
- **No new top-level folders required.**

### Project context rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **Schema changes REQUIRE a new migration file under `lib/data/database/migrations/`. Never mutate an existing version.** (line 117) — THIS STORY OPERATIONALIZES THIS RULE. The registry pattern enforces it: every future schema bump appends a single line to `_steps`.
- **`schema_backup_v{n}.sqlite` must be copied BEFORE running any migration** (line 120) — preserved by the existing `_backupDatabase(from)` call inside the new `onUpgrade` try block (Task 4.1).
- **No raw SQL — always typed Drift DSL** (line 117) — every migration step body uses `Migrator` typed APIs only.
- **`meta.lastSavedAt` (UTC ISO8601) is the offline clock source** (line 122) — irrelevant to this story (no meta writes); preserved as-is.
- **Direction: `data/ → game/`** (line 60) — migration steps are pure persistence DDL; do not import from `lib/game/` (architecture test enforces in Task 10).
- **No `freezed` / `json_serializable`** (line 263) — `MigrationFailureException` is hand-written.
- **Drift-generated `.g.dart` files MUST be excluded from lint and committed** (line 376) — already configured; this story doesn't regenerate `.g.dart`.
- **No `print()` anywhere** (line 138) — `Logger('BackupRetentionPolicy')` and `Logger('main')`.
- **No `DateTime.now()` in `lib/game/`** (line 354) — this story does not touch `lib/game/`. `DateTime.now().toUtc().millisecondsSinceEpoch` IS used in `SaveRecoveryActions.restoreFromBackup` for the corrupt-rename timestamp; that's in `lib/data/`, where it's permitted.
- **No `Random()` in `lib/game/`** — not used.
- **Only `lib/providers/` imports `game/` + `data/` + `services/` together** (line 65) — `data_providers.dart` is in `lib/providers/`; the new `databaseBootstrapProvider` correctly composes data layer types only.
- **Audio/haptics/persistence subscribe to `gameWorld.events`** — not applicable to this story (no event bus interaction).
- **Sealed `switch` must stay exhaustive** (line 379) — no new sealed variants here.
- **`lib/utils/` is leaf-level** (line 64) — this story does not touch `lib/utils/`.
- **`lib/game/` has ZERO Flutter imports** (line 59) — this story does not touch `lib/game/`.

### Backwards-compatibility note (project rule)

Per the project rule: **"backward compatibility is out of scope unless explicitly requested. Do not add migrations, versioning, or default-fallback logic to keep older saved games loading; it's acceptable for old saves to break and require a reset during development."**

This story's migration registry IS forward-only. The existing v1→v2 (crash_logs only) and v2→v3 (Story 6-1's normalized state tables) branches are extracted, NOT enhanced — they are preserved verbatim because they're the baseline. Future schema bumps SHIP their own forward migrations; if a migration legitimately breaks old player state (e.g. Story 5-2's `totalIntel` requires a backfill that we don't implement), the player gets the `SaveRecoveryScreen` and chooses Start Fresh (Story 6-6 owns that flow). The 3-launch backup retention is NOT a backward-compat shim — it's a forensic safety net for the session immediately following a successful migration, in case a regression surfaces post-launch and the player or developer wants to roll back manually.

The `_FailingMigrator` test patterns in Tasks 11/15 are NOT testing backward compatibility — they test the runtime error path of a forward-only migration that throws.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.3: Typed Migrations and `schema_backup_v{n}.sqlite`] — original ACs (lines 69–87)
- [Source: _bmad-output/implementation-artifacts/6-1-drift-schema-and-gamestatemapper.md#Tasks 3.3 / 3.4] — inline v2→v3 branch (lines 130–148 of 6-1 spec) that this story extracts; meta singleton no-seed decision
- [Source: _bmad-output/implementation-artifacts/6-2-persistence-write-strategy-event-driven-and-debounced-snapshot.md#Task 6 / Task 7] — `data_boundary_test.dart` allowlist + ConsumerStatefulWidget conversion that this story extends
- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.6: Save Recovery Path on Corrupt Database] — the downstream story that owns the full corruption-recovery UX surface; `SaveRecoveryScreen` in this story is the migration-failure subset only
- [Source: _bmad-output/game-architecture/architectural-decisions.md#4. Persistence — Drift 2.26] — typed migrations + schema_backup mandate (lines 45–52)
- [Source: _bmad-output/game-architecture/implementation-patterns.md#F. Drift Typed Query Pattern] — typed DSL discipline (lines 376–404)
- [Source: _bmad-output/project-context.md#Drift] — schema-change discipline, schema_backup ordering, typed DSL (lines 114–122)
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] — "Modifying an existing schema version file. Always add a new migration." (line 362)
- [Source: lib/data/database/app_database.dart] — current `migration` getter (lines 23–36); `_backupDatabase` helper (lines 38–48); `LazyDatabase` open path (lines 50–57)
- [Source: lib/game/game_error.dart] — `MigrationFailure` sim-layer error envelope (lines 151–175); deliberately distinct from this story's `MigrationFailureException` data-layer type
- [Source: lib/main.dart] — boot-time setup pattern; `CrashReporter.attach` site that needs to await bootstrap (lines 35–45)
- [Source: lib/app.dart] — `GlobalDominationApp.build`'s existing `registryAsync.when(...)` gate that wraps with the new bootstrap gate (lines 18–29)
- [Source: lib/ui/boot_error_screen.dart] — UX pattern for the new `SaveRecoveryScreen` (centered icon + message + buttons)
- [Source: lib/services/crash_reporter.dart] — `attach`/`reportZonedError` API used in Task 5.4's bootstrap-failure log path
- [Source: lib/data/repositories/crash_log_repository.dart] — pattern for typed Drift DSL in repositories; uses `_db.transaction(...)`, `_db.into(_db.crashLogs).insert(...)` — irrelevant to migrations but confirms the no-raw-SQL precedent
- [Source: lib/providers/data_providers.dart] — current `appDatabaseProvider` (lines 7–11) being replaced; pattern for new `databaseBootstrapProvider`
- [Source: test/data/database/app_database_test.dart] — pattern for `flutter_test` + `NativeDatabase.memory()` + `tearDown` close (lines 11–22); deferred-test comment block (lines 1–3) referenced in this story's Task 15.2
- [Source: test/architecture/game_boundary_test.dart] — pattern for static-analysis architecture tests; mirrored in this story's data-boundary test extension (Task 10)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
