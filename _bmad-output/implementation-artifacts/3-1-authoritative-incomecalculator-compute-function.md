# Story 3.1: Authoritative `IncomeCalculator.compute` Function

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an architect,
I want a pure function `IncomeCalculator.compute(country, state, content) → Influence per second` that encodes the exact multiplier stack order from the architecture,
So that there is one source of truth for income rates and no duplicate math can drift.

## Acceptance Criteria

1. **Given** a country with IP level, leader tier, continent membership, achievement-backed global multipliers, active global upgrades, golden opportunity, and boost multipliers **When** `IncomeCalculator.compute(country, state, content)` is called for an `unlocked` country **Then** the returned `Influence` rate (per second) equals `baseInfluence × (1 + ipLevel × BalanceConfig.ipMultPerLevel) × leaderMultiplier × continentCompletionBonus × (1 + Σ achievementMultipliers) × globalUpgradesInfluenceAmplifier × goldenOpportunityMultiplier × boostMultiplier` applied in exactly that order.

2. **Given** a locked country (`unlocked == false`) or a country with no `CountryDef` in `ContentRegistry` **When** `compute` is called **Then** it returns `Influence.zero` (no silent throw).

3. **Given** property tests over the multiplier stack **When** each multiplier is varied in isolation (IP, leader, continent, achievements, global upgrades, golden, boost) and in composition **Then** each test pins the observed effect on the rate, preventing reorder/regression.

4. **Given** the reducer code in `lib/game/` **When** searched for duplicate inline income math (e.g. `baseInfluence *` outside `lib/game/features/economy/income_calculator.dart`) **Then** no duplicates exist — `tickCountries` consumes `IncomeCalculator.compute` for per-country generation.

5. **Given** `flutter analyze` and `dart format --set-exit-if-changed .` run on the changed tree **Then** both pass cleanly.

## Tasks / Subtasks

- [ ] Task 1: Create `BalanceConfig` with pinned multiplier constants (AC: 1)
  - [ ] 1.1 Create `lib/game/config/balance.dart` (new folder `lib/game/config/`)
  - [ ] 1.2 Define `abstract final class BalanceConfig` containing:
    - `static final Decimal ipMultPerLevel = Decimal.parse('0.1');` (placeholder — Epic 10 retunes; do not change here without Epic 10 coordination)
    - `static const Map<LeaderTier, String> leaderMultipliers = { none: '1.0', tier1: '1.5', tier2: '2.0', tier3: '3.0' };` — use `String` constants so the map is `const`, then parse to `Decimal` at lookup time (or expose `leaderMultiplier(LeaderTier) → Decimal` helper; either is fine, but keep the raw table `const`)
  - [ ] 1.3 Add a short doc comment: "Balance constants. Values pinned here are placeholders until Epic 10 final tuning pass. Re-tuning changes happen ONLY in this file + content JSON."
  - [ ] 1.4 No Flutter imports. Pure Dart.

- [ ] Task 2: Extend `GameState` with zero-effect multiplier fields (AC: 1, 3)
  - [ ] 2.1 Open `lib/game/game_state.dart` and add these fields (all immutable, with zero-effect defaults):
    - `final Map<ContinentId, bool> continentCompletions;` — default `const {}` (no continent completed)
    - `final Set<String> earnedAchievementIds;` — default `const {}` (no achievements earned)
    - `final Set<String> activeGlobalUpgradeIds;` — default `const {}` (no global upgrades active)
    - `final Decimal goldenOpportunityMultiplier;` — default `Decimal.one`
    - `final Decimal boostMultiplier;` — default `Decimal.one`
  - [ ] 2.2 Update `GameState` constructor to accept/default these fields. Use `Decimal.one` (not `Decimal.parse('1')` every time) as a top-level `final _one = Decimal.one;` if needed; `Decimal.one` already exists in the `decimal` package.
  - [ ] 2.3 Update `copyWith` to include all new fields.
  - [ ] 2.4 Update `==`, `hashCode`, `toString` to include all new fields. For `Set` equality, use `SetEquality` from `package:collection` (already a dependency per project-context) — or explicit set equality via `a.length == b.length && a.containsAll(b)`.
  - [ ] 2.5 In `GameState.initialSeed`, keep these fields at their zero-effect defaults (do not override). `Map.unmodifiable({})` and `Set` literals `const {}` are preferred.
  - [ ] 2.6 Do NOT change existing fields (`countries`, `totalInfluence`) — backwards-compatible extension only.

