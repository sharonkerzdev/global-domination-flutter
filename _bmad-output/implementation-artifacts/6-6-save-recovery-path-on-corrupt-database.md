# Story 6.6: Save Recovery Path on Corrupt Database

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Implementation MUST start from the Story 6.3 recovery foundation currently in the branch. Before coding, verify:

- `databaseBootstrapProvider` exists in `lib/providers/data_providers.dart` and forces Drift open with `customSelect('SELECT 1')`.
- `SaveRecoveryScreen` exists at `lib/ui/save_recovery_screen.dart`.
- `SaveRecoveryActions` exists at `lib/data/database/migrations/save_recovery_actions.dart`.
- `MigrationFailureException` restore from exact `schema_backup_v{fromVersion}.sqlite` still works.
- The failed bootstrap `AppDatabase` is closed before recovery file operations run.

If any of those are missing, finish Story 6.3 first. This story extends the recovery surface; it must not replace typed migrations, the bootstrap provider, or the schema-backup retention policy.

## Story

As a player,
I want a clear path to recover if my save file becomes corrupt,
so that I do not silently lose progress or get stuck in a crash loop.

## Acceptance Criteria

1. **Given** `AppDatabase` fails during boot because SQLite reports a corrupt or non-database file
   **When** `databaseBootstrapProvider` catches the failure
   **Then** it closes the failed database handle, wraps the failure in a `DatabaseCorruptionException`, reports it through `CrashReporter.instance.reportZonedError`, and surfaces `AsyncError(DatabaseCorruptionException, stack)` to `GlobalDominationApp`.

2. **Given** the boot error is a `DatabaseCorruptionException`
   **When** `GlobalDominationApp` builds
   **Then** the app shows the existing `SaveRecoveryScreen` with exactly these player choices: `Restore Latest Backup` when at least one `schema_backup_v{n}.sqlite` exists, `Start Fresh`, and `Contact Support`.

3. **Given** one or more schema backups exist
   **When** the recovery screen checks backups
   **Then** it selects the most recent valid file matching `schema_backup_v{n}.sqlite`, exposes the parsed schema version in the UI/test seam, and ignores non-matching files such as `global_domination.sqlite`, `app_v3_corrupt_*.sqlite`, `*.sqlite-wal`, and `*.sqlite-shm`.

4. **Given** `Restore Latest Backup` is selected
   **When** restore runs
   **Then** the corrupt live database file is renamed to `app_v{currentSchemaVersion}_corrupt_{timestamp}.sqlite`, any live `global_domination.sqlite-wal` and `global_domination.sqlite-shm` sidecars are quarantined with the same timestamped stem, the selected backup is copied to `global_domination.sqlite`, stale live sidecars are not left beside the restored database, and `databaseBootstrapProvider` is invalidated so boot retries.

5. **Given** no schema backup exists
   **When** the recovery screen renders
   **Then** `Restore Latest Backup` is hidden or disabled, `Start Fresh` remains available, and `Contact Support` remains available.

6. **Given** the player chooses `Start Fresh`
   **When** the first confirmation is accepted
   **Then** no file operation has happened yet and a second, final confirmation is required.

7. **Given** the second `Start Fresh` confirmation is accepted
   **When** the action runs
   **Then** the corrupt live database and any live WAL/SHM sidecars are renamed with the same `app_v{currentSchemaVersion}_corrupt_{timestamp}` stem, no schema backup is deleted, no old save rows are migrated, and `databaseBootstrapProvider` is invalidated so Drift creates a fresh database from the normal first-launch path.

8. **Given** `Contact Support` is selected
   **When** the clipboard operation completes
   **Then** the clipboard contains a support-ready plaintext diagnostic payload including the user-visible error, stack trace when available, SQLite result code details when available, current app schema version, and discovered backup filenames/versions; the UI shows a short confirmation SnackBar.

9. **Given** the boot error is a `MigrationFailureException`
   **When** the recovery screen renders after this story
   **Then** the Story 6.3 exact-backup restore path remains intact, but `Start Fresh` and `Contact Support` use the same completed flows as corruption recovery.

