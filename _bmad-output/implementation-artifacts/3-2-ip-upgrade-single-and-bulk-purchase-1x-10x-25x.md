# Story 3.2: IP Upgrade — Single and Bulk Purchase (1×/10×/25×)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to spend Influence to increase a country's IP level, with a toggle for 1×, 10×, or 25× bulk purchases,
So that I can power up efficiently without tapping Upgrade repeatedly.

## Acceptance Criteria

1. **Given** a country with `ipLevel < 200` and I have enough Influence **When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)` **Then** my `totalInfluence` decreases by the cost, the country's `ipLevel` increments by 1, and an `UpgradePurchased` event fires.
2. **Given** I do not have enough Influence **When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)` **Then** the reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))` and no state mutates.
3. **Given** a country at `ipLevel == 200` **When** I dispatch the upgrade **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'max_level'))`.
4. **Given** the cost calculation **When** `ipLevel = L` and `baseCost = B` **Then** cost = `B × (1.5 ^ L)` per the GDD (tuned values land in Epic 10).
5. **Given** a country with `ipLevel + bulk ≤ 200` and enough Influence for the full stack **When** I dispatch `PurchaseUpgrade(countryId, bulk: 10)` or `bulk: 25` **Then** `ipLevel` increments by exactly 10 or 25, Influence decreases by the summed geometric-series cost, and one `UpgradePurchased` event fires with `bulk` and `totalCost` fields.
6. **Given** `ipLevel + bulk > 200` **When** I dispatch the bulk upgrade **Then** the reducer caps the purchase at 200 (partial purchase), charges only for the levels actually bought, and fires `UpgradePurchased` with the actual count.
7. **Given** I cannot afford the full bulk **When** I dispatch the upgrade **Then** the reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))` and no state mutates — it does NOT partial-buy as many as I can afford (explicit, documented behavior).
8. **Given** the cost math **When** `bulk` purchases from level L **Then** `cost = B × (1.5^L) × (1.5^bulk - 1) / (1.5 - 1)` — exact geometric sum, unit-tested.

## Developer Context

This story introduces the first active spend mechanic in the game. It requires adding a new command `PurchaseUpgrade`, a new event `UpgradePurchased`, and implementing the exact geometric series cost formula in a pure function.

### Technical Requirements

- **Command:** Add `PurchaseUpgrade(CountryId countryId, {int bulk = 1})` to `GameCommand`.
- **Event:** Add `UpgradePurchased(CountryId countryId, int levelsAdded, Influence totalCost)` to `GameEvent`.
- **Cost Math:** Implement `IncomeCalculator.upgradeCost(CountryDef def, int currentLevel, int bulk)` returning `Influence`. The formula is `baseCost * (1.5^L) * (1.5^bulk - 1) / (1.5 - 1)`. Use `Decimal` for all math. Since `1.5` is rational, `pow` can be computed via repeated multiplication or `Rational.pow` if available, but be mindful of precision. For `bulk = 1`, it simplifies to `baseCost * 1.5^L`.
- **Reducer:** Add a reducer for `PurchaseUpgrade` that validates the country exists, is unlocked, checks `ipLevel + bulk` against the max level (200), computes the cost, checks `totalInfluence >= cost`, and then returns the updated `GameState` and `UpgradePurchased` event. If `ipLevel + bulk > 200`, adjust `bulk` to `200 - ipLevel` before computing cost.
- **Error Handling:** Use `GameError.userInsufficientFunds(required: cost)` and `GameError.userLocked(reason: 'max_level')`.

### Architecture Compliance

- **Pure Dart:** All changes must be in `lib/game/` and have zero Flutter imports.
- **State Mutation:** Only mutate state by returning a new `GameState` from the reducer. Do not mutate `CountryState` directly (use `copyWith`).
- **Big Numbers:** All math must use `Decimal`. Convert to `Influence` only at the return boundary. Do not use `double`.
- **Exhaustive Switch:** Adding `PurchaseUpgrade` and `UpgradePurchased` will break existing exhaustive switches (e.g., in `GameWorld.applyCommand`, `AudioService`, etc.). You must update all consumers.

### Library / Framework Requirements

- `decimal: ^3.0.2`: Use `Decimal.parse('1.5')` for the multiplier.
- `collection: ^1.19.1`: Available if needed.

### File Structure Requirements

- `lib/game/game_command.dart`: Add `PurchaseUpgrade`.
- `lib/game/game_event.dart`: Add `UpgradePurchased`.
- `lib/game/features/upgrades/upgrades_reducer.dart`: Create this new file for the upgrade logic.
- `lib/game/features/economy/income_calculator.dart`: Add the static cost calculation method here.
- `lib/game/game_world.dart`: Wire the new command to the new reducer.

### Testing Requirements

- **Pure Dart Tests:** Add tests in `test/game/features/upgrades/upgrades_reducer_test.dart`. Use `package:test/test.dart`.
- **Cost Math Tests:** Add property tests in `test/game/features/economy/income_calculator_test.dart` to verify the geometric sum exactly matches a loop of single purchases for `bulk = 10` and `bulk = 25`.
- **Reducer Tests:** Test success (1x, 10x, partial cap at 200), insufficient funds, locked country, max level reached.

### Previous Story Intelligence

From Story 3.1:
- `IncomeCalculator` is the single source of truth for economy math. The cost calculation MUST live here as a static method, e.g., `IncomeCalculator.upgradeCost`.
- `BalanceConfig` was introduced. Add `static final Decimal ipUpgradeCostMultiplier = Decimal.parse('1.5');` and `static const int maxIpLevel = 200;` to `lib/game/config/balance.dart`.
- `CountryDef` has `baseInfluence`. The GDD implies `baseCost` is derived from the country. If `baseCost` is not in `CountryDef`, you may need to add it to `CountryDef` and `countries.json`, or derive it (e.g., `baseCost = baseInfluence * 10`). For now, assume `CountryDef.baseCost` exists or add it to the model and JSON. (Check `CountryDef` first).

### Project Context Reference

- **No Flutter in lib/game/:** `lib/game/` has ZERO Flutter imports. Pure Dart only.
- **Result / error handling:** `Result<T, GameError>` (sealed) for anything that can fail meaningfully. NO exceptions for control flow.
- **Big numbers:** All game math flows through `Influence` / `Intel` value objects. `double` for game quantities is a bug.
- **Configuration discipline:** Game constants (`const` in `lib/game/config/constants.dart`) and Balance values (`const` in `lib/game/config/balance.dart`). Put `1.5` and `200` in `BalanceConfig`.

## Tasks / Subtasks

- [x] Add `PurchaseUpgrade`, `UpgradePurchased`, and `BalanceConfig` IP upgrade constants
- [x] Implement `IncomeCalculator.upgradeCost` (geometric per-level sum in `Decimal`)
- [x] Add `upgrades_reducer` and wire `GameWorld.applyCommand`
- [x] Unit tests: reducer, cost math, exhaustive switches, `GameWorld` purchase path

### Review Findings

- [x] [Review][Patch] Guard corrupted negative `ipLevel` from throwing in purchase flow [`lib/game/features/upgrades/upgrades_reducer.dart:31`]
- [x] [Review][Patch] Reject non-positive `baseInfluence` to prevent free/negative-cost upgrades [`lib/game/features/upgrades/upgrades_reducer.dart:46`]
- [x] [Review][Patch] Add defensive reducer tests for invariant/missing-country branches [`test/game/features/upgrades/upgrades_reducer_test.dart:196`]

## Dev Agent Record

### Debug Log

(none)

### Completion Notes

- `B` = `baseInfluence × ipUpgradeBaseInfluenceScale` (10). `UpgradePurchased` carries `levelsAdded`, `bulkRequested`, and `totalCost` (Influence). Insufficient-funds `required` is the full intended purchase cost (after cap to 200), with no “buy what you can afford” behavior.
- `upgradeCost` is implemented as a `Decimal` loop over levels to match the geometric series without `Rational` division from the `decimal` package.

### File List

- `lib/game/config/balance.dart`
- `lib/game/features/economy/income_calculator.dart`
- `lib/game/features/upgrades/upgrades_reducer.dart`
- `lib/game/game_command.dart`
- `lib/game/game_event.dart`
- `lib/game/game_world.dart`
- `test/game/features/economy/income_calculator_test.dart`
- `test/game/features/upgrades/upgrades_reducer_test.dart`
- `test/game/game_command_test.dart`
- `test/game/game_event_test.dart`
- `test/game/game_world_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (3-2 → review)

### Change Log

- 2026-04-22: Implemented story 3.2 — single/bulk IP upgrades, `IncomeCalculator.upgradeCost`, tests; story and sprint set to `review`.