- [ ] Task 3: Create `IncomeCalculator.compute` (AC: 1, 2)
  - [ ] 3.1 Create `lib/game/features/economy/income_calculator.dart`
  - [ ] 3.2 Implement `abstract final class IncomeCalculator` with static method:
    ```dart
    static Influence compute(
      CountryState country,
      GameState state,
      ContentRegistry content,
    ) { ... }
    ```
  - [ ] 3.3 **Early returns (AC 2):**
    - If `!country.unlocked` → return `Influence.zero`.
    - Lookup `def = content.countries[country.id]`; if `def == null` → return `Influence.zero`.
    - If `def.baseInfluence == Decimal.zero` → return `Influence.zero` (short-circuit — no need to run the stack).
  - [ ] 3.4 **Multiplier stack, applied in this exact order (AC 1):**
    1. `rate = def.baseInfluence`
    2. `rate *= Decimal.one + Decimal.fromInt(country.ipLevel) * BalanceConfig.ipMultPerLevel`  // IP
    3. `rate *= _leaderMultiplier(country.leaderTier)`  // none=1.0, tier1=1.5, tier2=2.0, tier3=3.0
    4. `rate *= _continentCompletionBonus(country, state, content)`  // 1.0 when not completed; `Decimal.one + def.continent.completionBonus` when completed
    5. `rate *= Decimal.one + _sumAchievementMultipliers(state, content)`  // Σ additive then +1
    6. `rate *= _globalUpgradeAmplifier(state, content)`  // product over active upgrades; 1.0 if empty
    7. `rate *= state.goldenOpportunityMultiplier`  // 1.0 default
    8. `rate *= state.boostMultiplier`  // 1.0 default
  - [ ] 3.5 Return `Influence(rate)`.
  - [ ] 3.6 Helper: `_leaderMultiplier(LeaderTier) → Decimal` — reads `BalanceConfig.leaderMultipliers` table.
  - [ ] 3.7 Helper: `_continentCompletionBonus(country, state, content) → Decimal` — `content.countries[id].continent` gives `ContinentId`; if `state.continentCompletions[continentId] == true`, return `Decimal.one + content.continents[continentId].completionBonus`; otherwise `Decimal.one`.
  - [ ] 3.8 Helper: `_sumAchievementMultipliers(state, content) → Decimal` — iterate `state.earnedAchievementIds`, for each id find the `AchievementDef` in `content.achievements` (list lookup by id), and if `rewardType == 'influenceMultiplier'` add `rewardValue` to the sum. Other reward types contribute `Decimal.zero` to this specific sum. Return the `Decimal` sum (starts at `Decimal.zero`). Precompute `Map<String, AchievementDef>` inside the function only if it matters for perf — do NOT cache globally (content is immutable but state is not, and the function stays pure).
  - [ ] 3.9 Helper: `_globalUpgradeAmplifier(state, content) → Decimal` — iterate `state.activeGlobalUpgradeIds`, for each id find the `GlobalUpgradeDef` in `content.globalUpgrades` (list lookup by id), multiply their `influenceAmplifier` values. Return `Decimal.one` if the set is empty.
  - [ ] 3.10 Pure Dart only — no Flutter imports, no `DateTime.now()`, no RNG, no logging.
  - [ ] 3.11 Add a `/// `-level doc comment on `compute` that spells out the multiplier stack order. This is the single source of truth.

- [ ] Task 4: Route `tickCountries` through `IncomeCalculator.compute` (AC: 4)
  - [ ] 4.1 Open `lib/game/features/countries/countries_reducer.dart`.
  - [ ] 4.2 Replace the inline `deltaDecimal = def.baseInfluence * ratio` computation. New approach:
    - `final ratePerSecond = IncomeCalculator.compute(state, gameState, content);` — rate in Influence per second.
    - `final delta = ratePerSecond.value * ratio; // ratio = dt / generationSeconds, see existing logic`
    - The existing `generationSeconds` scaling stays — it is a content-driven "tick cadence" independent of the multiplier stack. `compute()` returns the per-tick-cadence base rate; multiplying by `ratio` converts it to the real-time delta over `dt`.
  - [ ] 4.3 The `tickCountries` signature now needs `GameState` (not just the countries map). Update signature to `Map<CountryId, CountryState> tickCountries(GameState state, Duration dt, ContentRegistry content)` and update `GameWorld.tick()` caller accordingly.
  - [ ] 4.4 Alternative (if GameState change is too invasive): pass only the extra fields needed (e.g., `continentCompletions`, `earnedAchievementIds`, `activeGlobalUpgradeIds`, `goldenOpportunityMultiplier`, `boostMultiplier`) via a dedicated `MultiplierContext` value object. PREFER the direct `GameState` pass — it's simpler and matches arch test pattern `IncomeCalculator.compute(s.countries['egypt']!, s)`.
  - [ ] 4.5 Do NOT delete the `ratio = dtMicros / genMicros` calculation — `generationSeconds` governs tick cadence, not the multiplier stack. Keep that division logic intact.
  - [ ] 4.6 Verify `GameWorld.tick()` still passes all existing Story 2.5 / 2.7 tests (Egypt generates, Nigeria does not).

