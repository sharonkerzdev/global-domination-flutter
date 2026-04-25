# Story 5.3: Missions Cycle Rotating Objectives Rewarding Intel

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a small set of rotating missions ("tap 50 countries," "collect 1M influence," "unlock 2 countries") visible in a Missions UI,
so that I have short-term goals that pay Intel for active engagement.

## Acceptance Criteria

1. **Given** the mission catalog in `assets/data/missions.json` with data-driven conditions and `BalanceConfig.missionCatalogSize` defines the number of concurrently-active mission slots (set to `3` for this story)
   **When** `GameState.initialSeed(content)` is called
   **Then** `state.activeMissions` is populated with EXACTLY `BalanceConfig.missionCatalogSize` `MissionState` entries, each cloned from the FIRST `missionCatalogSize` `MissionDef`s in `content.missions` declaration order with `progress = 0`, `target` and `rewardIntel` copied from the def. If `content.missions.length < missionCatalogSize`, fill all available slots and leave the remainder unfilled (do NOT throw — degrade gracefully so missing/empty mission JSON during early development does not break the seed).

2. **Given** an active `MissionState(id: m, progress: p, target: t, rewardIntel: r)` and a `GameEvent` is emitted that matches the mission's data-driven condition predicate (e.g. `CountryTapped` advances a `tap_countries_n` mission by `+1`; `UpgradePurchased` advances a `purchase_upgrades_n` mission by `+1`; a `CountryUnlocked` event advances `unlock_countries_n` by `+1`)
   **When** the mission evaluator runs IMMEDIATELY AFTER the originating event is appended in `GameWorld.applyCommand`
   **Then** the matching mission's `progress` is set to `min(p + delta, t)`. If `progress >= t`, a `MissionCompleted(missionId: m, rewardIntel: r)` event fires AND `state.totalIntel` increases by `Intel(r)`, both atomically with the progress update.

3. **Given** a `MissionCompleted` event has just fired for slot `i` of `state.activeMissions`
   **When** the mission rotation logic runs in the same evaluator pass
   **Then** the completed slot is replaced by the NEXT eligible `MissionDef` from `content.missions`, where eligible = not currently active in any other slot AND not already in `state.completedMissionIds`. The catalog scan starts from the index AFTER the just-completed mission's catalog position and wraps around once. If NO eligible mission exists (catalog exhausted relative to `completedMissionIds`), the slot is REMOVED from `activeMissions` (length decreases) — do NOT throw, do NOT leave a stale entry. A `MissionRotated(oldMissionId, newMissionId?)` event fires (with `newMissionId == null` if the slot was retired).

4. **Given** multiple active missions match the same triggering event in the same evaluator pass (e.g. two simultaneous `tap_countries_n` missions)
   **When** the evaluator runs
   **Then** EVERY matching mission's progress advances by the same `+delta`, in slot order (index 0 first). If two missions complete in the same pass, both `MissionCompleted` events fire in slot order, both Intel rewards are added to `totalIntel`, and rotation runs once for each completion before the next event is processed.

5. **Given** a `GameEvent` is emitted that matches NO active mission's condition (e.g. `Tick` events)
   **When** the evaluator runs
   **Then** no progress changes, no events fire, and the returned state is identical to the input state (`identical(next, state)` is true) so callers can early-return without mutating `_state`.

6. **Given** the mission catalog has 5 missions and `missionCatalogSize == 3`, and the player completes mission #1 (catalog index 0)
   **When** the rotation runs
   **Then** the new slot 0 is filled by catalog index 3 (the first non-active eligible def — assuming indices 1 and 2 are still active and index 3 is not in `completedMissionIds`). Subsequent completion of mission #2 (catalog index 1) draws catalog index 4. After index 4 also completes with no more eligible defs, the slot is retired (length 2).

7. **Given** any condition type in `assets/data/missions.json` that this story has NOT yet wired to a real `GameEvent` (e.g. `golden_claimed_count` before Story 5.1 lands; `boost_activated_count` before Story 5.2 lands; `stay_active_seconds`)
   **When** the evaluator processes an event
   **Then** missions with unwired condition types load successfully into `activeMissions`, never advance progress (the condition predicate returns `0` delta for every event), but ALSO never throw or log errors — they simply remain pending until the corresponding event source ships.

8. **Given** `GameState.initialSeed` is called
   **When** the seed is built
   **Then** `state.totalIntel == Intel.zero` AND `state.completedMissionIds` is an empty unmodifiable `Set<String>` AND `state.activeMissions` is an unmodifiable `List<MissionState>`. All three fields participate in `==`, `hashCode`, `toString`, and `copyWith`.

9. **Given** any `applyCommand` succeeds
   **When** the mission evaluator runs (after milestone evaluator from Story 4.3, which is already wired in `GameWorld._evaluateMilestones`)
   **Then** the causal event order on the `events` stream is: `command-event → continent-unlock-events → milestone-events → mission-completion-events → mission-rotated-events`. Mission events ALWAYS come last so downstream subscribers see the fully-reconciled state.

