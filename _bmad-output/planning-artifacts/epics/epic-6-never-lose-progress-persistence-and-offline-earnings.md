# Epic 6: Never Lose Progress — Persistence and Offline Earnings

**Goal:** Deliver the Offline Respectful pillar. All state persists to Drift/SQLite with typed migrations and `schema_backup_v{n}.sqlite` snapshots. On resume, offline earnings are computed from Leader-automated countries only (8h cap, stable multipliers) and presented via the Offline Reward Modal before any other UI.

### Story 6.1: Drift Schema and `GameStateMapper`

As a developer,
I want a normalized Drift schema for all game state tables and a `GameStateMapper` that converts between `GameState` and Drift rows,
So that the simulation layer stays ignorant of persistence details and state round-trips losslessly.

**Acceptance Criteria:**

**Given** the Drift schema at the end of this story
**When** `dart run build_runner build` runs
**Then** generated code compiles cleanly for all listed tables: `meta`, `countries`, `leaders`, `upgrades`, `achievements`, `missions`, `boosts`, `goldens`, `daily_rewards`, `settings`, `crash_logs`, `tutorial_state`.

**Given** each table
**When** examined
**Then** it has a primary key, clear foreign-key relationships where applicable, and `big number` fields use TEXT columns with a `DecimalConverter`.

**Given** the `meta` table
**When** queried
**Then** it contains `schemaVersion`, `lastSavedAt` (UTC ISO8601), `totalInfluence`, `totalIntel`, `dailyStreak` (JSON), `tutorialCompleted` flag.

**Given** a fully-populated `GameState`
**When** `mapper.toRows(state)` is called
**Then** it returns typed Drift companion objects for every table in the schema.

**Given** a complete set of Drift rows from `AppDatabase.loadAll()`
**When** `mapper.fromRows(rows)` is called
**Then** it returns an equivalent `GameState` such that `mapper.toRows(mapper.fromRows(rows))` round-trips losslessly (unit-tested).

**Given** an empty database (first launch)
**When** `mapper.fromRows` is called
**Then** it returns the initial `GameState` seeded from `ContentRegistry`.

### Story 6.2: Persistence Write Strategy — Event-Driven Writes and Debounced Snapshot

As a developer,
I want the `SaveRepository` to persist targeted row updates per `GameEvent` and a 2-second debounced snapshot of currency totals,
So that saves happen with minimal DB churn and no per-tick writes.

**Acceptance Criteria:**

**Given** the event → table mapping
**When** a `CountryUnlocked` fires
**Then** the repository runs a typed Drift `update(countries).where(id = event.id).write(Companion(unlocked: Value(true), ...))`.

**Given** similar mappings for `UpgradePurchased`, `LeaderHired`, `LeaderUpgraded`, `ContinentUnlocked`, `ContinentCompleted`, `AchievementEarned`, `MissionCompleted`, `DailyRewardClaimed`, `BoostActivated/Expired`, `GoldenSpawned/Claimed/Expired`
**When** each fires
**Then** exactly the affected row(s) are written — no full-state dump.

**Given** per-tick events like `CountryTapped`
**When** they fire
**Then** they do NOT trigger a DB write (handled by the debounced snapshot below).

**Given** `totalInfluence` or `totalIntel` changes
**When** 2 seconds elapse without another change
**Then** a single `UPDATE meta SET totalInfluence = ?, totalIntel = ?, lastSavedAt = ?` fires.

**Given** rapid changes within the debounce window
**When** they occur
**Then** only one write executes at the end of the window.

**Given** the app transitions to `AppLifecycleState.paused`
**When** the lifecycle observer fires
**Then** any pending debounced write is flushed immediately before the ticker stops.

### Story 6.3: Typed Migrations and `schema_backup_v{n}.sqlite`

As a developer,
I want Drift's `MigrationStrategy` wired such that every schema version bump has a typed migration, and a backup `schema_backup_v{n}.sqlite` is copied before the migration runs,
So that migration failures are recoverable without data loss.