- [ ] Task 5: Unit tests — `IncomeCalculator.compute` multiplier stack (AC: 1, 2, 3)
  - [ ] 5.1 Create `test/game/features/economy/income_calculator_test.dart` using `package:test/test.dart` (NOT `flutter_test`).
  - [ ] 5.2 Build a test `ContentRegistry` fixture helper (inline or in `test/helpers/`) containing:
    - 3 countries (egypt in africa `baseInfluence=1`, nigeria in africa `baseInfluence=5`, tokyo in asia `baseInfluence=100`)
    - 2 continents (africa `completionBonus=0.25`, asia `completionBonus=0.75`)
    - 3 achievements (`ach_mult_small` rewardType=`influenceMultiplier` rewardValue=`0.10`, `ach_mult_big` `influenceMultiplier` `0.25`, `ach_intel` `intelBoost` `5.0` — this last must NOT contribute to the sum)
    - 2 global upgrades (`upg_small` amp=`1.5`, `upg_big` amp=`2.0`)
  - [ ] 5.3 Baseline test: all defaults (ipLevel=0, none, no completion, no achievements, no upgrades, golden=1.0, boost=1.0) → rate == `baseInfluence`. Verify for egypt.
  - [ ] 5.4 IP isolation: ipLevel=10 → `rate == baseInfluence × (1 + 10 × 0.1) = 2 × baseInfluence`. ipLevel=0 → `1 × baseInfluence`. ipLevel=200 → `21 × baseInfluence`.
  - [ ] 5.5 Leader isolation: `LeaderTier.none` → `1.0 × baseInfluence`; `tier1` → `1.5×`; `tier2` → `2.0×`; `tier3` → `3.0×`.
  - [ ] 5.6 Continent completion isolation: egypt with `continentCompletions[africa]=true` → `rate ×= (1 + 0.25) = 1.25`.
  - [ ] 5.7 Achievement isolation:
    - Earning `ach_mult_small` alone → rate ×= `(1 + 0.10) = 1.10`.
    - Earning both `ach_mult_small` + `ach_mult_big` → rate ×= `(1 + 0.35) = 1.35` (additive, then +1).
    - Earning `ach_intel` alone → rate unchanged (rewardType filter).
  - [ ] 5.8 Global upgrade isolation:
    - `activeGlobalUpgradeIds = {upg_small}` → rate ×= `1.5`.
    - `activeGlobalUpgradeIds = {upg_small, upg_big}` → rate ×= `1.5 × 2.0 = 3.0` (product, not sum).
  - [ ] 5.9 Golden isolation: `goldenOpportunityMultiplier = Decimal.parse('10')` → rate ×= 10.
  - [ ] 5.10 Boost isolation: `boostMultiplier = Decimal.parse('2')` → rate ×= 2.
  - [ ] 5.11 Composed test (stack order regression): Egypt with ipLevel=100, leaderTier=tier2, africa completed, both mult achievements earned, both global upgrades active, golden=10, boost=2. Compute expected rate manually: `1 × (1 + 100*0.1) × 2.0 × (1 + 0.25) × (1 + 0.35) × (1.5 × 2.0) × 10 × 2 = 1 × 11 × 2.0 × 1.25 × 1.35 × 3.0 × 10 × 2`. Pin this exact `Decimal` value in an assertion. If the order of multipliers is ever reordered, the test fails.
  - [ ] 5.12 Locked country: `country.unlocked=false` → `Influence.zero`.
  - [ ] 5.13 Missing def: build a `CountryState` with `CountryId('atlantis')` that is NOT in content → `Influence.zero`.
  - [ ] 5.14 Zero `baseInfluence`: a fixture country with `baseInfluence: '0'` → `Influence.zero` even with full multiplier stack.
  - [ ] 5.15 Precision test: ipLevel=200, leader=tier3, africa completed, 20 × 10% achievements earned, 10 × 10x global upgrades active, golden=100, boost=2 → result is finite and exact (no `toDouble` anywhere in `compute`). Precision guard: the result's `Decimal` string representation should be computable without exception.

