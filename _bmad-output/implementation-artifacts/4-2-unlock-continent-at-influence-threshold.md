# Story 4.2: Unlock Continent at Influence Threshold

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the next continent to unlock automatically when my total Influence crosses its threshold,
so that new geography opens as my power grows without extra friction.

## Acceptance Criteria

1. **Given** a continent `C` whose `ContinentDef.unlockThreshold ≤ state.totalInfluence` and `state.unlockedContinents[C.id] != true`,
   **When** `GameWorld.tick` runs,
   **Then** `state.unlockedContinents[C.id]` becomes `true` and a single `ContinentUnlocked(at: now, continentId: C.id)` event is emitted.

2. **Given** a fresh state loaded with `totalInfluence` already past several thresholds (e.g. Drift load with `1e15`),
   **When** the next `GameWorld.tick` runs,
   **Then** every crossed-but-unhandled continent unlocks in **ascending `unlockThreshold` order**, each emitting its own `ContinentUnlocked` event in that order, in a single tick.

3. **Given** a continent `C` is already in `state.unlockedContinents` with value `true`,
   **When** any subsequent tick runs (regardless of `totalInfluence` value),
   **Then** no additional `ContinentUnlocked(C.id)` event fires and `state.unlockedContinents[C.id]` remains `true` — idempotent across the run.

4. **Given** `GameState.initialSeed(content)` is called,
   **When** the seed is constructed,
   **Then** `state.unlockedContinents` contains exactly the continents whose `unlockThreshold ≤ Decimal.zero` (i.e. africa) mapped to `true`, and **no `ContinentUnlocked` event is emitted** at boot for those threshold-0 continents on the first tick (idempotent rule from AC 3).

5. **Given** two continents share the exact same `unlockThreshold` (defensive — current content has none),
   **When** they unlock in the same tick,
   **Then** events fire in deterministic secondary order by `ContinentId.value` ASC — never random.

6. **Given** Story 4.1's `UnlockCountry` reducer needs a continent-eligibility signal,
   **When** any caller (4.1, future `nextUnlockInContinentProvider`, UI) needs to know if a continent is unlocked,
   **Then** `state.unlockedContinents[continentId] == true` is the canonical source. (Story 4.1 already gates on `totalInfluence >= continentDef.unlockThreshold`; that remains correct because of AC #1's invariant — if a continent is unlocked here it MUST have been due to threshold crossing. Do NOT modify Story 4.1's reducer in this story; only expose the new field.)

7. **Given** `GameWorld.applyCommand` runs (any command path: `TapCountry`, `PurchaseUpgrade`, `HireLeader`, `UpgradeLeader`, `UnlockCountry`),
   **When** that command increases `state.totalInfluence` past a continent threshold (e.g. tapping the last country needed to reach 1e9),
   **Then** the continent unlock evaluation fires from inside `applyCommand` BEFORE returning `Result.success` — the unlocked state and `ContinentUnlocked` event must be observable on the same microtask as the originating command's event. (Don't make the player wait for the next tick for a celebration that their tap caused.)

8. **Given** `state.unlockedContinents` is mutated,
   **When** the reducer constructs the new map,
   **Then** the map remains `Map.unmodifiable` and equality / hash code on `GameState` must already work via the existing `_continentCompletionEq` pattern (use a parallel `MapEquality<ContinentId, bool>` instance).

## Tasks / Subtasks

- [x] Task 1: Add `unlockedContinents: Map<ContinentId, bool>` field to `GameState` (AC: 1, 4, 8)
  - [x] Subtask 1.1: Add field, constructor param (`Map.unmodifiable` wrap, default `const <ContinentId, bool>{}`), `copyWith` param.
  - [x] Subtask 1.2: Add `_unlockedContinentsEq = MapEquality<ContinentId, bool>()` static; include in `==`, `hashCode`, `toString`.
  - [x] Subtask 1.3: Update `GameState.initialSeed`: iterate `content.continents.values`, include any whose `unlockThreshold ≤ Decimal.zero` (use `<=` operator from `decimal: ^3.0.2`) into the seed map → `Map.unmodifiable`.
- [x] Task 2: Add `ContinentUnlocked` event in `lib/game/game_event.dart` (AC: 1, 2, 5)
  - [x] Subtask 2.1: `final class ContinentUnlocked extends GameEvent { final ContinentId continentId; const ContinentUnlocked(super.at, {required this.continentId}); }` with `==`, `hashCode`, `toString`.
