# Story 4.1: Unlock Next Country in Current Continent

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to spend Influence to unlock the next locked country in my current continent,
so that I can expand my influence footprint geographically.

## Acceptance Criteria

1. **Given** a country with `unlocked == false`, prerequisites met (its continent unlocked), and `state.totalInfluence >= def.unlockCost`
   **When** I dispatch `UnlockCountry(countryId)`
   **Then** the country's `unlocked` flag becomes `true`, its `ipLevel` becomes `1`, `bankedInfluence` is `Influence.zero`, `lastCollectedAt` is `null`, `state.totalInfluence` decreases by `def.unlockCost`, and a `CountryUnlocked(at, countryId, continent, cost)` event fires.
2. **Given** the content data is the source of truth for `unlockCost`
   **When** the reducer computes the cost
   **Then** it reads `CountryDef.unlockCost` directly — it does NOT recompute the `previousCountry × 5` formula at runtime. The 5× scaling is encoded in `assets/data/countries.json` (Epic 10 retunes there, not in code).
3. **Given** a country whose `def.continent` has `state.totalInfluence < continentDef.unlockThreshold` (continent not yet unlocked)
   **When** `UnlockCountry` is dispatched
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'continent_locked'))` and no state mutates. (Story 4.2 will add a persisted `unlockedContinents` set + `ContinentUnlocked` event; until then, the continent gate is the threshold check.)
4. **Given** the targeted country is already `unlocked == true`
   **When** `UnlockCountry` is dispatched
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'already_unlocked'))` and no state mutates.
5. **Given** `state.totalInfluence < def.unlockCost`
   **When** `UnlockCountry` is dispatched
   **Then** the reducer returns `Result.failure(GameError.userInsufficientFunds(required: Influence(def.unlockCost)))` and no state mutates.
6. **Given** a `CountryId` that is not present in `ContentRegistry.countries` (or `state.countries`)
   **When** `UnlockCountry` is dispatched
   **Then** the reducer returns `Result.failure(GameError.internalMissingCountry(id: cmd.countryId))`.
7. **Given** all countries in a continent have `unlocked == true`
   **When** I look for the next unlock in that continent
   **Then** there is no eligible target — `UnlockCountry` is never validly dispatched (the `nextUnlockInContinentProvider` from Story 4.5 returns `null`). This story does NOT implement that provider; it only guarantees the reducer rejects an already-unlocked target per AC #4.
8. **Given** a successful unlock
   **When** the next `gameWorld.tick(dt)` runs
   **Then** the newly unlocked country accrues banked influence at `IncomeCalculator.compute` rate × `dt` — no special-casing required, because `tickCountries` already gates on `country.unlocked` and the new state has `unlocked == true, ipLevel == 1`.

## Tasks / Subtasks

