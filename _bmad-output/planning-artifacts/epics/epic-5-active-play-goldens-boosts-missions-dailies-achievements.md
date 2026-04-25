# Epic 5: Active Play — Goldens, Boosts, Missions, Dailies, Achievements

**Goal:** Deliver the burst / retention layer. Golden Opportunities spawn for 10–100× bursts, Boosts give 2× for 30s, Missions reward Intel for active play, Daily Rewards encourage streaks, and Achievements grant permanent multipliers.

### Story 5.1: Golden Opportunity — Spawn and Claim

As a player,
I want Golden Opportunities to randomly spawn on my owned countries and be claimable by tapping for a 10–100× multiplier burst,
So that active play feels explosive and rewarding.

**Acceptance Criteria:**

**Given** the `GoldenScheduler` runs on tick
**When** the current RNG seed + elapsed time crosses a spawn probability threshold (defined in `BalanceConfig`)
**Then** a `GoldenSpawned(countryId, multiplier, expiresAt)` event fires and the golden is added to `state.activeGoldens`.

**Given** an active Golden with `expiresAt` in the past
**When** the scheduler runs
**Then** the Golden is removed from state and a `GoldenExpired` event fires — it is not claimable.

**Given** the RNG is seeded (test) OR live-random (release)
**When** tests run
**Then** golden spawns are deterministic — exactly reproducible from seed + clock.

**Given** an active Golden on country X
**When** I tap the Golden (hit-test resolves to a Golden overlay, not just the country)
**Then** `ClaimGolden(goldenId)` fires, the Golden is removed from `activeGoldens`, a `GoldenClaimed(multiplier, duration)` event fires, and `state.activeGoldenEffect` is set with `expiresAt = now + duration`.

**Given** an active `goldenEffect`
**When** `IncomeCalculator` runs
**Then** the `goldenOpportunityMultiplier` slot uses the effect's multiplier.

**Given** `goldenEffect.expiresAt` has passed
**When** tick runs
**Then** the effect is cleared and `GoldenExpired` fires.

### Story 5.2: Activate Boost (2× / 30s) Using Intel

As a player,
I want to spend Intel to activate a 30-second 2× Boost,
So that I can amplify a tap burst on my own schedule.

**Acceptance Criteria:**

**Given** I have at least `boostCost` Intel and no active Boost
**When** I dispatch `ActivateBoost()`
**Then** Intel decreases by `boostCost`, `state.activeBoost = { multiplier: 2.0, expiresAt: now + 30s }`, and `BoostActivated` event fires.

**Given** an active Boost
**When** I dispatch `ActivateBoost` again
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'boost_already_active'))` — boosts do not stack (refresh-or-queue deferred to Epic 10 if balance calls for it).

**Given** Intel < boostCost
**When** I dispatch `ActivateBoost`
**Then** the reducer returns `Result.failure(userInsufficientFunds)`.

**Given** `activeBoost.expiresAt` passes
**When** tick runs
**Then** the boost clears and `BoostExpired` fires.

### Story 5.3: Missions Cycle Rotating Objectives Rewarding Intel

As a player,
I want a small set of rotating missions ("claim 3 Goldens," "activate 2 Boosts," "stay active 5 minutes") visible in a Missions UI,
So that I have short-term goals that pay Intel for active engagement.

**Acceptance Criteria:**

**Given** the mission catalog in `assets/data/missions.json` with data-driven conditions
**When** the game boots
**Then** exactly N active missions (N defined in `BalanceConfig`) are populated, each with `id`, `progress`, `target`, `rewardIntel`.

**Given** a `GameEvent` fires that advances a mission's condition (e.g. `GoldenClaimed` advances a "claim 3 Goldens" mission)
**When** the mission evaluator runs after `applyCommand`
**Then** the mission's `progress` increments, and if `progress ≥ target`, `MissionCompleted(missionId, rewardIntel)` fires and Intel increases.

**Given** a mission completes
**When** the rotation logic runs
**Then** a new mission is drawn from the catalog (excluding currently-active missions) to replace it.

### Story 5.4: 7-Day Daily Reward Streak

As a player,
I want a once-per-day reward that grows over a 7-day consecutive-return streak,
So that I have gentle reason to return daily without being punished for missing.

**Acceptance Criteria:**

**Given** I haven't claimed today's daily reward and today's local date ≠ `lastDailyClaimDate`
**When** I open the app
**Then** the Daily Reward Modal is queued (ahead of Achievement modals, behind Offline Reward per the priority order).

**Given** I claim the daily reward
**When** the reducer runs
**Then** `totalInfluence` and `totalIntel` increase per the streak day's reward table in content JSON, `state.dailyStreak.day` increments up to 7 (then resets to 1 on day 8), `lastDailyClaimDate = today`, and `DailyRewardClaimed` fires.

**Given** I miss a day (today's date - `lastDailyClaimDate` > 1 day)
**When** I next open the app
**Then** the streak resets to day 1 — the game does NOT penalize past progress, only resets the streak counter.

### Story 5.5: 27 Achievements Granting Permanent Multipliers

As a player,
I want 27 discoverable achievements with permanent multiplier rewards,
So that my long-term play is rewarded with growing base power.

**Acceptance Criteria:**

**Given** `assets/data/achievements.json` with 27 entries, each having `id`, `condition` (data-driven predicate), `rewardType` (`multiplier` or `intel`), `rewardValue`
**When** the game boots
**Then** all 27 achievements load into `ContentRegistry` and their definitions are available to the evaluator.

**Given** the `AchievementEvaluator` runs after every `applyCommand`
**When** a not-yet-earned achievement's condition evaluates `true` against current `GameState`
**Then** `state.earnedAchievements` adds the id, `AchievementEarned(id, reward)` fires, and the reward is applied (either added to `Σ achievementMultipliers` in `IncomeCalculator` or added to `totalIntel`).

**Given** an already-earned achievement
**When** the evaluator runs
**Then** it is skipped (no re-firing).

**Given** 27 achievements are loaded
**When** counted
**Then** exactly 27 entries exist — parse-time assertion in content validation.

---