- [x] Task 3: Create `lib/game/features/continents/continents_reducer.dart` with `evaluateContinentUnlocks` (AC: 1, 2, 3, 5)
  - [x] Subtask 3.1: Signature: `Result<(GameState, List<GameEvent>), GameError> evaluateContinentUnlocks(GameState state, ContentRegistry content, {required DateTime now})`.
  - [x] Subtask 3.2: Build candidate list: `content.continents.values.where((c) => c.unlockThreshold <= state.totalInfluence.value && state.unlockedContinents[c.id] != true).toList()`.
  - [x] Subtask 3.3: If candidates empty → `Result.success((state, const []))` (return same state instance, do NOT allocate a new map).
  - [x] Subtask 3.4: Sort candidates by `(c.unlockThreshold ASC, c.id.value ASC)` — comparator must handle Decimal ordering via `compareTo`.
  - [x] Subtask 3.5: Build new `unlockedContinents` map: `{...state.unlockedContinents, for (final c in sorted) c.id: true}`; wrap `Map.unmodifiable`.
  - [x] Subtask 3.6: Build events list: `sorted.map((c) => ContinentUnlocked(now, continentId: c.id)).toList(growable: false)`.
  - [x] Subtask 3.7: Return `Result.success((state.copyWith(unlockedContinents: newMap), events))`.
  - [x] Subtask 3.8: Defensive guard: if any `c.unlockThreshold` is negative, return `Result.failure(GameError.internalInvariantBroken(message: 'continent ${c.id.value} has negative unlockThreshold'))` BEFORE sorting.
- [x] Task 4: Wire `evaluateContinentUnlocks` into `GameWorld.tick` (AC: 1, 2, 3)
  - [x] Subtask 4.1: After `tickCountries` updates `_state.countries`, call `evaluateContinentUnlocks(_state, _content, now: _clock.now())`.
  - [x] Subtask 4.2: On `Result.success((newState, events))`: assign `_state = newState`, then `for (final e in events) _events.add(e);`. Order matters — events must be added in list order.
  - [x] Subtask 4.3: On `Result.failure(InvariantBroken)`: throw — invariants are programmer errors per architecture (`GameWorld throws only on programmer-error invariants`).
  - [x] Subtask 4.4: Continue to emit `Tick(now)` AFTER the continent events (so audio/persistence subscribers see continent-unlock side effects before the tick marker if they care about ordering).
- [x] Task 5: Wire `evaluateContinentUnlocks` into `GameWorld.applyCommand` post-success path (AC: 7)
  - [x] Subtask 5.1: After each successful command branch (`_applyTapCountry`, `_applyPurchaseUpgrade`, `_applyHireLeader`, `_applyUpgradeLeader`, and `_applyUnlockCountry` if Story 4.1 has merged) updates `_state` and emits its own event, run the continent evaluation against the just-updated `_state`.
  - [x] Subtask 5.2: Append any resulting `ContinentUnlocked` events to the stream AFTER the originating command's event (preserves causal order: `CountryTapped` → `ContinentUnlocked`).
  - [x] Subtask 5.3: Extract this into a private helper `void _evaluateContinentUnlocks(DateTime now)` to avoid duplication across the command paths. Call it once at the end of every successful `applyCommand` branch.
  - [x] Subtask 5.4: If Story 4.1's `_applyUnlockCountry` branch is not yet merged when this story is implemented, wire it into the four existing branches and document the pattern in a comment so 4.1's merge follows it. If 4.1 has already merged, ensure its `_applyUnlockCountry` also calls `_evaluateContinentUnlocks(now)` post-success.
- [x] Task 6: Update `test/game/game_state_seed_test.dart` (AC: 4)
  - [x] Subtask 6.1: Add test `seed includes continents with unlockThreshold <= 0 in unlockedContinents` covering single-continent (africa, threshold 0) and a two-continent fixture (africa threshold 0 + europe threshold 1e9 → only africa pre-populated).
- [x] Task 7: Add `test/game/features/continents/continents_reducer_test.dart` (AC: 1, 2, 3, 5, 8)
  - [x] Subtask 7.1: Single new unlock — totalInfluence at threshold returns new state + 1 event.
  - [x] Subtask 7.2: Below threshold returns same `GameState` instance (`identical(newState, state)` true) and empty events list.
  - [x] Subtask 7.3: Multiple thresholds crossed in one call → events emitted in `unlockThreshold` ASC order with correct continent IDs.
  - [x] Subtask 7.4: Already unlocked continent → no re-emit, state unchanged.
  - [x] Subtask 7.5: Tied thresholds (build content with two continents at threshold `0`) → secondary sort by `id.value` ASC.
  - [x] Subtask 7.6: Negative threshold in content → `Result.failure(InvariantBroken)`.
  - [x] Subtask 7.7: Returned `unlockedContinents` map is unmodifiable (`expect(() => map[X] = false, throwsUnsupportedError)`).