- [x] Task 1: Add `UnlockCountry({required CountryId countryId})` to `lib/game/game_command.dart` (AC: #1, #3, #4, #5, #6)
  - [x] Subtask 1.1: Mirror the shape of `HireLeader` / `TapCountry` (sealed `final class`, manual `==` / `hashCode` / `toString`).
  - [x] Subtask 1.2: Update `test/game/game_command_test.dart` with equality + `toString` coverage.
- [x] Task 2: Add `CountryUnlocked` to `lib/game/game_event.dart` (AC: #1)
  - [x] Subtask 2.1: Fields `{CountryId countryId, ContinentId continent, Influence cost}` plus inherited `at`. Manual `==` / `hashCode` / `toString`.
  - [x] Subtask 2.2: Update `test/game/game_event_test.dart`.
- [x] Task 3: Create `lib/game/features/continents/unlocks_reducer.dart` with `applyUnlockCountry(state, content, cmd, {required DateTime now})` (AC: #1, #3, #4, #5, #6)
  - [x] Subtask 3.1: Validate command shape (country exists in `state.countries` AND `content.countries`) → `MissingCountry`.
  - [x] Subtask 3.2: Already-unlocked guard → `Locked(reason: 'already_unlocked')`.
  - [x] Subtask 3.3: Continent-unlocked guard via `state.totalInfluence >= continentDef.unlockThreshold` → `Locked(reason: 'continent_locked')`. If `continentDef` is missing from content → `MissingCountry` (use the country's missing-from-content path, do NOT invent a new error variant).
  - [x] Subtask 3.4: Affordability check via `def.unlockCost` → `InsufficientFunds(required: Influence(def.unlockCost))`.
  - [x] Subtask 3.5: Build new `CountryState` with `unlocked: true, ipLevel: 1, leaderTier: LeaderTier.none, bankedInfluence: Influence.zero, lastCollectedAt: null` and new `GameState` with deducted `totalInfluence`. Emit `CountryUnlocked(now, countryId, def.continent, Influence(def.unlockCost))`.
- [x] Task 4: Wire `UnlockCountry` into `GameWorld.applyCommand` switch in `lib/game/game_world.dart` (AC: #1)
  - [x] Subtask 4.1: Add `_applyUnlockCountry(cmd)` helper following the `_applyHireLeader` template — adopt the same `result.map((tuple) { ... })` pattern, push state, emit event.
- [x] Task 5: Pure-Dart unit tests in `test/game/features/continents/unlocks_reducer_test.dart` (AC: #1, #3, #4, #5, #6)
  - [x] Subtask 5.1: Happy path (unlock nigeria from africa with enough Influence) — assert state mutation, event payload, and that totalInfluence decreased exactly by `def.unlockCost`.
  - [x] Subtask 5.2: Already-unlocked → `Locked('already_unlocked')`, no mutation.
  - [x] Subtask 5.3: Continent locked (use a test continent with `unlockThreshold > totalInfluence`) → `Locked('continent_locked')`, no mutation.
  - [x] Subtask 5.4: Insufficient funds → `InsufficientFunds(required: Influence(def.unlockCost))`, no mutation.
  - [x] Subtask 5.5: Missing country (id not in content) → `MissingCountry(id: ...)`.
  - [x] Subtask 5.6: Africa edge: `unlockThreshold = 0` means continent always unlocked; nigeria with `unlockCost = 5` and `totalInfluence = Influence(Decimal.fromInt(5))` succeeds (boundary `>=`).
- [x] Task 6: Integration test in `test/game/game_world_test.dart` (AC: #1, #8)
  - [x] Subtask 6.1: Dispatch `UnlockCountry` through `GameWorld.applyCommand`, observe state change AND emitted event on `world.events` stream.
  - [x] Subtask 6.2: After unlock, call `world.tick(Duration(seconds: 1))` and assert the newly unlocked country's `bankedInfluence` increased (proves AC #8 — no special-casing needed).
- [x] Task 7: Verify `CountryDef.unlockCost` is consumed correctly (AC: #2)
  - [x] Subtask 7.1: Confirm no NEW computation of "previous × 5" appears anywhere in `lib/game/`. Cost MUST come from `def.unlockCost`. Add a comment in the reducer if needed.
  - [x] Subtask 7.2: Optional: extend `test/architecture/no_duplicate_income_math_test.dart` is NOT in scope here (that test is income-specific); do not modify it.

### Review Findings

- [x] [Review][Patch] `lastCollectedAt` is not reliably cleared on unlock because `CountryState.copyWith` cannot represent explicit null (`lastCollectedAt ?? this.lastCollectedAt`); reducer intent in AC #1 can be violated for a locked state carrying stale `lastCollectedAt`. [lib/game/features/countries/country_state.dart:39]
- [x] [Review][Patch] AC #4 no-mutation test is tautological (`snap` aliases `afterFirst`), so it does not prove failed re-dispatch preserves state. [test/game/features/continents/unlocks_reducer_test.dart:135]
- [x] [Review][Patch] Negative `unlockCost` invariant branch exists but has no dedicated unit test, leaving that guard unverified. [test/game/features/continents/unlocks_reducer_test.dart:100]
- [x] [Review][Defer] `GameWorld.applyCommand` can partially commit state then throw when events stream is closed after `dispose()`; this predates story 4.1 and affects all command handlers. [lib/game/game_world.dart:117] — deferred, pre-existing

## Dev Notes

### Technical Requirements

- **Command:** `UnlockCountry({required CountryId countryId})` — sealed variant of `GameCommand`. Shape mirrors `HireLeader` exactly.
- **Event:** `CountryUnlocked(DateTime at, {required CountryId countryId, required ContinentId continent, required Influence cost})` — sealed variant of `GameEvent`. The architecture document (game-architecture.md §7) prescribes this exact name and payload shape.
- **Reducer signature:** `Result<(GameState, GameEvent?), GameError> applyUnlockCountry(GameState state, ContentRegistry content, UnlockCountry cmd, {required DateTime now})`. Identical to `applyHireLeader` for shape.
- **Cost source:** `CountryDef.unlockCost` (already populated in `assets/data/countries.json`: egypt=`"0"`, nigeria=`"5"`, south_africa=`"25"`). Wrap with `Influence(def.unlockCost)` for typed deduction. **Do NOT compute `previousCountry × 5` at runtime.**
- **Continent gate:** `state.totalInfluence >= continentDef.unlockThreshold`. Africa = 0 (always unlocked). For any country in africa, this check passes trivially.
- **Affordability check:** `state.totalInfluence < Influence(def.unlockCost)` → fail. Use `Influence` operator overloads, not raw `Decimal` comparison in the reducer.
- **State mutation:** `state.copyWith(countries: {...state.countries, cmd.countryId: newCountry}, totalInfluence: state.totalInfluence - cost)` — same pattern as `applyHireLeader`.

### Architecture Compliance

- **`lib/game/` is Pure Dart** — no `package:flutter/*`, no `dart:ui`. Reducer must compile under `dart test`, not `flutter test`.
- **Reducer purity** — no `DateTime.now()` (use `now` parameter), no `Random()`, no I/O. The pre-existing `now` parameter pattern (see `applyHireLeader`, `applyPurchaseUpgrade`) is mandatory.
- **Result pattern** — return `Result.success((newState, event))` / `Result.failure(GameError...)`. NEVER throw for control flow.
- **Sealed exhaustiveness** — adding `UnlockCountry` to `GameCommand` will trigger compile errors in every `switch (cmd)` site. The only one currently is `GameWorld.applyCommand`. Adding `CountryUnlocked` to `GameEvent` may break consumers if any new switches landed; check `lib/game/`, `lib/services/`, and `test/`.
- **Event emission** — only `GameWorld` emits via `_events.add(event)`. Services subscribe but never re-emit.
- **Big numbers** — `def.unlockCost` is `Decimal`; wrap once in `Influence` at the reducer boundary. Subtraction uses `Influence.operator -`.
- **No income math here** — this story does NOT add anything to `IncomeCalculator`. Cost is a pre-tuned content value, not a derived rate. Routing through `IncomeCalculator` would be misuse; the architecture test `test/architecture/no_duplicate_income_math_test.dart` enforces income math stays in `IncomeCalculator` — it does NOT require unlock costs to live there.

### Library / Framework Requirements

- `package:decimal/decimal.dart` — comparison and arithmetic on `def.unlockCost` (already in `pubspec.yaml`, `^3.0.2`).
- `package:test/test.dart` for `test/game/**` (NOT `flutter_test`).
- `package:meta/meta.dart` for `@immutable` on the new event class.
- No new `pubspec.yaml` entries.

### File Structure Requirements

**Create:**
- `lib/game/features/continents/unlocks_reducer.dart` — the reducer. Place under `continents/` (per game-architecture.md §System→Location Mapping: "Continent gating | `lib/game/features/continents/`"). Stories 4.2–4.4 will add sibling files in the same folder.
- `test/game/features/continents/unlocks_reducer_test.dart` — pure-Dart tests, mirrors source path.

**Modify:**
- `lib/game/game_command.dart` — add `final class UnlockCountry extends GameCommand` after `UpgradeLeader`.
- `lib/game/game_event.dart` — add `final class CountryUnlocked extends GameEvent` after `LeaderUpgraded`.
- `lib/game/game_world.dart` — extend the `switch (cmd)` in `applyCommand` and add `_applyUnlockCountry(cmd)` private method.
- `test/game/game_command_test.dart` — equality / hashCode / toString for `UnlockCountry`.
- `test/game/game_event_test.dart` — equality / hashCode / toString for `CountryUnlocked`.
- `test/game/game_world_test.dart` — integration: dispatch + tick after unlock.

**Do NOT modify:**
- `assets/data/countries.json` — content tuning is Epic 10 (the existing 3-country data is sufficient for tests; story 4.1 must work generically for any number of countries).
- `lib/game/game_state.dart` — no new fields. `Story 4.2` will add `unlockedContinents` (a `Set<ContinentId>` or `Map<ContinentId, bool>` mirroring `continentCompletions`); 4.1 derives the continent-unlocked predicate from `state.totalInfluence` + `continentDef.unlockThreshold` instead.
- `lib/game/features/economy/income_calculator.dart` — unlock cost is content data, not income math.
- `lib/game/config/balance.dart` — no new constants. The "× 5" scaling lives in JSON content.

### Testing Requirements

- **Pure Dart only for reducer tests** — `import 'package:test/test.dart';`, NOT `flutter_test`. Tests under `test/game/**` are headless; using `flutter_test` here is an architectural violation.
- **Test content fixture** — copy the `_content()` helper pattern from `test/game/features/leaders/leaders_reducer_test.dart` (lines 19–47). Two helpers needed: one with africa (threshold=0, always unlocked) and one with europe (threshold=1e9 — for the continent-locked path). Inline `jsonEncode([...])` is the established pattern.
- **State helper** — emulate the local `_egypt(...)` builder pattern from leaders test. Include `totalInfluence` parameter so each test can pin the affordability state precisely.
- **Coverage matrix (every AC must have a test):**
  - AC #1, #2, #8: happy path on nigeria + tick-after-unlock integration test.
  - AC #3: continent locked (use europe-fixture with `totalInfluence < 1e9`).
  - AC #4: re-dispatch on already-unlocked country.
  - AC #5: affordability boundary — `totalInfluence == cost - epsilon` fails, `totalInfluence == cost` succeeds (boundary `>=`).
  - AC #6: missing country id (`CountryId('atlantis')`).
- **Determinism** — tests pin `now` to a fixed `DateTime.utc(...)` and assert event `at` equals it.
- **No mutation on failure** — every failure-case test must `expect(state, equals(originalState))` to prove transactional semantics.

### Previous Story Intelligence

**From Story 3.3 (Leader Hire and Tier System) — closest analog:**
- Reducer template proven: `applyHireLeader` at `lib/game/features/leaders/leaders_reducer.dart` lines 13–75. Mirror its structure exactly: country lookup → unlocked guard → invariant guards → def lookup → cost computation → affordability check → state copy + event emission.
- Edge guards Code Review demanded (and that ship in `applyHireLeader`):
  1. `country == null` → `internalMissingCountry`
  2. Negative `ipLevel` invariant → `internalInvariantBroken` — **NOT applicable here** because we're unlocking from `ipLevel: 0` (or whatever locked state had); we're SETTING `ipLevel: 1` not reading it. Skip this guard.
  3. `def == null` → `internalMissingCountry`
  4. `def.baseInfluence <= Decimal.zero` invariant — **NOT applicable here** because unlock cost is independent of `baseInfluence`. Instead, validate `def.unlockCost >= Decimal.zero` (negative cost is an invariant violation; zero cost is legal — egypt has `unlockCost: "0"`).
- `GameWorld.applyCommand` integration pattern: see `_applyHireLeader` (lines 77–89). Copy verbatim, swap names. Reviewer will demand a `GameWorld.applyCommand(UnlockCountry)` test in `game_world_test.dart` (precedent: 3.3 review patch added that exact test for `UpgradeLeader`).

**From Story 3.2 (IP Upgrade) — secondary template:**
- The "no mutation on failure" assertion was a review patch demand. Pre-empt it by writing those `expect(state, equals(originalState))` checks in every failure-case test from the start.
- The reviewer flagged "Reject non-positive `baseInfluence` to prevent free/negative-cost upgrades". For 4.1, the analog is: reject negative `def.unlockCost`. Zero IS legal (egypt). So the guard is `def.unlockCost < Decimal.zero` → `internalInvariantBroken`.

**From Story 2.7 (Initial Seed):**
- Initial state seeds egypt as `unlocked: true, ipLevel: 1`. New unlocks must use the SAME shape: `ipLevel: 1` (not 0). This is consistent with AC #1 and ensures `IncomeCalculator.compute` returns non-zero on the first tick after unlock (since the multiplier is `1 + ipLevel × 0.1 = 1.1`, not `1.0`).

**From Story 2.5 (GameWorld tick drives generation):**
- `tickCountries` already short-circuits when `!state.unlocked` (`countries_reducer.dart` line 26). After unlock, no further work in the tick path is required — the very next `tick(dt)` will accrue. AC #8 falls out for free; just write a test that proves it.

### Project Structure Notes

- **Folder choice (`features/continents/` vs `features/countries/`):** game-architecture.md §System→Location Mapping pins "Continent gating" → `lib/game/features/continents/`. Country UNLOCKS are part of continent gating (the cost scaling, the threshold gate, milestones, completion bonus all live in continents/). Story 4.2 (`ContinentUnlocked` event), 4.3 (milestone rewards), and 4.4 (completion permanent multiplier) will all sit in `lib/game/features/continents/`. Place 4.1 there for cohesion. **Do NOT** create `lib/game/features/countries/unlocks_reducer.dart` — that conflicts with Epic 4 cohesion.
- **Filename:** `unlocks_reducer.dart` (plural) — Story 4.2 will likely extend or sibling this with continent-level unlock logic. The existing `countries_reducer.dart` (tick) and `leaders_reducer.dart` (hire/upgrade) precedent uses verb-domain naming; `unlocks_reducer.dart` follows.
- **No `nextUnlockInContinentProvider`** — that's Story 4.5. Do NOT add Riverpod providers in this story; `UnlockCountry` is dispatched by callers who already know the target id.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only. (Enforced by `test/architecture/game_boundary_test.dart`.)
- **UI never mutates `GameState` directly.** UI dispatches `UnlockCountry` via `ref.read(gameWorldProvider.notifier).apply(cmd)`. (UI wiring is out of scope for this story — Story 7.7 will wire the Upgrades tab.)
- **Reducers** — pure functions, `now` injected, return `Result<(NewState, Event), GameError>`, no exceptions for control flow.
- **Commands vs Events** — `UnlockCountry` (imperative, command) vs `CountryUnlocked` (past tense, event). Both are sealed-class hierarchy variants; every consumer's `switch` becomes non-exhaustive on add — fix all of them.
- **Big numbers** — `Influence` value object at the reducer boundary. Raw `Decimal` only inside the reducer for the `def.unlockCost` comparison and arithmetic. Never `double`.
- **Result / error handling** — `GameError.userLocked(reason: '...')` for `'continent_locked'` / `'already_unlocked'`. `GameError.userInsufficientFunds(required: Influence(def.unlockCost))` for affordability. `GameError.internalMissingCountry(id: cmd.countryId)` for content/state lookup misses. `GameError.internalInvariantBroken(message: '...')` for negative `unlockCost` (defense-in-depth).
- **Configuration discipline** — `def.unlockCost` is content data (`assets/data/countries.json` → loaded via `ContentRegistry`). Do NOT add a new constant to `BalanceConfig`. The "× 5" scaling factor is encoded in the JSON, not in code.
- **Logging** — none in the reducer (hot path budget). `assert(...)` for invariants if needed.
- **Sealed switch exhaustive** — when adding `UnlockCountry` and `CountryUnlocked`, the compiler will force every `switch` site to handle the new variant. Update `GameWorld.applyCommand` (the only `switch (cmd)` site today). Audit `switch (event)` sites — none in `lib/game/` today, but the compiler will flag any.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1] — original ACs and story statement
- [Source: _bmad-output/planning-artifacts/gdd.md#Content Breakdown] — continent thresholds (Africa=0 ... Oceania=1e38), 79 countries / 7 continents
- [Source: _bmad-output/planning-artifacts/gdd.md#Unlock System] — "Countries: Unlocked sequentially within a continent by spending Influence (cost = previous × 5)"
- [Source: _bmad-output/game-architecture.md#7. Event Bus] — `CountryUnlocked` event in the prescribed sealed hierarchy
- [Source: _bmad-output/game-architecture.md#1. Simulation Layering] — pure-Dart `GameWorld`, injected `Clock`, reducer/event pattern
- [Source: _bmad-output/game-architecture.md#System → Location Mapping] — continent-gating logic lives in `lib/game/features/continents/`
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — pure-Dart boundary, Result/error pattern, sealed exhaustive switch, big-number value objects
- [Source: lib/game/features/leaders/leaders_reducer.dart] — closest analog reducer; mirror its structure
- [Source: lib/game/features/upgrades/upgrades_reducer.dart] — secondary template, especially edge guard pattern
- [Source: lib/game/features/countries/countries_reducer.dart#L24-L29] — `tickCountries` already gates on `unlocked`; AC #8 is free
- [Source: assets/data/countries.json] — `unlockCost` already in data: egypt=0, nigeria=5, south_africa=25
- [Source: assets/data/continents.json] — africa.unlockThreshold=0; europe=1e9; etc.

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- Implemented `UnlockCountry` / `CountryUnlocked` / `applyUnlockCountry` and `GameWorld` wiring per story; cost from `CountryDef.unlockCost` only (comment in `unlocks_reducer.dart`); full `flutter test` passed (467 tests). Adjusted `game_event_test` switches to use `GameEvent` typing and canonical arm order to clear analyzer dead-code warnings.

### File List

- `lib/game/game_command.dart`
- `lib/game/game_event.dart`
- `lib/game/game_world.dart`
- `lib/game/features/continents/unlocks_reducer.dart`
- `test/game/game_command_test.dart`
- `test/game/game_event_test.dart`
- `test/game/features/continents/unlocks_reducer_test.dart`
- `test/game/game_world_test.dart`

### Change Log

- 2026-04-24: Story 4.1 — `UnlockCountry` command, `CountryUnlocked` event, `applyUnlockCountry` reducer, tests and `GameWorld` integration; `game_event_test` analyzer cleanup.