10. **Given** `GameWorld.tick` runs (idle accrual emitting `Tick` and possibly `ContinentUnlocked` events)
    **When** the tick completes
    **Then** the mission evaluator DOES run inside `tick()` BUT is gated to react ONLY to events that can advance a mission (currently `ContinentUnlocked` from tick — `Tick` itself never advances any mission per AC #5). Per-tick mission evaluation MUST be a no-op when no eligible-condition events fire (`identical(next, state)` short-circuits — see AC #5) so the tick hot path stays under budget.

11. **Given** a `MissionDef` exists in `content.missions` with `id = X` AND `state.completedMissionIds` already contains `X`
    **When** `seedActiveMissions` runs (or rotation backfills)
    **Then** that def is SKIPPED — completed missions never re-enter the active slate within the same `GameState` lifetime. (Resetting `completedMissionIds` is out-of-scope; Epic 10 may add a "weekly reset" later.)

12. **Given** `assets/data/missions.json`
    **When** `ContentRegistry.fromJsonStrings` parses it
    **Then** the file contains AT LEAST `BalanceConfig.missionCatalogSize + 2` entries (so rotation can be exercised end-to-end), each with valid `id` (unique, lowercase-snake-case), `name` (display text — Epic 10 may retune), `conditionType` (one of the wired types listed in Dev Notes), `conditionParams` (matching the type's expected schema — see Dev Notes table), and `rewardIntel` (parseable `Decimal` string). All `id`s are unique across the catalog.

_(UI rendering of missions lands in Epic 7 — this story provides the sim layer + content + sample data only.)_

## Tasks / Subtasks

- [ ] Task 1: Add `MissionState` value class (AC: 1, 2, 3, 4, 8)
  - [ ] 1.1 Create `lib/game/features/missions/mission_state.dart`
  - [ ] 1.2 Define `@immutable class MissionState` with four final fields: `final String id; final int progress; final int target; final Intel rewardIntel;` and a `const` constructor that takes named required params
  - [ ] 1.3 Implement manual `==`, `hashCode`, `toString`, and `MissionState copyWith({int? progress})` (only `progress` is mutable across the lifecycle — `id`/`target`/`rewardIntel` are def-locked at seed time). Pattern: mirror `lib/game/features/countries/country_state.dart`.
  - [ ] 1.4 Add a convenience getter `bool get isComplete => progress >= target;` — used by the evaluator and downstream UI.
  - [ ] 1.5 NO `freezed`. NO `json_serializable`. Pure Dart with `package:meta/meta.dart`.

- [ ] Task 2: Extend `lib/game/game_state.dart` (AC: 1, 2, 3, 8, 11)
  - [ ] 2.1 Add three fields:
    - `final List<MissionState> activeMissions;` — unmodifiable
    - `final Set<String> completedMissionIds;` — unmodifiable
    - `final Intel totalIntel;` — defaults to `Intel.zero`
  - [ ] 2.2 Constructor: wrap `activeMissions` in `List.unmodifiable(...)`; wrap `completedMissionIds` in `Set.unmodifiable(...)`; default `totalIntel` to `Intel.zero` when null.
  - [ ] 2.3 `copyWith`: add the three params with `?`-nullable types and forward.
  - [ ] 2.4 `==`/`hashCode`: add `ListEquality<MissionState>()` (reuse `package:collection`) for `activeMissions`; reuse the existing `_stringSetEq` for `completedMissionIds`; add direct `==` for `totalIntel`. Mirror the `_stringSetEq` static-final pattern already at the top of the file.
  - [ ] 2.5 `toString`: include `activeMissions.length`, `completedMissionIds.length`, `totalIntel`. Match the existing concise-summary style.
  - [ ] 2.6 `initialSeed(content)`: AFTER existing seed logic, call `seedActiveMissions(content)` (Task 3) and assign the result to the constructor's `activeMissions` param. `completedMissionIds` and `totalIntel` default to empty/zero.
  - [ ] 2.7 Backward compatibility is OUT OF SCOPE per project rules — old saves will break, that is acceptable.

- [ ] Task 3: Create `MissionDef → MissionState` seed helper (AC: 1, 11, 12)
  - [ ] 3.1 Add top-level function in `lib/game/features/missions/missions_seed.dart`:
        `List<MissionState> seedActiveMissions(ContentRegistry content, {Set<String> completedIds = const <String>{}})`
  - [ ] 3.2 Iterate `content.missions` in declaration order. Skip defs whose `id` is in `completedIds`. Take the FIRST `BalanceConfig.missionCatalogSize` eligible defs.
  - [ ] 3.3 For each, build `MissionState(id: def.id, progress: 0, target: _targetFromParams(def), rewardIntel: Intel(def.rewardIntel))`. The `target` is read from `def.conditionParams['count'] as int` (or analogous key per condition type — see Dev Notes table). Use a private `int _targetFromParams(MissionDef def)` helper that switches on `def.conditionType`.
  - [ ] 3.4 Return `List.unmodifiable(...)`. Empty list if no defs are eligible.
  - [ ] 3.5 Pure function. No clock, no RNG.

- [ ] Task 4: Add `BalanceConfig.missionCatalogSize` (AC: 1, 6, 12)
  - [ ] 4.1 In `lib/game/config/balance.dart`, add: `static const int missionCatalogSize = 3;` with a doc comment marking it as Epic 10 retune-eligible.

- [ ] Task 5: Add events to `lib/game/game_event.dart` (AC: 2, 3, 4, 9)
  - [ ] 5.1 Add `final class MissionCompleted extends GameEvent` with `final String missionId; final Intel rewardIntel;` plus `==`/`hashCode`/`toString`.
  - [ ] 5.2 Add `final class MissionRotated extends GameEvent` with `final String oldMissionId; final String? newMissionId;` (`newMissionId == null` when the slot was retired per AC #3) plus `==`/`hashCode`/`toString`.
  - [ ] 5.3 Both extend the sealed `GameEvent` so `switch` exhaustiveness keeps audio/haptics/persistence services compilable. Update any `switch (event)` exhaustive consumers — there should be none in `lib/game/`, but check `lib/services/` if they exist (they don't as of this story; safe).

- [ ] Task 6: Create the mission evaluator `lib/game/features/missions/missions_reducer.dart` (AC: 2, 3, 4, 5, 7, 11)
  - [ ] 6.1 Top-level pure function:
        ```
        (GameState, List<GameEvent>) evaluateMissions(
          GameState state,
          ContentRegistry content,
          GameEvent triggeringEvent,
          DateTime now,
        )
        ```
  - [ ] 6.2 Compute the per-event `delta` by switching on `triggeringEvent.runtimeType`:
        - `CountryTapped` → `1` for missions of type `tap_countries_n`
        - `UpgradePurchased` → `1` for missions of type `purchase_upgrades_n` (note: do NOT scale by `levelsAdded` — one purchase = one count for v1; Epic 10 may revisit)
        - `CountryUnlocked` → `1` for missions of type `unlock_countries_n`
        - `LeaderHired` → `1` for missions of type `hire_leaders_n`
        - `ContinentUnlocked` → `1` for missions of type `unlock_continents_n`
        - All other events (incl. `Tick`, `ContinentCompleted`, `MilestoneReached`, `MissionCompleted`, `MissionRotated`, future `GoldenClaimed` / `BoostActivated`) → `0` for ALL types in this story (AC #7 — unwired condition types stay pending).
  - [ ] 6.3 Iterate `state.activeMissions` in slot order; for each slot, look up the `MissionDef` by id in `content.missions` (linear scan is fine — catalog is small). If `def == null` (orphaned id — content was edited mid-save), skip silently and DO NOT throw. If the slot's condition matches the event type, increment `progress` by `delta` (capped at `target`). Track which slots completed in this pass.
  - [ ] 6.4 For each completed slot in slot order: emit `MissionCompleted(now, missionId: id, rewardIntel: r)`, add `r` to `totalIntel`, append `id` to a working `completedMissionIds` set, then run the rotation step (Task 6.5) for that slot, recording the resulting `MissionRotated` event.
  - [ ] 6.5 Rotation step (the AC #3 logic): given `completedMissionId` at catalog index `k` (linear-scan to find), iterate `content.missions` starting at index `(k + 1) % length`, wrapping ONCE. Pick the first def whose `id` is NOT in (`workingActiveMissionIds` ∪ `workingCompletedIds`). If found, replace the slot with `MissionState(id: newDef.id, progress: 0, target: _targetFromParams(newDef), rewardIntel: Intel(newDef.rewardIntel))` and emit `MissionRotated(now, oldMissionId: oldId, newMissionId: newDef.id)`. If not found, REMOVE the slot from the working list (length decreases) and emit `MissionRotated(now, oldMissionId: oldId, newMissionId: null)`.
  - [ ] 6.6 If no missions advanced AND no missions completed, return `(state, const <GameEvent>[])` with `identical(returnedState, state) == true` (no `copyWith` invocation) — AC #5.
  - [ ] 6.7 Otherwise return `(state.copyWith(activeMissions: List.unmodifiable(working), completedMissionIds: Set.unmodifiable(workingCompleted), totalIntel: workingIntel), events)`.
  - [ ] 6.8 Pure function. No `DateTime.now()`, no `Random()`, no I/O. `now` flows in for event timestamps only.
  - [ ] 6.9 Use `assert(...)` for programmer-error invariants (e.g. `assert(state.activeMissions.length <= BalanceConfig.missionCatalogSize)` — defensive but not critical).

- [ ] Task 7: Wire evaluator into `lib/game/game_world.dart` (AC: 9, 10)
  - [ ] 7.1 Add private helper `void _evaluateMissionsForEvents(List<GameEvent> events)` that loops the freshly-emitted events; for each event, calls `evaluateMissions(_state, _content, event, _clock.now())`; if returned events are non-empty, assigns `_state = next` and emits them via `_events.add(e)` for each. The helper must be defensive: if `evaluateMissions` itself emits a `MissionCompleted` (which feeds into a NEW `_evaluateMissionsForEvents` cycle?), short-circuit by NOT re-evaluating mission-emitted events — `MissionCompleted` and `MissionRotated` always produce `0` delta per AC #7, so this is structurally safe but ALSO MUST be enforced with an explicit early-return: `if (event is MissionCompleted || event is MissionRotated) continue;`.
  - [ ] 7.2 In `applyCommand`: BUFFER the events emitted by the originating reducer + `_evaluateContinentUnlocks` + `_evaluateMilestones` instead of streaming them as they happen, OR (simpler) re-architect to: track events emitted in this `applyCommand` invocation by snapshotting the stream, OR (simplest) re-evaluate per-event by running the existing evaluators in their current spots and THEN running `_evaluateMissionsForEvents` against the events accumulated for this command. **Implementation choice (recommended):** add a `final List<GameEvent> _pendingEvents = [];` instance field, change every `_events.add(e)` inside `applyCommand` / `tick` to ALSO append to `_pendingEvents`, run mission evaluation against `_pendingEvents` at the end of the command/tick, then emit mission events. **DO NOT change subscriber-visible ordering** for non-mission events; keep `command-event → continent-unlock → milestone` order, then append mission events at the tail (AC #9).
  - [ ] 7.3 Alternative (cleaner) implementation: refactor `_evaluateContinentUnlocks` / `_evaluateMilestones` to RETURN events instead of emitting directly, accumulate ALL events in a local `List<GameEvent> emitted` for the command, run `_evaluateMissionsForEvents(emitted)` once at the end, append its events to `emitted`, then call `_events.add(...)` for each in order. This keeps the stream contract intact with a single emit phase per command. **Use this alternative if the inline-buffer approach feels invasive.**
  - [ ] 7.4 In `tick()`: SAME pattern. Mission evaluator runs ONCE at the end of `tick`, processing all events emitted that tick (currently: `Tick`, optionally `ContinentUnlocked`). Per AC #10, the per-tick path MUST short-circuit when no mission-eligible events fire — the evaluator's AC #5 `identical(next, state)` guarantee handles this if the helper checks `if (returnedEvents.isEmpty) return;` before any state assignment.
  - [ ] 7.5 Causal ordering on the `events` stream MUST match AC #9: `command-event → continent-unlock-events → milestone-events → mission-completion-events → mission-rotated-events`. Verify with a unit test that subscribes to `world.events` via `world.events.toList()`.
  - [ ] 7.6 Do NOT re-fire missions for the `MissionCompleted` / `MissionRotated` events themselves (the evaluator's `delta = 0` logic in Task 6.2 already guarantees this; the helper-level guard in 7.1 is belt-and-suspenders).

- [ ] Task 8: Populate `assets/data/missions.json` (AC: 12)
  - [ ] 8.1 Replace the empty `[]` with at least 5 entries (`missionCatalogSize=3` plus 2 spares so AC #6 rotation is testable). Suggested initial catalog (Epic 10 will retune values):
        ```json
        [
          { "id": "tap_50_countries",       "name": "Tap 50 countries",         "conditionType": "tap_countries_n",       "conditionParams": { "count": 50 },   "rewardIntel": "10" },
          { "id": "purchase_5_upgrades",    "name": "Purchase 5 upgrades",      "conditionType": "purchase_upgrades_n",   "conditionParams": { "count": 5 },    "rewardIntel": "15" },
          { "id": "unlock_2_countries",     "name": "Unlock 2 countries",       "conditionType": "unlock_countries_n",    "conditionParams": { "count": 2 },    "rewardIntel": "25" },
          { "id": "hire_3_leaders",         "name": "Hire 3 leaders",           "conditionType": "hire_leaders_n",        "conditionParams": { "count": 3 },    "rewardIntel": "40" },
          { "id": "unlock_1_continent",     "name": "Unlock a new continent",   "conditionType": "unlock_continents_n",   "conditionParams": { "count": 1 },    "rewardIntel": "100" }
        ]
        ```
  - [ ] 8.2 All `id`s lowercase-snake-case and unique across the catalog.
  - [ ] 8.3 Mark these as Epic 10 placeholders in the File List notes (rewardIntel values are not balanced).

- [ ] Task 9: Pure-Dart unit tests `test/game/features/missions/missions_reducer_test.dart` (AC: 2, 3, 4, 5, 6, 7, 11)
  - [ ] 9.1 Use `package:test/test.dart` (NOT `flutter_test`). Pure-Dart for `lib/game/` per `test/architecture/game_boundary_test.dart`.
  - [ ] 9.2 Build a fixture `ContentRegistry` via `ContentRegistry.fromJsonStrings(...)` with 5 missions (the AC #12 catalog). Reuse the `_fixtureRegistry()` pattern from `test/game/features/economy/income_calculator_test.dart`.
  - [ ] 9.3 Test `seedActiveMissions`: 5 defs + `missionCatalogSize=3` → 3 active missions in declaration order with `progress=0`.
  - [ ] 9.4 Test `seedActiveMissions`: completedIds = {firstId} → skips that one, fills slots from indices 1, 2, 3.
  - [ ] 9.5 Test `seedActiveMissions`: empty catalog → returns empty list (AC #1 graceful degrade).
  - [ ] 9.6 Test `evaluateMissions`: `Tick` event → returns `(state, [])` and `identical(returnedState, state) == true` (AC #5).
  - [ ] 9.7 Test `evaluateMissions`: `CountryTapped` event vs a `tap_countries_n` mission with `target=2, progress=0` → progress becomes 1, no events fired.
  - [ ] 9.8 Test `evaluateMissions`: `CountryTapped` event with `target=2, progress=1` → completes, fires `MissionCompleted` + `MissionRotated`, `totalIntel` increases by `rewardIntel`, `completedMissionIds` adds the id, slot is replaced by next eligible def (index 3).
  - [ ] 9.9 Test `evaluateMissions`: progress capped at target (`target=2, progress=1`, but two events arrive in one pass — wait, the evaluator processes ONE event per call; document this and verify by calling the evaluator twice in the same test). Single-event pass: progress increments by exactly +1 per matching event regardless of how many slots match.
  - [ ] 9.10 Test rotation exhaustion (AC #3, #6): catalog of 5, complete 3 missions in sequence — verify slot retirement once eligible defs run out (`activeMissions.length` decreases from 3 to 2 to 1 as completions exceed catalog spares).
  - [ ] 9.11 Test multi-slot match (AC #4): build a state with TWO active `tap_countries_n` missions (override the seed for the test); a single `CountryTapped` advances both slots in order.
  - [ ] 9.12 Test unwired condition type (AC #7): seed a mission with `conditionType: 'golden_claimed_count'` in the fixture catalog; emit a `CountryTapped` — progress stays 0, no throw, no log assertion. (Logging is forbidden in pure reducers anyway — `package:logging` is not imported.)
  - [ ] 9.13 Test orphaned-id resilience (Task 6.3): build a state whose `activeMissions` references an id NOT in `content.missions` (simulating mid-development content edits) — evaluator skips that slot and DOES NOT throw.
  - [ ] 9.14 Test `MissionState` value semantics: equality, hashCode, toString, and `copyWith(progress: ...)` produces a new instance with all other fields preserved.

- [ ] Task 10: GameWorld integration tests `test/game/game_world_test.dart` (AC: 2, 9, 10)
  - [ ] 10.1 Append (do NOT replace) tests to the existing `test/game/game_world_test.dart` covering missions wiring.
  - [ ] 10.2 Test causal event order (AC #9): boot a `GameWorld` with a fixture content where Egypt is unlocked + ipLevel=1 + `bankedInfluence` non-zero; subscribe to `world.events`; dispatch `TapCountry(egypt)`; assert the emitted-event sequence matches `[CountryTapped, ...possibleContinent/MilestoneEvents, MissionCompleted?, MissionRotated?]`. Cleanest assertion: collect events into a `List<GameEvent>`, then `expect(events.indexOf(<MissionCompleted>), greaterThan(events.indexOf(<CountryTapped>)));`.
  - [ ] 10.3 Test `tick()` mission evaluation (AC #10): boot world, advance state to a point where a tick will trigger `ContinentUnlocked`; assert that AFTER the tick, an `unlock_continents_n` mission's progress advanced by 1 and a `MissionRotated` event fires if the mission completed.
  - [ ] 10.4 Test that a no-event tick (`Tick` only, no continent unlocks, no mission-eligible events) does NOT mutate `state.activeMissions` (`identical(stateBefore.activeMissions, stateAfter.activeMissions) == true`).
  - [ ] 10.5 Test that `MissionCompleted` and `MissionRotated` events do NOT recursively trigger further mission evaluation (Task 7.1 guard) — assert event stream contains exactly ONE `MissionCompleted` and ONE `MissionRotated` per single-completion command, not duplicates.

- [ ] Task 11: GameState tests `test/game/game_state_test.dart` (AC: 1, 8)
  - [ ] 11.1 Append: `initialSeed(content)` populates `activeMissions` with `BalanceConfig.missionCatalogSize` entries when fixture has ≥ that many missions; populates fewer entries gracefully when fixture has fewer.
  - [ ] 11.2 Append: `initialSeed(content)` sets `totalIntel == Intel.zero` AND `completedMissionIds.isEmpty`.
  - [ ] 11.3 Append: `==` / `hashCode` / `toString` cover the new fields — two states differing only in `totalIntel` are not equal; differing only in `activeMissions[0].progress` are not equal; differing only in `completedMissionIds` are not equal.
  - [ ] 11.4 Append: `copyWith(activeMissions: ...)` / `copyWith(completedMissionIds: ...)` / `copyWith(totalIntel: ...)` each produce a new state with the swapped field and all others identity-preserved.

- [ ] Task 12: Architecture compliance verification (AC: all)
  - [ ] 12.1 Run `flutter test test/architecture/` — new files in `lib/game/features/missions/` MUST contain no `package:flutter/`, no `dart:ui`, no `lib/data/` imports (`test/architecture/game_boundary_test.dart`).
  - [ ] 12.2 Confirm `missions_reducer.dart` does NOT match `test/architecture/no_duplicate_income_math_test.dart` patterns (it doesn't touch `def.baseInfluence *` or `country.baseInfluence *`).
  - [ ] 12.3 Confirm no `print(`, no `Logger(...)` import in mission reducer files (hot-path discipline; AC #5 requires evaluator to be a no-op for unrelated events — logging would defeat that).

- [ ] Task 13: Full validation (AC: all)
  - [ ] 13.1 `flutter analyze` — 0 warnings.
  - [ ] 13.2 `dart format --set-exit-if-changed .`
  - [ ] 13.3 `flutter test` — all pass (existing + new). Expect ALL pre-existing tests to keep passing; the only legitimate breakage is tests that hand-construct `GameState` and now need to pass `activeMissions`/`completedMissionIds`/`totalIntel` — fix them by relying on `initialSeed(content)` or the `GameStateBuilder` test helper if it exists.
  - [ ] 13.4 Update `Status` to `review` and append entries to Completion Notes / File List.

## Dev Notes

### Coordination with sibling Epic 5 stories (CRITICAL — read before starting)

Stories 5.1 (Goldens) and 5.2 (Boosts) are still **backlog** as of this story's creation. This story (5.3) is being implemented OUT OF ORDER. The design accommodates this by:

- Mission `conditionType` is a **string in JSON**, not an enum or sealed type — adding new types later (`golden_claimed_count`, `boost_activated_count`, `stay_active_seconds`) only requires adding a `case` in `evaluateMissions`'s event-matcher switch.
- Per AC #7, mission entries with unwired condition types load fine, never advance, never crash. So you CAN ship missions referencing `GoldenClaimed`/`BoostActivated` in `missions.json` from day one if you want — they'll just be permanently pending until 5.1/5.2 land. **For this story, ship only wired condition types in `missions.json` (Task 8) to keep the catalog actionable.**
- When 5.1 and 5.2 land, their stories will add cases to the evaluator's event-matcher switch (`GoldenClaimed → 1 for golden_claimed_count`, etc.) and update `missions.json`. NO refactor of this story's reducer is required.

**Decisions locked in by this story — do NOT redebate when 5.1/5.2 land:**

| Decision | Locked-in here | Rationale |
|---|---|---|
| Conditions are strings in JSON, not Dart enums | `MissionDef.conditionType: String` already in code | Data-driven per architecture §"Declarative Rule Engine for Achievements & Missions" |
| Rotation is **deterministic** by catalog index, not RNG-based | Task 6.5 wraps from `(k+1) % length` | No RNG dependency yet (Story 5.1 may add `lib/game/support/rng.dart`); deterministic is also better for tests |
| `MissionCompleted` carries `Intel` reward inline; reducer applies `totalIntel += reward` atomically | Task 6.4 | Symmetric with how `MilestoneReached` (Story 4.3) carries `rewardValue` and the reducer applies it. |
| Mission evaluator runs LAST among reducers | AC #9 ordering | Mission progress depends on the FULL post-state of all earlier reducers; running it last means `state.totalInfluence` etc. are reconciled when missions read them (currently no condition reads state directly, but future "reach 1M influence" missions will). |
| Per-tick evaluator IS allowed (not skipped like milestones in Story 4.3) | AC #10 | `tick()` can emit `ContinentUnlocked` which advances `unlock_continents_n` missions; AC #5's `identical(next, state)` short-circuit keeps the cost zero on no-op ticks. |
| `state.completedMissionIds` is **lifetime-cumulative** within a `GameState` (no reset) | AC #11 | Epic 10 may add weekly resets; this story does NOT. |

### Architecture Compliance (non-negotiable)

- **`lib/game/` has ZERO Flutter imports.** `mission_state.dart`, `missions_reducer.dart`, `missions_seed.dart` MUST NOT import `package:flutter/*` or `dart:ui`. Use `package:meta/meta.dart` for `@immutable`.
- **Reducers / selectors are pure.** No `DateTime.now()` (use injected `now` param), no `Random()`, no I/O. The architecture invariant for `lib/game/` purity is enforced by `test/architecture/game_boundary_test.dart`.
- **Sealed `switch` exhaustiveness.** Adding `MissionCompleted` and `MissionRotated` as new `GameEvent` variants will force every existing exhaustive `switch (event) { ... }` in the codebase to update. As of this story there are NO exhaustive switches over `GameEvent` outside of `lib/game/` (audio/haptics services don't exist yet) — so the diff is contained. If you find one, add the cases (do NOT use `default:` — keeps the type system honest).
- **Big numbers.** `rewardIntel` flows as `Decimal` from JSON, wrap in `Intel(...)` at the seed/reducer boundary. `state.totalIntel` is `Intel`. Never expose raw `Decimal` outside `lib/game/values/`.
- **No income math here.** This story doesn't touch `IncomeCalculator`. The grep guard (`test/architecture/no_duplicate_income_math_test.dart`) flags `def.baseInfluence *` / `country.baseInfluence *` patterns — neither appears in mission code.
- **No income-modifying effect for v1.** Mission rewards are Intel only. Boost activation (Story 5.2) will spend Intel; this story produces it. There is NO multiplier-stack interaction in this story.
- **Event bus discipline.** ONLY `GameWorld` emits events. Reducers RETURN `(GameState, List<GameEvent>)`; `GameWorld` adds them to the stream. Do NOT have the reducer call `_events.add(...)`.
- **`ContentRegistry` is immutable and load-once.** Already true; this story consumes it but does not add a new asset path or loading step (the `missions.json` slot already exists in `ContentRegistry`).
- **No `freezed`, no `json_serializable`, no `riverpod_generator`.** Manual `==`/`hashCode`/`toString`/`copyWith` for `MissionState`. Manual `MissionDef.fromJson` already exists; do not regenerate.

### Library / Framework Requirements

- `package:meta/meta.dart` — `@immutable` for `MissionState`. Already in transitive deps.
- `package:collection/collection.dart` — `ListEquality<MissionState>` for `GameState ==`. Already pinned in `pubspec.yaml` and used by `GameState` (`MapEquality`, `SetEquality` patterns).
- `package:decimal/decimal.dart` — for `Intel(Decimal.parse(...))`. Already pinned.
- `package:test/test.dart` — pure-Dart reducer tests (NOT `flutter_test`).
- No new `pubspec.yaml` entries required.

### Condition type → event matcher table (Task 6.2 reference)

This is the AUTHORITATIVE list of `conditionType` strings this story wires. Add new entries here when 5.1/5.2 land — do NOT silently invent new types in JSON without updating this table AND the matcher switch.

| `conditionType` (JSON) | `conditionParams` schema | Triggering event | Delta per event | Wired by |
|---|---|---|---|---|
| `tap_countries_n` | `{"count": int}` | `CountryTapped` | `+1` | THIS story (5.3) |
| `purchase_upgrades_n` | `{"count": int}` | `UpgradePurchased` | `+1` (one purchase = one count, NOT scaled by `levelsAdded`) | THIS story (5.3) |
| `unlock_countries_n` | `{"count": int}` | `CountryUnlocked` | `+1` | THIS story (5.3) |
| `hire_leaders_n` | `{"count": int}` | `LeaderHired` | `+1` | THIS story (5.3) |
| `unlock_continents_n` | `{"count": int}` | `ContinentUnlocked` | `+1` | THIS story (5.3) |
| `golden_claimed_count` | `{"count": int}` | `GoldenClaimed` (does not exist yet) | `+1` (when 5.1 lands) | DEFERRED — Story 5.1 |
| `boost_activated_count` | `{"count": int}` | `BoostActivated` (does not exist yet) | `+1` (when 5.2 lands) | DEFERRED — Story 5.2 |
| `stay_active_seconds` | `{"seconds": int}` | requires per-tick session-time accumulation | DEFERRED — needs `state.sessionElapsed` field | NOT THIS STORY |

The `_targetFromParams(MissionDef def)` helper switches on `def.conditionType` and reads:
- `tap_countries_n`/`purchase_upgrades_n`/`unlock_countries_n`/`hire_leaders_n`/`unlock_continents_n`/`golden_claimed_count`/`boost_activated_count` → `def.conditionParams['count'] as int`
- `stay_active_seconds` → `def.conditionParams['seconds'] as int` (target is seconds; not exercised in this story but the helper handles it gracefully so future content doesn't crash the seed)

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/features/missions/mission_state.dart` | `MissionState` value class |
| `lib/game/features/missions/missions_seed.dart` | `seedActiveMissions(content, {completedIds})` helper |
| `lib/game/features/missions/missions_reducer.dart` | `evaluateMissions(state, content, event, now)` pure function + condition-type → delta switch |
| `test/game/features/missions/missions_reducer_test.dart` | Pure-Dart reducer + seed tests |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add `activeMissions`, `completedMissionIds`, `totalIntel` fields; constructor / `copyWith` / `==` / `hashCode` / `toString` / `initialSeed` |
| `lib/game/game_event.dart` | Add `MissionCompleted` and `MissionRotated` events |
| `lib/game/game_world.dart` | Wire `_evaluateMissionsForEvents` after milestone evaluator in `applyCommand` AND in `tick()` |
| `lib/game/config/balance.dart` | Add `missionCatalogSize = 3` constant |
| `assets/data/missions.json` | Replace `[]` with the 5-entry placeholder catalog (Task 8) |
| `test/game/game_state_test.dart` | Append tests for new state fields |
| `test/game/game_world_test.dart` | Append tests for evaluator wiring + causal ordering + tick path |

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` — missions do not affect income in v1; do NOT add a "missionMultiplier" slot to the multiplier stack.
- `lib/game/content/mission_def.dart` — already correct; do not change `MissionDef.fromJson`.
- `lib/data/database/**` — Drift persistence for missions is Epic 6 (story 6.1's `GameStateMapper`). This story produces the in-memory shape; persistence wiring is later.
- `lib/services/**`, `lib/ui/**` — UI/audio for missions lands in Epic 7 / Epic 8.
- `lib/providers/feature_providers.dart` — Adding `activeMissionsProvider` is a UI-layer concern (Epic 7). This story does NOT add Riverpod selectors; the dev agent for Story 7.x will add `Provider<List<MissionState>>((ref) => ref.watch(gameWorldProvider).activeMissions)` etc. when wiring the Missions tab.

### Previous-Story Intelligence (4.3, 4.4, 4.5 patterns to mirror)

From the most-recently-shipped Epic 4 stories (all `done` as of 2026-04-25):

- **Story 4.3 (`milestones_reducer.dart`)** — IDENTICAL pattern to what's needed here:
  - Pure top-level function returning `(GameState, List<GameEvent>)`.
  - Iterates content in deterministic order (sorted by id).
  - Carries forward `totalInfluence` increments through the working state.
  - Uses `Map<ContinentId, Set<int>>` with nested-set unmodifiability — the `state.completedMissionIds` field follows the same `Set.unmodifiable` discipline.
  - **Read [`lib/game/features/continents/milestones_reducer.dart`](../../lib/game/features/continents/milestones_reducer.dart) before writing the missions reducer — copy the structure, swap the domain logic.**
- **Story 4.4 (continent completion multiplier)** — Same pattern of "evaluator runs after a state mutation, emits events, side-effects state". The wiring point in `GameWorld._evaluateMilestones` is the most direct precedent for `_evaluateMissionsForEvents`.
- **Story 4.5 (selectors + providers)** — Used `_TestGameWorldNotifier extends GameWorldNotifier` for provider tests. NOT NEEDED for this story (no providers added) but the test fixture pattern (`ContentRegistry.fromJsonStrings` from inline JSON strings) IS reused.

**Code-review-found landmines from prior stories (do NOT repeat):**
- **4-3 review** flagged "milestone evaluation gated to actual state mutation" — same applies here: skip mission evaluation if no events produced (AC #5).
- **4-3 review** flagged "milestone threshold math aligned with floor formula for small-N continents" — analogous concern here: `progress` capped at `target` so completing on overshoot doesn't push `progress > target`.
- **4-5 review** flagged "missing-state branch coverage" — corresponding test here is AC #7 (orphaned-id resilience) and the empty-catalog seed test (Task 9.5).
- **2-7 review** flagged "gameWorldProvider empty-content assert landmine" — the seed helper here MUST handle `content.missions.isEmpty` gracefully (Task 3.4 returns empty list, AC #1).

### Project Structure Notes

- **Folder choice (`lib/game/features/missions/`):** matches game-architecture.md §System→Location Mapping ("Missions" → `lib/game/features/missions/`). First files in this folder; this story establishes the convention.
- **Provider file location:** No new providers in this story. Epic 7 (Story 7.7 / 7.x for Missions tab) will add `final activeMissionsProvider = Provider<List<MissionState>>((ref) => ref.watch(gameWorldProvider).activeMissions);` to `lib/providers/feature_providers.dart`. Do NOT pre-add it here.
- **Test folder location (`test/game/features/missions/`):** mirrors `lib/` structure per `CLAUDE.md`. First test file in this folder.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only. (Enforced by `test/architecture/game_boundary_test.dart`.)
- **UI never mutates `GameState` directly.** UI dispatches commands; only `GameWorld` mutates. This story adds NO new commands — missions advance via existing events emitted by existing commands plus `tick()`.
- **Reducers are pure functions.** NO clock reads, NO RNG reads, NO I/O. `now` flows in for event timestamps only. The mission evaluator follows the same purity contract as `evaluateMilestones` (Story 4.3).
- **Multiplier stack is single source of truth in `IncomeCalculator.compute`.** This story does NOT touch the multiplier stack. Mission rewards are Intel currency, not influence multipliers (achievements grant influence multipliers in Story 5.5; missions do NOT).
- **Big numbers:** All Intel values flow through the `Intel` value object. The reducer wraps `def.rewardIntel` (a `Decimal`) in `Intel(...)` at the seed/reward-emit boundary. The `state.totalIntel` field is `Intel`. Never expose raw `Decimal` outward.
- **Configuration discipline:** `missionCatalogSize` is a balance constant (`BalanceConfig`). The mission catalog itself is content (`assets/data/missions.json`). No hardcoded mission ids or counts in reducer code.
- **No `freezed`, no `json_serializable`, no `riverpod_generator`.** Manual `==`/`hashCode`/`toString`/`copyWith`. Manual JSON parsing in `MissionDef.fromJson` (already done).
- **Sealed `switch` exhaustiveness:** Adding `MissionCompleted` + `MissionRotated` to the sealed `GameEvent` hierarchy will force every existing exhaustive `switch (event)` to add cases. As of this story, search for `switch (.*) {.*Tick()` in `lib/` and `test/` to find any exhaustive consumers — fix them. (Architecture allows `default:` only in `AudioService`/`HapticsService` where unhandled events are no-ops; those services don't exist yet.)
- **Logging:** `package:logging` only. The reducer is pure and SHOULD NOT log anything (hot-path discipline). Per AC #5, the per-tick path can run thousands of times per session; logging an `info` per tick would be a perf disaster.
- **Event bus:** `StreamController.broadcast(sync: true)` — already in use; subscribers see state + event in the same microtask. The mission evaluator's events appended via `_events.add(e)` will be visible to subscribers BEFORE the next tick fires.
- **Drift persistence is Epic 6.** Do NOT add a `MissionsTable` or migration here. The `state.activeMissions`/`state.completedMissionIds`/`state.totalIntel` fields will get persistence wiring in Story 6.1's `GameStateMapper`.
- **Backward compatibility is OUT OF SCOPE** per user rules — adding three new fields to `GameState` will break old saves; that is acceptable during development.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.3: Missions Cycle Rotating Objectives Rewarding Intel] — original ACs and story statement
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5] — epic goal and FR13
- [Source: _bmad-output/game-architecture.md#3. Declarative Rule Engine for Achievements & Missions] — pattern for data-driven evaluator + post-`applyCommand` evaluation
- [Source: _bmad-output/game-architecture.md#System→Location Mapping] — `lib/game/features/missions/` folder placement
- [Source: _bmad-output/project-context.md#Engine-Specific Rules (Flutter / Dart)] — pure `lib/game/`, sealed event hierarchies, multiplier-stack discipline, big-number value objects
- [Source: _bmad-output/project-context.md#Code Organization Rules] — feature-folder layout (`features/missions/{state, reducer}`)
- [Source: _bmad-output/project-context.md#Testing Rules] — pure-Dart vs widget test conventions
- [Source: _bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md] — most-direct precedent: pure evaluator + `(GameState, List<GameEvent>)` return shape + `GameWorld._evaluateMilestones` wiring
- [Source: _bmad-output/implementation-artifacts/4-4-continent-completion-permanent-multiplier.md] — precedent for adding state fields without touching multiplier stack until necessary
- [Source: _bmad-output/implementation-artifacts/4-5-next-unlock-teaser-data-on-state.md] — value-class style; `ContentRegistry.fromJsonStrings` fixture pattern (lines 17–67 of `test/game/features/economy/income_calculator_test.dart`)
- [Source: lib/game/features/continents/milestones_reducer.dart] — concrete pattern to mirror for `missions_reducer.dart`
- [Source: lib/game/game_world.dart#_evaluateMilestones] — wiring pattern for `_evaluateMissionsForEvents`
- [Source: lib/game/content/mission_def.dart] — `MissionDef` shape; do NOT modify
- [Source: lib/game/values/intel.dart] — `Intel` value object; `Intel(Decimal.parse(...))` construction
- [Source: lib/game/features/countries/country_state.dart] — `@immutable` value-class pattern for `MissionState`
- [Source: lib/game/game_state.dart#_continentCompletionEq] — static-final `MapEquality` / `SetEquality` pattern for new field equality
- [Source: test/game/features/economy/income_calculator_test.dart] — fixture `ContentRegistry` construction (`_fixtureRegistry()` ~lines 17–67)
- [Source: test/architecture/game_boundary_test.dart] — boundary invariants enforced by tests
- [Source: assets/data/missions.json] — currently `[]`; populated by Task 8

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
