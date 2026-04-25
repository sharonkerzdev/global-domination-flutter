# Epic 4: Expand — Unlocks, Continents, and Completion Bonuses

**Goal:** Deliver the geographic-progression promise. Players unlock new countries with exponential cost scaling, unlock new continents at Influence thresholds, hit 25/50/75/100% continent milestones, and receive permanent global multipliers on continent completion.

### Story 4.1: Unlock Next Country in Current Continent

As a player,
I want to spend Influence to unlock the next locked country in my current continent,
So that I can expand my influence footprint geographically.

**Acceptance Criteria:**

**Given** a continent with at least one locked country whose prerequisites are met, and enough Influence
**When** I dispatch `UnlockCountry(countryId)`
**Then** the country's `unlocked` flag becomes `true`, its `ipLevel` starts at 1, Influence decreases by `unlockCost`, and `CountryUnlocked` event fires.

**Given** `unlockCost` formula per GDD
**When** the Nth country in a continent unlocks
**Then** `unlockCost = previousCountry.unlockCost × 5` (with the continent's base unlock cost seeding N=1).

**Given** I try to unlock a country in a continent not yet unlocked
**When** `UnlockCountry` is dispatched
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'continent_locked'))`.

**Given** all countries in the current continent are unlocked
**When** I look for the next unlock
**Then** no country in that continent is unlockable; only the next continent is.

### Story 4.2: Unlock Continent at Influence Threshold

As a player,
I want the next continent to unlock automatically when my total Influence crosses its threshold,
So that new geography opens as my power grows without extra friction.

**Acceptance Criteria:**

**Given** the continent thresholds (Africa=0, Europe=1e9, Middle East=1e14, Asia=1e20, South America=1e26, North America=1e32, Oceania=1e38)
**When** my `totalInfluence` crosses a threshold
**Then** the `ContinentUnlocked(continentId)` event fires exactly once, the continent's `unlocked` flag becomes `true`, and its countries become `UnlockCountry`-eligible.

**Given** my total Influence is already past multiple thresholds (e.g. fresh state loaded after a jump)
**When** the game ticks
**Then** all crossed-but-unhandled continents unlock in order with separate events.

**Given** a continent is unlocked
**When** I check the state
**Then** the `ContinentUnlocked` event is emitted only once per continent per game — idempotent.

### Story 4.3: Continent Milestone Rewards at 25/50/75/100 %

As a player,
I want rewards when I own 25%, 50%, 75%, and 100% of the countries in a continent,
So that I feel celebrated for making steady progress, not just final completion.

**Acceptance Criteria:**

**Given** a continent with N countries and I own `floor(0.25 × N)`, `floor(0.50 × N)`, `floor(0.75 × N)`, or all N
**When** the reducer evaluates milestone progress after each `CountryUnlocked`
**Then** the corresponding `MilestoneReached(continentId, tier)` event fires exactly once per tier per continent.

**Given** a `MilestoneReached` event
**When** the reward effect is applied
**Then** the reward type and amount is defined in content JSON (Influence boost, Intel boost, or permanent multiplier snippet) — no hardcoded values.

**Given** the 100% milestone
**When** fired
**Then** `ContinentCompleted(continentId)` is ALSO fired in the same microtask (Story 4.4 handles the completion bonus).

### Story 4.4: Continent Completion Permanent Multiplier

As a player,
I want a permanent global multiplier when I own 100% of a continent's countries,
So that every subsequent action is amplified by my completed conquests.

**Acceptance Criteria:**

**Given** I own all countries in a continent
**When** `ContinentCompleted(continentId)` fires
**Then** `state.continentCompletions[continentId] = true` and the `continentCompletionBonus` factor in `IncomeCalculator` uses the per-continent bonus (Africa +0.25×, Europe +0.50× ... Oceania +1.75×).

**Given** multiple continents are complete
**When** `IncomeCalculator.compute` runs
**Then** the `continentCompletionBonus` factor is the product `∏(1 + bonus)` over all completed continents.

**Given** a continent was previously completed and is loaded from save
**When** the game boots
**Then** the bonus applies without re-firing `ContinentCompleted` (idempotent — save records completion state, not just event log).

### Story 4.5: Next-Unlock Teaser Data on State

As a player,
I want to know which country is next and what it will cost,
So that I have a clear near-term goal.

**Acceptance Criteria:**

**Given** the player is in continent C with unlocked and locked countries
**When** a UI watches `nextUnlockInContinentProvider(C)`
**Then** it returns `{ countryId, unlockCost }` for the next locked country in continent order, or `null` if C is fully unlocked.

**Given** multiple continents are unlocked
**When** a UI watches `nextUnlockOverallProvider`
**Then** it returns `{ countryId, unlockCost, continent }` for the next locked country in the earliest-unlocked continent with locked countries, or `null` if world is complete.

_(UI rendering of this teaser lands in Epic 7 — this story provides the derived state only.)_

---
