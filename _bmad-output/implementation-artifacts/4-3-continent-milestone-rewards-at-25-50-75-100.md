# Story 4.3: Continent Milestone Rewards at 25/50/75/100 %

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want rewards when I own 25%, 50%, 75%, and 100% of the countries in a continent,
so that I feel celebrated for making steady progress, not just final completion.

## Acceptance Criteria

1. **Given** a continent with N countries and I own `floor(0.25 × N)`, `floor(0.50 × N)`, `floor(0.75 × N)`, or all N
   **When** the reducer evaluates milestone progress after each `CountryUnlocked`
   **Then** the corresponding `MilestoneReached(continentId, tier)` event fires exactly once per tier per continent.
2. **Given** a `MilestoneReached` event
   **When** the reward effect is applied
   **Then** the reward type and amount is defined in content JSON (Influence boost, Intel boost, or permanent multiplier snippet) — no hardcoded values.
3. **Given** the 100% milestone
   **When** fired
   **Then** `ContinentCompleted(continentId)` is ALSO fired in the same microtask (Story 4.4 handles the completion bonus).

## Tasks / Subtasks

- [ ] 1. Update `ContinentDef` and `continents.json` (AC: #2)
  - [ ] Add `milestoneRewards` to `ContinentDef` (e.g., mapping `25`, `50`, `75`, `100` to reward types/amounts).
  - [ ] Add sample rewards to `assets/data/continents.json`.
- [ ] 2. Update `GameState` (AC: #1)
  - [ ] Add `claimedMilestones` tracking per continent (e.g., `Map<String, Set<int>>` or `Map<String, List<int>>`) to `GameState` or a new `ContinentState`.
- [ ] 3. Define new Events (AC: #1, #3)
  - [ ] Add `MilestoneReached(String continentId, int tier)` to `GameEvent`.
  - [ ] Add `ContinentCompleted(String continentId)` to `GameEvent`.
- [ ] 4. Implement Milestone Evaluation Logic (AC: #1, #2, #3)
  - [ ] Create or update a reducer (e.g., `continents_reducer.dart`) to evaluate milestones after a country unlocks.
  - [ ] Calculate thresholds using `floor(percent * totalCountries)`.
  - [ ] Ensure idempotency: only fire if the tier hasn't been claimed yet.
  - [ ] Apply the reward to the state (e.g., add Influence/Intel).
  - [ ] If tier is 100, emit BOTH `MilestoneReached` and `ContinentCompleted`. (May require returning `Iterable<GameEvent>` from the reducer and updating `GameWorld` to handle multiple events).
- [ ] 5. Write Pure Dart Tests (AC: #1, #2, #3)
  - [ ] Test exact thresholds: `floor(0.25 * N)`, etc.
  - [ ] Test idempotency (doesn't re-fire on next country unlock).
  - [ ] Test 100% threshold emits both events.
  - [ ] Test rewards are correctly applied.

## Dev Notes

- **Architecture:** The logic must live in `lib/game/` (pure Dart, no Flutter imports).
- **Multiple Events:** `GameWorld.applyCommand` currently expects a single event from reducers (`Result<(GameState, GameEvent?), GameError>`). To emit both `MilestoneReached` and `ContinentCompleted`, you may need to refactor the return type to `Result<(GameState, Iterable<GameEvent>), GameError>` across all reducers, or handle it specifically. Follow the cleanest path that maintains the architecture.
- **Big Numbers:** Use `Influence` / `Intel` value objects for rewards. No raw `Decimal` or `double`.
- **Idempotency:** The state MUST track which milestones have been claimed to survive app restarts and prevent double-dipping.

### Project Structure Notes

- `lib/game/features/continents/continents_reducer.dart`
- `lib/game/game_event.dart`
- `lib/game/content/continent_def.dart`
- `assets/data/continents.json`

### Project Context Rules

- **No Flutter in `lib/game/`:** Pure Dart only.
- **Result/Error Handling:** Reducers must return `Result<(NewState, Event), GameError>`. NO exceptions for control flow.
- **Big Numbers:** All game math flows through `Influence` / `Intel` value objects.
- **Events:** Events are past tense (`MilestoneReached`, `ContinentCompleted`). They are sealed classes.
- **Logging:** Use `package:logging` only. NEVER `print()`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3]
- [Source: _bmad-output/project-context.md]
- [Source: _bmad-output/game-architecture.md]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