- [x] Task 8: Add integration tests in `test/game/game_world_test.dart` (AC: 1, 2, 3, 7)
  - [x] Subtask 8.1: Tick that crosses europe threshold via accrual emits `ContinentUnlocked(europe)` BEFORE the trailing `Tick` event (subscribe via `events.toList()` and assert order).
  - [x] Subtask 8.2: Construct a `GameWorld` with `initialState` whose `totalInfluence == Influence(Decimal.parse('1e15'))` and `unlockedContinents` empty; first tick emits `ContinentUnlocked(africa)`, `ContinentUnlocked(europe)`, ... in threshold order, then `Tick`.
  - [x] Subtask 8.3: `applyCommand(TapCountry)` that bumps `totalInfluence` past a threshold emits `CountryTapped` THEN `ContinentUnlocked(...)` on the same microtask (use `events.take(2).toList()`).
  - [x] Subtask 8.4: After unlocking africa via the seed pre-population, ticking with `totalInfluence == 0` emits zero `ContinentUnlocked` events (only `Tick` if countries changed, or no event if not).
- [x] Task 9: Update existing tests broken by new `GameState` field (AC: 8)
  - [x] Subtask 9.1: Run `flutter test`; fix any direct `GameState(...)` constructions in tests that now need `unlockedContinents` (most should be fine via default `const {}`).
  - [x] Subtask 9.2: Audit `test/game/game_state_test.dart` and add equality coverage for `unlockedContinents` (two states equal iff their maps are equal; differ when one has africa unlocked).

### Review Findings

- [x] [Review][Patch] UnlockCountry can unlock a country while continent remains locked when cost drops total below threshold [lib/game/game_world.dart]
- [x] [Review][Patch] Noop now triggers continent unlock side effects on stale states [lib/game/game_world.dart]

## Dev Notes

### Domain semantics (read carefully)

- **Threshold from CONTENT, not constants.** `ContinentDef.unlockThreshold` is the single source of truth. **DO NOT** add `BalanceConfig.continentThresholds` or hardcode the GDD's `[0, 1e9, 1e14, 1e20, 1e26, 1e32, 1e38]` list anywhere. The list in the epic AC is a balance reference for Epic 10; the live values come from `assets/data/continents.json` via `ContentRegistry`. Also note: the JSON values currently differ from the GDD (e.g. `middle_east: 1e12` in JSON vs `1e14` in GDD) — Epic 10 retunes; the reducer is content-driven and indifferent.
- **`unlockedContinents` is a NEW state field**, distinct from the existing `continentCompletions` (which tracks 100% ownership per Story 4.4). Don't reuse `continentCompletions`. Don't fold them together.
- **Boot semantics:** `GameState.initialSeed` pre-populates threshold-0 continents (africa) into `unlockedContinents`. This avoids spurious "Africa Unlocked!" celebrations at first launch — the player starts already in africa with egypt unlocked, so the unlock event is never raised for it (idempotent rule in AC 3).
- **Per-tick AND per-command:** the continent reducer must run from BOTH `tick()` (covers idle accrual crossing a threshold) AND `applyCommand()` (covers active player actions like `TapCountry`/`PurchaseUpgrade` that bump `totalInfluence` instantly). Without the per-command path, the player taps the last country needed for europe, sees their HUD jump past 1e9, but the celebration waits for the next ticker frame — feels broken.
- **Tick event ordering:** continent events emit BEFORE the trailing `Tick`. Same for `applyCommand`: continent events emit AFTER the originating command's event. This preserves causal ordering for audio/persistence subscribers.

### Architectural compliance (non-negotiable from project-context)

