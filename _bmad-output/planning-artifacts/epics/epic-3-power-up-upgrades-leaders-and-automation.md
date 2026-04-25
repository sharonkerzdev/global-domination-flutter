# Epic 3: Power Up — Upgrades, Leaders, and Automation

**Goal:** Deliver the "feel more powerful" layer. Players spend Influence to raise Influence Power (1×/10×/25× bulk), hire Leaders at IP 10 to automate income, and upgrade Leaders through tiers. The single `IncomeCalculator` is the authoritative source for all multiplier math.

### Story 3.1: Authoritative `IncomeCalculator.compute` Function

As an architect,
I want a pure function `IncomeCalculator.compute(country, state) → Influence per second` that encodes the exact multiplier stack order from the architecture,
So that there is one source of truth for income rates and no duplicate math can drift.

**Acceptance Criteria:**

**Given** a country with IP level, leader tier, continent membership, and achievement-backed global multipliers
**When** `IncomeCalculator.compute(country, state)` is called
**Then** the returned rate equals `baseInfluence × (1 + ipLevel × IP_MULT_PER_LEVEL) × leaderMultiplier × continentCompletionBonus × (1 + Σ achievementMultipliers) × globalUpgrades.influenceAmplifier × goldenOpportunityMultiplier × boostMultiplier` applied in exactly that order.

**Given** property tests over the multiplier stack
**When** each multiplier is varied in isolation
**Then** the test pins the observed effect on the rate, preventing regression.

**Given** the reducer code
**When** grep'd for duplicate inline income math (e.g. `baseInfluence *` outside `IncomeCalculator`)
**Then** no duplicates exist.

### Story 3.2: IP Upgrade — Single and Bulk Purchase (1×/10×/25×)

As a player,
I want to spend Influence to increase a country's IP level, with a toggle for 1×, 10×, or 25× bulk purchases,
So that I can power up efficiently without tapping Upgrade repeatedly.

**Acceptance Criteria:**

**Given** a country with `ipLevel < 200` and I have enough Influence
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)`
**Then** my `totalInfluence` decreases by the cost, the country's `ipLevel` increments by 1, and an `UpgradePurchased` event fires.

**Given** I do not have enough Influence
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)`
**Then** the reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))` and no state mutates.

**Given** a country at `ipLevel == 200`
**When** I dispatch the upgrade
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'max_level'))`.

**Given** the cost calculation
**When** `ipLevel = L` and `baseCost = B`
**Then** cost = `B × (1.5 ^ L)` per the GDD (tuned values land in Epic 10).

**Given** a country with `ipLevel + bulk ≤ 200` and enough Influence for the full stack
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 10)` or `bulk: 25`
**Then** `ipLevel` increments by exactly 10 or 25, Influence decreases by the summed geometric-series cost, and one `UpgradePurchased` event fires with `bulk` and `totalCost` fields.

**Given** `ipLevel + bulk > 200`
**When** I dispatch the bulk upgrade
**Then** the reducer caps the purchase at 200 (partial purchase), charges only for the levels actually bought, and fires `UpgradePurchased` with the actual count.

**Given** I cannot afford the full bulk
**When** I dispatch the upgrade
**Then** the reducer returns `Result.failure(userInsufficientFunds)` and no state mutates — it does NOT partial-buy as many as I can afford (explicit, documented behavior).

**Given** the cost math
**When** `bulk` purchases from level L
**Then** `cost = B × (1.5^L) × (1.5^bulk - 1) / (1.5 - 1)` — exact geometric sum, unit-tested.

### Story 3.3: Leader Hire and Tier System

As a player,
I want to hire a Leader for a country once its IP reaches level 10, then upgrade that Leader through tiers,
So that my countries generate Influence passively and grow more powerful over time.

**Acceptance Criteria:**

**Given** a country with `ipLevel ≥ 10` and `leaderTier == LeaderTier.none`, and I have enough Influence
**When** I dispatch `HireLeader(countryId)`
**Then** `leaderTier` becomes `LeaderTier.tier1`, Influence decreases by the hire cost, and `LeaderHired` event fires.

**Given** a country with `ipLevel < 10`
**When** I dispatch `HireLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'ip_below_10'))`.

**Given** a country with an existing Leader
**When** I dispatch `HireLeader` again
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_already_hired'))`.

**Given** a country with a Leader and the tick runs
**When** the game loop processes the country
**Then** the country's income is continuous (per-second) rather than timer-gated — banked influence accumulates without needing a generation cycle to complete.

**Given** a country with `leaderTier == tier1` and enough Influence
**When** I dispatch `UpgradeLeader(countryId)`
**Then** `leaderTier` becomes `tier2`, Influence decreases by the tier-2 cost, and `LeaderUpgraded` fires with the new tier.

**Given** `leaderTier == tier2` → upgrade to `tier3` works identically.

**Given** `leaderTier == tier3`
**When** I dispatch `UpgradeLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_max_tier'))`.

**Given** `leaderTier == none`
**When** I dispatch `UpgradeLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'no_leader_hired'))` — upgrade only applies after hire.

**Given** the multiplier lookup
**When** `LeaderTier` values are read
**Then** they map per the final mapping pinned in `BalanceConfig` at Epic 10 — the GDD documents `1.0× → 1.5× → 2.0× → 3.0×` across 4 tiers. This story implements the lookup as a single named-constant table; exact values may be adjusted during Epic 10 tuning without code changes beyond that table.

> **Design note:** Pin the tier-count decision (3 upgradeable tiers vs 4) at kickoff and reflect it in both the `LeaderTier` enum AND `BalanceConfig.leaderMultipliers`.

---