- [ ] Task 6: Integration tests — `tickCountries` uses `IncomeCalculator.compute` (AC: 4)
  - [ ] 6.1 Update `test/game/game_world_test.dart` with a test: seed Egypt unlocked, ipLevel=10, leaderTier=none, tick for 1 second → egypt.bankedInfluence ≈ `baseInfluence × (1 + 10*0.1) × 1 × 1 × 1 × 1 × 1 × 1 / 1s × 1s = 2 × baseInfluence`. Pin the exact `Decimal`.
  - [ ] 6.2 Second test: with `leaderTier = LeaderTier.tier2` and a completed continent, tick for 1 second → expected banked influence per the full stack.
  - [ ] 6.3 Verify existing Story 2.5 / 2.7 test expectations still hold — if a baseline test asserts "tick 1s on a fresh-seed Egypt produces baseInfluence delta", that remains true only when `ipLevel == 1` is the seed → the expected rate becomes `baseInfluence × (1 + 1*0.1) = 1.1 × baseInfluence` instead of `1.0 ×`. This is EXPECTED; **update those tests** to reflect the IP-level-1 multiplier and document in the commit that the change reflects the new authoritative stack. DO NOT revert tests to mask the change.
  - [ ] 6.4 Ticks with `identical(newCountries, state.countries)` short-circuit must still hold when no countries are unlocked (no rate computation happens → no allocation).

- [ ] Task 7: Grep-guard test — no duplicate income math (AC: 4)
  - [ ] 7.1 Create `test/architecture/no_duplicate_income_math_test.dart` (new folder `test/architecture/` if not already present — check `test/` listing first).
  - [ ] 7.2 The test walks every `.dart` file under `lib/game/` via `Directory`. For each file whose path is NOT `lib/game/features/economy/income_calculator.dart`, it reads the contents and asserts that none of these regex patterns match:
    - `def\.baseInfluence\s*\*` (raw multiplication of `baseInfluence` outside the calculator)
    - `country\.baseInfluence\s*\*` (same)
    - `baseInfluence\s*\*\s*ratio` (the specific pattern extracted from the old `tickCountries`)
  - [ ] 7.3 If any match is found, `fail('Duplicate income math detected in $path — route through IncomeCalculator.compute')`.
  - [ ] 7.4 This test runs as part of the standard `flutter test` suite. It is the enforcement mechanism for the "one source of truth" rule.

- [ ] Task 8: Full validation (AC: all)
  - [ ] 8.1 `flutter analyze` — 0 warnings.
  - [ ] 8.2 `dart format --set-exit-if-changed .` — clean.
  - [ ] 8.3 `flutter test` — all pass (existing + new).
  - [ ] 8.4 Manually run the grep guard mentally: search `lib/` for `baseInfluence *` — only `income_calculator.dart` should match.

## Dev Notes

### Architecture Compliance

- **Pure function.** `IncomeCalculator.compute` is pure: inputs (`CountryState`, `GameState`, `ContentRegistry`) → output (`Influence`). No `DateTime.now()`, no RNG, no I/O, no logging. Per project-context §Anti-patterns: "Writing income math anywhere other than `lib/game/features/economy/income_calculator.dart`" is an automatic PR rejection.
- **`lib/game/` has ZERO Flutter imports** — `income_calculator.dart`, `balance.dart`, and extended `game_state.dart` stay pure Dart. Confirm with `import 'package:test/test.dart'` (not `flutter_test`) in the economy test file.
- **Big-number discipline.** All math is `Decimal` throughout. The `Influence` wrapping happens only at the final return. NEVER `toDouble()`. NEVER `double` arithmetic.
- **Naming conventions.** `BalanceConfig.ipMultPerLevel` — camelCase constants, NOT `IP_MULT_PER_LEVEL` (project-context explicit: "Do NOT use SCREAMING_SNAKE_CASE"). The architecture doc uses `IP_MULT_PER_LEVEL` as pseudocode only.
- **Immutable state.** Extended `GameState` fields use `Map.unmodifiable` / `Set` literal defaults. The reducer creates new `GameState` via `copyWith` — never mutates.
- **Result discipline.** `compute` returns `Influence`, not `Result` — it CANNOT fail meaningfully (locked countries → zero; missing def → zero). This matches the arch test signature `compute(country, state) → Influence`.