- `lib/game/` has ZERO Flutter imports. Pure Dart only.
- `evaluateContinentUnlocks` is a pure function. No `DateTime.now()` — `now` flows in as a parameter. No I/O. No RNG.
- Returns `Result<(GameState, List<GameEvent>), GameError>` — no exceptions for control flow. (`GameWorld.tick` may throw on `InvariantBroken` per the global pattern.)
- `ContinentUnlocked` is past-tense (event), not imperative (no `UnlockContinent` command — continents auto-unlock; no user input triggers them).
- `StreamController.broadcast(sync: true)` — already in `GameWorld._events`. Don't change. Subscribers must observe state + event in the same microtask.
- `Map.unmodifiable` for the new `unlockedContinents` map — match the existing `continentCompletions` pattern.
- Decimal comparison: use `<=` directly on `Decimal` (the `decimal: ^3.0.2` package supports operator overloads). For sort, use `compareTo`.

### Source tree components to touch

- `lib/game/game_state.dart` — add field, copyWith, equality, hashCode, toString, initialSeed pre-population.
- `lib/game/game_event.dart` — add `ContinentUnlocked`.
- `lib/game/features/continents/continents_reducer.dart` — **new** (matches `_bmad-output/game-architecture.md` line 575: `continents/ { state, reducer }`).
- `lib/game/game_world.dart` — wire reducer into `tick()` and `applyCommand()`; add `_evaluateContinentUnlocks(now)` helper.
- `test/game/game_state_seed_test.dart` — extend with seed pre-population test.
- `test/game/features/continents/continents_reducer_test.dart` — **new**.
- `test/game/game_world_test.dart` — extend with integration tests.

### Testing standards

- Pure-Dart tests (`import 'package:test/test.dart';` — NEVER `flutter_test` for `lib/game/`).
- Use existing `_buildSingleCountryContent` / `_buildThreeCountryContent` helper patterns from `test/game/game_world_test.dart`. Build inline content for multi-continent tests.
- Subscribe to `events` stream BEFORE triggering tick/command: `final captured = <GameEvent>[]; final sub = world.events.listen(captured.add); ... ; await Future<void>.delayed(Duration.zero); sub.cancel();` — events emit synchronously per architecture, so order assertions are deterministic.
- Use `FakeClock` from `test/helpers/fake_clock.dart` for `now`.
- For multi-continent test fixtures, build content JSON inline (see existing `_buildSingleCountryContent` pattern).

### Edge cases to test (AC #5, #8, plus defensive)

