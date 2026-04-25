# Story 4.3: Continent Milestone Rewards at 25/50/75/100%

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want rewards when I own 25%, 50%, 75%, and 100% of the countries in a continent,
so that I feel celebrated for making steady progress, not just final completion.

## Acceptance Criteria

1. **Given** a continent with `N` countries (`N == content.countries.values.where((c) => c.continent == continentId).length`) and the player owns `>= floor(tier/100 * N)` of them (where "owns" means `state.countries[id].unlocked == true` and `tier ∈ {25, 50, 75, 100}`)
   **When** the milestone evaluator runs after a state mutation
   **Then** the corresponding `MilestoneReached(continentId, percent, rewardType, rewardValue)` event fires exactly once per `(continentId, percent)` pair across the lifetime of the GameState (idempotent — never fires twice).

2. **Given** a `MilestoneReached` event with `rewardType == 'influence'`
   **When** the evaluator emits it
   **Then** `state.totalInfluence` increases by the `Influence` value parsed from the JSON `rewardValue` in the same state mutation (atomic with the milestone detection).

3. **Given** a `MilestoneReached` event with `rewardType == 'permanentMultiplier'` or any other non-`'influence'` type
   **When** the evaluator emits it
   **Then** the event fires with full payload but no side effect is applied to `totalInfluence` (effect application deferred to a later story; payload carries the data so a future consumer can apply it).

4. **Given** the 100% tier is crossed for a continent
   **When** the evaluator emits the `MilestoneReached(continentId, 100, ...)`
   **Then** a `ContinentCompleted(continentId)` event ALSO fires in the same microtask, ordered immediately after the `MilestoneReached(100)` event. (Story 4.4 will add the `state.continentCompletions[continentId] = true` flag flip and the multiplier hookup; this story does NOT mutate `continentCompletions`.)

5. **Given** multiple tiers cross simultaneously (e.g. ownership jumps from 20% to 60% in a continent with N=20 — 4 to 12 owned crosses both 25% and 50%)
   **When** the evaluator runs once
   **Then** all newly-crossed tiers fire in ascending percent order (25 before 50, 50 before 75, etc.), each appended to the event list and recorded in `state.reachedMilestones`.

6. **Given** the milestone evaluator runs on a state where the seed (Egypt unlocked, 1/19 of Africa = ~5%) was just loaded
   **When** no countries have been unlocked yet
   **Then** no `MilestoneReached` or `ContinentCompleted` events fire and `state.reachedMilestones` remains empty.

7. **Given** `GameState.initialSeed(content)` is called
   **When** building the initial state
   **Then** `state.reachedMilestones` is an empty unmodifiable `Map<ContinentId, Set<int>>` (no tiers pre-recorded — the seed is below all milestone thresholds by construction).

8. **Given** `assets/data/continents.json`
   **When** `ContentRegistry.fromJsonStrings` parses it
   **Then** every continent's `milestoneRewards` array contains exactly 4 entries with `percent` values `[25, 50, 75, 100]`, each with valid `rewardType` (currently only `'influence'` is wired) and a parseable `rewardValue` Decimal string. (Final tuned values land in Epic 10; this story populates placeholder values.)

9. **Given** `GameWorld.applyCommand` runs any command that succeeds and mutates state
   **When** the reducer returns
   **Then** the milestone evaluator runs against the post-reducer state, and any milestone events it produces are emitted on `events` AFTER the originating reducer's event AND AFTER any `ContinentUnlocked` events from Story 4.2's `_evaluateContinentUnlocks` helper (causal order: command-event → continent-unlock-events → milestone-events). Currently no command can change `unlocked` country flags, so this is a no-op in practice — Story 4.1's `UnlockCountry` will be the trigger. Wiring lands here so that 4.1's integration is automatic.