### The Multiplier Stack (authoritative — applies in this exact order)

```
rate = baseInfluence
     × (1 + ipLevel × BalanceConfig.ipMultPerLevel)        // 1. Influence Power
     × leaderMultiplier(country.leaderTier)                 // 2. Leader
     × continentCompletionBonus(country, state, content)    // 3. Continent
     × (1 + Σ achievementMultipliers)                       // 4. Achievements
     × globalUpgradesInfluenceAmplifier (product)           // 5. Global upgrades
     × state.goldenOpportunityMultiplier                    // 6. Golden
     × state.boostMultiplier                                // 7. Boost
```

Source: [_bmad-output/game-architecture.md#§12 DI & Multiplier Stack Ordering](../../_bmad-output/game-architecture.md) and [_bmad-output/project-context.md#Multiplier Stack](../../_bmad-output/project-context.md).

### Implementation Approach — Key Decisions

**Why 3-arg signature (`country, state, content`) instead of 2-arg (`country, state`)?**
The arch test snippet shows `compute(s.countries['egypt']!, s)` for readability, but the function needs `ContentRegistry` access for:
- `baseInfluence` (lives on `CountryDef`)
- Continent `completionBonus` (lives on `ContinentDef`)
- `AchievementDef` lookup by id (to find the `influenceMultiplier` reward type)
- `GlobalUpgradeDef` lookup by id (for the `influenceAmplifier`)
The other options (storing `baseInfluence` on `CountryState`, injecting a singleton) violate immutability or purity. Three positional params is the clean call site: `IncomeCalculator.compute(country, state, content)`. Update the arch test snippet in a later doc pass — that's not this story's scope.

**Why extend `GameState` now with zero-effect defaults instead of waiting for Epics 4/5?**
The story contract is "encodes the exact multiplier stack order." To encode the stack, the function must READ state fields. Adding them now with zero-effect defaults (`const {}`, `Decimal.one`) means:
- The stack shape is FROZEN at this story.
- Epic 4 (continent completion) and Epic 5 (achievements, goldens, boosts) fill the fields but DO NOT touch `IncomeCalculator.compute`.
- Property tests (AC 3) can vary each multiplier in isolation without stubs or mocks — the fields are just data.

Alternative rejected: building an "empty" compute that ignores missing fields and adding them per-epic. This causes two bugs: (a) stack order drifts silently as fields are added; (b) each epic story has to touch `compute`, violating single-source-of-truth.

**Leader multiplier mapping.** The architecture doc §12 lists "leaderMultiplier: 0 / 1.0 / 1.5 / 2.0 / 3.0" (5 values) while `LeaderTier` enum has 4 values (`none, tier1, tier2, tier3`) and the content JSON `leaders.json` has `tierMultipliers: ["1.0", "1.5", "2.0", "3.0"]` (also 4). The epic explicitly says "the GDD documents `1.0× → 1.5× → 2.0× → 3.0×` across 4 tiers." **Resolution:** Use 4 values. `LeaderTier.none` → 1.0 (identity — no leader means no amplification, not zeroed income). The arch doc's leading `0` is a spec inconsistency; this story aligns with the enum + content + epic.

**`BalanceConfig.ipMultPerLevel` value.** Placeholder `0.1` is used (ipLevel 10 ⇒ 2× rate; ipLevel 200 ⇒ 21× rate). Epic 10 retunes this constant during balance pass — do NOT pick a different placeholder "because it feels better." Any change here ripples through every property test. Epic 10 is the agreed-upon retuning window.

**`generationSeconds` is NOT part of the multiplier stack.** It is a per-country content-driven "tick cadence" for the accumulator. `IncomeCalculator.compute` returns the per-second rate for the country; `tickCountries` applies `ratio = dt / generationSeconds` to convert that rate into the `bankedInfluence` delta for the elapsed `dt`. Keep that division intact in `countries_reducer.dart`. The existing `Decimal` math in `tickCountries` (`dtMicros / genMicros`) is orthogonal to this story and MUST NOT be modified.

### Dependencies — What Must Exist Before This Story

| Dependency | Source Story | What It Provides |
|---|---|---|
| `GameState` with `countries` + `totalInfluence` | Story 2.5 | Base shape to extend |
| `CountryState` with `unlocked`, `ipLevel`, `leaderTier` | Story 2.5 | All multiplier inputs |
| `LeaderTier` enum | Story 2.5 | `none, tier1, tier2, tier3` |
| `Influence` + `Influence.zero` | Story 1.5 | Return type, short-circuit value |
| `ContentRegistry` with `countries`, `continents`, `achievements`, `globalUpgrades` | Story 1.7 | Lookup source for defs |
| `CountryDef.baseInfluence`, `CountryDef.continent` | Story 1.7 | Base multiplier input, continent lookup |
| `ContinentDef.completionBonus` | Story 1.7 | Continent completion multiplier |
| `AchievementDef` with `conditionType`, `rewardType`, `rewardValue` | Story 1.7 | Achievement sum source |
| `GlobalUpgradeDef.influenceAmplifier` | Story 1.7 | Global upgrade product source |
| `GameState.initialSeed` | Story 2.7 | Fresh-state factory; extend defaults |
| `tickCountries` (current inline math) | Story 2.5 | Will be refactored to call `compute` |
| `GameWorld.tick()` | Story 1.9 / 2.5 | Caller of `tickCountries` |

### Project Structure Notes

**Files to CREATE:**
| File | Purpose |
|---|---|
| `lib/game/config/balance.dart` | `BalanceConfig` with `ipMultPerLevel` + `leaderMultipliers` table |
| `lib/game/features/economy/income_calculator.dart` | **THE** multiplier stack — single source of truth |
| `test/game/features/economy/income_calculator_test.dart` | Unit + property tests for the stack |
| `test/architecture/no_duplicate_income_math_test.dart` | Grep-guard enforcing AC 4 |

**Files to MODIFY:**
| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add 5 new fields (`continentCompletions`, `earnedAchievementIds`, `activeGlobalUpgradeIds`, `goldenOpportunityMultiplier`, `boostMultiplier`); update ctor, `copyWith`, `==`, `hashCode`, `toString`, `initialSeed` |
| `lib/game/features/countries/countries_reducer.dart` | Route through `IncomeCalculator.compute`; signature change to accept `GameState` |
| `lib/game/game_world.dart` | Update `tick()` call to pass `GameState` to `tickCountries` |
| `test/game/game_world_test.dart` | Update existing "tick generates 1 influence" expectations to reflect IP-level-1 seed → `1.1 × baseInfluence` rate (or whatever the new math yields) |
| `test/game/features/countries/*` (if existing reducer tests exist) | Update expectations similarly |

**Files to READ (reference only — do not modify):**
| File | Why |
|---|---|
| `lib/game/content/content_registry.dart` | Verify `.countries`, `.continents`, `.achievements`, `.globalUpgrades` access |
| `lib/game/content/country_def.dart` | Verify `baseInfluence` + `continent` fields |
| `lib/game/content/continent_def.dart` | Verify `completionBonus` field |
| `lib/game/content/achievement_def.dart` | Verify `rewardType`, `rewardValue` — use exact string literal `'influenceMultiplier'` for the filter |
| `lib/game/content/global_upgrade_def.dart` | Verify `influenceAmplifier` field |
| `lib/game/values/influence.dart` | `Influence.zero`, `Influence(Decimal)` constructor, `Influence * Decimal` operator |
| `lib/game/features/leaders/leader_tier.dart` | 4-value enum |
| `assets/data/leaders.json` | Default content has `tierMultipliers: ["1.0", "1.5", "2.0", "3.0"]` — align with BalanceConfig |
| `assets/data/continents.json` | Africa completionBonus=0.25, Asia=0.75 etc. — confirms the `(1 + completionBonus)` formula yields 1.25 / 1.75 |

### Testing Standards

- **`test/game/**` uses `package:test/test.dart`** — NEVER `flutter_test`. The economy test file is pure-Dart.
- **`GameStateBuilder`** — if it doesn't exist yet under `test/helpers/`, CHECK `test/helpers/` first (per sprint status Story 1-9 mentions it). If missing, construct states directly in the test. Do NOT introduce a new helper just for this story unless 3+ tests duplicate the same construction boilerplate.
- **Fixture `ContentRegistry`** — build via `ContentRegistry.fromJsonStrings(...)` with inline JSON strings. Pattern already established in `game_world_test.dart` (Story 2.5 / 2.7).
- **Property tests** — the "vary each multiplier in isolation" tests ARE property tests in spirit. Use parameterized `test(...)` calls with `for` loops over representative values rather than requiring `package:glados` or similar. Keep it concrete: ipLevel ∈ {0, 1, 10, 100, 200}; leaderTier ∈ enum.values; etc.
- **Composed test precision.** Task 5.11's composed assertion pins an EXACT `Decimal` value. Compute it by hand (or with a throwaway script), and put the expected `Decimal.parse('...')` literal in the test with a code comment showing the expansion. If the stack order is ever reordered, this test fails on the exact-match assertion.
- **No mocks** — `ContentRegistry`, `GameState`, `CountryState` are all trivially constructible. Mocks would add noise without value.
- **Grep-guard test** uses `dart:io` `Directory`; this is allowed in `test/architecture/` because it is test code, not lib code. It does NOT run inside `lib/game/`.

### Anti-Patterns to Avoid

- **DO NOT** write a second income-rate function anywhere else. Stats screens, UI projections, offline catch-up (Epic 6) — ALL route through `IncomeCalculator.compute`. The grep-guard test enforces this.
- **DO NOT** use `toDouble()` inside `compute`. `Decimal`-only arithmetic. Result is wrapped in `Influence` at the return.
- **DO NOT** add per-epic branches inside `compute` (`if (epic4Shipped) ...`). The stack applies ALL multipliers always; the zero-effect defaults make unused multipliers mathematically identity operations. If Epic 4 isn't shipped, `continentCompletions` is `const {}` → `_continentCompletionBonus` returns `Decimal.one` → rate is unchanged. No branching needed.
- **DO NOT** introduce `package:flutter/*` imports in ANY file touched by this story. Pure-Dart only.
- **DO NOT** cache the `Map<String, AchievementDef>` lookup globally. The content is immutable but the achievements set mutates; the lookup is per-call. If perf matters, profile AFTER Epic 5 and Epic 11 (perf pass), not now.
- **DO NOT** change `tickCountries`'s `dtMicros / genMicros` logic — that governs per-country tick cadence (content-driven `generationSeconds`), which is orthogonal to the multiplier stack.
- **DO NOT** rename or relocate `BalanceConfig`. `lib/game/config/balance.dart` is the pinned location per project-context §"Configuration discipline".
- **DO NOT** use `Decimal.parse('1')` sprinkled through code — use `Decimal.one` (it is a const static on the `decimal` package).
- **DO NOT** introduce a `freezed` or `json_serializable` annotation on the extended `GameState` — project-context forbids `freezed` in v1. Manual `copyWith`, `==`, `hashCode` only.
- **DO NOT** revert tests that now fail due to the IP-level-1 seed yielding `1.1 × baseInfluence` rather than `1.0 × baseInfluence`. UPDATE them to the new correct expectation and document in the commit.
- **DO NOT** short-circuit the full stack for "performance" reasons inside `compute`. The only permitted short-circuits are: locked country, missing def, `baseInfluence == 0`. Everything else flows through the stack — the overhead is 7 `Decimal` multiplications, and the content lookups are `O(1)` (map) / `O(n_active)` (list), which is negligible vs the big-number arithmetic itself.

### Previous Story Intelligence

**From Story 2.5 (Tick Drives Influence Generation — done):**
- `tickCountries(Map<CountryId, CountryState> countries, Duration dt, ContentRegistry content)` is the current signature — this story changes it to take `GameState` (or an explicit multiplier context).
- Short-circuits already in place: `dt == Duration.zero` returns same map; unlocked==false countries untouched; `def == null` or `generationSeconds <= 0` skipped. **KEEP these** — they short-circuit BEFORE calling `compute`.
- `ratio = (dtMicros / genMicros).toDecimal(scaleOnInfinitePrecision: 18)` — preserve exactly as-is. This is the "how much of a generation tick elapsed" factor, separate from the multiplier stack.
- `anyChanged` flag tracks whether any country's state changed — keep it to preserve the `identical(newCountries, _state.countries)` optimization in `GameWorld.tick()`.

**From Story 2.6 (Tap-to-Collect — done):**
- `TapCountry` command transfers `bankedInfluence` → `totalInfluence`. This story does NOT touch the collect path — only the generation path.

**From Story 2.7 (Initial Seed — done, 2026-04-22):**
- Egypt is seeded with `unlocked: true, ipLevel: 1`. This means the FIRST 1-second tick under the new stack produces `1 × (1 + 1 × 0.1) × 1 × 1 × 1 × 1 × 1 × 1 = 1.1` per second (not `1.0`). Any existing test that asserts "Egypt earns 1 influence in 1 second" MUST be updated to `1.1`. This is correct per the new authoritative stack — do not revert.
- `GameWorld(initialState: ...)` optional parameter exists for Epic 6 forward-compatibility. The new `GameState` fields must round-trip through the constructor cleanly (defaults applied when not specified).
- Code review note from 2.7: `gameWorldProvider` passes `initialState: GameState()` when content is still loading. Verify that `GameState()` no-arg constructor still works with the extended fields (all defaults must be safe).

**From Story 1.11 (Canvas Performance Spike — review):**
- Dart-level perf budgets are tight. `IncomeCalculator.compute` runs once per unlocked country per tick — on a late-game state (195 countries unlocked) that's 195 calls/tick × 60 ticks/s = 11,700 calls/s. Each call is ~7 `Decimal` multiplications + a few map/list lookups. Profile in Epic 11 if this becomes hot.

### Cross-Story Context

- **Story 3.2** (IP Upgrade — bulk purchase) uses `IncomeCalculator.bulkCost(country, bulk)` — a separate static helper on `IncomeCalculator`. This story does NOT implement `bulkCost`; that's 3.2's scope.
- **Story 3.3** (Leader Hire & Tier) mutates `CountryState.leaderTier` — `compute` already reads this field; no further change needed in `compute`.
- **Story 4.4** (Continent Completion Bonus) populates `state.continentCompletions[continentId] = true` and fires `ContinentCompleted`. No change to `compute`.
- **Story 5.5** (Achievements) populates `state.earnedAchievementIds.add(id)`. No change to `compute`.
- **Story 5.1** (Golden Opportunity) toggles `state.goldenOpportunityMultiplier` during active window. No change to `compute`.
- **Story 5.2** (Boost) toggles `state.boostMultiplier` during active window. No change to `compute`.
- **Epic 6** (Persistence) — new `GameState` fields must round-trip through `GameStateMapper` (Drift). Flag in the story file: when Epic 6 writes the mapper, it MUST persist `continentCompletions`, `earnedAchievementIds`, `activeGlobalUpgradeIds`, and the two `Decimal` multipliers. `goldenOpportunityMultiplier` and `boostMultiplier` are transient (don't persist across offline — resume to 1.0 per arch Q6-offline). `continentCompletions` and `earnedAchievementIds` MUST persist.
- **Story 6-4** (Offline Earnings Calculation) calls `IncomeCalculator.computeAutomatedRate(country, state)` per epic text at line 1214 — a separate static helper that uses ONLY stable multipliers (IP × Leader × continent × achievement × global). This story implements `compute` with the FULL stack; `computeAutomatedRate` is Story 6-4's scope (a sibling method in the same file that omits golden + boost). Not in this story.

### Latest Technical Information

- **`decimal: ^3.0.2`** — `Decimal.one` is a top-level static (use it instead of `Decimal.parse('1')`). `Decimal.zero` likewise. `Decimal` supports `+`, `-`, `*`, `/` (returns `Rational`, use `.toDecimal(scaleOnInfinitePrecision: N)` for division). The `Influence` wrapper exposes `* Decimal` and `+ Influence` — use the `Influence` operators at boundaries.
- **`collection: ^1.19.1`** — `SetEquality`, `MapEquality` available for `==` on the new collection fields on `GameState`. Alternatively, explicit length + `containsAll` loop (existing `GameState._mapsEqual` pattern).
- **No new dependencies.** `pubspec.yaml` stays unchanged.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 3 — Story 3.1]
- [Source: _bmad-output/game-architecture.md#§12 DI & Multiplier Stack Ordering]
- [Source: _bmad-output/game-architecture.md#Standard Implementation Patterns §D — Test Patterns] (arch test snippet for `IncomeCalculator`)
- [Source: _bmad-output/game-architecture.md#Consistency Rules Summary — Single multiplier stack]
- [Source: _bmad-output/project-context.md#Multiplier stack — THE single source of truth]
- [Source: _bmad-output/project-context.md#Configuration discipline — BalanceConfig location]
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules — Writing income math anywhere other than income_calculator.dart]
- [Source: assets/data/leaders.json — tierMultipliers ["1.0","1.5","2.0","3.0"]]
- [Source: assets/data/continents.json — per-continent completionBonus values]
- [Source: lib/game/features/countries/countries_reducer.dart — current tickCountries to refactor]
- [Source: lib/game/game_state.dart — current shape + initialSeed factory]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