- Empty content (no continents) → no-op.
- All continents already unlocked → no-op, returns same state instance via `identical` check.
- Negative threshold in content → `Result.failure(InvariantBroken)` BEFORE allocating any map. (Defensive — content shouldn't have this, but guard the invariant.)
- Tied thresholds → deterministic ID-ASC ordering.
- `totalInfluence` exactly equal to threshold → unlocks (`<=`, not `<`).

### Project Structure Notes

- Aligns with existing per-feature folder layout: `lib/game/features/<feature>/<feature>_reducer.dart` (matches `countries_reducer.dart`, `leaders_reducer.dart`, `upgrades_reducer.dart`).
- New file `lib/game/features/continents/continents_reducer.dart` is the FIRST file in this feature folder. Story 4.3 (milestones) and 4.4 (completion bonus) will add siblings here. Don't create a `continent_state.dart` yet — there's no per-continent state beyond the bool map; if Story 4.3 needs richer state, it can introduce one.
- The choice to put `unlockedContinents` directly on `GameState` (rather than a new `ContinentState` aggregate) mirrors the existing `continentCompletions` pattern for the same reason: it's a sparse boolean, not a rich aggregate.

### Conflicts / variances

- Epic 4.2 AC enumerates threshold values (`Africa=0, Europe=1e9, Middle East=1e14, ...`) but those are **balance references**, not implementation constants. The reducer reads `ContinentDef.unlockThreshold`. Current `assets/data/continents.json` thresholds differ from the GDD list (Middle East is `1e12`, Asia is `1e14`, etc.) — this is intentional per Epic 10 ("BalanceConfig constants pinned and playtest-reviewed"). Do NOT "fix" `continents.json` in this story; the JSON is authoritative for runtime behavior, balance values come later.
- The previous Story 3.3 added `LeaderHired`/`LeaderUpgraded` events; this story adds `ContinentUnlocked`. The `AudioService` event handler wiring is Epic 8 — DO NOT add audio playback here. The architecture's open list includes `ContinentUnlocked` as a known future event, so wiring is anticipated.

### Project Context Rules

- **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only.
- **UI never mutates `GameState` directly.** UI dispatches a `GameCommand` via `ref.read(gameWorldProvider.notifier).apply(cmd)`. (Note: continent unlocks are NOT user-driven — there is NO `UnlockContinent` command. They are time/state-driven side effects of `tick`/`applyCommand`.)
- **Reducers:** Pure functions. NO clock reads, NO RNG reads, NO I/O. `now` and `rng` flow in as parameters. Return `Result<(NewState, ...), GameError>` — no exceptions for control flow.
- **Commands vs Events:** Commands (input to sim): imperative. Events (output from sim): past tense (`ContinentUnlocked`). Both are sealed class hierarchies. Exhaustive switch.
- **Big numbers:** All game math flows through `Influence` value objects. `Decimal` comparisons happen on the underlying `.value` only inside the reducer; never expose raw `Decimal` outside `lib/game/values/` to UI.
- **Result / error handling:** `Result<T, GameError>` (sealed) for anything that can fail meaningfully. NO exceptions for control flow.
- **Event bus discipline:** `StreamController.broadcast(sync: true)` — already in place; do NOT change. Audio/haptics/persistence subscribe; they NEVER re-emit events. `ContinentUnlocked` is emitted only from `GameWorld`.
- **Sealed switch must stay exhaustive.** Adding `ContinentUnlocked` to the `GameEvent` hierarchy will surface as a compiler error in any consumer that does an exhaustive `switch (event)` — verify and update those (likely the audio service stub and any test exhaustive switches; current code does NOT have an exhaustive `switch` over `GameEvent` outside tests).
- **No backward compatibility.** Per project rule: it's acceptable for old saves to break. Adding `unlockedContinents` to `GameState` does not require migration scaffolding for in-flight saves; persistence wiring is Epic 6.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2: Unlock Continent at Influence Threshold]
- [Source: _bmad-output/planning-artifacts/gdd.md#Content Breakdown] (continent threshold reference table)
- [Source: _bmad-output/game-architecture.md#7. Event Bus] (sealed `GameEvent` hierarchy includes `ContinentUnlocked`)
- [Source: _bmad-output/game-architecture.md#Source-tree layout] (lines 571–588: `lib/game/features/continents/`)
- [Source: _bmad-output/project-context.md#Critical Implementation Rules]
- [Source: lib/game/game_state.dart#L19] (existing `continentCompletions` pattern to mirror)
- [Source: lib/game/features/leaders/leaders_reducer.dart] (reducer signature pattern reference)
- [Source: assets/data/continents.json] (live threshold values; do not modify in this story)
- [Source: _bmad-output/implementation-artifacts/3-3-leader-hire-and-tier-system.md] (previous-story conventions: `Result<(GameState, GameEvent?), GameError>` reducer signature variant — note this story returns a **list** of events, not a single one)

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

### Completion Notes List

- Implemented `unlockedContinents` on `GameState` with `MapEquality`, `initialSeed` pre-population for `unlockThreshold <= 0`, and `ContinentUnlocked` event.
- Added pure `evaluateContinentUnlocks` in `continents_reducer.dart` (negative-threshold guard, sort by threshold then id, same-state short-circuit when no candidates).
- `GameWorld.tick`: always runs continent evaluation after `tickCountries`; emits `ContinentUnlocked` events before `Tick` when either countries changed or continents unlocked; throws `AssertionError` on invariant failure.
- `GameWorld.applyCommand`: uses `const Success<void, GameError>(null)` for `Noop`; after any successful command runs `_evaluateContinentUnlocks` so command events precede continent unlocks (AC 7).
- Integration tests: Task 8.1 uses high `totalInfluence` plus bank accrual on tick (engine does not add to `totalInfluence` on tick alone); Task 8.2 uses three continents at thresholds 0/10/20 and `totalInfluence` 100 with empty `unlockedContinents` instead of literal `1e15` while preserving ordering AC.
- Manual `GameState` fixtures with African content use `_seedAfricaUnlocked` so threshold-0 does not re-fire `ContinentUnlocked` during unrelated tests.
- Full `flutter test` passes.

### File List

- lib/game/game_state.dart
- lib/game/game_event.dart
- lib/game/features/continents/continents_reducer.dart
- lib/game/game_world.dart
- test/game/game_state_seed_test.dart
- test/game/game_state_test.dart
- test/game/game_event_test.dart
- test/game/features/continents/continents_reducer_test.dart
- test/game/game_world_test.dart
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-04-24: Story 4.2 implemented — continent unlock at influence threshold (`ContinentUnlocked`, `evaluateContinentUnlocks`, seed + tick + applyCommand wiring, tests).
