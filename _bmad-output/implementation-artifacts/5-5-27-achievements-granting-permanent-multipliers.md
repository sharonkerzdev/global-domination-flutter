# Story 5.5: 27 Achievements Granting Permanent Multipliers

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want 27 discoverable achievements that grant permanent influence multipliers as I hit progression milestones,
so that my long-term play is rewarded with a steadily growing base power.

## Acceptance Criteria

1. **Given** `assets/data/achievements.json` populated with **exactly 27 entries**, each shaped `{ id, name, conditionType, conditionParams, rewardType, rewardValue }`
   **When** `ContentRegistry.fromJsonStrings(...)` parses the file at boot
   **Then** all 27 `AchievementDef`s load into `content.achievements` (already-existing `List<AchievementDef>` field) and a parse-time check fires `ContentLoadException` if the count != 27.
2. **Given** the achievements are loaded
   **When** they are inspected
   **Then** every entry's `rewardType` is one of `{'influenceMultiplier', 'intel'}` and every `conditionType` is one of the supported set in **Dev Notes → Condition vocabulary** — any unknown value throws `ContentLoadException` at parse time (fail fast, don't lazy-fail in the evaluator).
3. **Given** a fresh `GameState` (no achievements earned)
   **When** `evaluateAchievements(state, content, now)` runs
   **Then** for every achievement whose `id` is **not** already in `state.earnedAchievementIds` AND whose condition evaluates to `true` against `state`, the function appends the id to `earnedAchievementIds` and emits one `AchievementEarned(at: now, achievementId: id, rewardType: ..., rewardValue: ...)` event per newly-earned achievement.
4. **Given** an already-earned achievement (its id is in `state.earnedAchievementIds`)
   **When** `evaluateAchievements` runs again
   **Then** it is skipped — no re-firing, no duplicate event, identical state returned (`identical(prevState, nextState) == true` when no other change).
5. **Given** the evaluator wires into `GameWorld.applyCommand` immediately **after** `_evaluateMilestones` (the last reducer step in the post-command pipeline)
   **When** any successful command mutates state (`UnlockCountry`, `TapCountry`, `PurchaseUpgrade`, `HireLeader`, `UpgradeLeader`)
   **Then** newly-satisfied achievements are detected in the same `applyCommand` call, their `AchievementEarned` events are emitted on the broadcast stream in declaration order, and the resulting `state.earnedAchievementIds` is observable to the very next `IncomeCalculator.compute` call.
6. **Given** a newly-earned achievement with `rewardType == 'influenceMultiplier'`
   **When** the next tick runs through `IncomeCalculator.compute`
   **Then** the per-second rate uses the new `(1 + Σ achievementMultipliers)` factor — already wired in `_sumAchievementMultipliers` (no IncomeCalculator change in this story; just verify the integration via test).
7. **Given** an achievement with `rewardType == 'intel'`
   **When** earned
   **Then** the achievement id is still added to `earnedAchievementIds` and `AchievementEarned` still fires with `rewardType: 'intel'`, but **no currency mutation occurs in this story** (the `totalIntel` field is owned by Story 5.2 — Activate Boost). This story documents the deferred wiring; do **not** add a `totalIntel` field here. All 27 seeded entries in this story use `rewardType: 'influenceMultiplier'` so this branch is exercised only by tests that synthesize intel-typed defs in fixtures.
