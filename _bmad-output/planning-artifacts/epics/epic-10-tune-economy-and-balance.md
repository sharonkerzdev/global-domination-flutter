# Epic 10: Tune — Economy and Balance

**Goal:** Populate content JSON with tuned values; populate `BalanceConfig` constants; revisit pacing walls on the new smoother Flutter tick loop; refine late-game curves via instrumented runs.

### Story 10.1: Populate Core Content JSON Files

As a developer,
I want `countries.json`, `continents.json`, and `achievements.json` fully populated with real game data,
So that all content-driven systems have the values they need to function correctly.

**Acceptance Criteria:**

**Given** `assets/data/countries.json`
**When** parsed
**Then** it contains exactly 79 entries with valid schema (all required fields present, `continent` matches a valid continent id, numeric fields parseable as `Decimal`).

**Given** the geographic distribution
**When** counted per continent
**Then** it matches GDD: Africa 19, Europe 19, Middle East 10, Asia 16, South America 8, North America 4, Oceania 3.

**Given** the values
**When** ported from v1 or authored fresh
**Then** exponential scaling holds: within each continent, consecutive countries' `unlockCost` increases by ~5× (loose validation; Story 10.2 refines).

**Given** `assets/data/continents.json`
**When** parsed
**Then** it contains 7 entries with unlock thresholds (0, 1e9, 1e14, 1e20, 1e26, 1e32, 1e38) and completion bonuses (+0.25×, +0.50×, +0.75×, +1.00×, +1.25×, +1.50×, +1.75×) per GDD.

**Given** each continent
**When** checked for milestone rewards
**Then** 25/50/75/100% milestone rewards are defined (type + value per tier).

**Given** `assets/data/achievements.json`
**When** parsed
**Then** exactly 27 achievements load, spanning the three GDD categories (milestone, activity, completion).

**Given** each achievement condition
**When** the `AchievementEvaluator` runs against varying game states
**Then** the condition function evaluates correctly (unit-tested with fixture states).

### Story 10.2: `BalanceConfig` Constants Pinned and Playtest-Reviewed

As a game designer,
I want `lib/game/config/balance.dart` to contain all tunable constants (`ipCostMultiplier`, `leaderUnlockIpLevel`, `maxIpLevel`, `boostMultiplier`, `boostDurationSeconds`, `boostIntelCost`, `goldenSpawnProbability`, `goldenMinMultiplier`, `goldenMaxMultiplier`, `goldenDurationSeconds`, `missionCatalogSize`, `ipMultPerLevel`, `offlineCapHours`, etc.),
So that all balance tuning happens in one file without touching code.

**Acceptance Criteria:**

**Given** `BalanceConfig`
**When** audited
**Then** no magic numbers exist anywhere in `lib/game/` that affect balance — all such constants reference `BalanceConfig`.

**Given** a playtest run-through of 0 → Africa complete
**When** measured
**Then** pacing matches GDD's "Early Game (0-2 hours)" feel — tuning adjustments made until this is true.

**Given** a playtest run-through mid-to-late (continents 2–4)
**When** measured
**Then** pacing matches "Mid Game (Days 2-7)" — adjustments made as needed.

### Story 10.3: Instrumented Late-Game Run and Final Tuning Pass

As a game designer,
I want a debug cheat panel that fast-forwards to late-game states (fully unlocked continents 1–4, partial 5+) and an instrumentation dump of effective rates per continent,
So that I can observe and tune late-game pacing walls without grinding.

**Acceptance Criteria:**

**Given** the debug cheat panel (`kDebugMode`-only from Epic 1's debug tools)
**When** I invoke "Fast Forward to Asia complete"
**Then** `state` is set to the target milestone configuration and I can continue play from there.

**Given** an instrumentation dump command in the cheat panel
**When** invoked
**Then** it prints per-continent effective rates, bottleneck countries, and estimated time-to-next-milestone at the current play rate.

**Given** late-game observation
**When** walls are identified (excessive time between milestones)
**Then** `BalanceConfig` and content JSON are adjusted and a brief changelog of tuning decisions is appended to a `docs/balance-changes.md` (or equivalent) for future reference.

---
