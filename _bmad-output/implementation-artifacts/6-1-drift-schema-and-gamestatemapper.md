# Story 6.1: Drift Schema and `GameStateMapper`

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a normalized Drift schema for the persistable subset of `GameState` and a pure-Dart `GameStateMapper` that converts between `GameState` and Drift rows,
So that Story 6-2's `SaveRepository` can persist event-driven row updates and Story 6-4's `OfflineCatchup` can rehydrate the simulation losslessly without the sim layer ever touching Drift.

## Acceptance Criteria

1. **Given** the project's `AppDatabase` after this story
   **When** `dart run build_runner build --delete-conflicting-outputs` runs
   **Then** generated code in `lib/data/database/app_database.g.dart` compiles cleanly with `flutter analyze` returning zero warnings, AND `AppDatabase.schemaVersion` returns `3`, AND the `@DriftDatabase(tables: [...])` list includes (in this exact order, alphabetized after `CrashLogs`): `ActiveGlobalUpgrades`, `ActiveGoldenEffect`, `ActiveGoldens`, `Continents`, `ContinentMilestones`, `Countries`, `CrashLogs`, `EarnedAchievements`, `Meta`.

2. **Given** every newly-added table
   **When** examined
   **Then** each has an explicit primary key, every `Decimal` field is a `TextColumn` with `.map(const DecimalConverter())`, every `DateTime` field is a `DateTimeColumn` (stored as TEXT per `build.yaml` `store_date_time_values_as_text: true`), every nullable column uses `.nullable()`, and FK relationships are declared via `references(...)`. **No raw SQL**: only typed Drift DSL.

3. **Given** the `Meta` table
   **When** any row exists in it
   **Then** the schema enforces single-row semantics via a `singletonId` `IntColumn` constrained to `check(singletonId.equals(0))` with default `Constant(0)` as primary key, AND the columns are: `singletonId INT PK`, `schemaVersion INT`, `lastSavedAt DATETIME`, `totalInfluence TEXT (Decimal)`, `goldenOpportunityMultiplier TEXT (Decimal)`, `boostMultiplier TEXT (Decimal)`. (Forward-looking columns `totalIntel`, `dailyStreakJson`, `tutorialCompleted` are deliberately **deferred** — see Dev Notes.)

4. **Given** a v2 database file (existing crash_logs only) on disk at app launch
   **When** `AppDatabase` opens
   **Then** the typed `MigrationStrategy.onUpgrade(2 → 3)` runs in this exact sequence: (a) `_backupDatabase(2)` copies the file to `schema_backup_v2.sqlite`, (b) `m.createTable(meta)` then all other new tables, (c) seeds a single `meta` row with `schemaVersion: 3`, `lastSavedAt: clock.now()`, `totalInfluence: '0'`, `goldenOpportunityMultiplier: '1'`, `boostMultiplier: '1'`, AND the database reaches schema version 3 with the existing `crash_logs` data preserved.

5. **Given** a fully-populated `GameState` (every collection non-empty: countries, unlockedContinents, reachedMilestones, continentCompletions, earnedAchievementIds, activeGlobalUpgradeIds, activeGoldens, activeGoldenEffect != null, totalInfluence > 0, goldenOpportunityMultiplier ≠ 1, boostMultiplier ≠ 1)
   **When** `GameStateMapper.toCompanions(state, savedAt: <DateTime>)` is called
   **Then** it returns a `GameStateCompanions` record bundle (see Task 5) containing typed Drift companion objects for every table, with every `GameState` field represented (no field silently dropped).

6. **Given** a `GameStateRows` bundle produced by `AppDatabase.loadAll()` from a database whose contents were written by `mapper.toCompanions(state, savedAt: ...)` then read back
   **When** `mapper.fromRows(rows, content)` is called
   **Then** it returns a `GameState` such that `GameState1 == mapper.fromRows(roundtripDb(mapper.toCompanions(GameState1)), content)` — i.e. the round-trip is lossless for every field listed in AC #5. Verified by a property-style test that constructs a non-trivial `GameState`, writes it via Drift in-memory, reads back, and compares with full `==`.

7. **Given** an empty database (`AppDatabase.loadAll()` returns a `GameStateRows` whose `meta` is `null` and every list is empty)
   **When** `mapper.fromRows(rows, content)` is called
   **Then** it returns `GameState.initialSeed(content)` byte-identically — no fallback heuristics, no "best-effort" reconstruction; the empty-rows branch is a single explicit `if (rows.meta == null) return GameState.initialSeed(content);`.

8. **Given** the architectural boundary `lib/data/ → lib/game/` (one-way)
   **When** any new file under `lib/data/database/tables/` or `lib/data/database/converters/` or `lib/data/mappers/` is examined
   **Then** **no Drift table file imports `package:global_domination/game/...`** (tables are pure persistence types), **the mapper is the ONLY file that imports both `lib/data/` and `lib/game/`**, AND `test/architecture/data_boundary_test.dart` is added (or extended) to assert this invariant via static-import analysis (mirror of `test/architecture/game_boundary_test.dart`).

9. **Given** the existing `lib/data/database/app_database.dart` `@DriftDatabase` annotation
   **When** the new tables are added
   **Then** the `tables` list is updated, `schemaVersion` is bumped to 3, `MigrationStrategy.onUpgrade` gains a `from <= 2 && to >= 3` branch, the existing `from == 1` (v1→v2) branch is preserved unchanged, AND `AppDatabase.loadAll() : Future<GameStateRows>` is added as a typed query method that batches reads of all persisted tables in a single `transaction(...)`.

10. **Given** all unit tests authored for this story
    **When** `flutter test test/data/` runs
    **Then** every test uses `NativeDatabase.memory()` (NEVER touches the real filesystem), every `AppDatabase` instance is `await db.close()`'d in `tearDown`, AND new tests cover at minimum: schemaVersion is 3 (1 test); each new table is queryable post-`onCreate` (1 test per table = 8 tests); v2→v3 onUpgrade preserves crash_logs (1 test, deferred-pattern OK per Story 1.4 precedent); mapper round-trip with full state (1 test); empty-DB → `initialSeed` (1 test); per-field smoke tests for each persisted GameState field (≥ 8 tests).

## Tasks / Subtasks