8. **Given** a save is loaded with `earnedAchievementIds` already populated (Story 6.1 round-trip)
   **When** the game boots and the first `applyCommand` runs the evaluator
   **Then** previously-earned achievements are NOT re-fired (idempotent — `earnedAchievementIds` is the ledger, mirroring Story 4.3's `reachedMilestones` pattern).
9. **Given** `evaluateAchievements` is invoked
   **When** examined for purity
   **Then** it is a pure function with signature `(GameState, ContentRegistry, DateTime now) → (GameState, List<GameEvent>)`, no `DateTime.now()`, no `Random()`, no I/O — `now` is injected, used only for event timestamps (matches `evaluateMilestones` and `evaluateContinentUnlocks` patterns).
10. **Given** the `AchievementEarned` event
    **When** sealed-switch consumers (audio service, persistence subscriber, future UI) compile
    **Then** they exhaustively handle the new variant — no `case _ =>` catch-all is added to existing switches in `lib/game/`, `lib/data/`, or test code (architecture invariant; the compiler enforces it).

## Tasks / Subtasks

- [x] **Task 1: Add the `AchievementEarned` event to `lib/game/game_event.dart`** (AC: 3, 5, 7, 10)
  - [x] 1.1 Append a new `final class AchievementEarned extends GameEvent` after `ContinentCompleted`. Fields: `final String achievementId; final String rewardType; final Decimal rewardValue;`. Constructor `const AchievementEarned(super.at, { required this.achievementId, required this.rewardType, required this.rewardValue });`
  - [x] 1.2 Implement manual `==`, `hashCode` (`Object.hash(at, achievementId, rewardType, rewardValue)`), and `toString` — same pattern as `MilestoneReached`
  - [x] 1.3 Do NOT add a corresponding `AchievementEarn` command — achievements fire from state evaluation, never from user input
  - [x] 1.4 Verify no exhaustive switch on `GameEvent` exists outside the lib/game/ event consumers; if any service or test does `switch (event)`, the compiler will force adding a case — handle as no-op where appropriate

- [x] **Task 2: Define the achievement condition vocabulary and evaluator helper** (AC: 2, 3, 9)
  - [x] 2.1 Create `lib/game/features/achievements/achievement_condition.dart` (NEW file; NEW folder `lib/game/features/achievements/` — first of its kind, matches architecture's documented per-feature layout)
  - [x] 2.2 Define a top-level pure function `bool evaluateAchievementCondition(AchievementDef def, GameState state, ContentRegistry content)` that switches on `def.conditionType` and reads `def.conditionParams`. Supported types — see **Dev Notes → Condition vocabulary** for exact param shapes:
        - `totalInfluenceAtLeast` → `state.totalInfluence.value >= Decimal.parse(params['value'])`
        - `countriesUnlockedAtLeast` → count of `state.countries.values.where((c) => c.unlocked)` ≥ `params['count']`
        - `continentCompleted` → `state.continentCompletions[ContinentId(params['continentId'])] == true`
        - `leadersHiredAtLeast` → count of `state.countries.values.where((c) => c.leaderTier != LeaderTier.none)` ≥ `params['count']`
        - `maxIpLevelAtLeast` → `state.countries.values.fold(0, (m, c) => c.ipLevel > m ? c.ipLevel : m) >= params['level']`
  - [x] 2.3 Unknown `conditionType` MUST throw `StateError('Unknown achievementConditionType: ${def.conditionType}')` — but this should never reach runtime because parse-time validation in Task 4 rejects unknown types
  - [x] 2.4 Each branch reads ONLY from the typed `state` and `content` — no allocations beyond what's necessary (this runs after every `applyCommand`)

- [x] **Task 3: Implement the achievements reducer** (AC: 3, 4, 5, 8, 9)
  - [x] 3.1 Create `lib/game/features/achievements/achievements_reducer.dart`
  - [x] 3.2 Top-level pure function:
        ```dart
        (GameState, List<GameEvent>) evaluateAchievements(
          GameState state,
          ContentRegistry content,
          DateTime now,
        )
        ```
  - [x] 3.3 Iterate `content.achievements` in declaration order (the list is preserved by `ContentRegistry`). Skip any `def.id` already in `state.earnedAchievementIds`. For the rest, evaluate `evaluateAchievementCondition(def, state, content)`.
  - [x] 3.4 Newly-true achievements: append `def.id` to a working `Set<String>`, add an `AchievementEarned(now, achievementId: def.id, rewardType: def.rewardType, rewardValue: def.rewardValue)` to a working `List<GameEvent>`.
  - [x] 3.5 If the working set is empty → return `(state, const <GameEvent>[])` (no copyWith, no allocation).
  - [x] 3.6 Otherwise return `(state.copyWith(earnedAchievementIds: {...state.earnedAchievementIds, ...newlyEarned}), events)`.
  - [x] 3.7 Do NOT mutate `totalInfluence`, `totalIntel`, or any other field — multiplier rewards apply lazily via `IncomeCalculator._sumAchievementMultipliers` (already wired). Intel rewards are a no-op in this story (AC #7).
  - [x] 3.8 The function MUST NOT call `evaluateMilestones`, `evaluateContinentUnlocks`, or any other reducer — the orchestration is `GameWorld`'s job.

- [x] **Task 4: Add parse-time validation in `lib/game/content/content_registry.dart`** (AC: 1, 2)
  - [x] 4.1 In `_parseAchievements`, after building `list`, assert `list.length == 27` — throw `ContentLoadException('Expected exactly 27 achievements, got ${list.length}')` otherwise.
  - [x] 4.2 For each entry, validate `rewardType ∈ {'influenceMultiplier', 'intel'}` — throw `ContentLoadException('AchievementDef ${def.id} has unknown rewardType: ${def.rewardType}')` otherwise.
  - [x] 4.3 Validate `conditionType ∈ {'totalInfluenceAtLeast', 'countriesUnlockedAtLeast', 'continentCompleted', 'leadersHiredAtLeast', 'maxIpLevelAtLeast'}` — throw `ContentLoadException` otherwise.
  - [x] 4.4 Validate that for `continentCompleted`, `conditionParams['continentId']` matches a key in the already-parsed `continents` map (call `_parseAchievements` AFTER `_parseContinents` and pass continents in — adjust signature as needed).
  - [x] 4.5 Validate ids are unique across the 27 entries (`Set`-based de-dup check).
  - [x] 4.6 Update existing `_parseAchievements` callers / tests that pass `'[]'` — they must be migrated to either pass a 27-entry fixture OR the call site must be a test that doesn't exercise the achievements list. Because production callers always go through `assets/data/achievements.json` (which this story populates with 27 entries), only tests are affected — see Task 7.

- [x] **Task 5: Wire the evaluator into `lib/game/game_world.dart`** (AC: 5, 8)
  - [x] 5.1 Add a private method:
        ```dart
        void _evaluateAchievements(DateTime now) {
          final (next, events) = evaluateAchievements(_state, _content, now);
          if (events.isEmpty) return;
          _state = next;
          for (final e in events) {
            _events.add(e);
          }
        }
        ```
  - [x] 5.2 In `applyCommand`, **after** every existing `_evaluateMilestones(_clock.now())` call, add `_evaluateAchievements(_clock.now())` — both branches (the `UnlockCountry` branch and the general `switch`-based branch).
  - [x] 5.3 Order matters: milestones MUST run before achievements so that a 100% milestone flipping `continentCompletions[id] = true` is visible to a `continentCompleted`-typed achievement in the same `applyCommand`.
  - [x] 5.4 Do NOT run achievements on `tick()` — out of scope per AC #5; the next user command catches up.
  - [x] 5.5 Use `_clock.now()` for the `now` argument so tests can pin timestamps via `FakeClock`.
  - [x] 5.6 Invoke evaluator using the same `if (result.isSuccess && _state != stateBeforeCommand)` gate that already protects the milestone evaluator — do NOT run on commands that returned a `Result.failure` or didn't change state.

- [x] **Task 6: Seed `assets/data/achievements.json` with 27 placeholder entries** (AC: 1, 6)
  - [x] 6.1 Replace the current `[]` content with 27 entries. All 27 use `rewardType: 'influenceMultiplier'` (intel-typed entries deferred per AC #7).
  - [x] 6.2 Distribute across the GDD's three categories (milestone / activity / completion) using the supported condition vocabulary:
        - **Country milestones (10):** `countriesUnlockedAtLeast` at `count = 1, 5, 10, 20, 30, 40, 50, 60, 70, 79` — names: "First Conquest", "Five Flags", "Decade Done", "Twenty Strong", … "World Conqueror"
        - **Influence milestones (8):** `totalInfluenceAtLeast` at `value = 1e3, 1e6, 1e9, 1e12, 1e18, 1e24, 1e30, 1e36` — names: "Kilo Influence", "Mega Influence", "Giga Influence", … "Undecillion"
        - **Continent completions (7):** `continentCompleted` for each of `africa, europe, middle_east, asia, south_america, north_america, oceania`
        - **Leader / IP milestones (2):** `leadersHiredAtLeast` at `count = 1` ("First Leader"); `maxIpLevelAtLeast` at `level = 50` ("Power Player")
  - [x] 6.3 Choose `rewardValue` placeholders in the range `0.05` to `0.50` — exact values are tuned in **Story 10.1**; do not over-invest tuning here. Use ASCII strings (e.g. `"0.10"`) so `Decimal.parse` is exact.
  - [x] 6.4 Use stable, snake_case ids that won't churn in 10.1 (e.g. `ach_first_conquest`, `ach_continent_africa`, `ach_total_influence_1e9`). Names are prose ("First Conquest"). The id field is the persistence key — don't rename later.
  - [x] 6.5 Validate the file parses by running `flutter test` — the parse-time assertions from Task 4 will fail loudly if the file is malformed.

- [x] **Task 7: Update existing tests that pass empty achievements JSON** (AC: 1)
  - [x] 7.1 Most pure-Dart tests under `test/game/**` build inline fixture content via `ContentRegistry.fromJsonStrings(achievementsJson: '[]', ...)`. After Task 4 lands, those tests will fail with "Expected exactly 27 achievements, got 0".
  - [x] 7.2 Introduce a shared helper `test/helpers/achievements_fixture.dart` that returns `String trivial27AchievementsJson()` — 27 entries with `conditionType: 'countriesUnlockedAtLeast', count: 999999` so they NEVER fire in fixtures that don't unlock 999999 countries (i.e. effectively inert). All 27 use `rewardType: 'influenceMultiplier'` and `rewardValue: '0'` so they contribute nothing to multipliers even if hypothetically earned.
  - [x] 7.3 Update every existing call site of `ContentRegistry.fromJsonStrings(achievementsJson: '[]', ...)` to use `trivial27AchievementsJson()` instead. Use Grep on `'achievementsJson: '` to find all call sites:
        - `test/game/features/economy/income_calculator_test.dart` — preserves its custom 1–2 entry fixtures only in tests that ASSERT on multipliers; expand those to 27 padded entries (use the helper, append the assertion-specific entries).
        - `test/game/features/continents/milestones_reducer_test.dart`, `unlocks_reducer_test.dart`, `continents_reducer_test.dart`
        - `test/game/features/countries/countries_reducer_test.dart`
        - `test/game/features/leaders/leaders_reducer_test.dart`
        - `test/game/features/upgrades/upgrades_reducer_test.dart`
        - `test/game/game_world_test.dart`, `test/game/game_state_seed_test.dart`, `test/game/game_state_test.dart`, `test/game/game_command_test.dart`, `test/game/game_event_test.dart`
        - `test/game/features/continents/next_unlock_selector_test.dart`, `test/helpers/next_unlock_test_fixtures.dart`
        - `test/providers/feature_providers_test.dart`
  - [x] 7.4 For tests that ALREADY define a non-empty achievements fixture (e.g. `income_calculator_test.dart`'s `ach_mult_small`, `ach_mult_big`, `ach_intel`), use the helper to pad up to 27 total entries, ensuring the assertion-target ids remain.

- [x] **Task 8: Pure-Dart unit tests for the evaluator** (AC: 3, 4, 5, 6, 7, 8, 9)
  - [x] 8.1 Create `test/game/features/achievements/achievements_reducer_test.dart` using `package:test/test.dart` (NOT `flutter_test`).
  - [x] 8.2 Build a fixture `ContentRegistry` with 27 achievements, where (say) the first 3 cover each interesting condition type (`countriesUnlockedAtLeast: 1`, `totalInfluenceAtLeast: 1000`, `continentCompleted: africa`) and the remaining 24 use the inert pattern from Task 7.
  - [x] 8.3 Test: from a fresh `GameState` with no countries unlocked → evaluator returns `(state, [])` and earnedAchievementIds remains empty.
  - [x] 8.4 Test: state with 1 country unlocked → evaluator emits exactly one `AchievementEarned` for `ach_first_conquest`-equivalent, adds id to `earnedAchievementIds`.
  - [x] 8.5 Test: state with `totalInfluence` ≥ threshold AND a country unlocked → both fire in the same call, in declaration order (assert event sequence equality).
  - [x] 8.6 Test (idempotency / AC #4): re-run evaluator on the post-state from 8.4 → returns `(samePostState, [])`, no duplicate event, `identical(samePostState, returnedState)` holds.
  - [x] 8.7 Test (AC #7 intel branch): build fixture with one `rewardType: 'intel'` achievement → evaluator still adds id and emits event with `rewardType: 'intel'`, but no `totalIntel` field is mutated (asserted by checking only `earnedAchievementIds` changed).
  - [x] 8.8 Test (AC #9 purity): evaluator returns deterministic results for same inputs across two calls (different injected `now` only changes event timestamp).
  - [x] 8.9 Test (AC #6 IncomeCalculator integration): build fixture with one earned multiplier achievement and one country unlocked, call `IncomeCalculator.compute(country, postState, content)` — assert the returned rate equals `baseInfluence × ipFactor × leaderFactor × continentFactor × (1 + rewardValue) × ...` (cross-check by removing the earned id and recomputing).

- [x] **Task 9: GameWorld integration tests** (AC: 5, 8, 10)
  - [x] 9.1 Add tests to `test/game/game_world_test.dart` (existing file).
  - [x] 9.2 Test: dispatch `UnlockCountry` that takes the unlocked-countries count from 0 → 1 with a fixture where `ach_first_conquest` exists → assert `state.earnedAchievementIds` contains the id AND the broadcast stream emitted `AchievementEarned` (use `expectLater(world.events, emitsThrough(...))` or collect events to a list).
  - [x] 9.3 Test: dispatch a command that completes a continent (i.e. unlocks the last country, milestone evaluator flips `continentCompletions['africa'] = true`) → assert the `continentCompleted: africa` achievement is emitted **after** the `MilestoneReached` and `ContinentCompleted` events (declaration-order ledger; this validates Task 5.3 ordering).
  - [x] 9.4 Test: dispatch a `Result.failure` command (e.g. `UnlockCountry` with insufficient influence) → assert NO `AchievementEarned` events fire even if a hypothetical achievement is satisfied by the prior state (`stateBeforeCommand == _state` short-circuit gate).
  - [x] 9.5 Test (idempotency / load-from-save): boot `GameWorld` with `initialState: GameState(... earnedAchievementIds: {'ach_first_conquest'})` and a state that satisfies `ach_first_conquest` → first `applyCommand(Noop())` does NOT re-fire the event (Noop bypasses the gate via early-return; use any minimal command that exercises the gate, or assert by reading state directly without dispatching).

- [x] **Task 10: Architecture compliance and full validation** (AC: 9, 10)
  - [x] 10.1 New files under `lib/game/features/achievements/` MUST contain no `package:flutter/`, no `dart:ui`, no `lib/data/` imports — `test/architecture/game_boundary_test.dart` enforces this.
  - [x] 10.2 `evaluateAchievements` and `evaluateAchievementCondition` MUST be pure (no `DateTime.now()`, no `Random()`).
  - [x] 10.3 No new income math is introduced (`test/architecture/no_duplicate_income_math_test.dart`'s grep guard does not flag any `def.baseInfluence *` or `country.baseInfluence *` patterns in the new files).
  - [x] 10.4 `flutter analyze` — 0 warnings.
  - [x] 10.5 `dart format --set-exit-if-changed .`
  - [x] 10.6 `flutter test` — full suite passes (existing + new). Expect ~12–15 new tests under `test/game/features/achievements/` plus 4–5 added to `test/game/game_world_test.dart`.
  - [x] 10.7 Set `Status` to `review` and append entries to Completion Notes / File List.

### Review Findings

- [x] [Review][Patch] Validate achievement condition parameter shapes at parse time [lib/game/content/content_registry.dart:120]
- [x] [Review][Patch] Add coverage for achievement parsing guardrails and production achievement asset parsing [test/game/content/content_registry_test.dart:113]

## Dev Notes

### Why this story is mostly system, only minimally content

The `IncomeCalculator` already references `state.earnedAchievementIds` and `content.achievements` and already sums `rewardType == 'influenceMultiplier'` into the multiplier stack (see `_sumAchievementMultipliers`). `GameState` already has the `earnedAchievementIds` field. `AchievementDef` is already defined and parsed. **What's missing is the evaluator + event + GameWorld wire-up + populated content + parse-time guardrails.**

This story does NOT:
- Introduce a new `GameState` field (everything needed is already there).
- Modify `IncomeCalculator` (it's already correct; just unexercised).
- Tune the final reward values — that's Story 10.1's job.
- Add a `totalIntel` field — that's Story 5.2's job.
- Build any UI — Achievement modals/screens land in Epic 7.

### Coordination with sibling Epic 5 stories

Stories 5.1–5.5 are simultaneously `backlog` in the sprint plan. This story is the **most independent** of the five — it does not require Goldens, Boosts, Missions, or Daily Rewards to land first. It only touches:
- `lib/game/game_event.dart` (append `AchievementEarned`)
- `lib/game/game_world.dart` (append `_evaluateAchievements` call)
- `lib/game/content/content_registry.dart` (parse-time validation)
- `lib/game/features/achievements/` (NEW folder)
- `assets/data/achievements.json` (replace `[]` with 27 entries)
- `test/game/features/achievements/` (NEW folder)
- Existing tests that pass `achievementsJson: '[]'` (migrate to a 27-entry fixture helper)

Story 5.2 (Activate Boost) will introduce `state.totalIntel`. When that lands, a one-line follow-up to `evaluateAchievements` will start applying `rewardType: 'intel'` rewards. **Do not pre-add `totalIntel` here** — let 5.2 own that field's lifecycle.

### Architecture compliance (non-negotiable)

- **`lib/game/` has ZERO Flutter imports.** New files MUST NOT import `package:flutter/*` or `dart:ui`. Use `package:meta/meta.dart` for `@immutable` if needed (the reducer file likely needs nothing).
- **Reducer purity.** `evaluateAchievements` is a pure function with signature `(GameState, ContentRegistry, DateTime now) → (GameState, List<GameEvent>)`. No clock reads, no RNG, no I/O — `now` is injected. Mirrors `evaluateMilestones` (`lib/game/features/continents/milestones_reducer.dart`) and `evaluateContinentUnlocks`.
- **No new event source.** Only `GameWorld` emits events on the broadcast stream. The achievements reducer **returns** events — it does NOT push to the stream itself.
- **Sealed-switch discipline.** `AchievementEarned extends GameEvent` — adding it forces every exhaustive `switch (event)` in the codebase to handle (or default-no-op via fallthrough where appropriate). Audio/haptics services may need a no-op case; persistence subscriber (Story 6.2) will own the row write later.
- **Big numbers.** `def.rewardValue` is `Decimal`; sum into the multiplier stack via existing `_sumAchievementMultipliers`. Never raw `Decimal` outside `lib/game/values/`.
- **No income math here.** This story does NOT touch `IncomeCalculator`. The grep guard in `test/architecture/no_duplicate_income_math_test.dart` flags `def.baseInfluence *` and `country.baseInfluence *` patterns — the reducer reads only state/content fields without multiplying base income, so it's safe.

### Library / Framework Requirements

- `package:decimal/decimal.dart` — for `Decimal.parse(params['value'] as String)` in `totalInfluenceAtLeast`. Already pinned.
- `package:meta/meta.dart` — for `@immutable` on `AchievementEarned`. Already in transitive deps.
- `package:test/test.dart` — for pure-Dart reducer tests (NOT `flutter_test`).
- No new `pubspec.yaml` entries.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/features/achievements/achievement_condition.dart` | `bool evaluateAchievementCondition(...)` — switch over `def.conditionType` |
| `lib/game/features/achievements/achievements_reducer.dart` | Pure-Dart `evaluateAchievements` |
| `test/game/features/achievements/achievements_reducer_test.dart` | Pure-Dart reducer tests |
| `test/helpers/achievements_fixture.dart` | `trivial27AchievementsJson()` helper for fixtures |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_event.dart` | Append `AchievementEarned` sealed variant |
| `lib/game/game_world.dart` | Append `_evaluateAchievements` private method; call after `_evaluateMilestones` in both `applyCommand` branches |
| `lib/game/content/content_registry.dart` | Add parse-time validation in `_parseAchievements` (count == 27, rewardType allowlist, conditionType allowlist, continentId existence, id uniqueness) |
| `assets/data/achievements.json` | Replace `[]` with 27 entries |
| `test/game/features/economy/income_calculator_test.dart` and other existing tests | Migrate `achievementsJson: '[]'` to `trivial27AchievementsJson()`; padded existing fixtures to 27 |
| `test/game/game_world_test.dart` | Add 4–5 integration tests |

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` — already wired correctly via `_sumAchievementMultipliers`.
- `lib/game/game_state.dart` — `earnedAchievementIds` is already present; no new field needed in this story.
- `lib/game/game_command.dart` — achievements fire from state evaluation, never from a user command.
- `lib/providers/*` — no UI yet (Epic 7); no new providers required.

### Condition vocabulary (the FIVE supported `conditionType`s)

The evaluator MUST handle exactly these five — no more, no less. The parse-time validator rejects anything else.

| `conditionType` | `conditionParams` shape | Evaluation |
|---|---|---|
| `totalInfluenceAtLeast` | `{ "value": "1e9" }` (string, parseable by `Decimal.parse`) | `state.totalInfluence.value >= Decimal.parse(params['value'])` |
| `countriesUnlockedAtLeast` | `{ "count": 5 }` (int) | `state.countries.values.where((c) => c.unlocked).length >= params['count']` |
| `continentCompleted` | `{ "continentId": "africa" }` (must match a `ContinentDef.id.value`) | `state.continentCompletions[ContinentId(params['continentId'])] == true` |
| `leadersHiredAtLeast` | `{ "count": 1 }` (int) | `state.countries.values.where((c) => c.leaderTier != LeaderTier.none).length >= params['count']` |
| `maxIpLevelAtLeast` | `{ "level": 10 }` (int) | `max(c.ipLevel for c in state.countries.values) >= params['level']` |

**Forbidden / deferred condition types** (do NOT add even tentatively):
- `tapsAtLeast` / `goldensClaimed` — require lifetime counters not yet on `GameState`. Defer to a follow-up after Stories 5.1, 5.4, or 6.x add the relevant counter fields.
- `dailyStreakAtLeast` — depends on Story 5.4's `state.dailyStreak.day` field.
- Anything that depends on RNG or wall-clock time.

If a future story needs another condition, it can extend the allowlist atomically — but adding all of them speculatively now bloats parse-time validation and creates dead branches.

### Reference reducer skeleton (do NOT reinvent)

```dart
// lib/game/features/achievements/achievements_reducer.dart
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/achievements/achievement_condition.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';

(GameState, List<GameEvent>) evaluateAchievements(
  GameState state,
  ContentRegistry content,
  DateTime now,
) {
  final events = <GameEvent>[];
  final newlyEarned = <String>{};
  for (final def in content.achievements) {
    if (state.earnedAchievementIds.contains(def.id)) continue;
    if (newlyEarned.contains(def.id)) continue;
    if (!evaluateAchievementCondition(def, state, content)) continue;
    newlyEarned.add(def.id);
    events.add(AchievementEarned(
      now,
      achievementId: def.id,
      rewardType: def.rewardType,
      rewardValue: def.rewardValue,
    ));
  }
  if (events.isEmpty) return (state, const <GameEvent>[]);
  return (
    state.copyWith(
      earnedAchievementIds: {...state.earnedAchievementIds, ...newlyEarned},
    ),
    events,
  );
}
```

### Reference GameWorld wiring

In both branches of `applyCommand`, append `_evaluateAchievements(_clock.now())` after `_evaluateMilestones(_clock.now())`:

```dart
// UnlockCountry branch (existing):
if (unlockResult.isSuccess && _state != stateBeforeCommand) {
  _evaluateContinentUnlocks(_clock.now());
  _evaluateMilestones(_clock.now());
  _evaluateAchievements(_clock.now()); // NEW
}

// general switch branch (existing):
if (result.isSuccess && _state != stateBeforeCommand) {
  _evaluateContinentUnlocks(_clock.now());
  _evaluateMilestones(_clock.now());
  _evaluateAchievements(_clock.now()); // NEW
}
```

### Previous Story Intelligence (Story 4.3 — most relevant)

Story 4.3 (`milestones_reducer`) is the closest precedent. Carry these decisions forward:
- **Ledger field over event log.** Story 4.3 added `state.reachedMilestones: Map<ContinentId, Set<int>>` as the idempotency ledger. This story uses the existing `state.earnedAchievementIds: Set<String>` for the same purpose — already on `GameState`, no new field needed.
- **Evaluate-after-mutation ordering.** Story 4.3 placed `_evaluateMilestones` AFTER `_evaluateContinentUnlocks` because milestones depend on continent-unlock state. This story places `_evaluateAchievements` AFTER `_evaluateMilestones` because `continentCompleted`-typed achievements depend on `continentCompletions[id]` being flipped by milestones first.
- **Short-circuit on no-op.** Both reducers return `(state, const [])` (with `identical(state, returnedState)` true) when no events fire. This story does the same.
- **Code review patch pass discovered:** "milestone evaluation gated to actual state mutation; milestone threshold math aligned with floor formula" (sprint-status 2026-04-25). This story's gate is `result.isSuccess && _state != stateBeforeCommand` — same as Story 4.3's. Don't re-evaluate on failed commands.

### Project Structure Notes

- **Folder choice (`lib/game/features/achievements/`):** matches game-architecture.md §System→Location Mapping ("achievements" → `lib/game/features/achievements/`). The folder doesn't exist yet; this story creates it.
- **Test folder (`test/game/features/achievements/`):** mirrors source. NEW folder; this story establishes the convention. Use `package:test/test.dart` (NOT `flutter_test`).
- **Asset path (`assets/data/achievements.json`):** already declared in `pubspec.yaml` flutter assets section; already loaded by `ContentRegistry` via `app_providers.dart`. No pubspec change needed.

### Project Context Rules (extracted from project-context.md)

| Rule | How it applies here |
|---|---|
| `lib/game/` has ZERO Flutter imports | `achievements_reducer.dart`, `achievement_condition.dart` MUST be pure Dart |
| Reducers are pure; `now` and `rng` flow in as parameters | `evaluateAchievements(state, content, now)` injects `now` |
| Return tuples; only `GameWorld` calls reducers and emits events | Reducer returns `(GameState, List<GameEvent>)`; `GameWorld._evaluateAchievements` pushes onto the stream |
| Events are past tense + sealed | `AchievementEarned` extends `GameEvent` (sealed) |
| `StreamController.broadcast(sync: true)` — synchronous emission | Tests can collect events synchronously after `applyCommand` returns |
| Big numbers: `Decimal` inside `lib/game/values/` only; wrap in `Influence`/`Intel` outside | `def.rewardValue` is `Decimal` — passed through unchanged in events; sum lives in `_sumAchievementMultipliers` already |
| Multiplier stack — single source of truth in `IncomeCalculator` | DO NOT add a parallel multiplier path. The reducer adds to `earnedAchievementIds`; the calculator picks it up automatically |
| Tests under `test/game/**` use `package:test/test.dart` (NOT `flutter_test`) | All new pure-Dart tests follow this rule |
| `GameStateBuilder` is the canonical state-building helper | If `test/helpers/game_state_builder.dart` exists, use it; otherwise hand-construct via `GameState(...)` like `milestones_reducer_test.dart` does |
| No `freezed`, no `riverpod_generator`, no `@riverpod` | Manual `==` / `hashCode` / `toString` on `AchievementEarned` |
| `print()` is forbidden | Use `Logger('AchievementsReducer')` only if absolutely needed (none expected for v1) |
| Drift schema changes require migration | NOT applicable — `earnedAchievementIds` already exists in state; persistence is Story 6.1's problem |

### Testing Requirements

- **Pure-Dart reducer tests** under `test/game/features/achievements/` use `package:test/test.dart`. Build fixture `ContentRegistry`s the same way `milestones_reducer_test.dart` does (via `jsonEncode` + `ContentRegistry.fromJsonStrings`).
- **Existing test migration is the LARGEST source of churn** — every test that built a `ContentRegistry` with `achievementsJson: '[]'` will fail after Task 4 lands. The shared `trivial27AchievementsJson()` helper in `test/helpers/achievements_fixture.dart` is the ONE place to update if the validation rules change later.
- **Integration tests** in `test/game/game_world_test.dart` exercise the full command → reducer → event-stream loop. Use `expectLater(world.events, emitsThrough(...))` or collect events to a list via `world.events.listen(events.add)` before dispatching the command.
- **No widget tests** for this story.
- **Property tests are NOT required** — the reducer is bounded by content (27 entries) and condition evaluation is deterministic; example-based tests cover the space adequately.

### Latest Tech Information (no churn)

- Flutter 3.41.6 stable / Dart `^3.11.4` — sealed classes, exhaustive switches, pattern matching all stable.
- `decimal: ^3.0.2` — `Decimal.parse` accepts scientific notation strings like `"1e9"`. Verified by existing usage in `milestones_reducer_test.dart` and `continents.json`.
- `package:test: ^1.x` — already used throughout `test/game/**`.

### Git Intelligence Summary (recent commits relevant to this story)

From sprint-status.yaml (last 5 entries):
- 2026-04-25: Story 4-5 done (next-unlock teaser selectors + `feature_providers.dart` established).
- 2026-04-25: Story 4-4 done (continent completion permanent multiplier — `state.continentCompletions[id] = true` semantics; `IncomeCalculator._continentCompletionBonus` is global product).
- 2026-04-25: Story 4-3 done (milestones reducer; `state.reachedMilestones` ledger; gated to actual state mutation).
- 2026-04-24: Stories 4-1, 4-2 done (continent unlock infrastructure).

**Implications for this story:**
1. Story 4.4's `state.continentCompletions[id] = true` is the trigger for `continentCompleted`-typed achievements — verified live and tested.
2. Story 4.3's pattern (`reachedMilestones` ledger + state-mutation gate) is the direct template for this story's evaluator structure.
3. `feature_providers.dart` exists and may be relevant when Epic 7's UI consumes achievements (NOT this story).
4. The "code review patch pass" entries for 4-3 and 4-4 caught (a) evaluation-on-no-op-state, (b) threshold math edge cases, (c) idempotency on save-load. Apply the same scrutiny to achievements: pin the `state-changed gate`, write idempotent-on-save-load tests, and add a "command failed → no event" test.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.5: 27 Achievements Granting Permanent Multipliers] — acceptance criteria source
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.1: Populate Core Content JSON Files] — final tuning of the 27 entries
- [Source: _bmad-output/planning-artifacts/gdd.md#Achievement System] — the three categories (milestone / activity / completion)
- [Source: _bmad-output/project-context.md#Multiplier stack] — exact stack order; achievements are the `(1 + Σ achievementMultipliers)` slot
- [Source: lib/game/features/economy/income_calculator.dart] — existing `_sumAchievementMultipliers` (already wired)
- [Source: lib/game/content/achievement_def.dart] — existing `AchievementDef` (already defined)
- [Source: lib/game/features/continents/milestones_reducer.dart] — direct precedent for reducer structure
- [Source: _bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md] — review-pass lessons (idempotency, mutation gate)
- [Source: _bmad-output/implementation-artifacts/4-5-next-unlock-teaser-data-on-state.md] — discovery of how-to-coordinate-with-sibling-stories pattern

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

(none)

### Change Log

- 2026-04-27: Story 5-5-27 implemented — `AchievementEarned`, `evaluateAchievementCondition` / `evaluateAchievements`, strict `ContentRegistry` achievement parsing (27 entries, allowlists, continent id + unique ids), `GameWorld._appendAchievementsToBatch` after milestones on successful state-changing commands, production `assets/data/achievements.json` (27), shared test fixtures `trivial27AchievementsJson` / `achievementsJson27`, reducer + GameWorld tests; full `flutter test` and `flutter analyze` green.
- 2026-04-27: Code review patch pass — added parse-time validation for every supported achievement condition parameter shape, plus guardrail tests and real production asset parsing coverage; `dart format --set-exit-if-changed .`, `flutter analyze`, and full `flutter test` green.

### Completion Notes List

- All acceptance criteria addressed: achievements content and parse-time validation, pure evaluator + `GameWorld` ordering after milestones, `IncomeCalculator` integration verified in reducer test, intel branch emits event without mutating `totalIntel`, exhaustive `GameEvent` switches updated in tests.
- Code review findings resolved: malformed allowlisted achievement conditions now fail during `ContentRegistry` parsing rather than during post-command evaluation.
- `flutter test` (full suite) and `flutter analyze` completed with no issues after `dart format`.

### File List

- `lib/game/game_event.dart`
- `lib/game/game_world.dart`
- `lib/game/content/content_registry.dart`
- `lib/game/features/achievements/achievement_condition.dart`
- `lib/game/features/achievements/achievements_reducer.dart`
- `assets/data/achievements.json`
- `test/helpers/achievements_fixture.dart`
- `test/game/features/achievements/achievements_reducer_test.dart`
- `test/game/game_world_test.dart`
- `test/game/game_event_test.dart`
- `test/game/content/content_registry_test.dart`
- `test/game/features/economy/income_calculator_test.dart`
- `test/game/game_state_test.dart`
- `test/game/game_state_seed_test.dart`
- `test/services/content_registry_loader_test.dart`
- `test/helpers/next_unlock_test_fixtures.dart`
- `test/game/features/continents/continents_reducer_test.dart`
- `test/game/features/continents/milestones_reducer_test.dart`
- `test/game/features/continents/unlocks_reducer_test.dart`
- `test/game/features/countries/countries_reducer_test.dart`
- `test/game/features/daily_rewards/daily_rewards_reducer_test.dart`
- `test/game/features/goldens/goldens_scheduler_test.dart`
- `test/game/features/leaders/leaders_reducer_test.dart`
- `test/game/features/missions/missions_reducer_test.dart`
- `test/game/features/upgrades/upgrades_reducer_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