**Acceptance Criteria:**

**Given** a schema version bump from v1 to v2 in a future story
**When** the app launches on a v1 database
**Then** Drift opens the database, detects version mismatch, copies the current DB file to `schema_backup_v1.sqlite` in app documents, runs the typed `MigrationStrategy.onUpgrade`, and the database is at v2.

**Given** a migration throws
**When** caught
**Then** `GameError.migrationFailure(fromVersion, toVersion, cause)` is logged via CrashReporter and the app displays a Save Recovery screen with options to restore from `schema_backup_v1.sqlite` or start fresh (with a dire warning).

**Given** a successful migration
**When** complete
**Then** `schema_backup_v{n}.sqlite` from before the migration is retained (not deleted) for at least 3 subsequent launches as a safety net.

### Story 6.4: Offline Earnings Calculation on Resume

As a player,
I want my Leader-automated countries to have earned Influence while the app was closed (up to 8 hours), presented to me when I return,
So that closing the app feels respectful of my time.

**Acceptance Criteria:**

**Given** `meta.lastSavedAt` and an injected `Clock`
**When** the app enters `AppLifecycleState.resumed`
**Then** `OfflineCatchup.apply(state, clock)` runs before the first Riverpod rebuild past boot, computing `elapsed = min(clock.now() - lastSavedAt, Duration(hours: 8))`.

**Given** `elapsed > Duration.zero`
**When** catch-up runs
**Then** for each country with a Leader, `earned = IncomeCalculator.computeAutomatedRate(country, state) × elapsed.inSeconds` using STABLE multipliers only (IP × Leader × continent × achievement × globalUpgrades).

**Given** active Boosts or Goldens at pause time
**When** offline catch-up computes earnings
**Then** their multipliers do NOT apply offline (per architecture default). If a Boost was active and expires during the offline window, no partial-time credit is given.

**Given** offline earnings computed
**When** applied
**Then** a single `OfflineEarningsApplied(totalEarned, elapsed)` event fires and `totalInfluence` increments by `totalEarned`.

### Story 6.5: Offline Reward Modal On Resume

As a player,
I want a modal that shows how much Influence I earned while away when I return,
So that the reward is celebrated instead of silently appearing in my total.

**Acceptance Criteria:**

**Given** `OfflineEarningsApplied` event with `totalEarned > 0`
**When** the UI wakes on resume
**Then** the Offline Reward Modal is shown BEFORE any other UI interaction is possible (enters the modal queue at top priority per Epic 7 rules — this story requires only the modal widget + trigger; queue logic lives in Epic 7).

**Given** `totalEarned == 0` (e.g. no Leaders hired yet, or elapsed = 0)
**When** the resume path runs
**Then** the modal is NOT shown.

**Given** the Offline Reward Modal
**When** shown
**Then** it displays the formatted earned amount, elapsed duration, and a single "Collect" CTA that dismisses.

### Story 6.6: Save Recovery Path on Corrupt Database

As a player,
I want a clear path to recover if my save file becomes corrupt,
So that I don't silently lose progress or get stuck in a crash loop.

**Acceptance Criteria:**

**Given** `AppDatabase` fails to open with a corruption error
**When** boot runs
**Then** the app shows a "Save Recovery" screen with three options: (1) Restore from latest `schema_backup_v{n}.sqlite` if present, (2) Start Fresh (warned and confirmed twice), (3) Contact Support (copies the crash log to clipboard).

**Given** option (1) is selected and a backup exists
**When** restore runs
**Then** the corrupt DB is renamed to `app_v{n}_corrupt_{timestamp}.sqlite` for forensics, the backup is copied into place, and the app reloads.

**Given** no backup exists and the user chooses (2) Start Fresh
**When** confirmed twice
**Then** the corrupt DB is renamed with a timestamp, a fresh DB initializes from `ContentRegistry`, and the app proceeds.

---
