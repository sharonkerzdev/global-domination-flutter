# Story 4.4: Continent Completion Permanent Multiplier

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a permanent global multiplier when I own 100% of a continent's countries,
so that every subsequent action is amplified by my completed conquests.

## Acceptance Criteria

1. **Given** the milestone evaluator from Story 4.3 is about to emit `MilestoneReached(continentId, 100, ...)` followed by `ContinentCompleted(continentId)`, **When** the evaluator constructs the new `GameState`, **Then** the same returned state has `state.continentCompletions[continentId] = true` (in the same atomic mutation as the milestone tier append). The flag flip and the event emission happen in lockstep — never one without the other.
2. **Given** multiple continents are complete (`continentCompletions[c] == true` for `c ∈ {africa, europe, ...}`), **When** `IncomeCalculator.compute(country, state, content)` runs for **any** country (regardless of which continent that country belongs to), **Then** the `continentCompletionBonus` factor in the multiplier stack equals `∏(Decimal.one + content.continents[c].completionBonus)` over every `c` where `state.continentCompletions[c] == true`. When no continent is complete, the factor is `Decimal.one`.
3. **Given** a continent was previously completed and the state is loaded with `continentCompletions[C] = true` AND `reachedMilestones[C]` containing `100` (Epic 6 persistence shape), **When** the game boots and the next `applyCommand` runs (which triggers Story 4.3's `_evaluateMilestones`), **Then** the bonus already applies in `IncomeCalculator` AND `ContinentCompleted(C)` is **NOT** re-emitted (4.3's `reachedMilestones` ledger blocks the duplicate). Re-running the evaluator on an already-complete continent must be a no-op.
4. **Given** the existing income calculator test `5.6 continent completion isolation` (which constructs Egypt + `continentCompletions = {africa: true}` and expects rate `1.25`), **When** this story's semantics change to `_continentCompletionBonus` lands, **Then** the test still passes (single completed continent → product `(1 + 0.25) = 1.25`) and a NEW test pins Egypt's rate to `1.5` when only **Europe** (a different continent than Egypt's) is in `continentCompletions` — proving the bonus is global, not country-own-continent.
5. **Given** all 7 continents are complete (`continentCompletions == {africa: true, europe: true, middle_east: true, asia: true, north_america: true, south_america: true, oceania: true}`), **When** `IncomeCalculator.compute` runs for any country, **Then** the `continentCompletionBonus` factor equals `∏(1 + bonus)` over the seven continents per the live `assets/data/continents.json` values: `1.25 × 1.50 × 1.60 × 1.75 × 2.00 × 2.25 × 2.75 = 64.96875` (exact `Decimal`). The test SHOULD compute this expected value from `content.continents.values` rather than hardcoding the literal, so it auto-adjusts when Epic 10 retunes.
6. **Given** `state.continentCompletions[continentId]` references a continent id that is not in `content.continents` (defensive — should never happen in production content), **When** `IncomeCalculator.compute` runs, **Then** the missing continent is silently skipped in the product (treated as factor `1.0`) — no exception, no `Result.failure`.
7. **Given** the multiplier-stack ordering pinned in `IncomeCalculator.compute` by Story 3.1, **When** `continentCompletionBonus` is applied, **Then** it is applied at the same position the stack already occupies (between `leaderMultiplier` and `(1 + Σ achievementMultipliers)`). Test `5.11 composed stack order regression` (`expected = 2227.5` for Egypt + Africa-complete + IP100 + tier2 + 2 achievements + 2 global upgrades + golden 10× + boost 2×) MUST still pass without changing its expected value.

## Tasks / Subtasks

- [x] Task 1: Extend Story 4.3's `evaluateMilestones` to flip `continentCompletions[continentId]` at the 100% tier (AC: #1, #3)
  - [x] Subtask 1.1: Edit `lib/game/features/continents/milestones_reducer.dart` (created by Story 4.3). Inside the per-continent loop, when the 100% tier is detected as crossed AND being appended to `reachedMilestones`, ALSO build an updated `continentCompletions` map with `continentId: true`.
  - [x] Subtask 1.2: The `continentCompletions` mutation is **atomic** with the milestone tier append and the `MilestoneReached(100)` + `ContinentCompleted(id)` emissions — they all flow into the SAME returned `GameState`. Do not split into two passes.
  - [x] Subtask 1.3: Wrap the new `continentCompletions` map with `Map.unmodifiable(...)` (mirror the constructor pattern in `lib/game/game_state.dart` lines 35–37).
  - [x] Subtask 1.4: Idempotency — if `state.continentCompletions[continentId] == true` already, do NOT re-flip (no allocation) and do NOT emit a duplicate `ContinentCompleted` (Story 4.3's `reachedMilestones` ledger already prevents the milestone re-fire; relying on that means the flag flip is automatically idempotent because the 100%-tier branch never re-enters).
  - [x] Subtask 1.5: When zero continents reach 100% in this evaluation pass, `state.continentCompletions` MUST be the same instance as the input (no spurious `copyWith` allocation). Use `identical` or a "did anything change" boolean.
- [x] Task 2: Make the continent-completion bonus global in `IncomeCalculator` (AC: #2, #4, #5, #6, #7)
  - [x] Subtask 2.1: In `lib/game/features/economy/income_calculator.dart`, replace the body of `_continentCompletionBonus(CountryDef def, GameState state, ContentRegistry content)` so it ignores `def.continent` entirely and instead computes `∏(Decimal.one + content.continents[id].completionBonus)` over every `id` in `state.continentCompletions.entries.where((e) => e.value == true).map((e) => e.key)`. If no continents are complete, return `Decimal.one`.
  - [x] Subtask 2.2: Skip ids missing from `content.continents` (defensive — AC #6) by treating them as factor `1.0` (continue the loop).
  - [x] Subtask 2.3: Remove the unused `def` parameter from `_continentCompletionBonus` and update the single call site at line 44 of the same file. (Caller no longer needs to pass `def` for this helper.)
  - [x] Subtask 2.4: Update the docstring on `IncomeCalculator` (the numbered comment block, step 4 around line 18). New text should read: `× product over all complete continents of (1 + ContinentDef.completionBonus) — global factor, NOT per-country`.
  - [x] Subtask 2.5: Iteration order must be deterministic — iterate `state.continentCompletions.entries` (insertion order via `LinkedHashMap`) to produce reproducible product order. (`Decimal` multiplication is associative & commutative so order does not affect the value, but a stable order eases debugging.)
- [x] Task 3: Tests — `package:test/test.dart` only, NEVER `flutter_test` (AC: all)
  - [x] Subtask 3.1: Extend `test/game/features/economy/income_calculator_test.dart`:
    - Add test `5.6b continent completion is global, not country-own-continent`: Egypt + `continentCompletions = {europe: true}` → rate `1.5` (proving cross-continent semantics).
    - Add test `5.6c continent completion product across two continents`: Egypt + `continentCompletions = {africa: true, europe: true}` → rate `1.25 × 1.50 = 1.875`.
    - Add test `5.6d continent completion product across all seven`: Egypt + `continentCompletions = {africa: true, europe: true, middle_east: true, asia: true, north_america: true, south_america: true, oceania: true}` → rate `Decimal.parse('41.6015625')`.
    - Add test `5.6e continent completion ignores ids missing from content`: Egypt + `continentCompletions = {africa: true, ContinentId('atlantis'): true}` → rate `1.25` (atlantis silently skipped).
    - Test `5.6 continent completion isolation` and test `5.11 composed stack order regression` MUST be left unchanged AND MUST still pass with no expected-value drift. AC #7 hangs on this.
  - [x] Subtask 3.2: Extend `test/game/features/continents/milestones_reducer_test.dart` (created by Story 4.3):
    - Add test `100% milestone flips continentCompletions atomically with event emission`: build a state where 3 of 3 Africa countries are unlocked but `continentCompletions` is empty AND `reachedMilestones[africa]` does not contain 100. Run `evaluateMilestones`. Assert (a) returned state has `continentCompletions[africa] == true`, (b) returned state has `reachedMilestones[africa]` containing 100, (c) the event list contains `MilestoneReached(...100...)` IMMEDIATELY followed by `ContinentCompleted(africa)`.
    - Add test `re-running evaluator on a complete continent is a no-op (loaded-from-save scenario)`: build a state where `continentCompletions[africa] = true` AND `reachedMilestones[africa]` already contains 100, with all 3 Africa countries unlocked. Run `evaluateMilestones`. Assert (a) returned state is `identical` to input (no allocation), (b) event list is empty.
    - Add test `partial unlock does not flip continentCompletions`: 2 of 3 Africa countries unlocked, no prior milestones. Run `evaluateMilestones`. Assert `continentCompletions[africa]` stays absent/false even though 50% milestone fires.
  - [x] Subtask 3.3: Extend `test/game/game_world_test.dart`:
    - Add test `complete-africa via applyCommand emits ContinentCompleted and flips flag`: construct a `GameWorld` whose `initialState` has 3 of 3 Africa countries unlocked but `continentCompletions` empty (no save loaded yet, just a hand-built state). Dispatch any successful no-op-style command (e.g., `TapCountry` on a country with `bankedInfluence = Influence.zero` — succeeds with `Result.success` and no event). Subscribe to `world.events` and assert: `MilestoneReached(...100...)` appears followed by `ContinentCompleted(africa)`, and `world.state.continentCompletions[africa] == true` after the command returns.
    - Add test `loaded-state with continentCompletions[africa]=true does NOT re-fire ContinentCompleted on first command`: same as above but seed `continentCompletions = {africa: true}` AND `reachedMilestones = {africa: {25, 50, 75, 100}}`. Dispatch `TapCountry`. Assert `world.events` produces ZERO `ContinentCompleted` events for the lifetime of the world.
  - [x] Subtask 3.4: Run `flutter test` and confirm 449+ existing tests still pass after the `_continentCompletionBonus` semantics change. Tests `5.6` and `5.11` MUST still pass unchanged.
- [x] Task 4: Pre-flight verification before submitting for review
  - [x] Subtask 4.1: `flutter analyze` → zero warnings.
  - [x] Subtask 4.2: `dart format --set-exit-if-changed .` → no diff.
  - [x] Subtask 4.3: Grep `lib/game/` for `package:flutter` and `dart:ui` — must return zero matches in any file you edited.
  - [x] Subtask 4.4: Confirm `IncomeCalculator.compute` retains the documented multiplier-stack order (Story 3.1's invariant). The order of operations between steps 2–8 MUST be unchanged; only step 4's *value* changes.
  - [x] Subtask 4.5: Confirm no new `GameCommand`, no new `GameEvent`, no new state field, and no new file are introduced by this story. All deltas are inside `milestones_reducer.dart` (Task 1) and `income_calculator.dart` (Task 2) plus their tests.

### Review Findings

- [x] [Review][Decision] Milestone evaluation trigger semantics conflict — resolved to keep mutation-gated milestone evaluation (`_evaluateMilestones` runs only when command execution mutates state). Update Story 4.4 wording to match implementation semantics; do not change runtime behavior.
- [x] [Review][Patch] Prevent duplicate `ContinentCompleted` when completion flag is already true but `reachedMilestones` is inconsistent [`lib/game/features/continents/milestones_reducer.dart`]
- [x] [Review][Patch] Make all-seven completion test data-driven from live continent content source instead of hardcoded in-test continent values [`test/game/features/economy/income_calculator_test.dart`]

## Dev Notes

### Sibling-Story Coordination — READ FIRST

This story is the SMALLEST of Epic 4's stories because four of its prerequisites are already covered by Stories 4.1, 4.2, 4.3 (all `ready-for-dev` in `sprint-status.yaml` as of 2026-04-24):

| What 4.4 needed | Who already provides it |
|---|---|
| `ContinentCompleted` event class in `game_event.dart` | **Story 4.3** Task 1.2 |
| `evaluateMilestones` reducer that detects 100% and emits `ContinentCompleted` | **Story 4.3** Task 3 |
| `_evaluateMilestones(now)` post-command wiring in `GameWorld.applyCommand` | **Story 4.3** Task 4 |
| `continents_reducer.dart` file in `lib/game/features/continents/` | **Story 4.2** (different reducer — `evaluateContinentUnlocks`) |
| `unlockedContinents` state field | **Story 4.2** |
| `reachedMilestones` state field (the idempotency ledger that prevents re-fire) | **Story 4.3** |

**Story 4.4 owns ONLY two changes:**
1. Extend `evaluateMilestones` (in `milestones_reducer.dart`) to ALSO flip `state.continentCompletions[id] = true` when the 100% tier crosses, in the same atomic state mutation that 4.3 already emits the events from.
2. Flip the semantics of `IncomeCalculator._continentCompletionBonus` from per-country-own-continent to global product across all completed continents.

**Implementation sequencing:** Story 4.4 cannot be merged before Story 4.3 because Task 1 edits a file 4.3 creates. Story 4.4 also cannot be merged before Story 3.1 (already done) because it depends on the existing `_continentCompletionBonus` helper. If 4.4 is dev'd before 4.3 ships, the dev agent must coordinate or the merge order must put 4.3 first.

### What Already Exists (don't re-create)

- `GameState.continentCompletions: Map<ContinentId, bool>` — `lib/game/game_state.dart` lines 17–67. Constructor wraps with `Map.unmodifiable`, `copyWith` accepts the field, equality uses `MapEquality<ContinentId, bool>`. **Story 4.4 does NOT modify `game_state.dart`** — the field shape is exactly what's needed.
- `IncomeCalculator._continentCompletionBonus(CountryDef def, GameState state, ContentRegistry content)` — `lib/game/features/economy/income_calculator.dart` lines 56–66. Currently returns `1 + completionBonus` ONLY when the country's OWN continent is complete. **Story 4.4 changes the body to compute global product** (semantics flip; signature loses `def`).
- `ContinentDef.completionBonus: Decimal` — `lib/game/content/continent_def.dart` line 37. Loaded from `assets/data/continents.json`. Values: africa=`0.25`, europe=`0.50`, middle_east=`0.60`, asia=`0.75`, north_america=`1.00`, south_america=`1.25`, oceania=`1.75` (sum-of-`(1+bonus)` product = `41.6015625` exactly).
- `MapEquality<ContinentId, bool>` — already in `game_state.dart` line 14 (`_continentCompletionEq`); no new equality wiring needed in this story.
- Existing test `5.6 continent completion isolation` in `test/game/features/economy/income_calculator_test.dart` line 202 — Egypt + Africa-complete → rate `1.25`. Still passes under the new semantics because `(1 + 0.25) = 1.25` whether Africa is "Egypt's own continent that's complete" (old) or "the only completed continent" (new).
- Existing test `5.11 composed stack order regression` in the same file line 278 — Egypt + Africa-complete + IP100 + tier2 + 2 achievements + 2 global upgrades + golden 10× + boost 2× → rate `2227.5`. The Africa factor is `1.25` in both old and new semantics; this test must still pass unchanged. **If `5.11` drifts, you've broken multiplier stack ordering — STOP and re-read Story 3.1.**

### Multiplier Stack Discipline (Story 3.1's Invariant — DO NOT BREAK)

The exact order pinned by Story 3.1's `IncomeCalculator.compute` is the project's single source of truth for income math. Story 4.4 changes ONLY the value of step 4, never its position:

```
baseInfluence
  × (1 + ipLevel × IP_MULT_PER_LEVEL)         // step 2
  × leaderMultiplier                            // step 3
  × continentCompletionBonus                    // step 4 — STORY 4.4: change semantics, NOT position
  × (1 + Σ achievementMultipliers)              // step 5
  × globalUpgrades.influenceAmplifier           // step 6
  × goldenOpportunityMultiplier                 // step 7
  × boostMultiplier                             // step 8
```

The pinning test (`test/game/features/economy/income_calculator_test.dart` `5.11 composed stack order regression`) compares the result against `Decimal.parse('2227.5')`. Egypt is in Africa, so the Africa factor under old semantics = `(1 + 0.25) = 1.25`; under new semantics also = `1.25` (Africa is the sole completed continent). Identical numeric outcome — test must not change. AC #7 makes this explicit.

### Why the Atomic Flag Flip Lives Inside `evaluateMilestones`

Architectural rule (`_bmad-output/project-context.md` lines 87–92): "Audio/haptics/persistence subscribe to `gameWorld.events`. They NEVER call `AudioService.play(...)` from widgets." Generalized: only `GameWorld` mutates `GameState`; subscribers read events but never write back. So a "listener that flips `continentCompletions[id]` when `ContinentCompleted` fires" is forbidden — it would be a service writing back to the simulation.

The CORRECT location for the flag flip is the same reducer that emits the event: `evaluateMilestones` in `milestones_reducer.dart`. The state mutation and the event emission are produced together in one returned `(GameState, List<GameEvent>)` tuple; `GameWorld` then assigns the new state and fans the events. This pattern is the existing convention (mirrors how `applyHireLeader` simultaneously mutates `country.leaderTier` and emits `LeaderHired`).

### Idempotency Mechanics (AC #3 — load-from-save scenario)

Story 4.3's `evaluateMilestones` checks `state.reachedMilestones[continentId]` BEFORE emitting `MilestoneReached(continentId, tier)`. So when a save loads with `reachedMilestones = {africa: {25, 50, 75, 100}}` AND `continentCompletions = {africa: true}`, the next evaluator call:

1. Sees Africa's 100% tier already in `reachedMilestones` → skips the inner branch entirely.
2. Therefore never reaches Story 4.4's flag-flip code.
3. Therefore never re-emits `MilestoneReached(...100...)` or `ContinentCompleted(africa)`.

`continentCompletions[africa]` remains `true` (from save load), so `IncomeCalculator._continentCompletionBonus` already includes Africa's `1.25` factor on the very first tick after boot. **The idempotency is "free" — Story 4.4 inherits it from 4.3's ledger; do not re-implement it.**

### Defensive Skipping (AC #6) — Why It's Load-Bearing

The current `assets/data/countries.json` defines only 3 countries (all in Africa). The other six continents are `unlocked: false` and have ZERO countries. If a future content edit, a malformed JSON, or a corrupt save left `continentCompletions[someInvalidId] = true`, looking up `content.continents[someInvalidId]` would yield `null`. Without defensive skipping (Subtask 2.2), a `null` access would either NPE or include `Decimal.one` (no-op) accidentally — both are silent bugs.

Explicit `if (continentDef == null) continue;` is the project pattern (mirrors the existing helper at line 64: `if (continentDef == null) return Decimal.one;`). AC #6 pins this behavior so a corrupt save does not crash the income calculator.

### Continent Completion Bonus Values (from `assets/data/continents.json`)

| Continent | `completionBonus` | `(1 + bonus)` factor |
|---|---|---|
| africa | `0.25` | `1.25` |
| europe | `0.50` | `1.50` |
| middle_east | `0.60` | `1.60` |
| asia | `0.75` | `1.75` |
| north_america | `1.00` | `2.00` |
| south_america | `1.25` | `2.25` |
| oceania | `1.75` | `2.75` |

Product of all seven `(1 + bonus)` values — verified exact under `Decimal`:

```
1.25 × 1.50 = 1.875
1.875 × 1.60 = 3.000
3.000 × 1.75 = 5.250
5.250 × 2.00 = 10.500
10.500 × 2.25 = 23.625
23.625 × 2.75 = 64.96875
```

All-seven product = **`Decimal.parse('64.96875')`** — pinned in AC #5.

**Do NOT hardcode this literal in the test.** Epic 10 will retune `continents.json`; the test should compute the expected value from `content.continents.values` so it auto-adjusts:

```dart
test('5.6d continent completion product across all seven', () {
  final expected = content.continents.values.fold<Decimal>(
    Decimal.one,
    (acc, c) => acc * (Decimal.one + c.completionBonus),
  );
  final s = _state(continentCompletions: {
    for (final id in content.continents.keys) id: true,
  });
  expect(IncomeCalculator.compute(_egypt(), s, content).value, equals(expected));
});
```

This pattern means the test self-adjusts when Epic 10 retunes content; only AC documentation needs to update.

### Always Read from `ContentRegistry` — Never Hardcode in `lib/game/`

Per `_bmad-output/project-context.md` line 259: "Never hardcode balance numbers in UI or sim logic — always read from `BalanceConfig` or `ContentRegistry`." The continent completion bonuses live in `assets/data/continents.json`, parsed into `ContentRegistry.continents`. `IncomeCalculator._continentCompletionBonus` ALREADY reads from `content.continents[id].completionBonus` at line 65 — Story 4.4 keeps that pattern; the only change is iterating over ALL completed continents instead of just one.

### Source Tree Components to Touch

Edit (these files exist; modify in place):
- `lib/game/features/economy/income_calculator.dart` — change `_continentCompletionBonus` body and signature; update docstring.

Edit (these files will exist after Story 4.3 ships; modify in place):
- `lib/game/features/continents/milestones_reducer.dart` — extend the 100%-tier branch to flip `continentCompletions[id] = true`.

Extend test files:
- `test/game/features/economy/income_calculator_test.dart` — new tests `5.6b`, `5.6c`, `5.6d`, `5.6e`. Existing `5.6` and `5.11` left untouched.
- `test/game/features/continents/milestones_reducer_test.dart` (created by Story 4.3) — new tests for atomic flag flip and load-from-save idempotency.
- `test/game/game_world_test.dart` — new integration tests for end-to-end completion flow.

DO NOT touch (out of scope, will conflict):
- `lib/game/game_event.dart` — `ContinentCompleted` is created by Story 4.3.
- `lib/game/game_command.dart` — no new commands. Continent completion is a side effect of state, not user input.
- `lib/game/game_state.dart` — `continentCompletions` field already exists. Do not add new fields.
- `lib/game/game_world.dart` — `_evaluateMilestones` wiring is added by Story 4.3.
- `lib/game/features/continents/continents_reducer.dart` — owned by Story 4.2.
- `assets/data/continents.json` — Epic 10 tunes; do not touch in 4.4.
- `lib/data/**` (persistence is Epic 6's job).
- `lib/ui/**` (celebration modal is Epic 7/8's job).

### Architecture Compliance

- `lib/game/` has ZERO Flutter imports — confirmed for both files this story edits (income_calculator.dart and milestones_reducer.dart, both pure Dart).
- Reducers are pure: no `DateTime.now()`, no `Random()`, no I/O. The `now` parameter already flows into `evaluateMilestones` per Story 4.3's contract; Story 4.4 changes the state-construction logic only, not the purity boundary.
- `Result<T, GameError>` — `evaluateMilestones` does NOT return `Result` (per Story 4.3's design — milestones can never fail meaningfully); 4.4 inherits that. `IncomeCalculator._continentCompletionBonus` returns `Decimal` directly; defensive skipping (AC #6) avoids any need for `Result.failure`.
- Sealed-switch exhaustiveness — no new `GameEvent` or `GameCommand` variants introduced; no consumer needs updating.
- Immutability — all `GameState` mutations via `copyWith` + `Map.unmodifiable`; `IncomeCalculator` is stateless (`abstract final class`).

### Library / Framework Requirements

- `package:decimal/decimal.dart` `^3.0.2` — for `Decimal.one + Decimal` arithmetic and `Decimal *` chaining in the global product. Already a project dependency; no `pubspec.yaml` change.
- `package:test/test.dart` — for all new tests. **Do NOT use `flutter_test`** in `test/game/`.
- No new packages.

### Project Context Rules (extracted from `_bmad-output/project-context.md`)

- **`lib/game/` has ZERO Flutter imports.** Both files edited in this story (`income_calculator.dart`, `milestones_reducer.dart`) are pure Dart and stay that way.
- **UI never mutates `GameState` directly.** This story introduces no UI surface. The `state.continentCompletions[id] = true` flip happens in the simulation reducer, never in a widget.
- **Reducers:** Pure functions. No clock/RNG/IO. The Story-4.3 reducer already accepts `now` as a parameter; Story 4.4 inherits.
- **Commands vs Events:** No new commands or events in this story. `ContinentCompleted` (event, past-tense) is added by Story 4.3.
- **Big numbers:** All multiplier math through `Decimal`. The product `∏(1 + bonus)` chains `Decimal *` operations; never `double`.
- **Multiplier stack — single source of truth in `IncomeCalculator.compute`.** Story 4.4 modifies `_continentCompletionBonus` IN PLACE inside `IncomeCalculator` — no parallel multiplier helper anywhere else. Step 4 of the stack changes value, not position.
- **Result / error handling:** `_continentCompletionBonus` cannot fail; missing-content scenarios degrade gracefully (AC #6).
- **Anti-patterns to avoid (project-context.md lines 351–367):** No `print` (none added). No per-tick allocations (the new product loop runs inside `IncomeCalculator.compute`, which IS per-tick; ensure the loop allocates nothing — `for (final entry in state.continentCompletions.entries) ...` is acceptable, no list materialization needed).

### Performance Note (project-context.md line 145)

`IncomeCalculator.compute` runs once per unlocked country per tick — it is on the hot path. The new `_continentCompletionBonus` body iterates `state.continentCompletions.entries`, which is `O(continents)` = `O(7)` worst case. That's negligible at production sizes. **Do not pre-cache the product on `GameState`** as a derived field — it would create a new invariant to maintain (recomputed on every `continentCompletions` change), and the existing per-tick cost is well below the 1ms tick budget. Keep the computation inline in `IncomeCalculator`.

If profiling later shows this loop is hot (unlikely until 7+ continents are completed AND `compute` is called >100k times/second), the optimization is to memoize the product on `GameState.copyWith`. That is explicitly OUT of scope for this story.

### Testing Standards Summary

- Pure-Dart tests for `lib/game/` (`test/game/...`) MUST `import 'package:test/test.dart';` — NEVER `flutter_test`.
- Use `IncomeCalculator.compute` directly in income tests; no widget pump.
- `GameWorld` tests construct a real `GameWorld` with a `Clock` fake and a hand-built `ContentRegistry` — copy the established pattern from `test/game/game_world_test.dart`. Subscribe via `world.events.listen(...)` synchronously (the controller is `sync: true`).
- `Decimal` expectations: prefer `Decimal.parse('...')` literal expectations; for content-driven products (AC #5), compute the expected value from `content.continents.values` so the test self-adjusts to Epic 10 retuning. Never compare via `toString()`.
- The new `5.6b` test should use `Egypt + continentCompletions = {europe: true}` (NOT Africa) to prove the cross-continent semantics flip — this is the most important new test in the suite.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 4 — Story 4.4 Continent Completion Permanent Multiplier]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3 — milestone reducer that emits ContinentCompleted at 100%]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1 — pinned multiplier stack order; do not reorder]
- [Source: _bmad-output/planning-artifacts/epics.md#FR9 — Continent completion permanent multipliers]
- [Source: _bmad-output/planning-artifacts/gdd.md#Continent Completion Bonuses — +0.25× through +1.75×]
- [Source: _bmad-output/game-architecture.md#12 DI & Multiplier Stack Ordering — exact stack and one-pure-function rule]
- [Source: _bmad-output/game-architecture.md#Event System — sealed hierarchy, sync broadcast, only GameWorld emits]
- [Source: _bmad-output/project-context.md#Multiplier stack — project-wide invariant]
- [Source: _bmad-output/project-context.md#Anti-patterns — automatic PR rejection list]
- [Source: lib/game/game_state.dart — `continentCompletions` field exists with `Map.unmodifiable` semantics; no schema change needed]
- [Source: lib/game/features/economy/income_calculator.dart — `_continentCompletionBonus` current per-country semantics that this story converts to global product]
- [Source: lib/game/content/continent_def.dart — `completionBonus: Decimal` field source]
- [Source: assets/data/continents.json — bonus values consumed by the calculator]
- [Source: test/game/features/economy/income_calculator_test.dart#L202 — existing 5.6 test that must continue to pass; #L278 — 5.11 stack-order regression that must continue to pass]
- [Source: _bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md — sibling story that creates `milestones_reducer.dart` and `ContinentCompleted` event; this story extends 4.3's reducer]
- [Source: _bmad-output/implementation-artifacts/4-2-unlock-continent-at-influence-threshold.md — sibling story that establishes `lib/game/features/continents/` folder convention and `_evaluateContinentUnlocks` post-command pattern]
- [Source: _bmad-output/implementation-artifacts/3-3-leader-hire-and-tier-system.md — most recent shipped story; mirror its review-fix cadence and test discipline]

## Change Log

- 2026-04-25: Implemented atomic `continentCompletions` flip at 100% in `evaluateMilestones`, global product in `IncomeCalculator._continentCompletionBonus`, tests 5.6b–5.6e + milestone/game_world coverage; full suite 512 tests, analyze clean, format clean.

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- `evaluateMilestones` now builds optional `updatedCompletions` only when crossing 100% for a continent not already marked complete; `copyWith(continentCompletions: null)` preserves the input map instance when no completion flip occurs (same as Subtask 1.5). `GameState` constructor still applies `Map.unmodifiable` to any new map.
- `_continentCompletionBonus` iterates `state.continentCompletions.entries` in insertion order, multiplies `(1 + completionBonus)` for each completed id present in `content.continents`, skips unknown ids.
- GameWorld integration test uses `UnlockCountry` for the third African country (not zero-bank `TapCountry`) because milestone evaluation only runs when `applyCommand` mutates state; loaded-save test uses `TapCountry` with banked influence so milestones run without re-firing `ContinentCompleted`.
- Subtask 3.1 story text still mentions `41.6015625` for 5.6d; implementation follows AC #5 and Dev Notes: expected product is computed from fixture continents (matching live `continents.json` bonuses → `64.96875`).

### File List

- `lib/game/features/continents/milestones_reducer.dart`
- `lib/game/features/economy/income_calculator.dart`
- `test/game/features/continents/milestones_reducer_test.dart`
- `test/game/features/economy/income_calculator_test.dart`
- `test/game/game_world_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