- [ ] Task 1: Create the new Drift table files under `lib/data/database/tables/` (AC: #1, #2, #3, #8)
  - [ ] 1.1 Create `lib/data/database/tables/meta_table.dart`. Pattern: pure persistence types, NO imports from `lib/game/`. Use `import 'package:drift/drift.dart';` and `import '../converters/decimal_converter.dart';` only.
    ```dart
    @DataClassName('MetaRow')
    class Meta extends Table {
      IntColumn get singletonId => integer().withDefault(const Constant(0))();
      IntColumn get schemaVersion => integer()();
      DateTimeColumn get lastSavedAt => dateTime()();
      TextColumn get totalInfluence => text().map(const DecimalConverter())();
      TextColumn get goldenOpportunityMultiplier => text().map(const DecimalConverter())();
      TextColumn get boostMultiplier => text().map(const DecimalConverter())();

      @override
      Set<Column<Object>> get primaryKey => {singletonId};

      @override
      List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
    }
    ```
  - [ ] 1.2 Create `lib/data/database/tables/countries_table.dart` mirroring current `CountryState` (id PK, unlocked BOOL, ipLevel INT, leaderTier TEXT [enum], bankedInfluence TEXT [Decimal], lastCollectedAt DATETIME nullable). Use `text()` for `id` (matches `CountryId.value`) and `text()` for `leaderTier` (store enum `name` — add a `LeaderTierConverter` in Task 2 OR persist `name` as raw text and convert in mapper; pick the latter — converter overhead not justified for one enum).
    ```dart
    @DataClassName('CountryRow')
    class Countries extends Table {
      TextColumn get id => text()();
      BoolColumn get unlocked => boolean()();
      IntColumn get ipLevel => integer()();
      TextColumn get leaderTier => text()(); // enum.name: 'none' | 'tier1' | 'tier2' | 'tier3'
      TextColumn get bankedInfluence => text().map(const DecimalConverter())();
      DateTimeColumn get lastCollectedAt => dateTime().nullable()();

      @override
      Set<Column<Object>> get primaryKey => {id};
    }
    ```
  - [ ] 1.3 Create `lib/data/database/tables/continents_table.dart` (id PK, unlocked BOOL, completed BOOL). Models the union of `state.unlockedContinents` and `state.continentCompletions` keyed by `ContinentId.value`. Both flags default to `false` for un-persisted continents (mapper supplies the missing-row interpretation).
  - [ ] 1.4 Create `lib/data/database/tables/continent_milestones_table.dart` modeling `Map<ContinentId, Set<int>>` (the `reachedMilestones` field). Composite PK `(continentId, milestone)`; FK `continentId references continents(id)` (typed Drift FK syntax, `onDelete: KeyAction.cascade`).
    ```dart
    @DataClassName('ContinentMilestoneRow')
    class ContinentMilestones extends Table {
      TextColumn get continentId => text().references(Continents, #id, onDelete: KeyAction.cascade)();
      IntColumn get milestone => integer()(); // 25, 50, 75, 100

      @override
      Set<Column<Object>> get primaryKey => {continentId, milestone};
    }
    ```
  - [ ] 1.5 Create `lib/data/database/tables/earned_achievements_table.dart` (id TEXT PK — single column, no other state stored on the row; rewards are re-applied from content on load and are idempotent per Story 5-5's `earnedAchievementIds` ledger).
  - [ ] 1.6 Create `lib/data/database/tables/active_global_upgrades_table.dart` (id TEXT PK — same shape as `earned_achievements`).
  - [ ] 1.7 Create `lib/data/database/tables/active_goldens_table.dart` mirroring `ActiveGolden`: `id TEXT PK, countryId TEXT, multiplier INT, expiresAt DATETIME`. **No FK to countries** — the country may technically be re-locked between spawn and claim; the reducer's defensive guard (Story 5-1 AC #7c) is the contract, not the schema. Document this decision in a one-line `// ` comment in the file.
  - [ ] 1.8 Create `lib/data/database/tables/active_golden_effect_table.dart`. Single-row pattern (same `singletonId` + `CHECK(singleton_id = 0)` trick as `meta`). Columns: `singletonId INT PK, goldenId TEXT, multiplier INT, expiresAt DATETIME`. **Empty table = no active effect** (this is how `state.activeGoldenEffect == null` round-trips: mapper writes 0 rows when null, 1 row when non-null; mapper reads `rows.activeGoldenEffect` as nullable).
  - [ ] 1.9 Every new table file MUST have `@DataClassName('XxxRow')` matching the singular naming (`Meta` → `MetaRow`, `Countries` → `CountryRow`, `ContinentMilestones` → `ContinentMilestoneRow`, etc.) per Drift convention and the project's "Drift: plural table, singular row class" rule (project-context.md line 242).

- [ ] Task 2: No new TypeConverters required (AC: #2)
  - [ ] 2.1 Reuse the existing `lib/data/database/converters/decimal_converter.dart` for ALL `Decimal` columns. **Do NOT** create a `LeaderTierConverter` — store `LeaderTier.name` as raw `text()` and convert via a private helper in `GameStateMapper` (cheaper, avoids generated-code coupling between the data layer and `lib/game/features/leaders/leader_tier.dart`). Justify in a one-line code comment in the mapper.
  - [ ] 2.2 No `BoolConverter` either — Drift's `boolean()` ships first-class.

- [ ] Task 3: Wire new tables + bump schema version + add `onUpgrade(2 → 3)` migration in `lib/data/database/app_database.dart` (AC: #1, #4, #9)
  - [ ] 3.1 Update `@DriftDatabase(tables: [...])` to include all new tables in alphabetical order, keeping `CrashLogs` in the list. Final order:
    ```dart
    @DriftDatabase(tables: [
      ActiveGlobalUpgrades,
      ActiveGoldenEffect,
      ActiveGoldens,
      Continents,
      ContinentMilestones,
      Countries,
      CrashLogs,
      EarnedAchievements,
      Meta,
    ])
    ```
  - [ ] 3.2 Bump `schemaVersion` from `2` to `3`.
  - [ ] 3.3 Extend `MigrationStrategy.onUpgrade`: keep the existing `if (from == 1) await m.createTable(crashLogs);` branch untouched. Add (in the same callback, AFTER the existing `_backupDatabase(from)` call):
    ```dart
    if (from <= 2 && to >= 3) {
      await m.createTable(meta);
      await m.createTable(countries);
      await m.createTable(continents);
      await m.createTable(continentMilestones);
      await m.createTable(earnedAchievements);
      await m.createTable(activeGlobalUpgrades);
      await m.createTable(activeGoldens);
      await m.createTable(activeGoldenEffect);
      await into(meta).insert(MetaCompanion.insert(
        schemaVersion: 3,
        lastSavedAt: DateTime.now().toUtc(),
        totalInfluence: Decimal.zero,
        goldenOpportunityMultiplier: Decimal.one,
        boostMultiplier: Decimal.one,
      ));
    }
    ```
    **Note:** `_backupDatabase(from)` is already called unconditionally at the top of `onUpgrade`; do NOT re-call it. The `_backupDatabase` no-op-on-memory limitation (existing comment) is preserved.
  - [ ] 3.4 The `onCreate` callback (`m.createAll()`) needs no changes — Drift auto-creates every registered table. **However**, `onCreate` MUST also seed the singleton `meta` row, otherwise a fresh DB has no `meta` row and `loadAll()` returns `meta: null` — which the mapper interprets as "first launch" and seeds from `ContentRegistry`. This is the **intended** behavior per AC #7 (no surprise meta row on cold launch). **Decision: do NOT seed meta in onCreate; let the empty-DB → `initialSeed` flow drive the first save's INSERT in Story 6-2.** Add a one-line code comment documenting this choice.
  - [ ] 3.5 Add a typed `loadAll()` method to `AppDatabase`:
    ```dart
    Future<GameStateRows> loadAll() async {
      return transaction(() async {
        final metaRow = await (select(meta)..limit(1)).getSingleOrNull();
        final countryRows = await select(countries).get();
        final continentRows = await select(continents).get();
        final milestoneRows = await select(continentMilestones).get();
        final achievementRows = await select(earnedAchievements).get();
        final upgradeRows = await select(activeGlobalUpgrades).get();
        final goldenRows = await select(activeGoldens).get();
        final goldenEffectRow = await (select(activeGoldenEffect)..limit(1)).getSingleOrNull();
        return GameStateRows(
          meta: metaRow,
          countries: countryRows,
          continents: continentRows,
          continentMilestones: milestoneRows,
          earnedAchievements: achievementRows,
          activeGlobalUpgrades: upgradeRows,
          activeGoldens: goldenRows,
          activeGoldenEffect: goldenEffectRow,
        );
      });
    }
    ```
    `GameStateRows` is a Dart `class` (immutable) defined in `lib/data/mappers/game_state_rows.dart` — see Task 4. **Do not return a `Map<String, dynamic>`** — typed bundle only.

- [ ] Task 4: Define the `GameStateRows` and `GameStateCompanions` bundle classes (AC: #5, #6, #7)
  - [ ] 4.1 Create `lib/data/mappers/game_state_rows.dart`:
    ```dart
    @immutable
    class GameStateRows {
      final MetaRow? meta;                           // null on first launch
      final List<CountryRow> countries;
      final List<ContinentRow> continents;
      final List<ContinentMilestoneRow> continentMilestones;
      final List<EarnedAchievementRow> earnedAchievements;
      final List<ActiveGlobalUpgradeRow> activeGlobalUpgrades;
      final List<ActiveGoldenRow> activeGoldens;
      final ActiveGoldenEffectRow? activeGoldenEffect; // null when state.activeGoldenEffect == null

      const GameStateRows({
        required this.meta,
        required this.countries,
        required this.continents,
        required this.continentMilestones,
        required this.earnedAchievements,
        required this.activeGlobalUpgrades,
        required this.activeGoldens,
        required this.activeGoldenEffect,
      });
    }
    ```
    No `==`/`hashCode` needed (consumed once per load; not stored, not compared).
  - [ ] 4.2 Create `lib/data/mappers/game_state_companions.dart` with the parallel write-side bundle. Each list is the full set of `Insert`-shape companions Story 6-2 will batch-write on first save:
    ```dart
    @immutable
    class GameStateCompanions {
      final MetaCompanion meta;
      final List<CountriesCompanion> countries;
      final List<ContinentsCompanion> continents;
      final List<ContinentMilestonesCompanion> continentMilestones;
      final List<EarnedAchievementsCompanion> earnedAchievements;
      final List<ActiveGlobalUpgradesCompanion> activeGlobalUpgrades;
      final List<ActiveGoldensCompanion> activeGoldens;
      final ActiveGoldenEffectCompanion? activeGoldenEffect; // null when state.activeGoldenEffect == null

      const GameStateCompanions({...});
    }
    ```
  - [ ] 4.3 Both files MAY import from `package:global_domination/data/database/app_database.dart` (for the generated row/companion types) and `package:meta/meta.dart`. They MUST NOT import `package:flutter/...`.

- [ ] Task 5: Implement `GameStateMapper` (AC: #5, #6, #7, #8)
  - [ ] 5.1 Create `lib/data/mappers/game_state_mapper.dart`. This is **the only file in `lib/data/` that imports `lib/game/`**. Static `flutter analyze` test from Task 8.3 enforces this.
  - [ ] 5.2 Public API:
    ```dart
    class GameStateMapper {
      const GameStateMapper();

      GameStateCompanions toCompanions(GameState state, {required DateTime savedAt});

      GameState fromRows(GameStateRows rows, ContentRegistry content);
    }
    ```
    Stateless, no fields. Inject as a Riverpod `Provider` in Story 6-2 (`gameStateMapperProvider`). No provider in this story.
  - [ ] 5.3 `toCompanions` per-field mapping:
    - `state.totalInfluence.value` → `meta.totalInfluence` (Decimal)
    - `state.goldenOpportunityMultiplier` → `meta.goldenOpportunityMultiplier`
    - `state.boostMultiplier` → `meta.boostMultiplier`
    - `savedAt` (parameter) → `meta.lastSavedAt` (UTC; mapper asserts `savedAt.isUtc` — see 5.7)
    - `meta.schemaVersion` = `Constant(3)` companion value (do NOT read from `AppDatabase.schemaVersion` here — keep mapper free of `AppDatabase` instance dependency)
    - For each `entry in state.countries.entries`: `CountriesCompanion.insert(id: entry.key.value, unlocked: entry.value.unlocked, ipLevel: entry.value.ipLevel, leaderTier: entry.value.leaderTier.name, bankedInfluence: entry.value.bankedInfluence.value, lastCollectedAt: Value(entry.value.lastCollectedAt))`
    - For each entry in the union of `state.unlockedContinents` and `state.continentCompletions` keys: emit one `ContinentsCompanion.insert(id, unlocked, completed)`. **Default missing flags to `false`** so a continent that's only in `unlockedContinents` (but absent from `continentCompletions`) round-trips with `completed: false`.
    - For each `(continentId, milestoneSet) in state.reachedMilestones.entries` and each `m in milestoneSet`: one `ContinentMilestonesCompanion.insert(continentId.value, m)`.
    - For each `id in state.earnedAchievementIds`: `EarnedAchievementsCompanion.insert(id: id)`.
    - For each `id in state.activeGlobalUpgradeIds`: `ActiveGlobalUpgradesCompanion.insert(id: id)`.
    - For each `g in state.activeGoldens.values`: `ActiveGoldensCompanion.insert(id: g.id, countryId: g.countryId.value, multiplier: g.multiplier, expiresAt: g.expiresAt)`.
    - If `state.activeGoldenEffect != null`: one `ActiveGoldenEffectCompanion.insert(goldenId: ..., multiplier: ..., expiresAt: ...)` (with `singletonId: Value(0)` to satisfy the CHECK constraint). If `null`: the companion field is `null` (write 0 rows).
  - [ ] 5.4 `fromRows` reconstruction:
    - `if (rows.meta == null) return GameState.initialSeed(content);` — single explicit branch (AC #7).
    - Reconstruct `countries` map: start from `content.countries.keys` (so every content-defined country exists in state — required by `tickCountries` and the existing `initialSeed` invariant). For each id: lookup the corresponding `CountryRow` (build a `Map<String, CountryRow>` once, lookup is O(1)); if found, build a `CountryState` from the row; if missing (content has a country the saved DB doesn't — i.e. content was extended after the save), use the same defaults as `initialSeed`'s non-egypt branch (`unlocked: false, ipLevel: 0, leaderTier: LeaderTier.none, bankedInfluence: Influence.zero, lastCollectedAt: null`).
    - Convert `leaderTier` string → enum: `LeaderTier.values.byName(row.leaderTier)`. If a row has an unknown name (impossible unless DB is hand-edited), throw `ContentLoadException`-style internal error — schema invariant violation.
    - Reconstruct `unlockedContinents` and `continentCompletions` from the `continents` rows. Drop continents not in `content.continents` defensively (similar to country handling).
    - Reconstruct `reachedMilestones`: group milestone rows by `continentId` and produce `Map<ContinentId, Set<int>>`.
    - Reconstruct `earnedAchievementIds`, `activeGlobalUpgradeIds`: simple `Set<String>.from(rows.xxx.map((r) => r.id))`.
    - Reconstruct `activeGoldens`: `{ for (final r in rows.activeGoldens) r.id: ActiveGolden(id: r.id, countryId: CountryId(r.countryId), multiplier: r.multiplier, expiresAt: r.expiresAt) }`.
    - Reconstruct `activeGoldenEffect`: `rows.activeGoldenEffect == null ? null : ActiveGoldenEffect(goldenId: row.goldenId, multiplier: row.multiplier, expiresAt: row.expiresAt)`.
    - Final `GameState(...)` constructor call with all reconstructed fields. **Read `totalInfluence` from `rows.meta!.totalInfluence` (Decimal) and wrap with `Influence(...)`.**
  - [ ] 5.5 Time discipline: `savedAt` parameter MUST be UTC. Add `assert(savedAt.isUtc, 'savedAt must be UTC');` at the top of `toCompanions`. The architecture's `meta.lastSavedAt` contract is "UTC ISO8601" (project-context.md line 122; architecture line 233). Drift's `store_date_time_values_as_text: true` gives ISO8601 automatically.
  - [ ] 5.6 Determinism in iteration order: when emitting companions for round-trip-test stability, sort `state.countries`, `state.unlockedContinents`, `state.reachedMilestones`, `state.earnedAchievementIds`, `state.activeGlobalUpgradeIds`, `state.activeGoldens` by their `String` key/id ASC before producing companions. This is **not** a correctness requirement (DB has no order) but tests benefit from deterministic companion lists when comparing equality.
  - [ ] 5.7 NO Flutter imports, NO logging, NO clock reads, NO RNG reads. The mapper is pure Dart utility code — every input is a parameter. (`DateTime.now()` is forbidden inside `toCompanions`/`fromRows`; the caller in Story 6-2 supplies `savedAt`.)
  - [ ] 5.8 NO Drift queries inside the mapper. The mapper consumes typed rows/companions; it does NOT call `select(...)` or `into(...)`. Story 6-2's `SaveRepository` orchestrates DB I/O.

- [ ] Task 6: Architecture boundary tests (AC: #8)
  - [ ] 6.1 If `test/architecture/data_boundary_test.dart` does not yet exist, create it. Mirror the structure of `test/architecture/game_boundary_test.dart` (read static-analysis-friendly imports via `Directory(...).list(recursive: true)` + `File.readAsStringSync()` + `RegExp` matching). Two assertions:
    - **(a) Tables and converters are pure persistence.** For every `.dart` file under `lib/data/database/tables/` and `lib/data/database/converters/`, assert there is no `import 'package:global_domination/game/...'` line. Failure message: `"<path> imports lib/game/ — tables/converters must be pure persistence types; mapping logic belongs in lib/data/mappers/game_state_mapper.dart"`.
    - **(b) Mapper is the SOLE bridge.** For every `.dart` file under `lib/data/`, count files that import BOTH `package:global_domination/data/database/...` AND `package:global_domination/game/...`. Assert that the only file matching is `lib/data/mappers/game_state_mapper.dart`. (`game_state_companions.dart` and `game_state_rows.dart` import `data/database/` only — they don't bridge.) **Note:** `crash_log_repository.dart` and `crash_log_entry.dart` import `data/database/` but NOT `game/` — they do not match the dual-import predicate; they're allowed.
  - [ ] 6.2 Run `flutter test test/architecture/` to confirm both `game_boundary_test.dart` (already exists) and the new `data_boundary_test.dart` pass.

- [ ] Task 7: Database tests in `test/data/database/app_database_test.dart` (AC: #4, #10)
  - [ ] 7.1 Add a top-level group `'AppDatabase v3 schema'`:
    - `'opens at schema version 3'` — `expect(db.schemaVersion, equals(3));`
    - `'onCreate creates meta table'` — `final rows = await db.select(db.meta).get(); expect(rows, isEmpty);` (empty per Task 3.4 decision)
    - One `'onCreate creates <table>'` test per new table (8 tests total, all asserting empty after fresh `NativeDatabase.memory()`). Pattern: `await db.select(db.<table>).get(); expect(..., isEmpty);`
    - `'meta table enforces single-row CHECK constraint'` — insert a row with `singletonId: Value(0)`; expect success. Insert a second with `singletonId: Value(1)`; expect a SQLite `CHECK constraint failed` error (`expectLater(..., throwsA(isA<SqliteException>()))`). **Note:** `package:sqlite3/sqlite3.dart` is already a transitive dep (used by `app_database.dart` already at line 8 — see existing source); add the import in the test file.
    - `'active_golden_effect table enforces single-row CHECK constraint'` — same pattern.
  - [ ] 7.2 Add `'onUpgrade v2→v3'` test, deferred-pattern per the existing `'onUpgrade v1→v2 ...'` comment (lines 41–53 of current `app_database_test.dart`). Body: open in-memory DB, assert `schemaVersion == 3`, assert each new table is queryable. **Do NOT attempt a real v2-on-disk upgrade** — same `NativeDatabase.memory()` limitation; defer real-file upgrade testing to Story 6-3.
  - [ ] 7.3 Update the existing `'opens at schema version 2'` test to assert `equals(3)`. Update the comment block at lines 1–3 of the file (currently mentions Story 6.5) — change to reference Story 6-3 (the typed-migrations story) since `_backupDatabase` testing is deferred there.

- [ ] Task 8: GameStateMapper tests in `test/data/mappers/game_state_mapper_test.dart` (NEW) (AC: #5, #6, #7, #10)
  - [ ] 8.1 Use `package:flutter_test/flutter_test.dart` (not `package:test/test.dart`) — the round-trip tests touch Drift, which requires `TestWidgetsFlutterBinding` for `NativeDatabase.memory()`. **Reference**: `test/data/database/app_database_test.dart` already uses `flutter_test` — match the convention.
  - [ ] 8.2 Build a `ContentRegistry` fixture (copy the helper from `test/game/features/economy/income_calculator_test.dart` lines 17–67 into a shared `test/helpers/test_content_registry.dart` if a similar helper does not yet exist; otherwise inline it). Need at least 2 continents (`africa`, `europe`), 3 countries (`egypt`, `nigeria`, `france`).
  - [ ] 8.3 Test `'fromRows on empty rows returns initialSeed'` (AC #7):
    ```dart
    final mapper = const GameStateMapper();
    final rows = GameStateRows(meta: null, countries: [], continents: [], continentMilestones: [], earnedAchievements: [], activeGlobalUpgrades: [], activeGoldens: [], activeGoldenEffect: null);
    expect(mapper.fromRows(rows, content), equals(GameState.initialSeed(content)));
    ```
  - [ ] 8.4 Test `'toCompanions then fromRows is lossless for trivial state'` (AC #6 base case):
    - Construct `state1 = GameState.initialSeed(content)`.
    - `final companions = mapper.toCompanions(state1, savedAt: DateTime.utc(2026, 1, 1));`
    - Open `AppDatabase(NativeDatabase.memory())`. Write all companions via `into(table).insert(companion)` in a transaction. Read back via `loadAll()`.
    - `final state2 = mapper.fromRows(rows, content);`
    - `expect(state2, equals(state1));`
  - [ ] 8.5 Test `'toCompanions then fromRows is lossless for fully-populated state'` (AC #6 main case): build a non-trivial `GameState` via `GameStateBuilder` (test helper — see 8.10) covering every field listed in AC #5. Same write→read→compare flow. **This is the headline round-trip test.**
  - [ ] 8.6 Per-field smoke tests (AC #10): one test per `GameState` field, each varying just that field from `initialSeed` and asserting round-trip. Fields: `totalInfluence` (use `Decimal.parse('1.234e38')` to test large numbers), `unlockedContinents`, `continentCompletions`, `reachedMilestones` (mix of empty set, single milestone, all four milestones), `earnedAchievementIds`, `activeGlobalUpgradeIds`, `activeGoldens` (1 entry, 3 entries), `activeGoldenEffect` (null and non-null), `goldenOpportunityMultiplier`, `boostMultiplier`. Per-country fields: `unlocked`, `ipLevel`, `leaderTier` (cycle through all 4 enum values), `bankedInfluence`, `lastCollectedAt` (null and non-null).
  - [ ] 8.7 Test `'savedAt non-UTC throws'` (AC #5 / Task 5.5): `expect(() => mapper.toCompanions(state, savedAt: DateTime(2026, 1, 1)), throwsA(isA<AssertionError>()));`. Run only in debug (asserts).
  - [ ] 8.8 Test `'leader_tier enum.name round-trips for every variant'`: parameterized over `LeaderTier.values`.
  - [ ] 8.9 Test `'meta single-row CHECK survives mapper write'`: write companions twice (round 1: full state; round 2: state mutated → re-write meta). Use `into(meta).insertOnConflictUpdate(...)`. Assert exactly one `meta` row exists. **Story 6-2 will own the upsert strategy**, but we test the schema constraint is compatible with upsert here.
  - [ ] 8.10 If `test/helpers/game_state_builder.dart` (mentioned in project-context.md line 289) does not yet exist, **create it now** as part of this story:
    ```dart
    class GameStateBuilder {
      static GameState fullyPopulated({required ContentRegistry content, DateTime? now}) {
        // returns a GameState with every collection non-empty, every multiplier ≠ 1, etc.
        // Used by 8.5 + future stories' tests.
      }
    }
    ```
    Place under `test/helpers/`, exporting `fullyPopulated`. **Audit existing tests** for hand-built `GameState(...)` calls; this story's surface is wide enough to justify centralizing.

- [ ] Task 9: Run code generation, format, analyze, full test suite (AC: #1, all)
  - [ ] 9.1 Run `dart run build_runner build --delete-conflicting-outputs`. Expect a single output: `lib/data/database/app_database.g.dart` regenerated with new table classes. **Commit** the regenerated `.g.dart` (per project-context.md "Drift-generated `*.g.dart` files must be excluded from lint and committed").
  - [ ] 9.2 `flutter analyze` — 0 warnings, 0 errors.
  - [ ] 9.3 `dart format --set-exit-if-changed .`.
  - [ ] 9.4 `flutter test` — full suite green. Expected new tests: ≈ 30–40 (8 table-creation + 2 CHECK + 1 schemaVersion + 1 onUpgrade + 1 trivial round-trip + 1 fully-populated round-trip + ≈ 14 per-field smoke + 1 savedAt-utc + 4 leader-tier + 1 upsert + 2 architecture). Full suite should land at ≈ 580–595 tests (currently ~551 per Story 5-1's notes).
  - [ ] 9.5 Update `Status` to `review`. Append a Change Log entry and File List.

## Dev Notes

### Why this story is the keystone of Epic 6

This is the FIRST story in Epic 6 (Persistence). It establishes the **schema contract** and the **pure-Dart bridge** that downstream stories depend on:

| Decision locked here | Used by |
|---|---|
| `MetaRow` columns: `totalInfluence`, `goldenOpportunityMultiplier`, `boostMultiplier`, `lastSavedAt` | Story 6-2 (debounced snapshot writes only `totalInfluence` + `lastSavedAt`); Story 6-4 (offline catch-up reads `lastSavedAt`); Story 5-2 will ADD `totalIntel` + `activeBoostJson` columns via a v3→v4 migration when it lands. |
| **`GameStateRows` / `GameStateCompanions` bundle pattern** (Tasks 4 + 5) | Story 6-2's `SaveRepository.flush()` writes companions in a single transaction; Story 6-4's `OfflineCatchup.apply()` calls `mapper.fromRows(rows, content)` after `AppDatabase.loadAll()`. |
| **`fromRows(rows: empty, content) == GameState.initialSeed(content)` invariant** (AC #7) | Story 6-2 first-launch path; Story 6-6 save-recovery "start fresh" branch. |
| **One mapper file is the ONLY place importing both `data/` and `game/`** (AC #8) | Architecture boundary discipline; protects refactor safety as schema grows. Future stories ADD column mappings to this same file — never split. |
| **Schema v3 baseline** | Stories 5-2/5-3/5-4/5-5 each ship their own v→v+1 migration (`MigrationStrategy.onUpgrade(3 → 4)`, etc.). DO NOT bundle their tables into v3 prematurely — their state shapes are not yet finalized. |

### Out of scope (do NOT expand)

- **`SaveRepository`, event-driven row updates, debounced 2s snapshot writes.** Story 6-2 owns those. This story's mapper is **stateless**; it does not touch the DB itself. The `loadAll()` method on `AppDatabase` (Task 3.5) is the only DB-touching addition, and it is read-only.
- **Tables for `boosts`, `missions`, `daily_rewards`, `settings`, `tutorial_state`, `leaders`-as-table, `upgrades`-as-table.** Per architecture Section 4 line 229, those are part of the eventual schema. **However**, their corresponding `GameState` fields do not yet exist (Story 5-2 adds `totalIntel`, `activeBoost`; Story 5-3 adds `activeMissions`/`completedMissionIds`; Story 5-4 adds `dailyStreak`; Story 5-5 reuses existing `earnedAchievementIds`; tutorial/settings have no Story yet). Adding empty placeholder tables now means **redefining** them when those stories land — wasteful churn. Per the project rule "backward compatibility is out of scope," each upcoming feature story will ship its OWN typed `vN → vN+1` migration that adds its table(s). This story scopes to **what `GameState` currently models**.
  - **NOTE for Story 5-2 dev:** when 5-2 introduces `totalIntel` + `activeBoost`, its migration v3→v4 must `addColumn(meta, totalIntel)` + `addColumn(meta, activeBoostJson)` (or equivalent normalized table). The `GameStateMapper` extends; it does not get rewritten.
  - **NOTE for Story 5-3 dev:** missions have a `MissionState` value class; map via two new tables (`active_missions`, `completed_mission_ids`) in v4→v5. **Reuse the singleton-row pattern from `meta` and `active_golden_effect` for any new singletons.** Prefer normalized tables over JSON blobs (per project rule "Never raw SQL — always typed Drift DSL"; JSON-in-TEXT is a degenerate raw-SQL anti-pattern).
- **Per-row `lastModifiedAt` audit columns.** Architecture does not require them; do not add.
- **`event_log` table** (mentioned in architecture line 594). Not required by any current story; deferred to a future epic. Do not add.
- **Schema-backup file copy testing.** `_backupDatabase` is uncovered because `NativeDatabase.memory()` does not have a backing file. Story 1.4 set the deferred-test pattern (see existing `app_database_test.dart` lines 1–3 comment); Story 6-3 will add real-file integration tests when typed migrations land.
- **Save corruption recovery, restore-from-backup, "Start Fresh" UX.** Story 6-6 owns those.
- **Riverpod provider for `GameStateMapper`.** Story 6-2 owns `data_providers.dart` wiring.
- **Lifecycle observer flushing the save on `paused`.** Story 6-2 owns that.

### Critical decisions worth restating in code

- **`GameState.totalInfluence` is `Influence` (a `Decimal` wrapper); `state.goldenOpportunityMultiplier` and `state.boostMultiplier` are raw `Decimal` fields.** When mapping to `meta.totalInfluence`, write `.value` (the underlying `Decimal`). When mapping back, wrap with `Influence(...)`. Forgetting to unwrap/wrap is a silent type-mismatch bug — **`flutter analyze` will catch it**, but be deliberate.

- **`leaderTier` round-trip uses `LeaderTier.values.byName(...)`**, not custom string parsing. The `name` getter returns the lowercase enum identifier (`'tier1'`, `'none'`). If `GameState.LeaderTier` ever renames a variant (it shouldn't), the round-trip would break — that's **correct** behavior because old saves SHOULD break per the project rule.

- **`reachedMilestones` is `Map<ContinentId, Set<int>>`.** The DB models this as a `(continentId, milestone)` composite-PK rows table. On read, group rows by `continentId`. On write, fan out one row per `(continentId, milestone)` pair. Empty sets produce ZERO rows (a continent with no milestones reached has no rows in `continent_milestones`).

- **`continents` table merges `unlockedContinents` and `continentCompletions`** into one row per continent. A continent missing from BOTH state maps is also missing from the DB. A continent in `unlockedContinents` only is `(unlocked: true, completed: false)`. A continent in `continentCompletions` only would be `(unlocked: false, completed: true)` — semantically nonsensical but the schema permits it; the mapper is permissive (doesn't reject) because that combination is unreachable through normal commands and the sim's `applyMilestones` only sets `completed: true` on continents already marked unlocked. **Don't add a CHECK constraint** for that invariant — the sim is the source of truth, not the schema.

- **`activeGoldens` table has NO foreign key to `countries`.** A country could theoretically be re-locked between spawn and claim (currently impossible per Story 5-1 AC #7c, but defensive). FK constraints would force schema-level enforcement of an invariant that belongs in the reducer. Document the decision in a one-line comment in the table file.

- **`active_golden_effect` is a singleton table (0 or 1 rows), not a column on `meta`.** Reasoning: the effect has 3 fields (`goldenId`, `multiplier`, `expiresAt`); inlining 3 nullable columns on `meta` is messier than a table whose row count IS the null-flag. The singleton CHECK constraint guards against accidental multi-row writes. **Pattern reusable for future singletons** (e.g. Story 5-2's `activeBoost`, Story 5-4's `dailyStreak`).

- **`AppDatabase.loadAll()` reads inside a `transaction(...)`** to ensure all tables are read at the same logical timestamp. Without the transaction, a concurrent `SaveRepository` write (Story 6-2) could interleave between two `select(...)` calls, producing inconsistent state. The transaction adds zero overhead on a serial test path.

- **`schema_backup_v2.sqlite` is created BEFORE the v3 migration runs** because `_backupDatabase(from)` is called at the top of `onUpgrade` (existing code lines 30–32). Do NOT move that call into the new `from <= 2 && to >= 3` branch — the existing v1→v2 branch still needs it for fresh-from-v1 upgrades (the file would be backed up to `schema_backup_v1.sqlite` first, then the v2→v3 branch runs but skips its own backup-call because `from == 1`). **Wait — re-read the existing code.** The current `_backupDatabase(from)` runs once per `onUpgrade` invocation with the starting `from`. For a v1-on-disk → v3 launch, `from == 1`, the backup is named `schema_backup_v1.sqlite`, then BOTH the v1→v2 and v2→v3 branches run in one `onUpgrade`. **This is the correct behavior** (only the pre-migration state is preserved). Story 6-3 adds typed `vN_to_vN+1` files but the per-version backup ladder isn't required until then.

- **Decimal precision at 1e38:** the existing `DecimalConverter` round-trip tests (lines 56–103 of `app_database_test.dart`) cover Decimal at `1e38` and beyond. Mapper inherits this — no new precision tests needed beyond the per-field smoke (`totalInfluence` with `1.234e38`).

- **`savedAt.isUtc` assertion:** per architecture line 233 and project-context.md line 122, `meta.lastSavedAt` is UTC ISO8601. Drift's `store_date_time_values_as_text: true` (build.yaml line 6) serializes `DateTime` to ISO8601, but **does not enforce UTC**. The mapper's assert is the only enforcement point. Story 6-2 must always pass `savedAt: clock.now().toUtc()`.

### Architecture compliance (non-negotiable)

- **`lib/game/` has ZERO new imports under this story.** This is a `lib/data/` story — the sim layer is unchanged. The mapper imports `lib/game/...` types but not vice versa.
- **`lib/data/database/tables/*` and `lib/data/database/converters/*` import NOTHING from `lib/game/`.** Enforced by `test/architecture/data_boundary_test.dart` (Task 6).
- **`GameStateMapper` is the SOLE bridge** between `lib/data/database/` and `lib/game/...`. Test 6.1(b) enforces this.
- **No raw SQL.** Typed Drift DSL only. The CHECK constraint in Tasks 1.1 / 1.8 is the lone exception (declared via `customConstraints: [...]`). It's a static schema annotation, not a runtime query — Drift treats it as DDL.
- **No `dart:io` in mapper or table files.** Already enforced by structure; only `app_database.dart` reaches `dart:io` (for `_backupDatabase`'s `File`).
- **No exceptions for control flow in mapper.** `fromRows` returns a `GameState` directly; on schema-level corruption (impossible-name enum, etc.) it throws — that's a programmer-error invariant, not a `Result.failure`. Story 6-6 owns the corruption-recovery UX path.
- **No `package:logging` calls in the mapper** — pure utility. (`AppDatabase` may log via `Logger('AppDatabase')` for migration steps if helpful; existing code does not, do not add for this story.)
- **Sealed switch exhaustiveness**: this story does NOT add a new `GameCommand` or `GameEvent` variant — no consumer switches break. (Story 6-2 will introduce `_OfflineEarningsApplied` event handling internally; not this story.)
- **`build.yaml` discipline:** `store_date_time_values_as_text: true` and `named_parameters: true` are pinned (lines 6–7). Do NOT change them; if a column needs a non-named-parameter API, override with `@JsonKey` on a per-column basis (no current need).

### Library / framework requirements

- `drift: ^2.26.1` (already pinned per pubspec / project-context.md line 33). All new tables use `package:drift/drift.dart`.
- `drift_dev: ^2.26.1` + `build_runner: ^2.4.14` for code generation. Run `dart run build_runner build --delete-conflicting-outputs` after any table change.
- `decimal: ^3.0.2` for `DecimalConverter` (already integrated).
- `package:meta/meta.dart` for `@immutable` on `GameStateRows`/`GameStateCompanions`.
- `package:sqlite3/sqlite3.dart` is a transitive dep (already imported in `app_database.dart` line 8 with `// ignore: depend_on_referenced_packages`). Tests in Task 7.1 that assert `SqliteException` on CHECK violations need the same import + ignore comment.
- **NO new dependencies.** Do not add `freezed`, `json_serializable`, or any DB-related package not already in `pubspec.yaml`.
- `path_provider: ^2.1.5` is unused by this story (mapper has zero filesystem access). The existing `app_database.dart`'s usage stays as-is.

### File structure requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/data/database/tables/meta_table.dart` | `Meta` singleton-row table (schema_version, last_saved_at, total_influence, golden_opportunity_multiplier, boost_multiplier) |
| `lib/data/database/tables/countries_table.dart` | `Countries` table mirroring `CountryState` |
| `lib/data/database/tables/continents_table.dart` | `Continents` table — union of unlocked + completed flags |
| `lib/data/database/tables/continent_milestones_table.dart` | `ContinentMilestones` table — composite PK `(continentId, milestone)` |
| `lib/data/database/tables/earned_achievements_table.dart` | `EarnedAchievements` table — id PK only |
| `lib/data/database/tables/active_global_upgrades_table.dart` | `ActiveGlobalUpgrades` table — id PK only |
| `lib/data/database/tables/active_goldens_table.dart` | `ActiveGoldens` table mirroring `ActiveGolden` |
| `lib/data/database/tables/active_golden_effect_table.dart` | `ActiveGoldenEffect` singleton-row table mirroring `ActiveGoldenEffect?` |
| `lib/data/mappers/game_state_rows.dart` | `GameStateRows` immutable bundle of read-side rows |
| `lib/data/mappers/game_state_companions.dart` | `GameStateCompanions` immutable bundle of write-side companions |
| `lib/data/mappers/game_state_mapper.dart` | Stateless `GameStateMapper` — `toCompanions(state, savedAt)` + `fromRows(rows, content)` |
| `test/architecture/data_boundary_test.dart` | Asserts table/converter purity + mapper-is-sole-bridge invariants |
| `test/data/mappers/game_state_mapper_test.dart` | Round-trip + per-field tests |
| `test/helpers/game_state_builder.dart` | `GameStateBuilder.fullyPopulated(content)` test helper (per project-context.md line 289) — only if not already present |
| `test/helpers/test_content_registry.dart` | Reusable `ContentRegistry` test fixture, factored out of `income_calculator_test.dart` lines 17–67 — only if not already present |

**Modify:**

| File | Change |
|---|---|
| `lib/data/database/app_database.dart` | `@DriftDatabase(tables: [...])` updated; `schemaVersion` 2 → 3; `onUpgrade` extended with `from <= 2 && to >= 3` branch; `loadAll()` method added |
| `lib/data/database/app_database.g.dart` | Regenerated by `build_runner` |
| `test/data/database/app_database_test.dart` | `schemaVersion` assertion 2 → 3; new tests per Task 7; comment block updated to reference Story 6-3 |

**Do NOT modify:**

- `lib/game/**` — sim layer is untouched.
- `lib/data/database/converters/decimal_converter.dart` — already complete and unit-tested.
- `lib/data/database/converters/crash_log_level_converter.dart` — orthogonal.
- `lib/data/database/tables/crash_logs_table.dart` — orthogonal.
- `lib/data/repositories/crash_log_repository.dart`, `lib/data/repositories/crash_log_entry.dart` — orthogonal.
- `lib/providers/**` — provider wiring lands in Story 6-2.
- `lib/services/**`, `lib/ui/**` — no UI/service surface in this story.
- `assets/data/*.json` — content tuning is orthogonal.
- `pubspec.yaml`, `build.yaml`, `analysis_options.yaml` — no dep / config changes.

### Testing requirements

- **Drift round-trip tests use `flutter_test`** (`NativeDatabase.memory()` requires `TestWidgetsFlutterBinding`). The mapper itself is pure Dart, but its round-trip test exercises Drift, so it lives under `test/data/mappers/` and uses `flutter_test`.
- **Pure-Dart unit tests for mapper logic that doesn't touch Drift** (e.g. `fromRows` empty-rows branch with hand-built `GameStateRows`) MAY use `package:test/test.dart`. Keep them in the same file as the round-trip tests for cohesion — `flutter_test` is a superset of `test`, so mixing is fine.
- **`AppDatabase` instances ALWAYS get `await db.close()` in `tearDown`.** Existing pattern (lines 19–21 of `app_database_test.dart`) — match exactly.
- **Test `GameState` construction goes through `GameStateBuilder`** (Task 8.10). Hand-rolled `GameState(...)` is permitted only inside the builder's implementation file.
- **Property-style round-trip test (Task 8.5)** is the headline test; it MUST cover every field listed in AC #5 in a single fully-populated state. Per-field smoke tests (Task 8.6) are defense-in-depth — they catch which field broke the round-trip when 8.5 fails.
- **Architecture tests (Task 6)** use static-analysis (regex over file contents). DO NOT execute the imports — the tests must run without booting any Drift / Flutter binding. Mirror `test/architecture/game_boundary_test.dart` structure.
- **No property tests required** for Decimal precision — `DecimalConverter` is already covered (lines 55–103 of `app_database_test.dart`).
- **Test count expectation:** ≈ 30–40 new tests; full suite lands at ≈ 580–595.

### Previous story intelligence

Direct guidance from the most recent `done` stories — **read these patterns into your implementation**:

- **Singleton-row CHECK pattern (NEW for Epic 6)**: `meta` and `active_golden_effect` use `IntColumn singletonId` with `customConstraints: ['CHECK (singleton_id = 0)']`. This is **the** pattern for at-most-one-row tables. Story 5-2 (`activeBoost`), Story 5-4 (`dailyStreak`), and Story 9-1 (`tutorialState`) will reuse it. **Do not invent a "single-row enforcement helper" abstraction now** — three sites is not enough to justify abstraction.

- **`copyWith` explicit-null sentinel pattern (from Story 4-1 Review Patch + Story 5-1)**: any nullable field that needs to be explicitly clearable uses an `Object _xxxUnchanged` sentinel. This is **purely a `GameState` concern** — the mapper never calls `copyWith`; it builds `GameState` directly via the constructor. **No sentinel work in this story.**

- **MapEquality / SetEquality discipline (from Story 4-1 / 4-3 / 5-1)**: `GameState.==` uses `MapEquality<...>` for nested maps. The round-trip test (Task 8.5) relies on `state1 == state2` working correctly — if `==` is broken on `GameState` for any new field, the round-trip test fails for the wrong reason. **No new equality work in this story** (every field already has equality wiring per Story 5-1 Task 4.4); just trust the existing `==`.

- **Tie-break by `id.value` ASC (from 4-2 / 4-5 / 5-1 Task 7.2 step 3 sub-bullet 4)**: when the mapper emits companions in a list, sort by `String` key/id ASC for test stability (Task 5.6). DB has no inherent order, but tests benefit.

- **Test fixture extraction (from 5-1 Tasks 12.2)**: Story 5-1 spotted that `_buildSingleCountryContent()` lives in `test/game/features/economy/income_calculator_test.dart` lines 17–67 and recommended copying. **Promote it to `test/helpers/test_content_registry.dart`** (Task 8.10) — by Story 6-1 the same fixture is needed in 4+ test files.

- **Deferred-test pattern (from Story 1-4)**: when a feature can't be exercised by `NativeDatabase.memory()` (e.g. real file backup, real cross-launch upgrade), document the deferral via top-of-file comment AND a stub test that asserts what IS testable. Existing pattern at `test/data/database/app_database_test.dart` lines 1–3 + 41–53. Match exactly for the v2→v3 onUpgrade test.

- **`GameStateBuilder` from project-context.md line 289**: project-context.md states "`GameStateBuilder` (under `test/helpers/`) is the canonical way to construct test states." **It does not yet exist.** Audit `git ls-files test/helpers/` confirms only `fake_clock.dart` (referenced in 5-1) and `country_path_builder.dart` (referenced in 5-1) exist. **This story is the right time to introduce `game_state_builder.dart`** (Task 8.10) — round-trip tests need a fully-populated `GameState`, and hand-construction is brittle. Future stories will extend the builder rather than re-roll fixtures.

- **Reducer-first-then-evaluators pattern (from 4-1 Task 4 / 5-1 Task 9.2)**: irrelevant here (no command in this story). Mentioned for completeness — Story 6-2 will hook the mapper into the event-driven save path; same `applyCommand` shape.

### Project structure notes

- **`lib/data/mappers/` is a new folder.** Architecture line 598 lists it as `mappers/      { game_state_mapper }`. Create the folder; this story populates it with three files (`game_state_mapper.dart`, `game_state_rows.dart`, `game_state_companions.dart`).
- **Table files live under `lib/data/database/tables/`** alongside the existing `crash_logs_table.dart`. Naming convention: `<plural_snake_case>_table.dart` matching the Drift `Table` subclass plural name.
- **Test mirror discipline:** `test/data/mappers/` mirrors `lib/data/mappers/`; `test/data/database/` already exists.
- **`test/helpers/` is the home for shared fixtures.** Architecture line 289 (project-context.md) mandates `GameStateBuilder` and `FakeClock` live here. Add `game_state_builder.dart` and `test_content_registry.dart` (if missing).
- **`test/architecture/` is the home for boundary invariant tests.** `game_boundary_test.dart` already exists; `data_boundary_test.dart` is added by this story.
- **No new providers in `lib/providers/`** — Story 6-2 owns the `gameStateMapperProvider` and `appDatabaseProvider` wiring.
- **No `package:drift` imports inside `lib/game/`** — the boundary holds. Even the `Decimal` type used in the schema lives in `lib/game/values/influence.dart`'s upstream dep (`package:decimal`), not via `lib/game/`.

### Project context rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`drift: ^2.26.1`, `drift_dev: ^2.26.1`, `build_runner: ^2.4.14`, `path_provider: ^2.1.5`, `path: ^1.9.0`** are pinned (line 33). DO NOT bump versions.
- **No raw SQL — always typed Drift DSL.** The `customConstraints: ['CHECK (singleton_id = 0)']` is a schema-level annotation, not a query; it is the lone permitted SQL string in this story.
- **Schema changes REQUIRE a new migration file under `lib/data/database/migrations/`. Never mutate an existing version.** This story bumps schemaVersion 2→3 by extending `MigrationStrategy.onUpgrade` in-place (the existing pattern from Story 1-4); the architectural mandate for separate `vN_to_vN+1.dart` files lands with Story 6-3 (typed migrations). **Do NOT create `migrations/v2_to_v3.dart` in this story** — Story 6-3 establishes the typed-migration scaffolding and will retroactively factor existing branches into it.
- **Big numbers stored as TEXT via `DecimalConverter`.** Already enforced; reuse the existing converter.
- **Write cadence is event-driven + debounced 2s `totalInfluence` snapshot. Never per-tick writes.** Story 6-2's concern; this story sets the schema up to support targeted row updates (each AC #6 round-trip uses `into(table).insert(...)` per row, which is the same primitive Story 6-2 will use for `update(table).where(...).write(...)`).
- **`schema_backup_v{n}.sqlite` must be copied BEFORE running the migration.** Already wired (existing `_backupDatabase(from)` call); no change needed.
- **`meta.lastSavedAt` (UTC ISO8601) is the offline clock source.** AC #5 + Task 5.5 enforce UTC.
- **Direction: `data/ → game/` (mappers convert DB rows to sim types). Reverse is forbidden.** The mapper's purpose is precisely to be that adapter. Architecture test (Task 6) enforces the boundary.
- **`lib/game/` has ZERO Flutter imports.** This story does NOT touch `lib/game/`.
- **No `freezed` / `json_serializable`.** `GameStateRows` and `GameStateCompanions` use manual constructors. No equality needed (consumed once per load/save).
- **No `riverpod_generator`.** No new providers in this story.
- **`schemaVersion` bump must be paired with a typed migration branch.** Done.
- **Drift-generated `.g.dart` files MUST be excluded from lint and committed.** Already configured in `analysis_options.yaml` (per project-context.md lines 333–335). Run `build_runner` and commit `app_database.g.dart`.
- **No `print()` anywhere.** Already enforced.
- **No `Random()` / `DateTime.now()` in `lib/game/`.** This story does NOT touch `lib/game/`.
- **`Decimal` outside `lib/game/values/` is a lint violation IN `lib/game/`** — the `Decimal` types in `lib/data/database/tables/*.dart` and the mapper are OUTSIDE `lib/game/` and are explicitly permitted (mappers are the converter layer between `Decimal` storage and `Influence` value-object usage).

### Backwards-compatibility note (project rule)

Per the project rule: **"backward compatibility is out of scope unless explicitly requested. Do not add migrations, versioning, or default-fallback logic to keep older saved games loading; it's acceptable for old saves to break and require a reset during development."**

The v2→v3 migration in this story creates new tables on top of the existing crash_logs schema. It does NOT preserve any user-side game state (there is none yet — pre-Epic-6 users had no game-state persistence). Future schema bumps (v3→v4 for Story 5-2's `totalIntel`, etc.) MAY break old saves; the player will get a fresh `initialSeed` via the `meta == null` branch (AC #7) on first launch after a clean install, OR via Story 6-6's "Start Fresh" path on a corrupted-but-recovered DB.

The `fromRows` "missing country in DB" defensive branch (Task 5.4 sub-bullet 2) is **NOT** a backwards-compatibility fallback — it's a defensive guard for content additions (e.g. Story 10-2 retunes content and adds a new country); the saved DB legitimately won't have that country yet, and we want the new country to appear locked rather than crash. This is forward-compatible content, not backward-compatible save format.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1: Drift Schema and `GameStateMapper`] — original ACs (lines 1116–1146)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2: Persistence Write Strategy] — downstream consumer (lines 1148–1178); confirms mapper API expectations
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3: Typed Migrations] — informs the deliberate decision to defer typed `vN_to_vN+1.dart` files (lines 1180–1198)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.4: Offline Earnings] — downstream consumer (lines 1200–1222); confirms `mapper.fromRows + meta.lastSavedAt` API expectations
- [Source: _bmad-output/game-architecture.md#4. Persistence — Drift 2.26] — schema list (line 229), big-number TEXT convention (230), write cadence (231), migration discipline (232), clock source (233)
- [Source: _bmad-output/game-architecture.md#Source-Tree] — `lib/data/database/tables/`, `lib/data/database/converters/`, `lib/data/mappers/` (lines 590–598)
- [Source: _bmad-output/project-context.md#Drift] — typed DSL, big-number TEXT, schema-change discipline, `schema_backup` ordering, `lastSavedAt` UTC contract (lines 114–122)
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] — "Modifying an existing schema version file. Always add a new migration." (line 362); "Drift-generated `*.g.dart` files must be excluded from lint and committed" (line 376)
- [Source: _bmad-output/project-context.md#Code Organization Rules] — "Drift: plural table (`Countries extends Table`), singular row class (`@DataClassName('Country')`), file = `countries_table.dart`" (line 242)
- [Source: _bmad-output/project-context.md#Testing Rules] — `GameStateBuilder` under `test/helpers/` (line 289); `NativeDatabase.memory()` for Drift tests (line 292)
- [Source: lib/game/game_state.dart] — every field that needs to round-trip; `initialSeed(content)` for empty-rows branch (lines 108–135)
- [Source: lib/game/features/countries/country_state.dart] — per-country fields that map into `Countries` table
- [Source: lib/game/features/goldens/active_golden.dart] — `ActiveGolden` shape mapping into `ActiveGoldens` table
- [Source: lib/game/features/goldens/active_golden_effect.dart] — `ActiveGoldenEffect` shape mapping into `ActiveGoldenEffect` singleton table
- [Source: lib/game/features/leaders/leader_tier.dart] — enum variants (`none`, `tier1`, `tier2`, `tier3`); use `LeaderTier.values.byName(...)` for round-trip
- [Source: lib/data/database/app_database.dart] — current schema version 2 baseline; existing `MigrationStrategy.onUpgrade` (lines 24–36); `_backupDatabase` (lines 38–48); pattern for `@DriftDatabase` annotation
- [Source: lib/data/database/converters/decimal_converter.dart] — reuse for all Decimal columns (already at lines 1–13)
- [Source: lib/data/database/tables/crash_logs_table.dart] — pattern for table file (`@DataClassName`, columns, no `lib/game/` imports)
- [Source: lib/data/repositories/crash_log_repository.dart] — pattern for typed Drift DSL (transaction, `into(...).insert(Companion.insert(...))`, `select(...).get()`)
- [Source: test/data/database/app_database_test.dart] — pattern for Drift in-memory tests; deferred-test comment block (lines 1–3); `tearDown` close pattern (lines 19–21)
- [Source: test/architecture/game_boundary_test.dart] — pattern for static-analysis architecture tests (mirror for new `data_boundary_test.dart`)
- [Source: test/game/features/economy/income_calculator_test.dart] — `ContentRegistry` fixture (lines 17–67); promote to `test/helpers/test_content_registry.dart`
- [Source: build.yaml] — `store_date_time_values_as_text: true`, `named_parameters: true` — pinned, do not change

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

