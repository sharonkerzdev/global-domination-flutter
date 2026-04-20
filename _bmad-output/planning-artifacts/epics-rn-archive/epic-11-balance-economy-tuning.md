# Epic 11: Balance & Economy Tuning

Adjust game economy parameters to improve pacing, reduce frustration, and increase engagement.

## Story 11.1: Rebalance Continent Unlock Thresholds

As a player,
I want continent transitions to feel like achievable milestones rather than impossible walls,
So that I stay motivated to continue.

**Acceptance Criteria:**

**Given** current thresholds jump 100,000x between some continents
**When** rebalancing is complete
**Then** threshold growth is smoother (10-100x jumps instead of 100,000x)
**And** intermediate milestones exist within continents (25%, 50%, 75% rewards)
**And** each milestone grants a small bonus (Intel, Influence burst, or minor multiplier)

## Story 11.2: Adjust Mission Intel Economy

As a player,
I want missions to feel rewarding enough that I can regularly afford boosts,
So that the active play loop feels worthwhile.

**Acceptance Criteria:**

**Given** missions reward 10-20 Intel and boosts cost 25 Intel
**When** rebalancing is complete
**Then** either mission rewards increase to 15-30 Intel, or boost cost decreases to 15-20 Intel
**And** the ratio allows approximately 1 boost per 1.5 completed mission cycles
**And** a new Intel source exists (e.g., continent milestones, achievements grant Intel)

## Story 11.3: Scale Daily Rewards with Progress

As a mid/late-game player,
I want daily rewards to remain meaningful as my income grows,
So that I am motivated to return each day.

**Acceptance Criteria:**

**Given** daily rewards are fixed (1K-100K Influence)
**When** scaling is implemented
**Then** Influence rewards scale with the player's current idle income (approximately 10 minutes of idle income)
**And** Intel rewards remain fixed (they do not inflate)
**And** the Day 7 multiplier bonus is unchanged
**And** minimum floor remains at current fixed values so early game is unaffected

## Story 11.4: Extend Golden Opportunity Window

As a player,
I want enough time to notice and tap a golden opportunity,
So that I do not miss them due to being scrolled away.

**Acceptance Criteria:**

**Given** golden window is currently 5-10 seconds
**When** the change is applied
**Then** the window is 8-15 seconds
**And** a global notification banner appears when a golden spawns: "Golden Opportunity! Tap [Country Name]!"
**And** the banner pulses and auto-dismisses when the golden expires

## Story 11.5: Add Missing Continent Completion Achievements

As a late-game player,
I want achievements for completing every continent,
So that there is a reward for each major milestone.

**Acceptance Criteria:**

**Given** achievements exist for some continent completions but not all
**When** the addition is complete
**Then** an achievement exists for each of the 7 continents
**And** each grants a meaningful multiplier bonus (+0.10x to +0.20x scaling with continent difficulty)
**And** achievement triggers work with the existing `checkAchievements()` system

---
