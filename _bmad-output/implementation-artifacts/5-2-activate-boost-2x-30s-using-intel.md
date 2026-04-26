# Story 5.2: Activate Boost (2× / 30s) Using Intel

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to spend Intel to activate a 30-second 2× Boost,
so that I can amplify a tap burst on my own schedule.

## Acceptance Criteria

1. **Given** `state.totalIntel >= BalanceConfig.boostCost` and `state.activeBoost == null` (or its `expiresAt` has already passed)
   **When** the dev agent (or UI later) dispatches `ActivateBoost()` and `applyActivateBoost` runs with `now = clock.now()`
   **Then** the reducer returns `Result.success((newState, BoostActivated))` where:
     - `newState.totalIntel == state.totalIntel - BalanceConfig.boostCost`
     - `newState.activeBoost == BoostState(multiplier: BalanceConfig.boostMultiplier, expiresAt: now.add(Duration(seconds: BalanceConfig.boostDurationSeconds)))`
     - The emitted event is `BoostActivated(now, multiplier: BalanceConfig.boostMultiplier, expiresAt: newState.activeBoost!.expiresAt, intelSpent: BalanceConfig.boostCost)`.

2. **Given** `state.activeBoost != null` and `state.activeBoost!.expiresAt.isAfter(now) == true` (i.e. a boost is genuinely active)
   **When** `applyActivateBoost` runs
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'boost_already_active'))` — boosts do not stack. State is unchanged. No event is emitted. (Refresh-or-queue behavior is explicitly deferred to Epic 10 if balance calls for it.)

3. **Given** `state.totalIntel < BalanceConfig.boostCost`
   **When** `applyActivateBoost` runs
   **Then** the reducer returns `Result.failure(GameError.userInsufficientIntel(required: BalanceConfig.boostCost))`. State is unchanged. No event is emitted. _(See Dev Notes "Locked-in decisions" → "Intel-aware error variant" for why this is a new sibling of `InsufficientFunds`, not the existing `InsufficientFunds` itself.)_

4. **Given** `state.activeBoost != null` and `!state.activeBoost!.expiresAt.isAfter(now)` (i.e. expiry has been reached or passed)
   **When** `evaluateBoostExpiry(state, now: now)` runs from `GameWorld.tick(...)`
   **Then** it returns `(state.copyWith(activeBoost: null), [BoostExpired(now)])`. The boost is cleared and `BoostExpired` is emitted on the events stream. After this, the next `IncomeCalculator.compute` call uses a 1.0 boost multiplier.

5. **Given** `IncomeCalculator.compute(country, state, content)` runs
   **When** `state.activeBoost == null`
   **Then** the boost slot in the multiplier stack contributes exactly `Decimal.one` (no behavior change vs. the current default).
   **And when** `state.activeBoost != null`
   **Then** the boost slot contributes exactly `state.activeBoost!.multiplier`. The boost stays last in the stack (slot 8/8) per `lib/game/features/economy/income_calculator.dart` documentation — order is unchanged.

6. **Given** `applyActivateBoost`, `evaluateBoostExpiry`, `BoostState`, `BoostActivated`, `BoostExpired`, `ActivateBoost`, and the new BalanceConfig constants
   **When** any of them are imported or read inside `lib/game/`
   **Then** they import only `package:meta/meta.dart`, `package:decimal/decimal.dart`, and other `lib/game/` modules. NO `package:flutter/*`, NO `dart:ui`, NO `lib/data/` imports. Enforced by `test/architecture/game_boundary_test.dart`.

7. **Given** `applyActivateBoost` and `evaluateBoostExpiry`
   **When** they are invoked
   **Then** they are pure functions: `now` is the only time source, no `DateTime.now()`, no `Random()`, no async, no I/O. They never log on the hot path. (Matches `lib/game/features/leaders/leaders_reducer.dart` and `lib/game/features/continents/milestones_reducer.dart` patterns.)

8. **Given** `GameWorld.tick(dt)` runs at wall-clock `_clock.now() = now`
   **When** the boost was active at the start of the tick but `state.activeBoost!.expiresAt <= now`
   **Then** the order of operations inside `tick(...)` is: (1) `_evaluateBoostExpiry(now)` first, (2) `tickCountries(...)` second (so the income generated this tick uses the post-expiry 1.0 multiplier — strictly correct), (3) `_evaluateContinentUnlocks(now)` third (existing), (4) emit a single `Tick(now)` if anything changed (`countriesChanged || continentEvents.isNotEmpty || boostExpiredThisTick`).

9. **Given** `ActivateBoost` is added to the `GameCommand` sealed hierarchy and `BoostActivated` / `BoostExpired` to the `GameEvent` sealed hierarchy
   **When** `flutter analyze` runs on the project
   **Then** every existing `switch` over `GameCommand` / `GameEvent` is updated to be exhaustive (only `GameWorld.applyCommand` switches on `GameCommand` today; events are pattern-matched in tests). Compiler errors from missing cases must be addressed in this story — no `default:` / `case _ =>` silencers in `lib/`.

10. **Given** `state.boostMultiplier: Decimal` (the legacy field) is replaced by `state.activeBoost: BoostState?` per the locked-in decision below
    **When** `IncomeCalculator.compute(...)` runs on a state with `activeBoost == null`
    **Then** the result is exactly `Decimal.one × ... × Decimal.one` for the boost slot — i.e. existing tests `5.10 boost isolation`, `5.11 composed stack order regression`, `5.14 zero baseInfluence → zero`, and `5.15 precision stress` continue to pass after their fixture builders are updated to use `activeBoost: BoostState(multiplier: ..., expiresAt: <future>)` instead of the deprecated `boostMultiplier:` named parameter.

_(UI rendering of the Boost button + "active" indicator lands in Epic 7 — this story provides commands, events, state, and the reducer only. No widgets are added here.)_

## Tasks / Subtasks

- [x] Task 1: Add Intel and active-boost fields to GameState (AC: #1, #4, #10)
  - [x] 1.1 In `lib/game/game_state.dart`, add `final Intel totalIntel` (default `Intel.zero`) — import `package:global_domination/game/values/intel.dart`.
  - [x] 1.2 In the same file, **replace** the existing `final Decimal boostMultiplier` field with `final BoostState? activeBoost` — drop the corresponding constructor param, copyWith param, equality, hash, toString fragment for `boostMultiplier`. Add `import '../features/boosts/boost_state.dart';` (the new file from Task 2).
  - [x] 1.3 Update `copyWith({...})` so it accepts `Intel? totalIntel` and `BoostState? activeBoost`. **Important:** because `activeBoost` is nullable AND can be cleared to null on expiry, follow the existing `lastCollectedAt` nullable-copyWith pattern in `lib/game/features/countries/country_state.dart` (use a sentinel object, OR use the named-param-with-`Object()`-default trick). Read `country_state.dart` first to mirror exactly.
  - [x] 1.4 Update `==`, `hashCode`, and `toString` to include `totalIntel` and `activeBoost`. Update the existing `test/game/game_state_test.dart` toString assertion (line 36) to match the new format.
  - [x] 1.5 Update `GameState.initialSeed(content)` to pass `totalIntel: Intel.zero` (explicit) and `activeBoost: null` (explicit).
  - [x] 1.6 **Backward compatibility is OUT OF SCOPE** per the project user rule — do NOT add migration paths, default-value fallbacks, or save-format guards. Old saves break and require a reset; that's accepted during development.

- [x] Task 2: Create the BoostState value class (AC: #1, #4, #10)
  - [x] 2.1 Create `lib/game/features/boosts/boost_state.dart` (NEW file; folder is also new — first file under `lib/game/features/boosts/`).
  - [x] 2.2 Define `@immutable class BoostState` with two final fields: `final Decimal multiplier; final DateTime expiresAt;` and a `const` constructor `const BoostState({required this.multiplier, required this.expiresAt});`.
  - [x] 2.3 Implement `==`, `hashCode`, `toString` manually (no `freezed`) — follow the pattern in `lib/game/features/continents/next_unlock_teaser.dart` and `lib/game/values/influence.dart`.
  - [x] 2.4 Imports: `package:meta/meta.dart` and `package:decimal/decimal.dart` only. NO Flutter, NO `dart:ui`, NO `lib/data/`.

- [x] Task 3: Add the ActivateBoost command (AC: #1, #2, #3, #9)
  - [x] 3.1 In `lib/game/game_command.dart`, add `final class ActivateBoost extends GameCommand` with no fields.
  - [x] 3.2 Implement a `const` zero-arg constructor, `==` (always true vs another `ActivateBoost`), `hashCode = runtimeType.hashCode`, and `toString => 'ActivateBoost()'` — mirror the `Noop` pattern at the top of the same file.

- [x] Task 4: Add BoostActivated and BoostExpired events (AC: #1, #4, #9)
  - [x] 4.1 In `lib/game/game_event.dart`, add `final class BoostActivated extends GameEvent` with fields: `final Decimal multiplier; final DateTime expiresAt; final Intel intelSpent;`. Constructor: `const BoostActivated(super.at, {required this.multiplier, required this.expiresAt, required this.intelSpent});`. Implement `==`, `hashCode`, `toString` — mirror `LeaderHired` (lines 89–116).
  - [x] 4.2 In the same file, add `final class BoostExpired extends GameEvent` with no extra fields. Constructor: `const BoostExpired(super.at);`. Implement `==`, `hashCode`, `toString` — mirror `Tick` (lines 15–27).
  - [x] 4.3 Import `package:global_domination/game/values/intel.dart` at the top of `game_event.dart` (next to the existing `influence.dart` import).
  - [x] 4.4 Do NOT add `IntelGained` / `IntelSpent` events in this story even though `_bmad-output/game-architecture.md` lines 264–266 list them as planned event types. Those are the responsibility of Story 5.3 (Missions) and Story 5.5 (Achievements), which actually grant Intel. The Intel SPEND in this story is captured fully by `BoostActivated.intelSpent`.

- [x] Task 5: Add the userInsufficientIntel error variant (AC: #3)
  - [x] 5.1 In `lib/game/game_error.dart`, add a new factory: `const factory GameError.userInsufficientIntel({required Intel required}) = InsufficientIntel;` next to the existing `userInsufficientFunds` factory.
  - [x] 5.2 Add a new `final class InsufficientIntel extends UserError` mirroring `InsufficientFunds` (lines 33–47): one final `Intel required` field, const ctor, manual `==`, `hashCode`, `toString`.
  - [x] 5.3 Import `package:global_domination/game/values/intel.dart` at the top of `game_error.dart` (currently it only imports `influence.dart`).
  - [x] 5.4 Do NOT modify `InsufficientFunds` or its `Influence required` field — existing reducers (`upgrades_reducer`, `unlocks_reducer`, `leaders_reducer`) all use it for Influence costs and must continue unchanged.

- [x] Task 6: Add Boost balance constants (AC: #1, #5, #10)
  - [x] 6.1 In `lib/game/config/balance.dart`, add `static final Intel boostCost = Intel(Decimal.fromInt(100));` (placeholder — Epic 10 retunes; do not change without Epic 10 coordination).
  - [x] 6.2 Add `static final Decimal boostMultiplier = Decimal.parse('2.0');` (placeholder — same Epic 10 caveat).
  - [x] 6.3 Add `static const int boostDurationSeconds = 30;` (placeholder — Epic 10).
  - [x] 6.4 Add `import 'package:global_domination/game/values/intel.dart';` at the top of `balance.dart` (next to the `decimal` import).
  - [x] 6.5 Document each constant with a one-line `///` comment matching the existing style ("Epic 10 retunes; do not change here without Epic 10 coordination.").

- [x] Task 7: Implement the boosts reducer (AC: #1, #2, #3, #4, #6, #7)
  - [x] 7.1 Create `lib/game/features/boosts/boosts_reducer.dart` (NEW file in the same folder as `boost_state.dart`).
  - [x] 7.2 Implement `Result<(GameState, GameEvent?), GameError> applyActivateBoost(GameState state, ActivateBoost cmd, {required DateTime now})`:
    - **Order of checks (lock this in — do NOT reorder):**
      1. If `state.activeBoost != null && state.activeBoost!.expiresAt.isAfter(now)` → `return const Result.failure(GameError.userLocked(reason: 'boost_already_active'));`
      2. If `state.totalIntel < BalanceConfig.boostCost` → `return Result.failure(GameError.userInsufficientIntel(required: BalanceConfig.boostCost));`
    - **Success path:**
      - Compute `expiresAt = now.add(Duration(seconds: BalanceConfig.boostDurationSeconds))`.
      - Build `final boost = BoostState(multiplier: BalanceConfig.boostMultiplier, expiresAt: expiresAt);`
      - `final newState = state.copyWith(totalIntel: state.totalIntel - BalanceConfig.boostCost, activeBoost: boost);`
      - `final event = BoostActivated(now, multiplier: BalanceConfig.boostMultiplier, expiresAt: expiresAt, intelSpent: BalanceConfig.boostCost);`
      - `return Result.success((newState, event));`
    - The reducer takes only `GameState` and `ActivateBoost cmd` — it does NOT take `ContentRegistry` (boost cost/duration/multiplier all come from `BalanceConfig`, not content JSON). Match the signature of `applyHireLeader` shape but drop the `ContentRegistry content` param.
  - [x] 7.3 Implement `(GameState, List<GameEvent>) evaluateBoostExpiry(GameState state, {required DateTime now})`:
    - If `state.activeBoost == null` → `return (state, const <GameEvent>[]);`
    - If `state.activeBoost!.expiresAt.isAfter(now)` → `return (state, const <GameEvent>[]);` (still active)
    - Otherwise → `return (state.copyWith(activeBoost: null), [BoostExpired(now)]);`
    - **Boundary rule:** `expiresAt == now` is treated as expired (consistent with "30s elapsed → boost ends"). The predicate `!expiresAt.isAfter(now)` covers `<=` cleanly.
    - Pure: no `DateTime.now()`, no `Random()`, no I/O. `now` is the only time source.
  - [x] 7.4 Imports: `package:global_domination/game/config/balance.dart`, `package:global_domination/game/features/boosts/boost_state.dart`, `package:global_domination/game/game_command.dart`, `package:global_domination/game/game_error.dart`, `package:global_domination/game/game_event.dart`, `package:global_domination/game/game_state.dart`, `package:global_domination/game/values/result.dart`. NO Flutter, NO `dart:ui`, NO `lib/data/`.
  - [x] 7.5 No income math — this reducer must NOT contain `def.baseInfluence *` or `country.baseInfluence *` patterns (would trip `test/architecture/no_duplicate_income_math_test.dart`).

- [x] Task 8: Wire ActivateBoost and boost-expiry into GameWorld (AC: #1, #2, #3, #4, #8)
  - [x] 8.1 In `lib/game/game_world.dart`, import `package:global_domination/game/features/boosts/boosts_reducer.dart`.
  - [x] 8.2 Modify `tick(Duration dt)` so the order of operations is **(1) expire boost → (2) tickCountries → (3) evaluateContinentUnlocks → (4) emit Tick if anything changed**:
    ```dart
    void tick(Duration dt) {
      assert(!dt.isNegative, 'tick dt must be non-negative, got $dt');
      assert(dt.inMilliseconds <= 100, 'tick dt should be clamped to 100ms');

      final now = _clock.now();
      final (boostExpiredState, boostEvents) =
          evaluateBoostExpiry(_state, now: now);
      final boostExpired = boostEvents.isNotEmpty;
      if (boostExpired) {
        _state = boostExpiredState;
        for (final e in boostEvents) {
          _events.add(e);
        }
      }

      final newCountries = tickCountries(_state, dt, _content);
      final countriesChanged = !identical(newCountries, _state.countries);
      if (countriesChanged) {
        _state = _state.copyWith(countries: newCountries);
      }

      final unlockRes = evaluateContinentUnlocks(_state, _content, now: now);
      // ... existing handling unchanged ...

      if (countriesChanged || continentEvents.isNotEmpty || boostExpired) {
        _events.add(Tick(now));
      }
    }
    ```
    Pin `now` once at the top of the method so all three evaluators see the same wall-clock instant.
  - [x] 8.3 In `applyCommand(GameCommand cmd)`, add `ActivateBoost() => _applyActivateBoost(cmd)` to the inner `switch` (next to `HireLeader()`, `UpgradeLeader()`). Keep the post-success `_evaluateContinentUnlocks` / `_evaluateMilestones` calls — they are idempotent and safe even though boost activation does not change country state.
  - [x] 8.4 Implement the private helper:
    ```dart
    Result<void, GameError> _applyActivateBoost(ActivateBoost cmd) {
      final result = applyActivateBoost(_state, cmd, now: _clock.now());
      return result.map((tuple) {
        final (newState, event) = tuple;
        _state = newState;
        if (event != null) _events.add(event);
      });
    }
    ```
  - [x] 8.5 Do NOT pass `ContentRegistry` to the boost reducer (it doesn't take one — see Task 7.2). Boost values come from `BalanceConfig`, not content.

- [x] Task 9: Update IncomeCalculator to read activeBoost (AC: #5, #10)
  - [x] 9.1 In `lib/game/features/economy/income_calculator.dart`, replace `rate *= state.boostMultiplier;` with `rate *= state.activeBoost?.multiplier ?? Decimal.one;`.
  - [x] 9.2 Update the docblock at the top: replace `8. × [GameState.boostMultiplier]` with `8. × (state.activeBoost?.multiplier ?? Decimal.one)` and add a one-line note: `// Boost slot: 1.0 when no active boost, else state.activeBoost!.multiplier.`
  - [x] 9.3 Do NOT change the order of slots 1–8 — Epic 11 balance tuning depends on it. The boost slot stays last.

- [x] Task 10: Update existing tests that reference `boostMultiplier` (AC: #10)
  - [x] 10.1 `test/game/features/economy/income_calculator_test.dart`:
    - In `_state(...)` helper (lines 133–149), replace the `Decimal? boostMultiplier` named param with `BoostState? activeBoost`. Pass it to the `GameState(...)` ctor as `activeBoost: activeBoost`.
    - Update test `5.10 boost isolation` (line 343) to pass `activeBoost: BoostState(multiplier: Decimal.parse('2'), expiresAt: DateTime.utc(2026, 5, 1))` (any future timestamp — the calculator does not check expiry; that's `evaluateBoostExpiry`'s job).
    - Update test `5.11 composed stack order regression` (line 354) similarly. The expected Decimal `2227.5` does NOT change — only the way the multiplier is supplied to the fixture changes.
    - Update test `5.14 zero baseInfluence → zero` (line 396) similarly.
    - Update test `5.15 precision stress` (line 414) similarly.
    - Add a NEW test: `boost slot is 1.0 when activeBoost == null` — pin every other multiplier to 1, set `activeBoost: null`, expect `Decimal.one`.
  - [x] 10.2 `test/game/game_state_test.dart`:
    - Update the `toString` assertion (line 36) to match the new field naming: e.g. drop `boostMultiplier: 1` and add `totalIntel: Intel(0)` and `activeBoost: null` in the expected string. Run the test once to capture the actual output, then pin it.
    - Add a new test group: `equality includes totalIntel` (mirror the `equality includes unlockedContinents` test at line 47).
    - Add a new test group: `equality includes activeBoost` — two states with the same `BoostState(multiplier, expiresAt)` are equal; differing `expiresAt` makes them unequal.
    - Add a new `copyWith clears activeBoost back to null` test — covers the nullable-copyWith sentinel pattern from Task 1.3.
  - [x] 10.3 `test/game/game_event_test.dart`: Add tests for `BoostActivated` and `BoostExpired`: equality (same `at + payload` → equal), `hashCode` consistency, `toString` includes all fields. Mirror existing `LeaderHired` and `Tick` test patterns.
  - [x] 10.4 `test/game/game_command_test.dart`: Add tests for `ActivateBoost`: two `const ActivateBoost()` instances are equal, share `hashCode`, `toString == 'ActivateBoost()'`. Mirror the existing `Noop` test pattern.
  - [x] 10.5 Do NOT touch `test/game/game_world_test.dart` lines 553+ existing applyCommand cases — only ADD new cases (Task 12).

- [x] Task 11: Pure-Dart unit tests for the boosts reducer (AC: #1, #2, #3, #4, #7)
  - [x] 11.1 Create `test/game/features/boosts/boosts_reducer_test.dart` using `package:test/test.dart` (NOT `flutter_test` — pure-Dart tests under `test/game/**` are an architectural invariant per `test/architecture/game_boundary_test.dart`).
  - [x] 11.2 Test happy path: starting state with `totalIntel: Intel(Decimal.fromInt(500))`, `activeBoost: null` → `applyActivateBoost(state, ActivateBoost(), now: t0)` returns `Result.success((newState, event))` with `newState.totalIntel == Intel(Decimal.fromInt(400))`, `newState.activeBoost!.multiplier == Decimal.parse('2.0')`, `newState.activeBoost!.expiresAt == t0.add(Duration(seconds: 30))`, and `event` is the expected `BoostActivated`.
  - [x] 11.3 Test `boost_already_active`: state with `activeBoost: BoostState(multiplier: 2.0, expiresAt: t0.add(Duration(seconds: 10)))` → `applyActivateBoost(state, ..., now: t0)` returns `Result.failure(GameError.userLocked(reason: 'boost_already_active'))`. State is structurally identical to input.
  - [x] 11.4 Test "expired-but-not-yet-cleared" edge: state with `activeBoost: BoostState(multiplier: 2.0, expiresAt: t0)` (i.e. expiresAt == now exactly) → `applyActivateBoost(state, ..., now: t0)` SUCCEEDS (re-activates) because `!t0.isAfter(t0) == true`. This is intentional — expiry boundary belongs to the new boost. Document this in a test name like `'allows re-activation when prior boost expiresAt == now (boundary)'`.
  - [x] 11.5 Test insufficient Intel: state with `totalIntel: Intel(Decimal.fromInt(50))` (less than 100), no active boost → returns `Result.failure(GameError.userInsufficientIntel(required: BalanceConfig.boostCost))`.
  - [x] 11.6 Test priority: state with both `activeBoost` (still active) AND `totalIntel < boostCost` → the reducer returns `boost_already_active` (the first check wins). Pin this so the dev agent doesn't "fix" it to insufficient-intel later.
  - [x] 11.7 Test purity: call `applyActivateBoost` twice with identical inputs → identical Result (proves no `DateTime.now()` / `Random()` calls).
  - [x] 11.8 Tests for `evaluateBoostExpiry`:
    - 11.8.a No active boost → `(state, [])`.
    - 11.8.b Active boost with `expiresAt > now` → `(state, [])`. State identity preserved.
    - 11.8.c Active boost with `expiresAt < now` → `(state.copyWith(activeBoost: null), [BoostExpired(now)])`.
    - 11.8.d Active boost with `expiresAt == now` (boundary) → expired (same as 11.8.c). Pin this.
    - 11.8.e After expiry: a follow-up `evaluateBoostExpiry(newState, now: ...)` returns `(newState, [])` — already cleared, idempotent.

- [x] Task 12: GameWorld integration tests (AC: #1, #2, #3, #4, #8)
  - [x] 12.1 In `test/game/game_world_test.dart`, add new tests under the existing `group('GameWorld.applyCommand', ...)`:
    - `applyCommand(ActivateBoost) succeeds when intel sufficient and no active boost` — assert state mutated AND `BoostActivated` event observed on the events stream.
    - `applyCommand(ActivateBoost) returns failure (locked) when boost already active`.
    - `applyCommand(ActivateBoost) returns failure (insufficientIntel) when intel below boostCost`.
    - `applyCommand(ActivateBoost) on success makes activeBoost.expiresAt = clock.now() + 30s`.
  - [x] 12.2 Add a new test group: `group('GameWorld.tick boost expiry', ...)`:
    - `tick clears active boost when expiresAt has passed and emits BoostExpired`. Build a `FakeClock` at `t0`, seed state with `activeBoost: BoostState(multiplier: 2.0, expiresAt: t0)` (so already expired), advance clock by `Duration(milliseconds: 100)`, call `tick(Duration(milliseconds: 100))`, assert `state.activeBoost == null`, assert one `BoostExpired` event AND one `Tick` event were observed.
    - `tick does NOT clear an unexpired boost`. Seed `activeBoost.expiresAt = t0 + 60s`, advance clock 100ms, tick — `state.activeBoost` unchanged, NO `BoostExpired` emitted.
    - `tick income generated AFTER boost expiry uses 1.0 multiplier`. Seed Egypt unlocked + ipLevel=0 + baseInfluence=1, `activeBoost.expiresAt = t0`, advance clock 1000ms, tick at 100ms intervals (10 ticks), assert `state.countries[egypt]!.bankedInfluence == Influence(Decimal.fromInt(1))` (NOT 2 — boost expired immediately at the start of the first tick). This is the strict-correct ordering test; if the dev agent reorders boost-expiry AFTER tickCountries, this test fails.
  - [x] 12.3 Build helper functions in the test file that seed states with non-zero Intel and known active-boost configurations. Follow the existing `_buildSingleCountryContent()` / `_seedAfricaUnlocked` / fake-clock fixtures already in the file (see lines 27–46, 19–25).

- [x] Task 13: BoostState value-class tests (AC: #1, #4, #6)
  - [x] 13.1 Create `test/game/features/boosts/boost_state_test.dart` using `package:test/test.dart`.
  - [x] 13.2 Test value semantics: two `BoostState` with same `(multiplier, expiresAt)` are `==` and share `hashCode`. Differing `multiplier` → `!=`. Differing `expiresAt` → `!=`.
  - [x] 13.3 Test `toString` includes both fields.

- [x] Task 14: Architecture compliance verification (AC: #6, #9)
  - [x] 14.1 Run `flutter test test/architecture/` — all tests must pass:
    - `game_boundary_test.dart`: New files in `lib/game/features/boosts/` MUST contain no `package:flutter/`, no `dart:ui`, no `lib/data/` imports.
    - `no_duplicate_income_math_test.dart`: `boosts_reducer.dart` and `boost_state.dart` must NOT match `def.baseInfluence *` / `country.baseInfluence *` / `baseInfluence * ratio` patterns. The boost reducer touches Intel and a multiplier constant only — no income math at all.
  - [x] 14.2 Confirm `IncomeCalculator.compute` (the only legal place for the multiplier stack) has been updated to read `state.activeBoost?.multiplier ?? Decimal.one` — no other source file should reference `state.activeBoost?.multiplier` for income purposes (UI-side reads in Epic 7 are a separate concern and out of scope).

- [x] Task 15: Full validation (AC: all)
  - [x] 15.1 `flutter analyze` — 0 warnings. Address every "missing case" warning the compiler raises from the new `ActivateBoost` / `BoostActivated` / `BoostExpired` variants in the existing exhaustive switches.
  - [x] 15.2 `dart format --set-exit-if-changed .` — clean.
  - [x] 15.3 `flutter test` — all tests pass (existing 512+ tests + the new boost suite).
  - [x] 15.4 Update `Status` to `review` and append entries to the Completion Notes / File List.

## Dev Notes

### Coordination with Epic 5 sibling stories (READ BEFORE STARTING)

**Sibling state at story creation time (2026-04-25):** Stories 5.1, 5.3, 5.4, 5.5 are all `ready-for-dev` but NOT YET implemented. This story (5.2) is implemented FIRST in implementation-slot order. That means:

- **`totalIntel` field ownership is THIS story.** Stories 5.3 (Missions) and 5.4 (Daily Rewards) each currently say "add `totalIntel` field" in their task lists, and Story 5.5 (Achievements) explicitly defers Intel currency mutation until "Story 5.2 adds `totalIntel`." When 5.3 or 5.4 is dev'd later, the agent will discover the field already exists and will skip the add-field tasks (their `totalIntel +=` reward-application logic still applies). **You are the canonical owner of `state.totalIntel`** — design it cleanly here.
- **`goldenOpportunityMultiplier` is Story 5.1's surface area, NOT yours.** That field already exists on `GameState` from Story 3.1's `IncomeCalculator` scaffolding (see `lib/game/game_state.dart` line 28). 5.1 will replace it with a richer `activeGoldenEffect` analogous to what 5.2 does for boosts. **Do NOT pre-touch `goldenOpportunityMultiplier`** — stay scoped to boost.
- **Stories 5.3 / 5.4 / 5.5 GAIN Intel; this story only SPENDS it.** To make 5.2 testable in isolation, the test fixtures construct `GameState(totalIntel: Intel(Decimal.fromInt(500)))` directly — there is no in-game way to earn Intel until 5.3+ ship after 5.2.
- **`boost_activated_count` mission condition** is referenced in Story 5.3 as "loads gracefully but stays pending until 5.2 lands." After this story merges, the mission delta-switch in 5.3 will be able to wire `BoostActivated` events to mission progress without further `lib/game/` changes.

### Locked-in decisions (DO NOT REDEBATE)

| Decision | Rationale | Where it shows up |
|---|---|---|
| **Replace `state.boostMultiplier: Decimal` with `state.activeBoost: BoostState?`** | The legacy field tracks "the number" but not the expiry instant. AC #4 mandates expiry-driven clearing, which requires `expiresAt` on state. Backward compat is OUT OF SCOPE per the project user rule, so a clean replacement (not an additive `boostExpiresAt` companion field) is the right call. | Task 1.2, Task 9, Task 10 |
| **`activeBoost` is nullable, cleared to `null` on expiry (not "muted to multiplier 1.0")** | Distinguishing "no boost" from "boost that just happens to be 1.0" preserves clear domain semantics for the UI later (Epic 7 needs to know whether to render the active-boost indicator). | Task 1.3, Task 7.3 |
| **Boundary `expiresAt == now` is treated as EXPIRED** | The 30s window is the open interval `[start, expiresAt)`. The predicate `!expiresAt.isAfter(now)` covers `<=` cleanly. | Task 7.3 (and tested in 11.4, 11.8.d) |
| **Boost-expiry runs BEFORE `tickCountries` in `tick()`** | The first tick AFTER a boost expires must use 1.0× multiplier — not 2.0×. Strict-correct ordering. AC #8 pins this. The tests in Task 12.2 will catch any reordering. | Task 8.2 |
| **`applyActivateBoost` does NOT take `ContentRegistry`** | Boost cost / multiplier / duration all come from `BalanceConfig` (not content JSON). Same precedent: `applyHireLeader` reads `BalanceConfig.leaderHireMinIpLevel` from `BalanceConfig`. | Task 7.2, Task 8.5 |
| **`boost_already_active` check fires BEFORE `insufficient_intel` check** | Pinned in AC #2 → AC #3 ordering. Test 11.6 enforces it. | Task 7.2 |
| **Intel-aware error variant `userInsufficientIntel({required Intel required})`** | The existing `InsufficientFunds.required` field is typed `Influence`; reusing it for Intel would silently lie about types. The architecture clearly anticipates Intel as a first-class currency (see `lib/game/values/intel.dart` and `_bmad-output/game-architecture.md` lines 30, 250, 266). Adding a sibling variant `InsufficientIntel` keeps `Influence`-typed reducers untouched and gives the future Intel-spending stories (5.3+) the same primitive. | Task 5 |
| **`BoostActivated` carries `intelSpent: Intel`; no separate `IntelSpent` event** | Architecture lists `IntelSpent` as a planned event (line 266) but it would duplicate `BoostActivated.intelSpent` here. Adding it now is forward-coupling without a payload differentiator. Story 5.3 (Missions) will earn Intel and will own the design call about whether `IntelGained` / `IntelSpent` become standalone events or stay as fields on the action-specific events. | Task 4.4 |
| **Boost folder is `lib/game/features/boosts/`** | Matches `_bmad-output/game-architecture.md` line 578 (`├── boosts/ { state, reducer }`). Aligns with the per-feature pattern: `lib/game/features/{countries,upgrades,leaders,continents}/`. | Task 2, Task 7 |
| **No UI in this story** | UI for the Boost button + active-boost HUD indicator lives in Epic 7 (see `_bmad-output/game-architecture.md` line 632: `hud/ { ..., active_boost_indicator }`). This story stops at the events stream — UI consumers (Epic 7) will subscribe later. | Story scope |
| **No persistence wiring in this story** | `state.totalIntel` and `state.activeBoost` are in-memory only here. Drift schema for `boosts` and `meta.totalIntel` columns lands in Story 6.1; the `BoostActivated` / `BoostExpired` event subscribers for save-write hooks land in Story 6.2. This story emits the events; Epic 6 listens. | Story scope |

### Architecture Compliance (non-negotiable)

- **`lib/game/` has ZERO Flutter imports.** New files (`boost_state.dart`, `boosts_reducer.dart`) MUST NOT import `package:flutter/*` or `dart:ui`. Use `package:meta/meta.dart` for `@immutable` and `package:decimal/decimal.dart` for math. Enforced by `test/architecture/game_boundary_test.dart`.
- **Reducers are pure functions.** `applyActivateBoost` and `evaluateBoostExpiry` take all inputs as parameters; no `DateTime.now()`, no `Random()`, no async, no I/O, no `Logger().info(...)`. The `now` parameter is the only time source.
- **Reducers return `Result<(GameState, GameEvent?), GameError>`** for command-style reducers (matches `applyHireLeader`, `applyPurchaseUpgrade`, `applyUnlockCountry`). For evaluator-style functions invoked from `tick()`, the convention is `(GameState, List<GameEvent>)` (matches `evaluateMilestones` at `lib/game/features/continents/milestones_reducer.dart`). `evaluateBoostExpiry` follows the evaluator convention.
- **Only `GameWorld` mutates `_state`.** Reducers return new states; `GameWorld._applyActivateBoost` and `GameWorld.tick` are the only mutators.
- **Sealed `switch` exhaustiveness.** Adding `ActivateBoost` to `GameCommand` will force `lib/game/game_world.dart`'s `switch (cmd)` (line 86) to update. Do NOT silence with `default:` / `case _ =>` — handle every variant explicitly. Adding `BoostActivated` / `BoostExpired` to `GameEvent` does NOT force any `switch` because nothing in `lib/` switches on event types yet (services do, but they're added in Epic 8); for now, just be sure tests that pattern-match events stay correct.
- **`Result<T, GameError>` (not exceptions) for control flow.** No `throw` in the reducer for user-error conditions. `GameWorld` may throw on programmer-error invariants — but boost activation has none in this story.
- **Big-number discipline.** All currency math goes through `Influence` / `Intel`. `state.totalIntel - BalanceConfig.boostCost` uses the `-` operator on `Intel` (already defined in `lib/game/values/intel.dart` line 18). Never use raw `Decimal` to compare currencies. `BoostState.multiplier` IS raw `Decimal` because it's a multiplier, not a currency — that's correct.
- **No income math here.** `applyActivateBoost` and `evaluateBoostExpiry` MUST NOT contain `def.baseInfluence *` or `country.baseInfluence *` patterns. The grep guard in `test/architecture/no_duplicate_income_math_test.dart` will fail CI otherwise. Boost just sets a multiplier on state; `IncomeCalculator.compute` reads it.
- **`StreamController.broadcast(sync: true)`** — events emit synchronously so subscribers see state and event in the same microtask. Don't change to async. (The events stream config is in `GameWorld` already; this story does not touch it.)
- **Event emission discipline.** Only `GameWorld` adds events to the stream. Reducers PRODUCE events (in their return tuple); `GameWorld` is what calls `_events.add(...)`. Same pattern as every existing reducer.

### Library / Framework Requirements

- `package:meta/meta.dart` — `@immutable` on `BoostState`. Already in transitive deps via `decimal`.
- `package:decimal/decimal.dart` — `BoostState.multiplier`, `BalanceConfig.boostMultiplier`. Pinned at `^3.0.2` in `pubspec.yaml`.
- `package:test/test.dart` — for pure-Dart tests under `test/game/features/boosts/`, `test/game/`. NEVER `flutter_test` for these.
- No new `pubspec.yaml` entries.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/features/boosts/boost_state.dart` | `BoostState` value class (`multiplier`, `expiresAt`) |
| `lib/game/features/boosts/boosts_reducer.dart` | `applyActivateBoost(...)` and `evaluateBoostExpiry(...)` — pure functions |
| `test/game/features/boosts/boost_state_test.dart` | Value-class equality / hash / toString |
| `test/game/features/boosts/boosts_reducer_test.dart` | Reducer unit tests (happy path, all failure modes, expiry, boundary, purity) |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add `Intel totalIntel`. Replace `Decimal boostMultiplier` with `BoostState? activeBoost`. Update copyWith / equality / hash / toString / initialSeed. |
| `lib/game/game_command.dart` | Add `ActivateBoost` final class. |
| `lib/game/game_event.dart` | Add `BoostActivated` (with `multiplier`, `expiresAt`, `intelSpent`) and `BoostExpired` (just `at`). Import `intel.dart`. |
| `lib/game/game_error.dart` | Add `userInsufficientIntel({required Intel required})` factory + `InsufficientIntel` final class. Import `intel.dart`. Do NOT modify `InsufficientFunds`. |
| `lib/game/config/balance.dart` | Add `boostCost: Intel`, `boostMultiplier: Decimal`, `boostDurationSeconds: int`. Import `intel.dart`. |
| `lib/game/features/economy/income_calculator.dart` | Replace `state.boostMultiplier` with `state.activeBoost?.multiplier ?? Decimal.one`. Update docblock slot 8. |
| `lib/game/game_world.dart` | Reorder `tick()` to expire boost first; add `ActivateBoost()` to `applyCommand` switch + `_applyActivateBoost` helper. Pin `now` once at the top of `tick()`. |
| `test/game/features/economy/income_calculator_test.dart` | Replace `boostMultiplier:` named param in `_state(...)` helper with `activeBoost:`. Update tests 5.10, 5.11, 5.14, 5.15. Add a `null activeBoost → 1.0` test. |
| `test/game/game_state_test.dart` | Update `toString` assertion (line 36). Add tests for `totalIntel` and `activeBoost` equality / copyWith-clears-to-null. |
| `test/game/game_event_test.dart` | Add `BoostActivated` and `BoostExpired` equality / hashCode / toString tests. |
| `test/game/game_command_test.dart` | Add `ActivateBoost` equality / hashCode / toString tests. |
| `test/game/game_world_test.dart` | Add `applyCommand(ActivateBoost)` cases. Add `group('GameWorld.tick boost expiry', ...)` with the post-expiry-1x-income test. |

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` _multiplier-stack ordering_ — only the boost slot's source changes; slot order is frozen for Epic 11.
- Any file under `lib/data/` or `lib/ui/` — out of scope (Epic 6, Epic 7).
- `assets/data/*.json` — boost values come from `BalanceConfig`, not content JSON. `assets/data/global_upgrades.json` etc. are content tuning (Epic 10).
- `lib/providers/*.dart` — no provider needed in this story; UI consumers in Epic 7 will read `state.activeBoost` via `gameWorldProvider` directly (or add a `.select`-based provider then).
- `lib/game/game_state.dart` continent / unlock fields — owned by Epic 4 stories, all `done`.
- `lib/game/features/continents/*.dart` — orthogonal, out of scope.

### Testing Requirements

- **Pure-Dart reducer tests** use `package:test/test.dart` (NOT `flutter_test`). Mirror the established pattern in `test/game/features/leaders/leaders_reducer_test.dart` and `test/game/features/upgrades/upgrades_reducer_test.dart`.
- **No `ContentRegistry` fixture is needed** for `applyActivateBoost` tests (the reducer doesn't read content). For `GameWorld.tick` integration tests, reuse `_buildSingleCountryContent()` already in `test/game/game_world_test.dart` lines 27–46.
- **Determinism:** every test that depends on time uses `FakeClock(DateTime.utc(...))` from `test/helpers/fake_clock.dart`. Never `DateTime.now()` in tests for `lib/game/`.
- **Property tests:** Not required for this story (the math is trivial — Intel subtraction and a multiplier constant). `IncomeCalculator` precision/composition property tests at line 414 of `test/game/features/economy/income_calculator_test.dart` continue to cover the boost slot under the new state shape.
- **Cross-story regression coverage:** Tests `5.10`, `5.11`, `5.14`, `5.15` in `income_calculator_test.dart` MUST pass after the migration to `activeBoost`. Their expected `Decimal` values (e.g. `2227.5` in test 5.11) do NOT change — the math is identical, only the data plumbing on `GameState` differs.
- **No widget tests** for this story — UI lives in Epic 7.
- **No integration tests** added — `integration_test/` covers golden-path and offline catch-up; boost activation will be covered there once Epic 7 wires the UI button.

### Reference reducer skeleton (do NOT reinvent)

```dart
// lib/game/features/boosts/boosts_reducer.dart
import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> applyActivateBoost(
  GameState state,
  ActivateBoost cmd, {
  required DateTime now,
}) {
  final current = state.activeBoost;
  if (current != null && current.expiresAt.isAfter(now)) {
    return const Result.failure(
      GameError.userLocked(reason: 'boost_already_active'),
    );
  }
  if (state.totalIntel < BalanceConfig.boostCost) {
    return Result.failure(
      GameError.userInsufficientIntel(required: BalanceConfig.boostCost),
    );
  }

  final expiresAt = now.add(
    Duration(seconds: BalanceConfig.boostDurationSeconds),
  );
  final boost = BoostState(
    multiplier: BalanceConfig.boostMultiplier,
    expiresAt: expiresAt,
  );
  final newState = state.copyWith(
    totalIntel: state.totalIntel - BalanceConfig.boostCost,
    activeBoost: boost,
  );
  final event = BoostActivated(
    now,
    multiplier: BalanceConfig.boostMultiplier,
    expiresAt: expiresAt,
    intelSpent: BalanceConfig.boostCost,
  );
  return Result.success((newState, event));
}

(GameState, List<GameEvent>) evaluateBoostExpiry(
  GameState state, {
  required DateTime now,
}) {
  final boost = state.activeBoost;
  if (boost == null) return (state, const <GameEvent>[]);
  if (boost.expiresAt.isAfter(now)) return (state, const <GameEvent>[]);
  return (state.copyWith(activeBoost: null), [BoostExpired(now)]);
}
```

(Pseudocode — adjust the nullable-`activeBoost` copyWith to whatever pattern Task 1.3 settles on. The `state.copyWith(activeBoost: null)` call assumes the sentinel pattern is implemented; without it, that line clears no field.)

### Reference: nullable-copyWith sentinel pattern (Task 1.3)

The existing `CountryState.copyWith(...)` at `lib/game/features/countries/country_state.dart` already deals with nullable fields — `lastCollectedAt: DateTime?` can be set or cleared. Read that file first and **mirror it exactly** for `activeBoost`. The sentinel pattern, briefly:

```dart
GameState copyWith({
  // ... existing params ...
  Intel? totalIntel,
  Object? activeBoost = _sentinel,
}) {
  return GameState(
    // ... existing assignments ...
    totalIntel: totalIntel ?? this.totalIntel,
    activeBoost: identical(activeBoost, _sentinel)
        ? this.activeBoost
        : activeBoost as BoostState?,
  );
}

const _sentinel = Object();
```

If `country_state.dart` uses a different idiom, follow that. Consistency > novelty.

### Project Structure Notes

- **Folder choice (`lib/game/features/boosts/`):** matches `_bmad-output/game-architecture.md` line 578. First file under this folder; future Epic 5 + 6 stories may add `boosts_persistence.dart` etc.
- **Provider file location:** none in this story. UI consumers in Epic 7 will read `state.activeBoost` via `gameWorldProvider` (probably with `.select(...)` to avoid rebuilding the HUD on every tick).
- **No conflict** with existing folders — `lib/game/features/economy/` (where `IncomeCalculator` lives) reads boost state but does not own it; it stays read-only of `state.activeBoost?.multiplier`.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` has ZERO Flutter imports.** New files MUST NOT import `package:flutter/*` or `dart:ui`. Pure Dart only. (Enforced by `test/architecture/game_boundary_test.dart`.)
- **UI never mutates `GameState` directly.** This story adds a new command (`ActivateBoost`); future UI in Epic 7 will dispatch it via `ref.read(gameWorldProvider.notifier).apply(const ActivateBoost())`. Never instantiate `BoostState` directly from UI.
- **Reducers are pure functions.** NO clock reads, NO RNG reads, NO I/O. `applyActivateBoost` and `evaluateBoostExpiry` take `now` as a parameter.
- **Multiplier stack is single source of truth in `IncomeCalculator.compute`.** This story only changes the SOURCE of slot 8 (from `state.boostMultiplier` to `state.activeBoost?.multiplier ?? Decimal.one`). Slot order is frozen.
- **Big numbers:** Intel currency flows through the `Intel` value class (`lib/game/values/intel.dart`). Never use raw `Decimal` for currency comparisons. Never use `double` for any game quantity.
- **Configuration discipline:** Boost cost / multiplier / duration are `BalanceConfig` constants — not content JSON. Epic 10 will retune; do not add to `assets/data/`.
- **No `freezed`, no `json_serializable`, no `riverpod_generator`.** Manual value-class boilerplate; raw `Result`, raw `Provider`.
- **Sealed `switch` exhaustiveness:** Adding `ActivateBoost` will force `GameWorld.applyCommand`'s `switch` to update. Adding `BoostActivated` / `BoostExpired` does not currently force any switch in `lib/`, but it WILL once Epic 8's `AudioService` lands — that's that story's problem, not this one.
- **Logging:** `package:logging` only. Reducers MUST NOT log on the hot path. Use `assert(...)` for invariants instead.
- **Result / error handling:** `Result<T, GameError>` (sealed) for fallible operations. NO exceptions for control flow. `userLocked` for state-blocked failures, `userInsufficientIntel` (NEW) for currency shortfall.
- **Drift / persistence:** Out of scope for this story. Story 6.1 (Drift schema) and 6.2 (event-driven write hooks) will subscribe to `BoostActivated` / `BoostExpired` and persist via typed Drift DSL.
- **Testing:** `test/game/**` uses `package:test/test.dart` (never `flutter_test`). `GameStateBuilder` for fixtures is preferred when it exists; for now, hand-construct `GameState(...)` since this is the canonical pattern in the existing reducer tests.
- **MCP `dart` tools** are available — prefer them over shell `dart` / `flutter` invocations during analysis and test runs.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.2: Activate Boost (2× / 30s) Using Intel] — original ACs and story statement (lines 1022–1044)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5: Active Play — Goldens, Boosts, Missions, Dailies, Achievements] — epic goal and intel-economy framing (lines 986–989, 313–315)
- [Source: _bmad-output/planning-artifacts/gdd.md#Resources] — Influence vs Intel currency roles (lines 440–460)
- [Source: _bmad-output/game-architecture.md#7. Event Bus] — sealed `GameEvent` hierarchy lists `BoostActivated`, `BoostExpired`, `IntelGained`, `IntelSpent` (lines 264–266)
- [Source: _bmad-output/game-architecture.md#12. DI & Multiplier Stack Ordering] — multiplier stack with `boostMultiplier` as slot 8 (lines 306–322); confirms order is authoritative and frozen
- [Source: _bmad-output/game-architecture.md#§System→Location Mapping] — `lib/game/features/boosts/ { state, reducer }` (line 578)
- [Source: _bmad-output/game-architecture.md#Open Question Q6-offline] — Boosts/Goldens do NOT apply during offline catch-up (line 326); reinforces that boost-expiry is a tick-time concern, not an offline-time one
- [Source: _bmad-output/project-context.md#Engine-Specific Rules (Flutter / Dart)] — pure `lib/game/`, sealed hierarchies, multiplier stack, command/event naming
- [Source: _bmad-output/project-context.md#Multiplier stack — THE single source of truth] — slot 8 documentation (lines 99–112)
- [Source: _bmad-output/project-context.md#Subtle gotchas] — "Boosts and Goldens do NOT apply during offline catch-up" (line 370)
- [Source: lib/game/game_state.dart] — current state shape; `boostMultiplier: Decimal` field at line 29 to be replaced
- [Source: lib/game/game_command.dart] — `Noop` (lines 7–18) and `HireLeader` (lines 60–75) patterns for the new `ActivateBoost`
- [Source: lib/game/game_event.dart] — `Tick` (lines 15–27) for `BoostExpired` skeleton; `LeaderHired` (lines 89–116) for `BoostActivated` skeleton
- [Source: lib/game/game_error.dart] — `InsufficientFunds` (lines 33–47) for the new `InsufficientIntel` skeleton
- [Source: lib/game/values/intel.dart] — `Intel` value class with `<` `-` `==` already defined; reuse directly
- [Source: lib/game/config/balance.dart] — placeholder pinning convention for new boost constants
- [Source: lib/game/features/leaders/leaders_reducer.dart] — `applyHireLeader` pattern for command-style reducer returning `Result<(GameState, GameEvent?), GameError>`
- [Source: lib/game/features/continents/milestones_reducer.dart] — `evaluateMilestones` pattern for evaluator-style reducer returning `(GameState, List<GameEvent>)`
- [Source: lib/game/features/economy/income_calculator.dart] — slot-8 (`state.boostMultiplier`) read site at line 48; the ONLY line that changes
- [Source: lib/game/game_world.dart] — `tick(Duration dt)` (lines 36–65) and `applyCommand(GameCommand cmd)` (lines 67–99) for the wiring changes
- [Source: lib/game/features/countries/country_state.dart] — nullable-field copyWith pattern (`lastCollectedAt: DateTime?`) for the new `activeBoost: BoostState?` copyWith
- [Source: lib/game/features/continents/next_unlock_teaser.dart] — recent immutable value-class pattern with manual `==` / `hashCode` / `toString` (added by Story 4.5)
- [Source: test/game/features/leaders/leaders_reducer_test.dart] — reducer unit-test fixture pattern using `package:test/test.dart` and `ContentRegistry.fromJsonStrings(...)`
- [Source: test/game/features/upgrades/upgrades_reducer_test.dart] — `_egyptState({...})` and `_content({...})` helper pattern (lines 19–67)
- [Source: test/game/features/economy/income_calculator_test.dart] — `_state({...})` test-state builder (lines 133–149) — must be updated to swap `boostMultiplier:` → `activeBoost:`
- [Source: test/game/game_world_test.dart] — `_buildSingleCountryContent()` and `FakeClock` integration pattern (lines 19–46)
- [Source: test/architecture/game_boundary_test.dart] — boundary invariants enforced by tests (no Flutter imports under `lib/game/`)
- [Source: test/architecture/no_duplicate_income_math_test.dart] — grep guard against duplicate income math (boost reducer must NOT match `def.baseInfluence *` patterns)
- [Source: _bmad-output/implementation-artifacts/4-5-next-unlock-teaser-data-on-state.md#File Structure Requirements] — reference for "create + modify + do NOT modify" structure used in this story
- [Source: _bmad-output/implementation-artifacts/3-3-leader-hire-and-tier-system.md] — last consolidated Epic 3 story; `LeaderHired` event payload pattern reused in `BoostActivated`

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

### Completion Notes List

- Implemented Story 5.2: `GameState` now has `totalIntel` and `activeBoost` (replaces `boostMultiplier`); `BalanceConfig` boost cost/duration/multiplier; `applyActivateBoost` / `evaluateBoostExpiry` in `lib/game/features/boosts/boosts_reducer.dart`; `GameWorld.tick` runs `evaluateBoostExpiry` before `tickCountries` and includes `boostExpired` in `Tick` emission; exhaustive switches updated in tests and `game_error_test` for `InsufficientIntel`. Full suite, `flutter analyze`, `dart format`, and `test/architecture/` all green (2026-04-26).

### File List

- lib/game/features/boosts/boost_state.dart
- lib/game/features/boosts/boosts_reducer.dart
- lib/game/config/balance.dart
- lib/game/game_state.dart
- lib/game/game_command.dart
- lib/game/game_event.dart
- lib/game/game_error.dart
- lib/game/features/economy/income_calculator.dart
- lib/game/game_world.dart
- test/game/features/boosts/boost_state_test.dart
- test/game/features/boosts/boosts_reducer_test.dart
- test/game/features/economy/income_calculator_test.dart
- test/game/game_state_test.dart
- test/game/game_event_test.dart
- test/game/game_command_test.dart
- test/game/game_error_test.dart
- test/game/game_world_test.dart
- _bmad-output/implementation-artifacts/5-2-activate-boost-2x-30s-using-intel.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-04-26: Story 5-2 implementation complete → review (boosts feature: state, command, events, reducers, GameWorld wiring, tests, analyze+format)
- 2026-04-25: Story 5-2 created → ready-for-dev (ActivateBoost command, BoostActivated/BoostExpired events, BoostState value class, applyActivateBoost + evaluateBoostExpiry reducers in lib/game/features/boosts/, GameState.totalIntel + activeBoost replacing boostMultiplier, GameError.userInsufficientIntel variant, BalanceConfig boost constants, IncomeCalculator slot 8 source change, GameWorld.tick boost-expiry-first ordering)