10. **Given** the boot error is not recognized as a migration failure or SQLite corruption
    **When** the recovery screen renders
    **Then** destructive file actions are not offered; the user can still use `Contact Support` to copy diagnostics.

11. **Given** all recovery UI is rendered on a narrow mobile viewport
    **When** text scale is elevated and long exception messages are present
    **Then** buttons and diagnostic text do not overflow, all destructive actions have accessible semantic labels, and the screen remains usable without app shell navigation.

## Tasks / Subtasks

- [ ] Task 1: Add an explicit database corruption exception and classifier (AC: #1, #10)
  - [ ] 1.1 Create `lib/data/database/migrations/database_corruption_exception.dart` or an equivalent adjacent recovery file near the existing 6.3 recovery helpers.
  - [ ] 1.2 Define an immutable `DatabaseCorruptionException implements Exception` with fields:
    - `Object cause`
    - `StackTrace? originalStackTrace`
    - `int? sqliteResultCode`
    - `int? sqliteExtendedResultCode`
    - `String? sqliteOperation`
  - [ ] 1.3 Add a classifier helper, for example:
    ```dart
    static DatabaseCorruptionException? tryFrom(Object error, StackTrace stack)
    ```
    It must recognize direct `SqliteException`, `DriftWrappedException(cause: SqliteException)`, and, if reachable from the current Drift API, `DriftRemoteException(remoteCause: SqliteException)`.
  - [ ] 1.4 Treat only SQLite primary result codes `SqlError.SQLITE_CORRUPT` and `SqlError.SQLITE_NOTADB` as corruption for this story. Do not classify `SQLITE_BUSY`, `SQLITE_LOCKED`, `SQLITE_CANTOPEN`, permission errors, or generic exceptions as corruption.
  - [ ] 1.5 Use the existing project precedent for `package:sqlite3/sqlite3.dart` imports. If importing sqlite3 from a file that does not have a direct dependency lint exemption, add the same narrow `// ignore: depend_on_referenced_packages` comment used by `app_database.dart`; do not change `pubspec.yaml`.

- [ ] Task 2: Wire corruption classification into database bootstrap (AC: #1, #10)
  - [ ] 2.1 Modify `databaseBootstrapProvider` in `lib/providers/data_providers.dart`.
  - [ ] 2.2 Preserve the existing first catch for `MigrationFailureException`.
  - [ ] 2.3 In the generic `catch (e, s)`, call `DatabaseCorruptionException.tryFrom(e, s)`.
  - [ ] 2.4 If it returns non-null, report that wrapped exception through `CrashReporter.instance.reportZonedError(corruption, s)`, close the failed DB handle via the existing `closeDb()` path, and rethrow it with `Error.throwWithStackTrace(corruption, s)`.
  - [ ] 2.5 If it returns null, preserve current behavior: close the failed handle and rethrow the original error.
  - [ ] 2.6 Do not make `appDatabaseProvider` nullable and do not let UI code read Drift directly.

- [ ] Task 3: Extend recovery actions for latest backup, sidecars, and start fresh (AC: #3, #4, #5, #7)
  - [ ] 3.1 Extend `SaveRecoveryActions` rather than creating a parallel recovery helper.
  - [ ] 3.2 Add a small immutable backup descriptor, for example:
    ```dart
    class SchemaBackup {
      const SchemaBackup({
        required this.version,
        required this.file,
        required this.modifiedAt,
      });

      final int version;
      final File file;
      final DateTime modifiedAt;
    }
    ```
  - [ ] 3.3 Add `latestBackup()` that scans `getApplicationDocumentsDirectory()`, filters exact filenames matching `^schema_backup_v(\d+)\.sqlite$`, parses the version, and returns the most recently modified backup. If modification times tie, use the higher version as the deterministic tie-break.
  - [ ] 3.4 Add `restoreLatestBackup({required int currentSchemaVersion, DateTime Function()? now})` that delegates to a lower-level restore helper using the selected `SchemaBackup`.
  - [ ] 3.5 Update existing `restoreFromBackup({fromVersion, toVersion})` so migration-failure restore also quarantines live WAL/SHM sidecars before copying the backup. Preserve its existing public signature and tests.
  - [ ] 3.6 Add `startFresh({required int currentSchemaVersion, DateTime Function()? now})`.
  - [ ] 3.7 Implement one shared private quarantine helper that:
    - uses one UTC timestamp for the main database and sidecars;
    - renames `global_domination.sqlite` to `app_v{currentSchemaVersion}_corrupt_{timestamp}.sqlite` when it exists;
    - renames `global_domination.sqlite-wal` and `global_domination.sqlite-shm` to the same stem plus `-wal` / `-shm` when they exist;
    - succeeds when the live DB file is already missing;
    - never touches `schema_backup_v*.sqlite`.
  - [ ] 3.8 Keep `DateTime.now()` out of `lib/game/`; using an injectable clock in this data-layer helper is for deterministic tests, not a game-layer rule.

- [ ] Task 4: Update `SaveRecoveryScreen` UI and behavior (AC: #2, #5, #6, #7, #8, #9, #10, #11)
  - [ ] 4.1 Rename the visible title from `Database Recovery` to `Save Recovery`.
  - [ ] 4.2 Replace `Copy Crash Log` with `Contact Support`. The button still copies diagnostics to the clipboard; there is no network or email integration in v1.
  - [ ] 4.3 For `DatabaseCorruptionException`, check `SaveRecoveryActions.latestBackup()` and show `Restore Latest Backup` only when a descriptor is present. Include the version in a tooltip/semantics label or visible secondary text; avoid a long button label that can overflow.
  - [ ] 4.4 For `MigrationFailureException`, preserve the exact `schema_backup_v{fromVersion}.sqlite` check and button behavior from Story 6.3.
  - [ ] 4.5 For `DatabaseCorruptionException` and `MigrationFailureException`, make `Start Fresh` real. It must show two sequential `AlertDialog`s or equivalent confirmations before file operations run.
  - [ ] 4.6 The first confirmation explains that the existing save will be quarantined and the game will start from a fresh save. The second confirmation must be the final destructive action. Both dialogs should use `barrierDismissible: false`.
  - [ ] 4.7 After restore or start fresh completes, call `ref.invalidate(databaseBootstrapProvider)`.
  - [ ] 4.8 For unrecognized boot errors, hide destructive file actions and show only diagnostics/support copy.
  - [ ] 4.9 Keep test seams. Add optional callbacks for `latestBackup`, `restoreLatestBackup`, and `startFresh` so widget tests do not touch real app documents.
  - [ ] 4.10 Wrap the screen body in scrollable/constrained layout so long errors, large text scale, and narrow widths do not overflow.
  - [ ] 4.11 Add `Semantics` labels for restore, start fresh, both confirmation buttons, and contact support.

- [ ] Task 5: Improve support diagnostics payload (AC: #8)
  - [ ] 5.1 Build the clipboard payload in one helper on `SaveRecoveryScreen`.
  - [ ] 5.2 Include:
    - current local timestamp in UTC;
    - error runtime type and `toString()`;
    - stack trace or original stack trace when available;
    - SQLite primary and extended result codes when the error is `DatabaseCorruptionException`;
    - migration from/to versions when the error is `MigrationFailureException`;
    - current app schema version;
    - discovered backup filenames and parsed versions when available.
  - [ ] 5.3 Do not try to read `crash_logs` through `CrashLogRepository` while the database cannot open. The corrupt database is the problem; use the in-memory boot error details.
  - [ ] 5.4 Continue to use `Clipboard.setData(ClipboardData(text: payload))` and show `Diagnostics copied` on success. Show a non-crashing `Copy failed` SnackBar on clipboard failure.

- [ ] Task 6: Add focused data/provider tests (AC: #1, #3, #4, #5, #7, #10)
  - [ ] 6.1 Extend `test/providers/database_bootstrap_provider_test.dart`:
    - `SqliteException(SQLITE_CORRUPT)` is wrapped as `DatabaseCorruptionException`;
    - `SqliteException(SQLITE_NOTADB)` is wrapped as `DatabaseCorruptionException`;
    - `SqliteException(SQLITE_BUSY)` is not wrapped as corruption;
    - failed DB handles are closed before the error is surfaced.
  - [ ] 6.2 Add or extend tests for the classifier to cover `DriftWrappedException(cause: SqliteException(...))` if using that branch.
  - [ ] 6.3 Extend `test/data/database/migrations/save_recovery_actions_test.dart`:
    - `latestBackup()` returns null with no backups;
    - ignores non-matching filenames;
    - picks most recent backup by mtime and higher version on ties;
    - `restoreLatestBackup` quarantines main DB and sidecars, copies backup into live path, and keeps the backup file;
    - `startFresh` quarantines main DB and sidecars, leaves backups untouched, and leaves no live DB file until bootstrap recreates it;
    - live-missing paths do not throw.
  - [ ] 6.4 Use `PathProviderPlatform.instance = _FakePathProvider(tempDir)` as current recovery-action tests do. Restore the platform in teardown and delete temp dirs recursively.

- [ ] Task 7: Add recovery screen widget tests (AC: #2, #5, #6, #7, #8, #9, #10, #11)
  - [ ] 7.1 Extend `test/ui/save_recovery_screen_test.dart`.
  - [ ] 7.2 Cover corruption with latest backup: shows `Save Recovery`, `Restore Latest Backup`, `Start Fresh`, and `Contact Support`.
  - [ ] 7.3 Cover corruption with no backup: hides restore and keeps start fresh/support.
  - [ ] 7.4 Cover restore tap calls the injected latest-backup restore action and invalidates/retries through existing provider behavior where practical.
  - [ ] 7.5 Cover Start Fresh does not call the action after the first confirmation only.
  - [ ] 7.6 Cover Start Fresh calls the injected action only after the second confirmation.
  - [ ] 7.7 Cover Contact Support copies diagnostics including result codes and backup metadata.
  - [ ] 7.8 Cover `MigrationFailureException` still shows exact-version restore from 6.3 and now uses real Start Fresh.
  - [ ] 7.9 Cover an unrecognized `Exception('boot failure')` shows Contact Support but no destructive restore/start-fresh actions.
  - [ ] 7.10 Add a narrow-width/text-scale smoke test and assert `tester.takeException()` is null after pump.

- [ ] Task 8: Verification (AC: all)
  - [ ] 8.1 Run `dart format --set-exit-if-changed` on every changed Dart file.
  - [ ] 8.2 Run:
    - `flutter test test/providers/database_bootstrap_provider_test.dart`
    - `flutter test test/data/database/migrations/save_recovery_actions_test.dart`
    - `flutter test test/ui/save_recovery_screen_test.dart`
  - [ ] 8.3 Run `flutter analyze`.
  - [ ] 8.4 Run full `flutter test` if time permits because this touches boot and recovery code.

## Dev Notes

### Implementation Scope

This story completes the user-facing save recovery path for corrupt database files. It does not add schema, migrations, offline earnings, modal queues, or game-state mutation. Recovery happens before the real game shell boots.

The intended flow is:

```dart
databaseBootstrapProvider
  -> force Drift open with SELECT 1
  -> MigrationFailureException: existing 6.3 recovery
  -> SqliteException(SQLITE_CORRUPT / SQLITE_NOTADB): DatabaseCorruptionException
  -> SaveRecoveryScreen
  -> restore latest backup OR double-confirm start fresh OR copy diagnostics
  -> invalidate databaseBootstrapProvider
```

### Current Codebase Observations

- `SaveRecoveryScreen` currently has the visual shell, exact migration-backup restore, a `Start Fresh available in Story 6-6` placeholder, and a `Copy Crash Log` clipboard action.
- `SaveRecoveryActions.restoreFromBackup` currently renames only `global_domination.sqlite`; this story must also handle `global_domination.sqlite-wal` and `global_domination.sqlite-shm`.
- `databaseBootstrapProvider` already closes failed DB handles before surfacing failures. Preserve that property; recovery file operations must not fight an open SQLite handle.
- `AppDatabase.schemaVersion` currently returns `3`. Prefer adding a static constant, e.g. `static const currentSchemaVersion = 3; @override int get schemaVersion => currentSchemaVersion;`, so recovery actions do not duplicate the schema version.
- `CrashReporter` cannot persist to `crash_logs` when the database cannot open. `Contact Support` must copy an in-memory diagnostic payload instead.

### Architecture Compliance

- No Flutter imports under `lib/game/**`.
- No Drift or file IO from UI; UI calls provider/data-layer helpers via injected callbacks.
- No raw SQL beyond the existing bootstrap `customSelect('SELECT 1')`.
- No schema bump and no new migration file.
- No new package in `pubspec.yaml`.
- Do not delete or prune schema backups in recovery actions.
- Do not load `ContentRegistry` or create `GameState` directly from recovery UI. Fresh DB creation happens by invalidating bootstrap and letting the normal first-launch path run.
- Use `Logger`/`CrashReporter`; no `print()`.

### Library / Framework Requirements

- `sqlite3` exposes `SqliteException.resultCode` and `extendedResultCode`; use result codes rather than string matching.
- SQLite primary result codes for this story are `SQLITE_CORRUPT` and `SQLITE_NOTADB`.
- Drift may wrap sqlite errors with additional context. Handle `DriftWrappedException` and, if needed by the current background-isolate path, `DriftRemoteException`.
- Flutter `showDialog` defaults to dismissible barriers; destructive confirmations must pass `barrierDismissible: false`.
- `AlertDialog` can overflow when content is too large unless content is scrollable/constrained. Keep confirmation content short and scrollable.
- `Clipboard.setData` is asynchronous; await it and handle failure.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/data/database/migrations/database_corruption_exception.dart` | Corruption exception + SQLite/Drift classifier |
| `test/data/database/migrations/database_corruption_exception_test.dart` | Optional focused classifier tests if not fully covered in provider tests |

**Modify:**

| File | Change |
|---|---|
| `lib/data/database/app_database.dart` | Add static `currentSchemaVersion` constant if useful |
| `lib/providers/data_providers.dart` | Wrap corrupt SQLite boot failures as `DatabaseCorruptionException` |
| `lib/data/database/migrations/save_recovery_actions.dart` | Latest backup scan, sidecar quarantine, restore latest, start fresh |
| `lib/ui/save_recovery_screen.dart` | Full corruption UI, double-confirm Start Fresh, Contact Support diagnostics |
| `test/providers/database_bootstrap_provider_test.dart` | Corruption wrapping and non-corruption pass-through tests |
| `test/data/database/migrations/save_recovery_actions_test.dart` | Backup scan, sidecar quarantine, restore/start-fresh tests |
| `test/ui/save_recovery_screen_test.dart` | Full recovery UX behavior and accessibility coverage |

**Do NOT modify:**

- `lib/game/**`
- `lib/data/database/tables/**`
- `lib/data/mappers/**`
- `lib/data/repositories/save_repository.dart`
- `lib/services/game_lifecycle_observer.dart`
- `assets/**`
- `pubspec.yaml`

### Previous Story Intelligence

- **Story 6.3 (done in current branch):** Introduced `MigrationFailureException`, `databaseBootstrapProvider`, `SaveRecoveryScreen`, `SaveRecoveryActions.restoreFromBackup`, and `BackupRetentionPolicy`. 6.6 must preserve migration failure behavior and finish the deferred `Start Fresh` flow.
- **Story 6.3 review patch:** Closed failed bootstrap DB handles before restore so file rename/copy can succeed on Windows. Keep this invariant and test it for corruption too.
- **Story 1.10 (done):** `SupportScreen` and `CrashReporter` use clipboard diagnostics and a local crash-log ring buffer. During DB corruption, the ring buffer may be unreadable, so recovery diagnostics must be built from the boot error in memory.
- **Story 6.1 (done):** Fresh empty DB plus no `meta` row maps to `GameState.initialSeed(content)`. Start Fresh should rely on that normal first-launch path instead of seeding rows itself.
- **Story 6.2 (done):** First later `SaveRepository` meta snapshot inserts the singleton `meta` row. Do not write meta rows from recovery actions.
- **Stories 6.4 and 6.5:** Offline catch-up and reward modal are unrelated to corrupt-DB recovery. Do not compute offline earnings or show offline reward UI during Save Recovery.

### Latest Technical Notes

- Local `pubspec.yaml` keeps `drift: ^2.26.1`; current `pubspec.lock` resolves Drift to `2.32.1`. Do not change dependency constraints for this story.
- Current sqlite3 API docs expose `SqliteException.resultCode`, `extendedResultCode`, `message`, and `operation`.
- SQLite documents `SQLITE_CORRUPT` as malformed database image and `SQLITE_NOTADB` as file opened that is not a database. Those are the only automatic corrupt-save recovery triggers here.
- Flutter dialog and clipboard APIs are sufficient; no native plugin, mail client integration, or support SDK belongs in v1.

### Testing Requirements

- Provider tests use `ProviderContainer` overrides and fake `AppDatabase` classes as current bootstrap tests do.
- Filesystem tests use `Directory.systemTemp.createTempSync()` and `PathProviderPlatform` override; restore the platform instance in teardown.
- Widget tests use `flutter_test`, `ProviderScope`, and injected recovery callbacks. They must not touch real app documents.
- Clipboard tests use `SystemChannels.platform` mock handlers as current support/recovery tests do.
- No test should require an actual corrupt SQLite file on disk. Unit-test the classifier with synthetic `SqliteException`s and test file operations separately.

## References

- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.6: Save Recovery Path on Corrupt Database] - original story and acceptance criteria.
- [Source: _bmad-output/implementation-artifacts/6-3-typed-migrations-and-schema-backup-v-n-sqlite.md] - existing recovery screen, migration failure, failed DB close, and restore foundation.
- [Source: _bmad-output/implementation-artifacts/1-10-crash-log-ring-buffer-and-support-screen.md] - support/clipboard diagnostic pattern and crash-log ring buffer constraints.
- [Source: _bmad-output/project-context.md#Drift] - typed Drift, schema backup before migration, no raw SQL, `meta.lastSavedAt`.
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] - backup ordering, no raw SQL, no `print()`, no Flutter in `lib/game/`.
- [Source: _bmad-output/game-architecture/architectural-decisions.md#4. Persistence - Drift 2.26] - recovery from `schema_backup` or Save Recovery screen.
- [Source: lib/providers/data_providers.dart] - `databaseBootstrapProvider` and failed DB close path to extend.
- [Source: lib/ui/save_recovery_screen.dart] - current screen with deferred Start Fresh placeholder.
- [Source: lib/data/database/migrations/save_recovery_actions.dart] - existing exact-backup restore helper.
- [Source: lib/data/database/app_database.dart] - current database filename, schema version, and `global_domination.sqlite` path.
- [Source: https://pub.dev/documentation/sqlite3/latest/sqlite3/SqliteException-class.html] - `SqliteException` fields for result code, extended result code, message, and operation.
- [Source: https://pub.dev/documentation/sqlite3/latest/sqlite3/SqlError-class.html] - `SQLITE_CORRUPT` and `SQLITE_NOTADB` constants.
- [Source: https://www.sqlite.org/rescode.html] - SQLite primary and extended result code semantics.
- [Source: https://api.flutter.dev/flutter/material/showDialog.html] - barrier behavior, root navigator, and dialog route behavior.
- [Source: https://api.flutter.dev/flutter/material/AlertDialog-class.html] - dialog overflow/scrolling caution and semantic label support.
- [Source: https://api.flutter.dev/flutter/services/Clipboard/setData.html] - clipboard write API.
- [Source: https://api.flutter.dev/flutter/widgets/Semantics-class.html] - accessibility annotations.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