10. **Given** `GameWorld.tick` runs (idle accrual)
    **When** the tick completes
    **Then** the milestone evaluator does NOT run inside `tick()` — `tickCountries` only mutates `bankedInfluence`, never `unlocked`, so milestones cannot cross during a tick. (4.2's `_evaluateContinentUnlocks` DOES run in `tick()` because `totalInfluence` can cross continent thresholds via accrual; that is unrelated to milestones.)

## Tasks / Subtasks

- [x] Task 1: Add events to `lib/game/game_event.dart` (AC: 1, 4)
  - [x] Subtask 1.1: Add `MilestoneReached(at, continentId, percent, rewardType, rewardValue)` with `Decimal rewardValue` field, equality/hashCode/toString
  - [x] Subtask 1.2: Add `ContinentCompleted(at, continentId)` with equality/hashCode/toString
- [x] Task 2: Extend `lib/game/game_state.dart` with `reachedMilestones` (AC: 1, 6, 7)
  - [x] Subtask 2.1: Add field `final Map<ContinentId, Set<int>> reachedMilestones` (unmodifiable; outer map and inner sets both wrapped via `Map.unmodifiable` / `Set.unmodifiable`)
  - [x] Subtask 2.2: Wire through constructor, `copyWith`, `initialSeed` (default to empty), `==`, `hashCode`, `toString`
  - [x] Subtask 2.3: Use `MapEquality<ContinentId, Set<int>>` with a custom `SetEquality` for nested-set comparison — mirror the `_continentCompletionEq` / `_stringSetEq` patterns already in the file
- [x] Task 3: Create `lib/game/features/continents/milestones_reducer.dart` (AC: 1, 2, 3, 5, 6)
  - [x] Subtask 3.1: Implement `(GameState, List<GameEvent>) evaluateMilestones(GameState state, ContentRegistry content, DateTime now)`
  - [x] Subtask 3.2: Iterate `content.continents` in deterministic order (sort by continent id string for determinism); for each continent compute `total = count(content.countries where continent == id)`, `owned = count(state.countries where unlocked && def.continent == id)`
  - [x] Subtask 3.3: For each tier in `[25, 50, 75, 100]` (ascending): if `owned >= (tier * total / 100).floor()` AND `tier` not in `state.reachedMilestones[continentId]`, append the tier and emit `MilestoneReached`. Look up the matching `MilestoneReward` from `content.continents[id].milestoneRewards.firstWhere((r) => r.percent == tier)`. If `rewardType == 'influence'`, add `Influence(rewardValue)` to `totalInfluence`. At tier 100, also append `ContinentCompleted(now, id)` immediately after the `MilestoneReached(100)`.
  - [x] Subtask 3.4: Return `(newState, eventList)` — `newState` reflects updated `reachedMilestones` and any `totalInfluence` increases; `eventList` is empty when nothing crosses
  - [x] Subtask 3.5: Pure function — no `DateTime.now()`, no I/O, no exceptions for control flow (use `assert` only for programmer-error invariants)
- [x] Task 4: Wire evaluator into `lib/game/game_world.dart` (AC: 9, 10)
  - [x] Subtask 4.1: Add private helper `void _evaluateMilestones(DateTime now)` that calls `evaluateMilestones(_state, _content, now)`, assigns `_state = newState`, then emits each event in returned-list order via `_events.add(e)`
  - [x] Subtask 4.2: At the END of every successful `_apply*` helper (`_applyTapCountry`, `_applyPurchaseUpgrade`, `_applyHireLeader`, `_applyUpgradeLeader`, plus `_applyUnlockCountry` once 4.1 lands), call `_evaluateMilestones(_clock.now())` AFTER the originating event has been emitted AND AFTER 4.2's `_evaluateContinentUnlocks(_clock.now())` (if present). The call order matters: command-event → continent-unlock-events → milestone-events
  - [x] Subtask 4.3: Do NOT run `_evaluateMilestones` inside `tick()` — `tickCountries` only mutates `bankedInfluence`, never `unlocked`, so milestones never cross during tick. (Skip ticks for performance — milestone evaluation iterates all continents × all countries.)
  - [x] Subtask 4.4: If Story 4.2 has not yet landed when this story is implemented, add the call site as documented and leave a TODO referencing 4.2 for the continent-unlock evaluator slot. If 4.2 has landed, slot `_evaluateMilestones` immediately after the existing `_evaluateContinentUnlocks` call.
- [x] Task 5: Populate `assets/data/continents.json` milestoneRewards (AC: 8)
  - [x] Subtask 5.1: For every continent, replace the empty `milestoneRewards: []` with 4 entries: `{percent: 25/50/75/100, rewardType: 'influence', rewardValue: '<placeholder>'}`. Use placeholder values that scale with continent unlockThreshold (e.g., for Africa: 1e3 / 1e4 / 1e5 / 1e6; for Europe: 1e9 * 0.001 / 0.01 / 0.1 / 1.0; etc.). Mark as Epic 10 placeholders in this story's File List notes.
- [x] Task 6: Pure-Dart tests `test/game/features/continents/milestones_reducer_test.dart` (AC: 1, 2, 3, 5, 6, 7)
  - [x] Subtask 6.1: Use `package:test/test.dart` (NOT `flutter_test`) — `lib/game/` headless invariant
  - [x] Subtask 6.2: Build a small `ContentRegistry` via `ContentRegistry.fromJsonStrings` with a 4-country continent (so 25/50/75/100 land at exactly 1/2/3/4 owned) and one influence-type reward per tier
  - [x] Subtask 6.3: Test: empty seed → no events, no state change
  - [x] Subtask 6.4: Test: ownership jumps 0 → 1 fires only `MilestoneReached(25)` and grants influence
  - [x] Subtask 6.5: Test: ownership jumps 0 → 4 fires `MilestoneReached(25)`, `MilestoneReached(50)`, `MilestoneReached(75)`, `MilestoneReached(100)`, `ContinentCompleted` IN THAT ORDER
  - [x] Subtask 6.6: Test: replaying `evaluateMilestones` on the post-state emits zero events (idempotent — `reachedMilestones` prevents re-fire)
  - [x] Subtask 6.7: Test: `rewardType == 'permanentMultiplier'` does NOT mutate `totalInfluence` but still emits the event
  - [x] Subtask 6.8: Test: 100% milestone does NOT flip `state.continentCompletions[c]` (4.4's job)
  - [x] Subtask 6.9: Test: floor math — for N=19 (Africa), 25% threshold is `floor(0.25 * 19) = 4`, so 25% fires when 4 (not 5) countries are owned
  - [x] Subtask 6.10: Test: multi-continent — owning all of Africa AND all of Oceania emits 8 milestone events + 2 ContinentCompleted events; deterministic order across continents (sorted by `ContinentId.value`)
- [x] Task 7: Tests for `GameState.reachedMilestones` (AC: 7)
  - [x] Subtask 7.1: Add cases to `test/game/game_state_test.dart` (or create if missing) — `initialSeed` returns empty `reachedMilestones`; `copyWith` round-trips; `==` and `hashCode` reflect nested-set equality
- [x] Task 8: Update `test/game/game_event_test.dart` for the two new events (AC: 1, 4)
  - [x] Subtask 8.1: Verify equality, hashCode, toString cover all fields (`continentId`, `percent`, `rewardType`, `rewardValue` for `MilestoneReached`; `continentId` for `ContinentCompleted`)
- [x] Task 9: Update `test/game/game_world_test.dart` to verify wiring (AC: 9)
  - [x] Subtask 9.1: Construct a `GameWorld` with content where the seed already has 25% of a continent owned AND `state.reachedMilestones` is empty (use `GameWorld(initialState: ...)`); dispatch any successful command (e.g., `TapCountry` after seeding `bankedInfluence`); assert that `MilestoneReached(25)` is emitted on `events` AFTER the originating `CountryTapped` event
  - [x] Subtask 9.2: Confirm `tick()` does NOT trigger milestone events (ticks don't change `unlocked`)
- [x] Task 10: Run `flutter analyze` — must be zero warnings; `dart format --set-exit-if-changed .` — must pass

## Dev Notes

- **Sibling-story coordination (READ FIRST).** Stories 4.1, 4.2, 4.3 all land in `lib/game/features/continents/` and all touch `GameWorld`. Three parallel reducer files will exist:
  - `unlocks_reducer.dart` — Story 4.1 — `applyUnlockCountry` (the one command that mutates `unlocked` flags)
  - `continents_reducer.dart` — Story 4.2 — `evaluateContinentUnlocks` (mutates `state.unlockedContinents`, emits `ContinentUnlocked`)
  - `milestones_reducer.dart` — Story 4.3 — `evaluateMilestones` (mutates `state.reachedMilestones` and `state.totalInfluence`, emits `MilestoneReached` + `ContinentCompleted`) — **THIS STORY**
  Three independent state fields, no overlap: `unlockedContinents` (4.2) vs `continentCompletions` (already exists, flag-flipped in 4.4) vs `reachedMilestones` (4.3). Don't fold any of them together.
- **Strategic placement of evaluator wiring (Task 4):** This story prepares the infrastructure that Story 4.1 (`UnlockCountry`) will use. By wiring `_evaluateMilestones` into the post-reducer flow of every `applyCommand` branch now, 4.1's `applyUnlockCountry` reducer needs zero special handling — milestones automatically fire when its returned state has more `unlocked` countries than the prior state. Currently no existing command (`TapCountry`, `PurchaseUpgrade`, `HireLeader`, `UpgradeLeader`) flips `unlocked`, so the evaluator is a runtime no-op for them. The Task 9 test proves the wiring works by constructing an initial state that already has milestones pending.
- **`reachedMilestones` is the idempotency ledger.** It MUST be checked before emitting any `MilestoneReached`. Without it, every subsequent reducer call would re-fire the same events.
- **State mutation atomicity.** When the evaluator detects a tier crossing, it must update BOTH `reachedMilestones` (add the tier) AND `totalInfluence` (apply the reward) in the SAME returned `GameState`. Splitting these would create a race where re-running the evaluator on the intermediate state re-fires the event.
- **Decimal arithmetic for thresholds.** Use integer arithmetic for the floor comparison: `owned * 100 >= tier * total` is equivalent to `owned >= floor(tier * total / 100)` and avoids any decimal/double rounding. Use the integer form.
- **Continent enumeration order.** `content.continents` is a `Map<ContinentId, ContinentDef>` — iteration order is insertion order from the JSON file. For test determinism, sort the continent ids by `ContinentId.value` (lexicographic) before iterating in `evaluateMilestones`.
- **Why the 100% milestone fires `ContinentCompleted` here, not a 4.4 reactive handler:** Architecture rule — only `GameWorld` emits `GameEvent`s; services subscribe but never re-emit. So the source of the `ContinentCompleted` event must be a reducer/evaluator path. 4.3 is that path. 4.4 will add the state-flag flip (`state.continentCompletions[c] = true`) by extending this same evaluator.
- **`ContentRegistry.fromJsonStrings` already parses `milestoneRewards`** — see `lib/game/content/continent_def.dart` lines 7-30. The `MilestoneReward` class with `percent`, `rewardType`, `rewardValue` is in place; you only need to populate `assets/data/continents.json` and consume the parsed list in the evaluator.
- **`MilestoneReward.fromJson` throws `ContentLoadException` on parse failure** — the assertion in Task 5 (`exactly 4 entries with valid types`) is a CI safety net; keep the JSON schema correct.
- **Source tree components to touch:**
  - New: `lib/game/features/continents/milestones_reducer.dart`
  - New: `test/game/features/continents/milestones_reducer_test.dart`
  - Modified: `lib/game/game_event.dart`, `lib/game/game_state.dart`, `lib/game/game_world.dart`
  - Modified: `assets/data/continents.json`
  - Modified: `test/game/game_event_test.dart`, `test/game/game_world_test.dart`, optionally `test/game/game_state_test.dart`
- **Testing standards summary:**
  - Pure-Dart tests for `lib/game/` MUST use `package:test/test.dart` — never `flutter_test`
  - Build content via `ContentRegistry.fromJsonStrings` with inline JSON — see `test/game/features/leaders/leaders_reducer_test.dart` lines 19-47 for the canonical pattern
  - Pin clock with `DateTime.utc(2026, ...)` constants — never `DateTime.now()`
  - Use `Decimal.parse('...')` for rewardValue strings — never construct from `double`

### Project Structure Notes

- The `lib/game/features/continents/` folder is created by Story 4.1 (`unlocks_reducer.dart`) and 4.2 (`continents_reducer.dart`). Story 4.3 adds `milestones_reducer.dart` as the third sibling. See architecture spec at `_bmad-output/game-architecture.md` line 694 ("Continent gating: `lib/game/features/continents/`") and line 575. Folder name MUST be `continents/` (plural, snake_case).
- File name convention: `<feature>_reducer.dart` — matches `countries_reducer.dart`, `leaders_reducer.dart`, `upgrades_reducer.dart`.
- `_bmad-output/game-architecture.md` line 717 confirms `MilestoneReached` is a sealed `GameEvent` variant; line 266 lists both `MilestoneReached` and `ContinentCompleted` in the canonical event roster.
- Save persistence (Epic 6) is NOT in scope for this story — the `reachedMilestones` field is in-memory only. Per the project's "backward compatibility out of scope" rule, no migration concern.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` (the LLM-optimized rule digest). All apply directly to this story's tasks:

- **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. The new `milestones_reducer.dart` and any new game-layer code is pure Dart only.
- **Reducers are pure functions.** No clock reads, no RNG reads, no I/O. `now` flows in as a parameter (`DateTime now`). Return values communicate state and events; no exceptions for control flow.
- **Commands vs Events naming.** Events are past tense — `MilestoneReached`, `ContinentCompleted`. Both are sealed-class additions to the existing `GameEvent` hierarchy. Exhaustive `switch` consumers (e.g., audio service when wired in Epic 8) will need updates as a follow-on; for this story, document but do not block on absent consumers (no audio service exists yet — see `lib/services/` is currently empty for it).
- **Big numbers.** All game math flows through `Influence` / `Intel` value objects. The `MilestoneReached.rewardValue` field is `Decimal` (raw, since rewardType determines interpretation), but when applying the reward to `totalInfluence`, wrap as `Influence(rewardValue)` first.
- **`StreamController.broadcast(sync: true)`** is already configured in `GameWorld` — the multiple events emitted in Task 4.2 will all observe in the same microtask. Do not change this configuration.
- **Multiplier stack — single source of truth in `IncomeCalculator.compute`.** Do NOT add any income math to the milestone reducer. Influence rewards are direct additions to `totalInfluence`, NOT multipliers. Permanent-multiplier reward effects are out of scope for 4.3.
- **Event payloads are immutable snapshots.** All event field types must be value types (`String`, `int`, `ContinentId`, `Decimal`).
- **No `freezed`** — manual `==` / `hashCode` / `toString` on the new events, mirroring the `LeaderHired` pattern in `lib/game/game_event.dart` lines 87-114.
- **`GameStateBuilder` is the canonical test state builder under `test/helpers/`** — but it does not currently exist (only `fake_clock.dart` and `country_path_builder.dart`). For this story, follow the established `_egypt(...)` helper-function pattern from `test/game/features/leaders/leaders_reducer_test.dart` lines 49-68 to construct test states inline. Do NOT introduce a new shared helper just for this story.
- **`Result<T, GameError>` is for failable operations.** The milestone evaluator does NOT fail — it always returns `(GameState, List<GameEvent>)` directly. Use `Result` only if a failure path is meaningful (e.g., a missing continent in content → assert/invariant, not a Result).
- **`flutter analyze` zero warnings + `dart format` clean** are merge gates — Task 10.

### Previous Story Intelligence

From Story 3.3 (Leader Hire and Tier System — `_bmad-output/implementation-artifacts/3-3-leader-hire-and-tier-system.md`):

- **`GameWorld.applyCommand` extension pattern.** When adding new event emissions, the existing pattern is `result.map((tuple) { final (newState, event) = tuple; _state = newState; if (event != null) _events.add(event); });` — follow this exact shape, then add the milestone evaluator call after the `_events.add(event)` line for each `_apply*` helper. See `lib/game/game_world.dart` lines 54-103 for all four current helpers.
- **Reducer-level invariants pattern.** Story 3.3 added invariant guards (negative `ipLevel`, non-positive `baseInfluence`) returning `GameError.internalInvariantBroken`. The milestones evaluator should `assert` on impossible states (e.g., a country whose continent isn't in `content.continents`) rather than return errors — these are programmer bugs.
- **Event field equality.** Match the `LeaderHired` / `LeaderUpgraded` pattern (lines 87-143 of `game_event.dart`) — manual `==` checks every field, `Object.hash(...)` for `hashCode`, descriptive `toString()`.
- **Test deduplication learning from 2-7 review.** Avoid duplicate test cases that assert the same thing — each test must add unique coverage.
- **Code-review patches landed for 3.2 + 3.3** caught negative-`ipLevel` and non-positive-`baseInfluence` cases. For 4.3, similarly check: negative `total` (impossible from `Map.length`), zero `total` (continent with no countries — should be impossible per content schema, but the evaluator should skip without crashing).

### Git Intelligence

Recent commits (last 5):

- `be1fe53` — Game: leaders/upgrades, income & countries; tests; sprint artifacts; gds-code-review skill & dev loop
- `65efa28` — adding cursor support for bmad
- `e08c4d8` — chore: update settings, Flutter deps, BMAD skills reorganization, and sprint artifacts
- `9c804f9` — chore: add planning artifacts, dev loop scripts, and settings update
- `6992c42` — chore: add MCP servers config

Most recent code work (`be1fe53`) established the leaders + upgrades + economy reducer patterns this story will mirror. Mirror the file layout (`lib/game/features/<feature>/<feature>_reducer.dart`) and test layout (`test/game/features/<feature>/<feature>_reducer_test.dart`).

### Latest Tech Information

- `decimal: ^3.0.2` — `Decimal.parse('1e9')` accepts scientific notation (used in `continents.json` for Oceania). Verify your placeholder rewardValue strings parse cleanly via a quick `Decimal.parse('<value>')` smoke check before committing the JSON.
- `collection: ^1.19.1` — `MapEquality` and `SetEquality` are available; for nested-set comparison use `MapEquality<ContinentId, Set<int>>` with a custom equality combining `SetEquality<int>()`. Pattern already in use in `game_state.dart` line 14.
- Flutter SDK 3.41.6 / Dart 3.11.4 — sealed-class exhaustive switches will compiler-error on unhandled `MilestoneReached` / `ContinentCompleted` variants in any `case GameEvent` switch. There are currently no exhaustive event consumers in `lib/services/` (services aren't wired yet), so adding the variants will not break the existing build. Verify with `flutter analyze`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3] — original story definition (line 926)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4] — epic goal and cross-story context (line 878)
- [Source: _bmad-output/planning-artifacts/gdd.md#Continent Milestones] — design intent (line 497, line 191, line 475)
- [Source: _bmad-output/game-architecture.md#Event roster] — `MilestoneReached`, `ContinentCompleted` listed as canonical events (line 266)
- [Source: _bmad-output/game-architecture.md#System → Location Mapping] — `lib/game/features/continents/` is the canonical home (line 694)
- [Source: _bmad-output/project-context.md#Engine-Specific Rules] — pure-Dart, sealed events, no Flutter in `lib/game/`
- [Source: lib/game/content/continent_def.dart] — `MilestoneReward` content model already in place
- [Source: lib/game/features/leaders/leaders_reducer.dart] — canonical reducer pattern to mirror
- [Source: lib/game/game_world.dart] — `_apply*` helper pattern for wiring (lines 44-103)
- [Source: assets/data/continents.json] — must populate `milestoneRewards` arrays
- [Source: _bmad-output/implementation-artifacts/3-3-leader-hire-and-tier-system.md] — most recent reducer story; mirror its structure
- [Source: _bmad-output/implementation-artifacts/4-1-unlock-next-country-in-current-continent.md] — sibling story creating `unlocks_reducer.dart` + `UnlockCountry` command + `CountryUnlocked` event in the same folder. Coordinate event-emission ordering.
- [Source: _bmad-output/implementation-artifacts/4-2-unlock-continent-at-influence-threshold.md] — sibling story creating `continents_reducer.dart` + `evaluateContinentUnlocks` helper + `unlockedContinents` state field. Mirror its `Result<(GameState, List<GameEvent>), GameError>` return shape and its `_evaluateContinentUnlocks(now)` GameWorld helper pattern.

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- Implemented `MilestoneReached` and `ContinentCompleted` on `GameEvent`; `GameState.reachedMilestones` with nested `MapEquality` / `SetEquality`; pure `evaluateMilestones` in `milestones_reducer.dart` (sorted `ContinentId`s, integer threshold `owned >= (tier * total) ~/ 100`, skip `tier < 100` when required count is 0 to avoid degenerate single-country continents, skip continents with empty `milestoneRewards` so existing tests stay valid).
- `GameWorld`: `_evaluateMilestones` after successful commands, following `_evaluateContinentUnlocks`; `UnlockCountry` path runs continent unlocks again after apply then milestones. Milestones not evaluated in `tick()`.
- `assets/data/continents.json`: four `influence` milestone rows per continent (Epic 10 placeholders, scaled by tier progression).
- Tests: `milestones_reducer_test.dart`, `game_event_test` switches, `game_state_test` / `game_state_seed_test` for `reachedMilestones`, `game_world_test` wiring. Repo-wide `dart format .` applied; `flutter analyze` clean (const `UpgradePurchased`, `map_screen` curly braces for lint).

### Change Log

- 2026-04-24: Story 4.3 implemented — continent milestone rewards, events, state, wiring, JSON placeholders, tests; sprint status → review.

### File List

- `lib/game/game_event.dart`
- `lib/game/game_state.dart`
- `lib/game/game_world.dart`
- `lib/game/features/continents/milestones_reducer.dart` (new)
- `lib/ui/features/map/map_screen.dart` (lint: braces on if)
- `assets/data/continents.json` (Epic 10 placeholder `milestoneRewards` per continent)
- `test/game/features/continents/milestones_reducer_test.dart` (new)
- `test/game/game_event_test.dart`
- `test/game/game_state_test.dart`
- `test/game/game_state_seed_test.dart`
- `test/game/game_world_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md` (this file — status/tasks/agent record only)
- Additional files touched only by `dart format .` (no logic changes): `lib/game/features/continents/continents_reducer.dart`, `lib/game/features/leaders/leaders_reducer.dart`, `test/game/features/continents/continents_reducer_test.dart`, `test/game/features/continents/unlocks_reducer_test.dart`, `test/game/features/countries/countries_reducer_test.dart`, `test/game/features/economy/income_calculator_test.dart`, `test/game/features/leaders/leaders_reducer_test.dart`, `test/game/features/upgrades/upgrades_reducer_test.dart`, `test/game/game_command_test.dart`
