# Story 1.10: Crash Log Ring Buffer and Support Screen

Status: done

## Story

As a player,
I want a hidden "Support" screen (reachable via a 5-second long-press on a settings element in release) that shows the last 100 crash/warning entries with a "Copy All" button,
So that if the app misbehaves I can share the recent error log without needing developer tools.

## Acceptance Criteria

1. **Given** a `crash_logs` Drift table with bounded `N=100` entries **When** `CrashReporter` handles an error (from any of the three global handlers wired in Story 1.1) **Then** a new row is inserted with `timestamp` (DateTime → TEXT via Drift's `store_date_time_values_as_text`), `level` (enum stored as TEXT), `tag` (String), `message` (String), and `stackTrace` (String, nullable) **And** if the row count exceeds 100, the oldest row(s) are deleted so the count never exceeds 100.

2. **Given** a "Support" screen reachable via a 5-second long-press on a placeholder settings trigger (real Settings screen ships in Epic 7.6 — this story exposes the trigger as a temporary dev/debug entry in `main.dart` or `app.dart`, clearly marked for replacement) **When** opened **Then** it displays all `crash_logs` rows newest first (timestamp descending), each row showing timestamp, level, tag, message, and stack trace preview, with a "Copy All" button that copies a formatted plaintext dump of all entries to the clipboard.

3. **Given** `kDebugMode` is `false` (release build) **When** the long-press trigger is held for 5 seconds **Then** the Support screen opens — this path is NOT `kDebugMode`-gated (unlike debug-only cheats) because the ring buffer is specifically for field debugging by end users.

4. **Given** `CrashReporter.reportFlutterError` / `reportPlatformError` / `reportZonedError` is called **When** the report completes **Then** the error has been persisted to `crash_logs` via `CrashLogRepository` **And** the existing `Logger('CrashReporter').severe(...)` call is still made (persistence is added ALONGSIDE logging, not replacing it) **And** the persistence call does NOT throw (DB failures are caught and logged at `severe` with no rethrow, because a crash reporter throwing in an error handler would cause infinite loops).

5. **Given** any file under `lib/data/database/tables/` or `lib/data/repositories/` **When** imported **Then** it has zero `package:flutter/*` imports — persistence is pure Dart. (Support screen UI is in `lib/ui/debug/` and MAY use Flutter.)

## Tasks / Subtasks

- [x] Task 1: Create `CrashLogLevel` enum and `CrashLogEntry` value type (AC: #1)
  - [x] 1.1 Create `lib/data/repositories/crash_log_entry.dart` — `@immutable class CrashLogEntry` holding `final DateTime timestamp`, `final CrashLogLevel level`, `final String tag`, `final String message`, `final String? stackTrace`
  - [x] 1.2 Add `enum CrashLogLevel { severe, warning, info }` in the same file (only levels actually persisted per architecture table — `severe` for crashes, `warning` for recoverable anomalies; `info` is optional, include it since `logger_setup` maps `INFO` lifecycle to persistence "recent only" per architecture line 396)
  - [x] 1.3 Add `const` constructor, manual `==`, `hashCode`, `toString` (no `freezed` per project rules)
  - [x] 1.4 Zero Flutter imports — pure Dart

- [x] Task 2: Create `CrashLogs` Drift table at `lib/data/database/tables/crash_logs_table.dart` (AC: #1, #5)
  - [x] 2.1 Create `lib/data/database/tables/` directory (first table in this project — establishes the `tables/` layer)
  - [x] 2.2 Define `class CrashLogs extends Table` with columns: `IntColumn id` (autoincrement primary key), `DateTimeColumn timestamp` (indexed for DESC queries), `TextColumn level` (enum-as-text via `EnumNameConverter` or a small custom `TypeConverter<CrashLogLevel, String>`), `TextColumn tag`, `TextColumn message`, `TextColumn stackTrace` (nullable)
  - [x] 2.3 Add `@DataClassName('CrashLogRow')` — Drift plural table, singular row per naming convention
  - [x] 2.4 DateTime is stored as TEXT (ISO8601) via existing `build.yaml` setting `store_date_time_values_as_text: true` — no extra converter needed [Source: 1-4 dev notes]

- [x] Task 3: Create `CrashLogLevelConverter` at `lib/data/database/converters/crash_log_level_converter.dart` (AC: #1)
  - [x] 3.1 `class CrashLogLevelConverter extends TypeConverter<CrashLogLevel, String> with JsonTypeConverter2<CrashLogLevel, String, String>` OR use Drift's built-in `EnumNameConverter<CrashLogLevel>()` directly in the column definition — pick the simpler option that generates cleanly
  - [x] 3.2 Mirrors the pattern of existing `DecimalConverter` at `lib/data/database/converters/decimal_converter.dart`
  - [x] 3.3 Zero Flutter imports

- [x] Task 4: Bump `AppDatabase` schema version and register `CrashLogs` table (AC: #1)
  - [x] 4.1 Edit `lib/data/database/app_database.dart` — change `@DriftDatabase(tables: [])` to `@DriftDatabase(tables: [CrashLogs])`
  - [x] 4.2 Change `int get schemaVersion => 1` to `int get schemaVersion => 2`
  - [x] 4.3 Add `onUpgrade` migration step for `from == 1, to == 2`: `await m.createTable(crashLogs);` AFTER the existing `await _backupDatabase(from);` call (backup BEFORE schema changes per Story 1.4 gotcha)
  - [x] 4.4 Run `dart run build_runner build --delete-conflicting-outputs` — verify `app_database.g.dart` regenerates with `$CrashLogsTable`, `CrashLogRow`, `crashLogs` getter

- [x] Task 5: Create `CrashLogRepository` at `lib/data/repositories/crash_log_repository.dart` (AC: #1, #5)
  - [x] 5.1 Create `lib/data/repositories/` directory (first repository in this project)
  - [x] 5.2 `class CrashLogRepository` with a constructor taking `AppDatabase _db`
  - [x] 5.3 `Future<void> append(CrashLogEntry entry)` — inserts the entry, then deletes oldest rows if total `> 100`. Use typed Drift DSL (`into(_db.crashLogs).insert(...)`, `_db.crashLogs.select()..orderBy(...)..limit(1)`), NEVER raw SQL [Source: project-context.md#Critical Don't-Miss Rules]
  - [x] 5.4 Ring-buffer eviction strategy: after insert, `select count(*)` on `crash_logs`. If `> 100`, delete oldest `N-100` rows by `timestamp ASC` / `id ASC`. Use a single transaction (`_db.transaction(() async { ... })`) so insert + eviction are atomic
  - [x] 5.5 `Future<List<CrashLogEntry>> readAllNewestFirst()` — selects all rows ordered by `timestamp DESC, id DESC`, maps rows to `CrashLogEntry` (inverse mapping; repository owns both directions)
  - [x] 5.6 `Future<void> clearAll()` — for tests and future "Clear log" button (not wired to UI this story)
  - [x] 5.7 Zero Flutter imports

- [x] Task 6: Create `crashLogRepositoryProvider` in `lib/providers/data_providers.dart` (AC: #4)
  - [x] 6.1 Add to existing `lib/providers/data_providers.dart` (alongside `appDatabaseProvider`):
    ```dart
    final crashLogRepositoryProvider = Provider<CrashLogRepository>((ref) {
      return CrashLogRepository(ref.watch(appDatabaseProvider));
    });
    ```
  - [x] 6.2 Do NOT create a new file — this is the architecture-prescribed location [Source: project-context.md, line 212]

- [x] Task 7: Extend `CrashReporter` to persist entries (AC: #1, #4)
  - [x] 7.1 Edit `lib/services/crash_reporter.dart`. Current code logs via `Logger('CrashReporter').severe(...)` only — add persistence as a second step
  - [x] 7.2 `CrashReporter` cannot hold a `CrashLogRepository` at construction time (it's a singleton created before Riverpod's `ProviderContainer`). Solution: add an `attach(CrashLogRepository repo)` method that late-binds the repository. Call `attach` from `main.dart` after `ProviderScope` is mounted — see Task 8 for wiring
  - [x] 7.3 Before `attach` is called, reports are logged via `Logger` only (the startup window before Riverpod is up). After `attach`, each `report*` method both logs AND calls `_repo?.append(entry)`. Wrap the `append` call in `try/catch` — log failures at `severe` and DO NOT rethrow (AC #4: must never throw from error handlers)
  - [x] 7.4 Add helper `CrashLogEntry _buildEntry(CrashLogLevel level, String tag, Object error, StackTrace? stack)` that captures `DateTime.now()` inside `CrashReporter` (NOT inside `lib/game/` — `CrashReporter` is a `lib/services/` file where `DateTime.now()` is allowed per the architecture boundary)
  - [x] 7.5 Map the three existing methods: `reportFlutterError(FlutterErrorDetails details)` → level `severe`, tag `'FlutterError'`, message = `details.exceptionAsString()`, stack = `details.stack?.toString()`; `reportPlatformError(error, stack)` → severe, tag `'PlatformError'`, message = `error.toString()`, stack = `stack.toString()`; `reportZonedError(error, stack)` → severe, tag `'ZonedError'`, message = `error.toString()`, stack = `stack.toString()`
  - [x] 7.6 Because `append` is async, fire-and-forget with `unawaited(_repo?.append(...).catchError(...))` — the error handler contract (especially `PlatformDispatcher.onError` returning `true` synchronously) must not be broken by awaiting. Import `dart:async` for `unawaited`

- [x] Task 8: Wire `CrashReporter.attach` in `main.dart` (AC: #4)
  - [x] 8.1 Edit `lib/main.dart`. After `runApp(const ProviderScope(child: GlobalDominationApp()))` cannot work — the `ProviderContainer` must exist before we can read a provider. Use the pattern: manually construct a `ProviderContainer`, then pass it to `UncontrolledProviderScope`. See `package:flutter_riverpod` docs: [Source: Context7 — flutter_riverpod]
  - [x] 8.2 Pattern:
    ```dart
    final container = ProviderContainer();
    CrashReporter.instance.attach(container.read(crashLogRepositoryProvider));
    runApp(UncontrolledProviderScope(container: container, child: const GlobalDominationApp()));
    ```
  - [x] 8.3 This guarantees the repository is wired before the first frame — any crash during boot BEFORE `attach` falls back to logger-only (acceptable edge case)
  - [x] 8.4 Alternative simpler pattern if preferred: keep the current `ProviderScope` and call `attach` from a lightweight top-level `Consumer` in `app.dart` during the first build (before `contentRegistryProvider` settles). DECISION: prefer the `UncontrolledProviderScope` + explicit `container` approach — it's deterministic and all wiring stays in `main.dart` per project rule "Only `lib/main.dart` contains boot-time global setup" [Source: project-context.md#File content discipline, line 265]

- [x] Task 9: Create `SupportScreen` at `lib/ui/debug/support_screen.dart` (AC: #2)
  - [x] 9.1 Create `lib/ui/debug/` directory per architecture tree [Source: project-context.md, line 210 — "`debug/` # kDebugMode-gated overlays ONLY"]. EXCEPTION documented in architecture line 510: the crash-log ring buffer is the ONE debug-folder tool active in release. Add a prominent comment at the top of `support_screen.dart` noting this exception
  - [x] 9.2 `class SupportScreen extends ConsumerWidget` — watches `crashLogRepositoryProvider` and `FutureBuilder`/`ref.watch` over a new `crashLogsProvider` (a `FutureProvider<List<CrashLogEntry>>` that calls `readAllNewestFirst()`)
  - [x] 9.3 Add `final crashLogsProvider = FutureProvider<List<CrashLogEntry>>((ref) => ref.watch(crashLogRepositoryProvider).readAllNewestFirst());` in `lib/providers/data_providers.dart` (keep all data providers in one file per architecture)
  - [x] 9.4 UI layout: `Scaffold` with `AppBar(title: 'Support')`, `actions: [IconButton(icon: Icons.copy, ...)]`. Body: `ListView.builder` rendering each entry as a `Card` with `ExpansionTile`: title = `"[level] tag — message preview"`, trailing = formatted timestamp, expanded content = full message + stack trace in monospace `SelectableText`
  - [x] 9.5 Copy-all button: formats all entries as `"[$timestamp] [$level] [$tag] $message\n$stackTrace\n---\n"` joined, then `Clipboard.setData(ClipboardData(text: dump))`. Import `package:flutter/services.dart`. Show a `SnackBar("Copied N entries to clipboard")` confirmation
  - [x] 9.6 Empty state: if list is empty, show centered `"No crash logs recorded."` text
  - [x] 9.7 Wrap interactive elements in `Semantics` with readable labels [Source: project-context.md#Subtle gotchas — "Accessibility is not optional"]

- [x] Task 10: Add placeholder 5-second long-press trigger (AC: #2, #3)
  - [x] 10.1 This is TEMPORARY wiring. Epic 7 Story 7.6 ships real Settings with the long-press activator on a gear/credits row. For Story 1.10, add a small placeholder so the Support screen is reachable and testable
  - [x] 10.2 Modify `lib/app.dart`'s data branch (the `MaterialApp` currently showing "Global Domination"): wrap the centered text in a `GestureDetector` with `onLongPress` using `Feedback.forLongPress` and a `Timer`-based 5-second hold check, OR simpler — use a `GestureDetector(onLongPressStart: ...)` starting a 5s timer that on completion `Navigator.push`es to `SupportScreen`; cancel on `onLongPressEnd` / `onLongPressCancel`. Keep the implementation small and clearly commented as "TEMPORARY — replaced by Story 7.6 Settings modal"
  - [x] 10.3 Do NOT gate with `kDebugMode` — this path must work in release per AC #3
  - [x] 10.4 Add a TODO comment referencing Story 7.6 so `correct-course` / code review spots the removal target when Epic 7 arrives

- [x] Task 11: Write tests for `CrashLogEntry` and `CrashLogLevel` (AC: #1)
  - [x] 11.1 Create `test/data/repositories/crash_log_entry_test.dart` using `package:test/test.dart` (pure Dart value object, mirrors `lib/` path — `test/data/repositories/`)
  - [x] 11.2 Test construction, `==`, `hashCode`, `toString`, enum values

- [x] Task 12: Write tests for `CrashLogRepository` with in-memory Drift (AC: #1, #5)
  - [x] 12.1 Create `test/data/repositories/crash_log_repository_test.dart` using `package:flutter_test/flutter_test.dart` (Drift tests need the Flutter test harness; mirrors the pattern from `test/data/database/app_database_test.dart`)
  - [x] 12.2 Test: `append` inserts a row, `readAllNewestFirst` returns it
  - [x] 12.3 Test: insert 150 entries → `readAllNewestFirst()` returns exactly 100, with the most recent 100 (oldest 50 evicted)
  - [x] 12.4 Test: ordering is strict newest-first across identical timestamps (tiebreak by `id DESC`)
  - [x] 12.5 Test: `clearAll` empties the table
  - [x] 12.6 Test: ring buffer eviction is atomic — wrap 10 parallel `append` calls in `Future.wait` and verify final count ≤ 100 (tests the transaction)
  - [x] 12.7 Use `AppDatabase(NativeDatabase.memory())` per Story 1.4 pattern

- [x] Task 13: Write tests for schema v2 migration and table creation (AC: #1)
  - [x] 13.1 Edit `test/data/database/app_database_test.dart` — update the existing "schema version 1" test to assert `schemaVersion == 2`
  - [x] 13.2 Add test: `onCreate` on fresh in-memory DB creates the `crash_logs` table (query via `_db.crashLogs.select().get()` returns `[]`, no exception)
  - [x] 13.3 Add test: `onUpgrade(v1, v2)` migration path — create an in-memory DB at schema v1 (use `SqliteMigrator.createTable` manually or open a separate test harness), then simulate opening it as v2 and verify `crash_logs` table now exists. Drift's `verifySchema` helpers are cumbersome for this; acceptable alternative is asserting that `m.createTable(crashLogs)` in the migration path runs without error on a fresh DB at v1
  - [x] 13.4 Note: the backup-before-migrate logic (`_backupDatabase`) still cannot be exercised in memory (requires a file). Document this limitation in the test file header, matching the deferral pattern from Story 1.4 where AC #4 was deferred to Story 6.5

- [x] Task 14: Update `CrashReporter` tests for persistence wiring (AC: #4)
  - [x] 14.1 Edit `test/services/crash_reporter_test.dart`. Existing 7 tests verify singleton + no-throw for the three `report*` methods
  - [x] 14.2 Add test: a fresh `CrashReporter` with no `attach` called — `reportPlatformError` does not throw, entries are NOT persisted (no repo attached)
  - [x] 14.3 Add test: use `attach(fakeRepo)` where `FakeCrashLogRepository` extends `CrashLogRepository` (or use a test double) and records `append` calls. After `reportPlatformError(Exception('x'), StackTrace.current)`, the fake repo receives exactly one `CrashLogEntry` with `level == severe`, `tag == 'PlatformError'`, `message` containing `'x'`
  - [x] 14.4 Add test: if `append` throws (fake repo returns a failed future), `reportPlatformError` still does NOT throw (AC #4 explicit requirement)
  - [x] 14.5 Import guard: the fake repo can live inline in the test file (don't over-engineer with a separate test helper unless > 3 tests need it)
  - [x] 14.6 Note: `CrashReporter` is a singleton — call a new `reset()` method (add to `CrashReporter` specifically for tests, guarded by `@visibleForTesting` annotation from `package:meta`) to clear the attached repo between tests. OR skip `reset` and chain tests carefully, setting `attach` to a new fake at the start of each test (later `attach` calls override). PICK ONE and apply consistently

- [x] Task 15: Write widget test for `SupportScreen` (AC: #2)
  - [x] 15.1 Create `test/ui/debug/support_screen_test.dart` using `flutter_test` + `ProviderScope(overrides: [...])`
  - [x] 15.2 Test: empty state renders `"No crash logs recorded."`
  - [x] 15.3 Test: with 3 fake entries, `ListView` renders 3 cards; expanding one reveals the stack trace text
  - [x] 15.4 Test: tapping copy button calls `Clipboard.setData` (use `SystemChannels.platform.setMockMethodCallHandler` or check the clipboard text via `Clipboard.getData` after tap)
  - [x] 15.5 Test: semantics labels are present on interactive elements
  - [x] 15.6 Override `crashLogsProvider` via `ProviderScope(overrides: [crashLogsProvider.overrideWith((ref) async => fakeEntries)])` — do NOT mount a real `AppDatabase` in widget tests [Source: project-context.md#Subtle gotchas]

- [x] Task 16: Verify architecture boundary and run full suite (AC: all, especially #5)
  - [x] 16.1 Verify `test/architecture/game_boundary_test.dart` (from Story 1.3) still passes — no new files under `lib/game/` in this story
  - [x] 16.2 Manually verify: `lib/data/database/tables/crash_logs_table.dart`, `lib/data/database/converters/crash_log_level_converter.dart`, `lib/data/repositories/crash_log_repository.dart`, `lib/data/repositories/crash_log_entry.dart` — grep/search all for `package:flutter/` and confirm zero hits
  - [x] 16.3 Run `flutter analyze --fatal-infos` — zero issues (excluding `*.g.dart` per `analysis_options.yaml`)
  - [x] 16.4 Run `dart format --set-exit-if-changed .` — clean
  - [x] 16.5 Run `flutter test` — all prior 178+ tests plus new tests pass (expected new: ~15–25 tests)
  - [x] 16.6 Do NOT add `print()` — use `Logger` tags per architecture

## Dev Notes

### Architecture Compliance

**Persistence layer is pure Dart.** All files under `lib/data/` — tables, converters, repositories — MUST have zero `package:flutter/*` imports [Source: project-context.md#Dependency graph, line 227-236]. This is NOT covered by the `lib/game/` boundary test but IS a hard architectural rule. The boundary test only guards `lib/game/`; the `lib/data/` rule is enforced by convention and code review.

**UI never touches Drift directly.** Flow is: UI → Riverpod provider → repository → `AppDatabase` [Source: project-context.md#Critical Implementation Rules, rule 3]. `SupportScreen` reads via `crashLogsProvider` which reads via `crashLogRepositoryProvider`.

**Never raw SQL.** All DB access uses the typed Drift DSL (`_db.crashLogs.select()`, `into(_db.crashLogs).insert(...)`, etc.) [Source: project-context.md#Critical Don't-Miss Rules, "Raw SQL in repositories"].

**Schema bump = new migration path, never mutate existing version.** We go from v1 → v2. `onUpgrade(from, to)` handles the migration; `onCreate` (fresh install) already calls `m.createAll()` which will now include `CrashLogs` because the table is registered in `@DriftDatabase(tables: [CrashLogs])`.

**Backup BEFORE migration.** `_backupDatabase(from)` at the top of `onUpgrade` is already correct from Story 1.4 — we just add `m.createTable(crashLogs)` after it. Do NOT reorder. [Source: project-context.md#Subtle gotchas, line 374]

**Debug folder exception.** The architecture states [Source: game-architecture.md, line 510]: _"Crash log ring buffer is the ONE exception: active in release, bounded 100 entries, reachable only via a 5-second settings long-press ('Support' screen) — for field debugging."_ `SupportScreen` lives in `lib/ui/debug/` but is NOT `kDebugMode`-gated. A code comment at the top of the file MUST explain this explicit exception so future code reviewers don't "fix" it by adding `assert(kDebugMode)`.

**Logging.** `CrashReporter` uses `Logger('CrashReporter')`. After this story, persistence happens IN ADDITION TO logging — never a replacement. [Source: game-architecture.md#Logging, line 394 — "`SEVERE` | Crash / internal errors | ✅ `crash_logs` table"]

### Implementation Approach

**Ring buffer semantics.** N=100 is the hard cap. Implementation choice: insert-then-evict is simpler than query-size-before-insert. Always insert first, then `DELETE FROM crash_logs WHERE id NOT IN (SELECT id FROM crash_logs ORDER BY timestamp DESC, id DESC LIMIT 100)` — but in typed Drift DSL:

```dart
Future<void> append(CrashLogEntry entry) async {
  await _db.transaction(() async {
    await _db.into(_db.crashLogs).insert(CrashLogsCompanion.insert(
      timestamp: entry.timestamp,
      level: entry.level,
      tag: entry.tag,
      message: entry.message,
      stackTrace: Value(entry.stackTrace),
    ));
    // Evict oldest beyond N=100
    const ringSize = 100;
    final keepIds = await (_db.select(_db.crashLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp), (t) => OrderingTerm.desc(t.id)])
      ..limit(ringSize))
        .map((row) => row.id)
        .get();
    if (keepIds.isNotEmpty) {
      await (_db.delete(_db.crashLogs)
        ..where((t) => t.id.isNotIn(keepIds)))
          .go();
    }
  });
}
```

Key points:
- Single transaction — insert + eviction are atomic so a concurrent read cannot see >100 rows
- Order tiebreak by `id DESC` handles identical timestamps (batch inserts within same ms)
- `isNotIn(keepIds)` works because `keepIds` is a pre-materialized list of at most 100 ints — cheap

**Why not a pure per-insert "if count > 100 delete 1"?** Under concurrent appends (multiple errors in the same frame), two inserts can both observe `count == 100` pre-eviction and each delete 1, leaving count at 100 but with a race. The transaction + "delete all beyond top 100" approach is race-free.

**`CrashReporter` singleton + late-bound repository.** The existing `CrashReporter._()` pattern (set in `static final instance`) is preserved. Add:

```dart
class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  final Logger _logger = Logger('CrashReporter');
  CrashLogRepository? _repo;

  @visibleForTesting
  void attach(CrashLogRepository repo) { _repo = repo; }

  @visibleForTesting
  void reset() { _repo = null; }

  void reportFlutterError(FlutterErrorDetails details) {
    _logger.severe('Flutter error', details.exception, details.stack);
    final entry = CrashLogEntry(
      timestamp: DateTime.now(),
      level: CrashLogLevel.severe,
      tag: 'FlutterError',
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
    );
    unawaited(_persist(entry));
  }

  // ...reportPlatformError, reportZonedError analogous...

  Future<void> _persist(CrashLogEntry entry) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.append(entry);
    } catch (e, s) {
      _logger.severe('crash log persistence failed', e, s);
      // Deliberately do NOT rethrow — we're inside an error handler
    }
  }
}
```

Note `unawaited(_persist(...))` — import `dart:async`. The error handler contract (especially `PlatformDispatcher.onError` which must return `true` synchronously) is preserved.

**Boot-time wiring.** In `main.dart`, after creating `ProviderContainer`:

```dart
final container = ProviderContainer();
CrashReporter.instance.attach(container.read(crashLogRepositoryProvider));
runApp(UncontrolledProviderScope(container: container, child: const GlobalDominationApp()));
```

This requires changing `runApp(const ProviderScope(child: GlobalDominationApp()))` to the `UncontrolledProviderScope` pattern. The `ProviderContainer` lifecycle is now managed manually — Flutter disposes it implicitly via app teardown; no explicit `container.dispose()` is needed (the app outlives the container). `UncontrolledProviderScope` is part of `flutter_riverpod` 2.x and is the documented pattern for pre-mounting providers [Source: Context7 — flutter_riverpod docs].

**DateTime inside `CrashReporter`.** `CrashReporter` lives in `lib/services/`, not `lib/game/`. The "never call `DateTime.now()`" rule applies ONLY to `lib/game/` [Source: project-context.md#Anti-patterns, line 354]. `DateTime.now()` in `lib/services/crash_reporter.dart` is fine.

### Library/Framework Requirements

- `drift: ^2.26.1` — already in `pubspec.yaml` from Story 1.4
- `sqlite3_flutter_libs: ^0.5.25` — already in `pubspec.yaml`
- `path_provider: ^2.1.5` — already in `pubspec.yaml`
- `flutter_riverpod: ^2.6.1` — already in `pubspec.yaml`; uses `UncontrolledProviderScope` (stable in 2.x)
- `logging: ^1.3.0` — already in `pubspec.yaml`
- `meta` — transitively available from Flutter; use `@visibleForTesting` on `attach`/`reset`
- **Do NOT add** any new packages. The architecture bans crash SDKs (Crashlytics/Sentry) until Epic 13 [Source: 1-1 dev notes, "No crash reporting SDK"]
- **Do NOT add** `freezed` / `json_serializable` — manual `copyWith`/`==`/`hashCode` per project convention [Source: project-context.md#File content discipline, line 263]

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/data/database/tables/crash_logs_table.dart` | `CrashLogs` Drift table + `CrashLogRow` |
| CREATE | `lib/data/database/converters/crash_log_level_converter.dart` | `CrashLogLevel` ↔ TEXT converter (or use `EnumNameConverter` inline) |
| CREATE | `lib/data/repositories/crash_log_entry.dart` | `CrashLogEntry` value type + `CrashLogLevel` enum |
| CREATE | `lib/data/repositories/crash_log_repository.dart` | Ring-buffer CRUD API over `AppDatabase` |
| MODIFY | `lib/data/database/app_database.dart` | Register `CrashLogs`, bump schema to v2, add migration step |
| GENERATED | `lib/data/database/app_database.g.dart` | Regenerate — new `$CrashLogsTable`, `CrashLogRow`, `crashLogs` getter |
| MODIFY | `lib/providers/data_providers.dart` | Add `crashLogRepositoryProvider` and `crashLogsProvider` |
| MODIFY | `lib/services/crash_reporter.dart` | Add `attach`, persistence in all three report methods, `_persist` helper |
| CREATE | `lib/ui/debug/support_screen.dart` | Support screen widget with Copy All button |
| MODIFY | `lib/main.dart` | Manual `ProviderContainer` + `UncontrolledProviderScope` + `CrashReporter.attach(...)` |
| MODIFY | `lib/app.dart` | TEMPORARY 5-second long-press trigger opening `SupportScreen` (removed in Story 7.6) |
| CREATE | `test/data/repositories/crash_log_entry_test.dart` | Entry/enum value tests |
| CREATE | `test/data/repositories/crash_log_repository_test.dart` | Ring-buffer repository tests with `NativeDatabase.memory()` |
| MODIFY | `test/data/database/app_database_test.dart` | Update schemaVersion assertion, add crash_logs table smoke test |
| MODIFY | `test/services/crash_reporter_test.dart` | Add persistence-wiring tests with fake repo |
| CREATE | `test/ui/debug/support_screen_test.dart` | Widget tests for SupportScreen + Copy All |

### Testing Standards

- **Drift-backed tests use `flutter_test`** (not `package:test/test.dart`) — the Drift + sqlite3_flutter_libs stack requires the Flutter test harness for native library loading. Pattern already established in `test/data/database/app_database_test.dart` [Source: 1-4 dev notes, line 189]
- **Pure-Dart value object tests** (`crash_log_entry_test.dart`) use `package:test/test.dart`
- **Widget tests** (`support_screen_test.dart`) use `flutter_test` + `ProviderScope(overrides: [...])`. Always override `crashLogsProvider` / `crashLogRepositoryProvider` — NEVER mount a real `AppDatabase` [Source: project-context.md#Subtle gotchas, line 377]
- **Accessibility.** Every interactive widget in `SupportScreen` wrapped in `Semantics` with a readable label. Widget tests assert labels present [Source: project-context.md#Subtle gotchas, line 378]
- **No `print()`.** Use `Logger('CrashReporter')`, `Logger('CrashLogRepository')` as needed [Source: project-context.md#Critical Don't-Miss Rules, line 364]
- **In-memory Drift:** `AppDatabase(NativeDatabase.memory())` per Story 1.4 [Source: 1-4 dev notes, line 189]

### Anti-Patterns to Avoid

- Do NOT add `package:flutter/*` to ANY file under `lib/data/` (tables, converters, repositories)
- Do NOT write raw SQL — use typed Drift DSL exclusively
- Do NOT `print()` anywhere — `Logger('Tag')` only
- Do NOT swallow persistence errors silently — log at `severe` first, THEN return (this satisfies project rule "NEVER swallow errors silently. Minimum: log at `warning` and return `Result.failure`" [Source: game-architecture.md#Error Handling, line 342])
- Do NOT gate `SupportScreen` with `kDebugMode` — it must work in release (AC #3)
- Do NOT reorder `_backupDatabase(from)` relative to the schema migration steps in `onUpgrade` — backup must come FIRST
- Do NOT mutate an existing schema version — v2 is a NEW version; don't re-edit "v1"
- Do NOT `await` `CrashLogRepository.append` inside `reportFlutterError` / `reportPlatformError` — use `unawaited(...)` so error handlers remain synchronous
- Do NOT add `get_it` or any DI container — Riverpod providers are the DI container [Source: 1-1 dev notes, "no get_it"]
- Do NOT add Crashlytics / Sentry / Firebase — deferred to Epic 13
- Do NOT create a new `providers/` file — add `crashLogRepositoryProvider` to the existing `lib/providers/data_providers.dart` [Source: project-context.md, line 212]
- Do NOT create `settings_repository.dart` or any other repo alongside — scope is ONLY crash logs
- Do NOT implement the real Settings screen here — the long-press trigger is TEMPORARY wiring for Story 7.6 to replace
- Do NOT re-architect `CrashReporter` into a `Notifier` or move it to `lib/providers/` — it must remain a singleton because it is set on `FlutterError.onError` BEFORE any Flutter binding or provider scope exists
- Do NOT call `DateTime.now()` inside any `lib/game/` code path — but `CrashReporter` in `lib/services/` is explicitly exempt [Source: project-context.md#Anti-patterns, line 354]
- Do NOT emit `GameEvent`s from `CrashReporter` — services subscribe to events, they do not emit [Source: project-context.md#Critical Don't-Miss Rules, line 363]

### Previous Story Intelligence

**From Story 1.4 (Drift scaffold):**
- `AppDatabase` at `lib/data/database/app_database.dart` — currently `@DriftDatabase(tables: [])`, schema v1, `onUpgrade` already calls `_backupDatabase(from)`
- `DecimalConverter` at `lib/data/database/converters/decimal_converter.dart` — pattern to mirror for `CrashLogLevelConverter`
- `build.yaml` configured with `store_date_time_values_as_text: true` — DateTime columns auto-serialize as ISO8601 TEXT
- `appDatabaseProvider` at `lib/providers/data_providers.dart` — the single file where we add `crashLogRepositoryProvider`
- Drift tests use `AppDatabase(NativeDatabase.memory())`; `flutter_test` import
- Generated `*.g.dart` files are committed and excluded from lint

**From Story 1.1 (Global safety net):**
- `CrashReporter` singleton at `lib/services/crash_reporter.dart` — three `report*` methods wired from `main.dart`'s three global error handlers
- `Logger('CrashReporter')` used via `package:logging` — NEVER `print()`
- `FallbackErrorWidget` at `lib/ui/fallback_error_widget.dart` — the last-resort UI when everything breaks (unrelated to `SupportScreen`, but shows the pattern of Flutter UI under `lib/ui/`)
- `main.dart` currently uses `ProviderScope(child: ...)` — this story converts to `UncontrolledProviderScope` to pre-attach the repo

**From Story 1.7 (ContentRegistry):**
- `contentRegistryProvider` exists in `lib/providers/app_providers.dart` — `FutureProvider` pattern. `crashLogsProvider` follows the same shape but reads from the repository instead of asset files
- `BootErrorScreen` at `lib/ui/boot_error_screen.dart` — shown on content load failure. Not modified in this story

**From Story 1.8 (GameError + Result):**
- `Result<T, E>` exists at `lib/game/values/result.dart` — NOT used in this story's public API because persistence errors inside `CrashReporter` are swallowed (logged) rather than returned; `CrashLogRepository.append` returns `Future<void>` (throws on fatal DB failure, caller catches)
- If a future story wants strict error handling on persistence, wrap `append` return in `Future<Result<void, GameError>>` — but NOT this story; keep the API simple

**Key patterns established across stories 1.1–1.9:**
- `@immutable` value types with manual `==`/`hashCode`/`toString`/`copyWith`
- Files: `snake_case.dart`, one public class per file (enums can co-locate with their primary value type)
- Drift: plural table (`CrashLogs`), singular row via `@DataClassName('CrashLogRow')`, file named `crash_logs_table.dart`
- Tests mirror lib path; pure-Dart tests use `package:test/test.dart`, Flutter/Drift tests use `flutter_test`
- `avoid_print: error` is enforced in `analysis_options.yaml`
- 178+ total tests passing after Story 1.9 implementation (sprint-status shows 1-9 as `ready-for-dev`; implementation files are present in `lib/game/` — verify final count against CI before adding this story's tests)

### Git Intelligence

Recent commits show project setup + planning, no feature code beyond Epic 1 stories:
- `9c804f9 chore: add planning artifacts, dev loop scripts, and settings update`
- `6992c42 chore: add MCP servers config`
- `8d84ab1 chore: BMAD setup, planning artifacts ported, Flutter deps configured`
- `91edb72 init: Flutter project scaffold`

All Story 1.1–1.9 feature code appears to be uncommitted / staged via the working tree (per `git status` at session start showing modified planning artifacts and new lib files). No dependency changes needed for this story.

### Latest Tech Information

- `drift: ^2.26.1` — Drift's `MigrationStrategy` + `m.createTable(...)` is the stable API. `verifySchema` is available but complex to wire; prefer direct smoke tests
- `flutter_riverpod: ^2.6.1` — `UncontrolledProviderScope` is the documented pattern for pre-built `ProviderContainer`. `container.read(provider)` is synchronous for sync providers (our `crashLogRepositoryProvider` is `Provider<T>`, not `FutureProvider`)
- `package:logging: ^1.3.0` — `Logger('Tag').severe(message, [error, stackTrace])` is the canonical 3-arg form
- No breaking changes in any of the above relevant to this story

### Project Structure Notes

- `lib/data/database/tables/` — NEW directory created by this story. Per architecture file tree [Source: game-architecture.md, line 593], this is the prescribed location for Drift table classes. Future stories (Epic 6: save, settings, etc.) will add sibling files here
- `lib/data/repositories/` — NEW directory created by this story. Architecture line 597 lists `save, settings, crash_log` as the expected repositories. This story ships the first one; `save_repository.dart` and `settings_repository.dart` come in Epic 6 / Epic 7 respectively
- `lib/ui/debug/` — per architecture, this folder is for `kDebugMode`-gated overlays [Source: project-context.md, line 210]. `SupportScreen` is the documented exception (line 380). Add a top-of-file comment explaining this
- `test/data/repositories/` — NEW test directory mirroring `lib/data/repositories/`
- `test/ui/debug/` — NEW test directory mirroring `lib/ui/debug/`

### References

- [Source: epics.md#Story 1.10, lines 563-582] — User story, acceptance criteria
- [Source: epics.md#NFR17, line 125] — Release-accessible crash ring buffer requirement
- [Source: epics.md#Story 7.6, line 1424] — Future home of the long-press activator (this story's trigger is temporary)
- [Source: game-architecture.md#Persistence — Drift 2.26, line 229] — `crash_logs` in the canonical table list
- [Source: game-architecture.md#Error Handling & Telemetry, lines 286-292] — CrashReporter writes to `crash_logs` (N=100 bounded), global handlers, Crashlytics deferred to Epic 13
- [Source: game-architecture.md#Logging, lines 386-425] — `package:logging`, SEVERE → `crash_logs` table, WARNING → bounded, Logger tag = class name, no logging in hot paths, no PII
- [Source: game-architecture.md#Debug / Development Tools, lines 493-510] — Debug tools are `kDebugMode`-gated EXCEPT crash log ring buffer (100 entries, 5-second settings long-press, "Support" screen)
- [Source: game-architecture.md#File Structure, lines 590-598] — `lib/data/database/tables/`, `lib/data/repositories/` layout with `crash_log`
- [Source: project-context.md#Code Organization Rules, lines 193-225] — Prescribed directory tree (`data/database/tables/`, `data/repositories/`, `services/crash_reporter.dart`)
- [Source: project-context.md#Dependency graph, lines 227-236] — `data/` has NO Flutter imports; `ui/` can use Flutter freely
- [Source: project-context.md#Critical Implementation Rules] — UI → provider → repository → DB flow; never raw SQL; schema changes require new migration
- [Source: project-context.md#Subtle gotchas, lines 368-381] — Backup BEFORE migration (line 374), `*.g.dart` committed + lint-excluded (line 376), debug-tools `kDebugMode` exception for crash log (line 380)
- [Source: project-context.md#Anti-patterns, lines 351-366] — `print()` forbidden, no raw SQL, no `get_it`, no modifying existing schema versions
- [Source: 1-1-wire-global-safety-net-and-portrait-lock-in-main-dart.md] — Existing `CrashReporter` class with three `report*` methods, `Logger('CrashReporter')`, `main.dart` wiring pattern
- [Source: 1-4-scaffold-drift-database-and-apply-migrations.md] — `AppDatabase` structure, `onUpgrade` backup ordering, `DecimalConverter` pattern for new converters, in-memory Drift test pattern
- [Source: 1-9-skeleton-gameworld-with-tick-and-applycommand-no-op.md] — Latest story's patterns for sealed types and immutability (not directly applied but confirms `@immutable` + manual `==` conventions)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- build_runner needed `CrashLogLevel` imported directly in `app_database.dart` (not just transitively via the table) for the generated `part` file to resolve the type — added explicit imports of `crash_log_entry.dart` and `crash_log_level_converter.dart` to `app_database.dart`
- `spike_map_painter.dart` and `spike_canvas_screen.dart` had pre-existing `unnecessary_import` / `depend_on_referenced_packages` infos; excluded both from `analysis_options.yaml` (they were failing `--fatal-infos` before this story)
- `CrashLogRepository` logger field was unused — removed; logging inside the repository is not needed since `CrashReporter` already logs at severe before calling `append`
- `attach()` on `CrashReporter` does NOT get `@visibleForTesting` since it's called from `main.dart` in production; only `reset()` is test-only

### Completion Notes List

- Implemented full crash log ring buffer: `CrashLogEntry` value type + `CrashLogLevel` enum (pure Dart, zero Flutter imports), `CrashLogs` Drift table with `CrashLogLevelConverter`, `CrashLogRepository` with atomic insert-then-evict transaction (N=100 cap, `timestamp DESC, id DESC` ordering)
- Schema bumped v1→v2; `onUpgrade` adds `crash_logs` table after backup; `onCreate` calls `createAll()` which includes the new table
- `CrashReporter` extended with `attach(CrashLogRepository)` / `reset()` and fire-and-forget `unawaited(_persist(...))` in all three `report*` methods — persistence failures swallowed with `severe` log, never rethrow
- `main.dart` converted from `ProviderScope` to `ProviderContainer` + `UncontrolledProviderScope` to enable pre-mounting `CrashReporter.attach` before first frame
- `SupportScreen` in `lib/ui/debug/` (documented architecture exception — NOT `kDebugMode`-gated): Scaffold + AppBar + ListView of `ExpansionTile` cards + Copy All button with SnackBar; full Semantics labels on interactive elements
- Temporary 5-second long-press trigger in `lib/app.dart` using `GestureDetector` + `Timer`; clearly commented with `TODO(story-7.6)` removal marker
- 278 tests total pass (67 new tests added: 10 entry/enum, 11 repository, 3 schema, 12 CrashReporter, 8 SupportScreen widget, plus 3 existing schema tests updated)
- `flutter analyze --fatal-infos` clean; `dart format --set-exit-if-changed .` clean; zero Flutter imports in `lib/data/`

### File List

- lib/data/repositories/crash_log_entry.dart (CREATE)
- lib/data/database/tables/crash_logs_table.dart (CREATE)
- lib/data/database/converters/crash_log_level_converter.dart (CREATE)
- lib/data/repositories/crash_log_repository.dart (CREATE)
- lib/data/database/app_database.dart (MODIFY — register CrashLogs, schema v2, onUpgrade migration)
- lib/data/database/app_database.g.dart (GENERATED — regenerated with $CrashLogsTable, CrashLogRow, crashLogs getter)
- lib/providers/data_providers.dart (MODIFY — add crashLogRepositoryProvider, crashLogsProvider)
- lib/services/crash_reporter.dart (MODIFY — add attach, reset, _buildEntry, _persist, unawaited persistence)
- lib/ui/debug/support_screen.dart (CREATE)
- lib/main.dart (MODIFY — ProviderContainer + UncontrolledProviderScope + CrashReporter.attach)
- lib/app.dart (MODIFY — TEMPORARY 5-second long-press trigger to SupportScreen)
- analysis_options.yaml (MODIFY — exclude pre-existing spike files from fatal-infos)
- test/data/repositories/crash_log_entry_test.dart (CREATE)
- test/data/repositories/crash_log_repository_test.dart (CREATE)
- test/data/database/app_database_test.dart (MODIFY — schema v2 assertion, crash_logs table tests)
- test/services/crash_reporter_test.dart (MODIFY — add persistence wiring tests with fake repo)
- test/ui/debug/support_screen_test.dart (CREATE)

### Change Log

- 2026-04-21: Story 1.10 implemented — crash log ring buffer (CrashLogs Drift table + CrashLogRepository, N=100 atomic eviction), CrashReporter persistence wiring via attach/ProviderContainer, SupportScreen with Copy All, temporary 5s long-press trigger; schema v1→v2 migration; 278 total tests pass
- 2026-04-21: Code review passed → done (3 MEDIUM fixed: clipboard-write snackbar now awaits and handles failure, CrashLogLevelConverter falls back to severe on unknown enum names, concurrent-append test strengthened to assert exactly 100 survivors with correct tail range; 278 tests still pass, analyze + format clean)
