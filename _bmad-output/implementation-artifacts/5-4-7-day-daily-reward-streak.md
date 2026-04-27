# Story 5.4: 7-Day Daily Reward Streak

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a once-per-day reward that grows over a 7-day consecutive-return streak,
so that I have gentle reason to return daily without being punished for missing.

## Acceptance Criteria

1. **Given** `state.dailyStreak.lastClaimDate` is `null` OR its calendar-date (local) is strictly before `today` (local calendar date derived from `now`)
   **When** `dailyRewardAvailable(state, now)` is read
   **Then** it returns `true`. Otherwise (already claimed today) it returns `false`. "Calendar date" = `(year, month, day)` of the `DateTime`'s LOCAL representation — comparison is integer triple, NOT a 24h `Duration`.

2. **Given** `dailyRewardAvailable == true` and the player issues `ClaimDailyReward()`
   **When** `GameWorld.applyCommand` runs the reducer with injected `now`
   **Then** the reducer returns `Success` with a new `GameState` and a `DailyRewardClaimed(at: now, day: <newDay>, influenceReward: <Influence>, intelReward: <Intel>)` event, where:
     - `newDay = priorDay + 1` capped at 7, OR `1` if the streak resets (see AC #4) OR if `lastClaimDate == null`
     - `state.totalInfluence` increases by the day's `influenceReward` (read from `assets/data/daily_rewards.json[newDay-1]`)
     - `state.totalIntel` increases by the day's `intelReward` (read from same content row)
     - `state.dailyStreak = DailyStreak(day: newDay, lastClaimDate: now)` (UTC `DateTime` of `now`; comparison logic uses `.toLocal()` on read)

3. **Given** `dailyRewardAvailable == false` (already claimed today: `lastClaimDate`'s local date == `now`'s local date)
   **When** `ClaimDailyReward` is dispatched
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'daily_reward_already_claimed'))`. No state change, no event emitted.

4. **Given** `state.dailyStreak.lastClaimDate` is non-null AND `(today - lastLocalDate).inDays > 1` (i.e., at least one full local calendar day was skipped)
   **When** `ClaimDailyReward` succeeds
   **Then** `newDay == 1` (streak reset). `totalInfluence` and `totalIntel` are NOT clawed back — only the streak counter resets, per the "no punishment" rule. The `DailyRewardClaimed.day` field equals `1`.

5. **Given** `state.dailyStreak.day == 7` and the player claims on a consecutive day (`(today - lastLocalDate).inDays == 1`)
   **When** the reducer runs
   **Then** `newDay == 1` (cycle restarts on day 8 → day 1 by spec: "increments up to 7 then resets to 1 on day 8"). The day-1 reward row is granted.

6. **Given** `assets/data/daily_rewards.json` is loaded by `ContentRegistry.fromJsonStrings`
   **When** parsing completes
   **Then** the registry exposes `List<DailyRewardDef> dailyRewards` of EXACTLY 7 entries with `day` values `[1,2,3,4,5,6,7]` in order, each carrying `influenceReward: Decimal` and `intelReward: Decimal` (strings parsed via `Decimal.parse`). A parse-time `ContentLoadException` is thrown if length ≠ 7, days are out of order/duplicated, or any value is unparseable.

7. **Given** `GameState.initialSeed(content)` is called
   **When** the seed is built
   **Then** `state.dailyStreak == DailyStreak(day: 0, lastClaimDate: null)` and `state.totalIntel == Intel.zero`. The `day == 0` sentinel means "never claimed"; the first successful claim transitions `0 → 1`.

8. **Given** any `GameWorld.applyCommand` path that returns `Result.failure`
   **When** the command was `ClaimDailyReward` already-claimed (AC #3)
   **Then** the failure surfaces but `_evaluateContinentUnlocks` and `_evaluateMilestones` are NOT invoked (consistent with `applyCommand`'s existing post-success-only evaluator gate at `lib/game/game_world.dart:94-97`).

9. **Given** `dailyRewardAvailableProvider` is watched by the UI
   **When** `state.dailyStreak.lastClaimDate` changes (via successful claim)
   **Then** the provider re-emits `false` for the rest of today and `true` again the next local calendar day. (UI rendering of the modal/queue priority lands in Epic 7 — this story exposes only the boolean and the cycle data.)

10. **Given** the modal-queue priority order from FR31 (Offline > Daily > Celebration > Achievement)
    **When** this story implements the simulation layer
    **Then** the story does NOT implement the modal queue itself. It only emits `DailyRewardClaimed` and exposes the `dailyRewardAvailable` boolean. Epic 7 (Story 7.4 "Sequential modal queue") owns the queue priority wiring.

11. **Given** the `lib/game/` purity invariant
    **When** new files in `lib/game/features/daily_rewards/` are written
    **Then** none import `package:flutter/*` or `dart:ui`. The reducer is a pure function `(GameState, ContentRegistry, ClaimDailyReward, {required DateTime now}) → Result<(GameState, GameEvent?), GameError>` — no `DateTime.now()` reads, no I/O, no logging in the hot path.

## Tasks / Subtasks

- [x] Task 1: Add the `DailyStreak` value class (AC: 2, 4, 5, 7)
  - [x] 1.1 Create `lib/game/features/daily_rewards/daily_streak.dart`
  - [x] 1.2 Define `@immutable class DailyStreak { final int day; final DateTime? lastClaimDate; const DailyStreak({required this.day, required this.lastClaimDate}); static const empty = DailyStreak(day: 0, lastClaimDate: null); }` (use `const` constructor; `DateTime?` is nullable)
  - [x] 1.3 Implement manual `==`, `hashCode`, `toString` (NO `freezed`). For `==` on `DateTime?`, use direct `==` (Dart compares microsecond-equal `DateTime`s as equal). Pattern reference: `lib/game/features/countries/country_state.dart`.
  - [x] 1.4 Add a `copyWith({int? day, DateTime? lastClaimDate, bool clearLastClaimDate = false})` helper following the `lastCollectedAt` nullable pattern in `country_state.dart` (the `clearLastClaimDate` flag handles the rare null-set case; for this story it's not needed — claims always set a non-null date — but include the flag for symmetry).

- [x] Task 2: Extend `lib/game/game_state.dart` with `totalIntel` and `dailyStreak` (AC: 2, 7)
  - [x] 2.1 Import `Intel` from `lib/game/values/intel.dart` and `DailyStreak` from the new file
  - [x] 2.2 Add fields: `final Intel totalIntel;` and `final DailyStreak dailyStreak;`
  - [x] 2.3 Wire through constructor (defaults: `totalIntel ?? Intel.zero`, `dailyStreak ?? DailyStreak.empty`), `copyWith`, `==`, `hashCode`, `toString`
  - [x] 2.4 Update `GameState.initialSeed(content)` to pass `totalIntel: Intel.zero, dailyStreak: DailyStreak.empty` explicitly (kept defensive even though defaults match)
  - [x] 2.5 No `MapEquality` needed — both new fields are scalars

- [x] Task 3: Add `ClaimDailyReward` command in `lib/game/game_command.dart` (AC: 2, 3)
  - [x] 3.1 `final class ClaimDailyReward extends GameCommand { const ClaimDailyReward(); }` with `==`/`hashCode`/`toString` matching existing command style (e.g., `Noop`)
  - [x] 3.2 Add to the exhaustive `switch` in `GameWorld.applyCommand` (`lib/game/game_world.dart`) — see Task 6

- [x] Task 4: Add `DailyRewardClaimed` event in `lib/game/game_event.dart` (AC: 2)
  - [x] 4.1 `final class DailyRewardClaimed extends GameEvent { final int day; final Influence influenceReward; final Intel intelReward; const DailyRewardClaimed(super.at, {required this.day, required this.influenceReward, required this.intelReward}); }` with manual `==`/`hashCode`/`toString` covering all 4 fields (`at`, `day`, `influenceReward`, `intelReward`)
  - [x] 4.2 Update `test/game/game_event_test.dart` to cover the new event

- [x] Task 5: Add content type and registry parse for daily rewards (AC: 6)
  - [x] 5.1 Create `lib/game/content/daily_reward_def.dart`:
      ```
      @immutable
      class DailyRewardDef {
        final int day;
        final Decimal influenceReward;
        final Decimal intelReward;
        const DailyRewardDef({required this.day, required this.influenceReward, required this.intelReward});
        factory DailyRewardDef.fromJson(Map<String, dynamic> json) { ... rethrow as ContentLoadException ... }
      }
      ```
      Pattern reference: `lib/game/content/continent_def.dart` (`MilestoneReward.fromJson`).
  - [x] 5.2 Extend `ContentRegistry`:
      - Add `final List<DailyRewardDef> dailyRewards;` field (immutable list)
      - Add to `const` constructor and `fromJsonStrings` (new required positional? — match the existing **named-required** style of all other `fromJsonStrings` parameters; add `required String dailyRewardsJson`)
      - Add `_parseDailyRewards(String json)` that:
        - decodes a JSON list of length 7
        - asserts each entry's `day == index + 1` (1..7 in order)
        - throws `ContentLoadException` with a clear message on length mismatch, duplicate days, out-of-order days, or unparseable Decimal strings
  - [x] 5.3 Update `lib/services/content_registry_loader.dart` to load `assets/data/daily_rewards.json` alongside the existing 6 files (`Future.wait` pattern); pass into `fromJsonStrings`
  - [x] 5.4 Create `assets/data/daily_rewards.json` with 7 placeholder entries (Epic 10 will tune):
      ```json
      [
        {"day": 1, "influenceReward": "100",      "intelReward": "1"},
        {"day": 2, "influenceReward": "300",      "intelReward": "2"},
        {"day": 3, "influenceReward": "1000",     "intelReward": "3"},
        {"day": 4, "influenceReward": "3000",     "intelReward": "5"},
        {"day": 5, "influenceReward": "10000",    "intelReward": "8"},
        {"day": 6, "influenceReward": "30000",    "intelReward": "13"},
        {"day": 7, "influenceReward": "100000",   "intelReward": "21"}
      ]
      ```
  - [x] 5.5 `pubspec.yaml` already declares `- assets/data/` (line 90) — NO pubspec change needed for the new file
  - [x] 5.6 NO Drift schema changes in this story — persistence is Epic 6's job. Old saves break (acceptable per project rule).

- [x] Task 6: Implement the reducer (AC: 1, 2, 3, 4, 5, 8, 11)
  - [x] 6.1 Create `lib/game/features/daily_rewards/daily_rewards_reducer.dart`
  - [x] 6.2 Implement pure helper `bool dailyRewardAvailable(GameState state, DateTime now)`:
      ```
      final last = state.dailyStreak.lastClaimDate;
      if (last == null) return true;
      final lastLocal = last.toLocal();
      final nowLocal = now.toLocal();
      return !_sameLocalDate(lastLocal, nowLocal);
      // _sameLocalDate compares (year, month, day)
      ```
  - [x] 6.3 Implement `Result<(GameState, GameEvent?), GameError> applyClaimDailyReward(GameState state, ContentRegistry content, ClaimDailyReward cmd, {required DateTime now})`:
      - if `!dailyRewardAvailable(state, now)` → `Result.failure(GameError.userLocked(reason: 'daily_reward_already_claimed'))`
      - compute `newDay`:
        - `last = state.dailyStreak.lastClaimDate`
        - if `last == null` → `newDay = 1`
        - else compute `gap = _localDayDelta(last.toLocal(), now.toLocal())` (integer count of full local calendar days between dates — see Task 6.5)
        - if `gap == 1` → `newDay = state.dailyStreak.day == 7 ? 1 : state.dailyStreak.day + 1`
        - if `gap > 1` → `newDay = 1` (reset)
        - if `gap == 0` → unreachable (guarded by `dailyRewardAvailable`); `assert(false)` invariant
      - assert `content.dailyRewards.length == 7` (programmer-error invariant; content validation enforces this)
      - `final def = content.dailyRewards[newDay - 1];`
      - assert `def.day == newDay` (invariant from content parser)
      - `final newState = state.copyWith(totalInfluence: state.totalInfluence + Influence(def.influenceReward), totalIntel: state.totalIntel + Intel(def.intelReward), dailyStreak: DailyStreak(day: newDay, lastClaimDate: now));`
      - `final event = DailyRewardClaimed(now, day: newDay, influenceReward: Influence(def.influenceReward), intelReward: Intel(def.intelReward));`
      - return `Result.success((newState, event))`
  - [x] 6.4 Pure: NO `DateTime.now()`, NO `Random()`, NO I/O, NO logging
  - [x] 6.5 Implement `int _localDayDelta(DateTime aLocal, DateTime bLocal)`:
      ```
      final a = DateTime(aLocal.year, aLocal.month, aLocal.day);
      final b = DateTime(bLocal.year, bLocal.month, bLocal.day);
      return b.difference(a).inDays;
      ```
      Both arguments MUST already be `.toLocal()`. Constructing `DateTime(y, m, d)` with no time gives midnight in the LOCAL zone, which makes `.difference(...).inDays` correct across DST (avoids the classic 23/25-hour DST off-by-one).

- [x] Task 7: Wire the reducer into `GameWorld` (AC: 2, 3, 8, 11)
  - [x] 7.1 In `lib/game/game_world.dart`, add a private helper `_applyClaimDailyReward(ClaimDailyReward cmd)` mirroring `_applyTapCountry` style: calls `applyClaimDailyReward(_state, _content, cmd, now: _clock.now())`, on success assigns `_state = newState` and emits the event via `_events.add(event)`
  - [x] 7.2 Add `ClaimDailyReward()` arm to the exhaustive `switch (cmd)` in `applyCommand` after the `UnlockCountry()` arm. The trailing post-success block (`_evaluateContinentUnlocks` + `_evaluateMilestones`) automatically runs — that's harmless because a successful daily claim DOES change `totalInfluence`, which can cross continent thresholds; we WANT continent-unlock evaluation to fire (this is consistent with FR14 + Story 4.2's threshold-based unlocks)
  - [x] 7.3 Do NOT short-circuit the post-command evaluators — `_evaluateContinentUnlocks` is currently the only path that auto-unlocks a continent when `totalInfluence` crosses its threshold via reward, and the daily reward reaches that scale at later days. `_evaluateMilestones` is a no-op here because the claim doesn't unlock countries.
  - [x] 7.4 Update `import 'daily_rewards_reducer.dart'` and ensure no Flutter import sneaks in via transitive imports.

- [x] Task 8: Riverpod provider (AC: 1, 9)
  - [x] 8.1 In `lib/providers/feature_providers.dart` (existing — created by Story 4.5), add:
      ```
      final dailyRewardAvailableProvider = Provider<bool>((ref) {
        final state = ref.watch(gameWorldProvider);
        final clock = ref.watch(clockProvider);
        return dailyRewardAvailable(state, clock.now());
      });
      ```
  - [x] 8.2 IMPORTANT — staleness caveat: this provider does NOT auto-refresh at midnight; it re-evaluates only when `gameWorldProvider` emits OR when explicitly invalidated. For v1 that is acceptable — `LifecycleObserver` (Epic 6) will trigger a re-read on resume, and any tick or command that follows will refresh the underlying state. Document this caveat in a `///` comment on the provider; do NOT add a midnight timer in this story (out of scope; Epic 7 modal-queue will own midnight refresh if needed).
  - [x] 8.3 Use `ref.watch(clockProvider)` (NOT `ref.read`) so the test override flows in
  - [x] 8.4 Do NOT use `.select(...)` — the entire `state` doesn't have a "dailyStreak.lastClaimDate"-narrow watcher worth optimizing; full-state watch is correct given how rarely daily claims happen

- [x] Task 9: Pure-Dart reducer tests (AC: 1, 2, 3, 4, 5, 6, 8, 11)
  - [x] 9.1 Create `test/game/features/daily_rewards/daily_rewards_reducer_test.dart` using `package:test/test.dart` (NOT `flutter_test` — pure-Dart invariant per `test/architecture/game_boundary_test.dart`)
  - [x] 9.2 Build a fixture `ContentRegistry` via `ContentRegistry.fromJsonStrings` with `dailyRewardsJson` = 7 entries with deterministic small integer reward values (e.g., influence `1, 2, 3, 4, 5, 6, 7`; intel `10, 20, 30, 40, 50, 60, 70`). Reuse the fixture-builder pattern from `test/game/features/economy/income_calculator_test.dart` lines 17-67.
  - [x] 9.3 Test: first-ever claim — `state.dailyStreak == DailyStreak.empty` → newDay = 1, totalInfluence += 1, totalIntel += 10, event = `DailyRewardClaimed(at: now, day: 1, influenceReward: Influence(1), intelReward: Intel(10))`, `state.dailyStreak == DailyStreak(day: 1, lastClaimDate: now)`
  - [x] 9.4 Test: consecutive-day claim — prior `(day: 3, lastClaimDate: yesterday)`, `now = today` → newDay = 4, totalInfluence += 4, totalIntel += 40
  - [x] 9.5 Test: day-7 → day-1 cycle (AC #5) — prior `(day: 7, lastClaimDate: yesterday)`, claim today → newDay = 1, day-1 reward applied
  - [x] 9.6 Test: skip-a-day reset (AC #4) — prior `(day: 5, lastClaimDate: 3 days ago)`, claim today → newDay = 1, day-1 reward applied, totalInfluence/Intel NOT clawed back from any prior totals
  - [x] 9.7 Test: same-day double-claim → `Result.failure(GameError.userLocked(reason: 'daily_reward_already_claimed'))`, state unchanged
  - [x] 9.8 Test: `dailyRewardAvailable` boundary — exactly midnight crosses local date (use a deliberately constructed `DateTime` at `23:59:59.999` and `00:00:00.001` of the next local date) — verifies calendar-date comparison, not 24h-Duration
  - [x] 9.9 Test: `dailyRewardAvailable` returns true when `lastClaimDate == null`
  - [x] 9.10 Test: content parser — wrong length (6 entries) throws `ContentLoadException`; out-of-order days (`[1,2,4,3,5,6,7]`) throws; duplicate day throws; unparseable Decimal throws
  - [x] 9.11 Test: `DailyStreak` value semantics — equal-field instances are `==` and share `hashCode`; `toString` includes both fields

- [x] Task 10: GameWorld wiring tests (AC: 2, 3, 8)
  - [x] 10.1 Update `test/game/game_world_test.dart`: dispatch `ClaimDailyReward` from a `GameWorld` constructed with a `FakeClock` pinned at a known `DateTime` and an initial state with `dailyStreak == DailyStreak.empty`. Assert: `state.totalInfluence` increases, `state.totalIntel` increases, `state.dailyStreak.day == 1`, the `DailyRewardClaimed` event was emitted on `events`. Use the `events.toList().then(...)` collection pattern already in that test file.
  - [x] 10.2 Test: same-day double-claim returns failure; state unchanged on the second call (verify via captured `state` reference equality — `identical(beforeSecondClaim, afterSecondClaim)` is true)
  - [x] 10.3 Test: a daily claim at a level that crosses a continent's `unlockThreshold` triggers `ContinentUnlocked` AFTER `DailyRewardClaimed` (proves Task 7.2's wiring — events ordered: claim → continent-unlock → milestone). Use a small-fixture content where a continent threshold is `<= day-1 reward` so a fresh claim crosses it.

- [x] Task 11: GameState seed test updates (AC: 7)
  - [x] 11.1 Add cases to `test/game/game_state_seed_test.dart`: `initialSeed` returns `totalIntel == Intel.zero` and `dailyStreak == DailyStreak.empty`
  - [x] 11.2 Add a `copyWith` round-trip case to `test/game/game_state_test.dart` covering both new fields and `==`/`hashCode` on identical streaks

- [x] Task 12: Provider test (AC: 9)
  - [x] 12.1 Extend `test/providers/feature_providers_test.dart` (existing from Story 4.5):
      - override `clockProvider` with a `_FixedClock` (test helper) returning a pinned `DateTime`
      - override `gameWorldProvider` via the `_TestGameWorldNotifier` pattern documented in Story 4.5 Dev Notes (see `test/providers/feature_providers_test.dart` lines around the existing override block)
      - assert `dailyRewardAvailableProvider` returns `true` for `dailyStreak.empty`, `false` after pushing a state where `lastClaimDate == clock.now()`, and `true` again after the test pushes a state where `lastClaimDate` is a prior local day
  - [x] 12.2 Always `addTearDown(container.dispose);`

- [x] Task 13: Architecture compliance verification (AC: 11)
  - [x] 13.1 Run `flutter test test/architecture/` — `lib/game/features/daily_rewards/**` and `lib/game/content/daily_reward_def.dart` MUST contain NO `package:flutter/`, NO `dart:ui`, NO `lib/data/` imports (`test/architecture/game_boundary_test.dart`)
  - [x] 13.2 Confirm `daily_rewards_reducer.dart` does NOT match the income-math grep guard in `test/architecture/no_duplicate_income_math_test.dart` — the reducer adds rewards to `totalInfluence`/`totalIntel` directly; it does not invoke or duplicate the multiplier stack. Daily reward is NOT a multiplier — it's a flat additive grant.

- [x] Task 14: Full validation (AC: all)
  - [x] 14.1 `flutter analyze` — 0 warnings
  - [x] 14.2 `dart format --set-exit-if-changed .`
  - [x] 14.3 `flutter test` — all pass (existing + new). Existing tests will need only the `ContentRegistry.fromJsonStrings` callsites to add `dailyRewardsJson:` — search across `test/` and update each fixture builder.
  - [x] 14.4 Update `Status` to `review` and append entries to the Completion Notes / File List

## Dev Notes

### Sibling-story coordination (READ FIRST)

This is the FIRST Epic-5 story to land. It establishes patterns that 5.1 (Goldens), 5.2 (Boosts), 5.3 (Missions), 5.5 (Achievements) will follow:

- New `lib/game/features/daily_rewards/` folder — sibling features should each create their own (`goldens/`, `boosts/`, `missions/`, `achievements/`) per `_bmad-output/game-architecture.md` line 580.
- `Intel` value object FIRST PRODUCTION USE — until now `lib/game/values/intel.dart` was unreferenced. This story wires `totalIntel` into `GameState`. Stories 5.2/5.3/5.5 will SPEND/EARN Intel via the same field — DO NOT create a parallel field.
- New `ContentRegistry.dailyRewards` and `daily_rewards.json` — match the pattern when 5.5 adds `achievements.json`-driven content (already exists, but 5.5 will require new schema fields).
- The content-loader `Future.wait` pattern in `content_registry_loader.dart` extends to 7 entries; if 5.5 adds another asset file, it follows the same pattern.

### Decisions locked in by upstream stories — DO NOT redebate

| Decision | Source | Application here |
|---|---|---|
| `lib/game/` is pure Dart (NO Flutter imports) | project-context.md §Engine-Specific Rules | All new files under `lib/game/features/daily_rewards/` and `lib/game/content/daily_reward_def.dart` MUST follow |
| Reducers are pure functions returning `Result<(NewState, Event?), GameError>` | project-context.md, multiple prior stories | Daily reducer matches signature exactly |
| Commands are imperative, events past-tense, both sealed | project-context.md | `ClaimDailyReward` (cmd) → `DailyRewardClaimed` (event) |
| `now` and `rng` are injected, never read inside `lib/game/` | project-context.md, Story 1.9 | Reducer takes `required DateTime now`; provider reads `clockProvider` |
| Big numbers via `Influence` / `Intel` value objects; `double` for currency is a bug | project-context.md, Story 1.5 | Reward values: `Influence(def.influenceReward)`, `Intel(def.intelReward)` |
| Manual `==`/`hashCode`/`toString`; NO `freezed` | project-context.md | `DailyStreak`, `DailyRewardDef`, new event/command |
| `StreamController.broadcast(sync: true)` for events | game_world.dart line 22 | New event flows on the same stream |
| Raw `Provider`/`Provider.family`; NO `riverpod_generator`, NO `@riverpod` | Story 4.5 + project-context | New provider in `lib/providers/feature_providers.dart` |
| Multiplier stack lives ONLY in `IncomeCalculator.compute` | project-context, Story 3.1 | Daily reward is FLAT ADDITIVE — DO NOT wire as a multiplier |
| Modal-queue priority (Offline > Daily > Celebration > Achievement) | FR31, epics §Story 7.4 | Explicitly OUT of scope; this story exposes only the boolean + event |
| Persistence (`dailyStreak` JSON column on `meta` table) | epics §Story 6.1 | Explicitly OUT of scope; Epic 6 owns it. Old saves break. |

### Architecture Compliance (non-negotiable)

- **`lib/game/` ZERO Flutter imports.** New files in `lib/game/features/daily_rewards/` and `lib/game/content/daily_reward_def.dart` MUST NOT import `package:flutter/*` or `dart:ui`. Use `package:meta/meta.dart` for `@immutable`. Enforced by `test/architecture/game_boundary_test.dart`.
- **Pure reducer.** Reducer takes `(GameState, ContentRegistry, ClaimDailyReward, {required DateTime now})`. No `DateTime.now()`, no `Random()`, no async, no I/O, no logging.
- **Sealed exhaustiveness.** Adding `ClaimDailyReward` to `GameCommand` and `DailyRewardClaimed` to `GameEvent` will force compiler errors at every consumer `switch`. UPDATE every consumer:
  - `lib/game/game_world.dart` — add `ClaimDailyReward()` arm in `applyCommand` switch (Task 7.2). The current switch is at lines 86-93.
  - Audio/haptics services and other event subscribers may use a `default` / no-op fallthrough on unhandled events (project-context permits this for `AudioService` / `HapticsService` only). Verify NO consumer compile-errors after adding the new event.
- **`StreamController.broadcast(sync: true)`** — DO NOT change; the existing controller is correct.
- **Big numbers.** `def.influenceReward` is `Decimal`; wrap in `Influence(...)` at the reducer/event boundary. Same for `Intel(...)`. NEVER expose raw `Decimal` from event payloads. NEVER use `double`.
- **No income math here.** This reducer adds `Influence`/`Intel` directly — it does NOT touch `IncomeCalculator.compute` or any multiplier. The grep guard in `test/architecture/no_duplicate_income_math_test.dart` flags `def.baseInfluence *` patterns; this reducer doesn't match.
- **`lib/data/` is OFF-LIMITS this story.** No new Drift table, no migration, no `GameStateMapper` change. Epic 6 owns persistence; old saves breaking is acceptable per project rule.

### Library / Framework Requirements

- `package:meta/meta.dart` — `@immutable`. Already a transitive dep.
- `package:decimal/decimal.dart: ^3.0.2` — already pinned. Used for `Decimal.parse` in content and arithmetic in `Influence`/`Intel`.
- `package:flutter_riverpod: ^2.6.1` — for the new `Provider`.
- `package:test/test.dart` — pure-Dart reducer/content tests.
- `package:flutter_test/flutter_test.dart` + `package:flutter_riverpod/flutter_riverpod.dart` — provider tests.
- NO new pubspec entries required.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/features/daily_rewards/daily_streak.dart` | `DailyStreak` value class |
| `lib/game/features/daily_rewards/daily_rewards_reducer.dart` | Pure reducer + `dailyRewardAvailable` selector |
| `lib/game/content/daily_reward_def.dart` | `DailyRewardDef` content type |
| `assets/data/daily_rewards.json` | 7 placeholder entries (Epic 10 will tune) |
| `test/game/features/daily_rewards/daily_rewards_reducer_test.dart` | Pure-Dart reducer tests |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add `totalIntel: Intel`, `dailyStreak: DailyStreak` fields; constructor, `copyWith`, `==`, `hashCode`, `toString`, `initialSeed` |
| `lib/game/game_command.dart` | Add `ClaimDailyReward` command |
| `lib/game/game_event.dart` | Add `DailyRewardClaimed` event |
| `lib/game/game_world.dart` | Add `_applyClaimDailyReward` helper + arm in `applyCommand` switch |
| `lib/game/content/content_registry.dart` | Add `dailyRewards` field + `_parseDailyRewards` + new `dailyRewardsJson` parameter on `fromJsonStrings` |
| `lib/services/content_registry_loader.dart` | Load `assets/data/daily_rewards.json` |
| `lib/providers/feature_providers.dart` | Add `dailyRewardAvailableProvider` |
| `test/game/game_state_test.dart`, `test/game/game_state_seed_test.dart` | Cover new fields |
| `test/game/game_command_test.dart`, `test/game/game_event_test.dart` | Cover new variants |
| `test/game/game_world_test.dart` | Cover `ClaimDailyReward` wiring + post-claim continent-unlock evaluation |
| `test/providers/feature_providers_test.dart` | Cover `dailyRewardAvailableProvider` |
| All existing tests calling `ContentRegistry.fromJsonStrings(...)` | Add `dailyRewardsJson:` named arg (sweep `test/` for callsites) |

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` — daily reward is NOT a multiplier; it's a flat additive grant.
- `lib/data/**` — persistence is Epic 6's job; old saves break.
- `assets/data/countries.json`, `assets/data/continents.json`, etc. — content for those is owned by other stories/epics.
- `lib/game/game_state.dart`'s existing `unlockedContinents`, `reachedMilestones`, `continentCompletions` — independent state, leave alone.

### Testing Requirements

- **Pure-Dart reducer tests** use `package:test/test.dart` (NOT `flutter_test`). Pattern: `test/game/features/economy/income_calculator_test.dart`, `test/game/features/continents/milestones_reducer_test.dart`.
- **Content fixture** via `ContentRegistry.fromJsonStrings` with inline JSON strings; pass deterministic small reward values for clear arithmetic assertions. Reuse the existing helper-builder shape from `test/game/game_state_seed_test.dart` lines 15-67.
- **Clock injection.** Use `FakeClock` from `test/helpers/fake_clock.dart` for `GameWorld` tests; for pure reducer tests, pass `now: DateTime(2026, 4, 25, 12, 0).toUtc()` (or a similarly explicit `DateTime`). Tests for the local-date-boundary AC (#1, AC #8 implicitly) MUST use deterministic `DateTime`s, NOT `DateTime.now()`.
- **Local-date pitfall.** `DateTime.toLocal()` depends on the host timezone. Tests SHOULD use timezone-agnostic constructions: build both `lastClaimDate` and `now` from the same `DateTime` constructor (defaults to local); the comparison is intra-test consistent. Avoid `DateTime.utc(...)` for inputs unless the test explicitly verifies a UTC vs local boundary.
- **DST guard.** Add ONE test that crosses a DST boundary (construct `DateTime(2026, 3, 14, 23, 0)` "yesterday" and `DateTime(2026, 3, 15, 23, 0)` "today" — DST starts in the US on Mar 8, 2026; pick a real DST transition date). The `_localDayDelta` implementation using `DateTime(y,m,d)` truncation MUST return `1` across DST. If the host CI runs in UTC (no DST) the test still passes — that's fine; the test documents intent.
- **No widget tests** for this story — UI rendering is Epic 7. The provider test in Task 12 is sufficient.
- **Property test NOT required** — daily reward arithmetic is bounded (7 days × 1 reward each); deterministic tests cover all branches.

### Provider test wiring (gotcha — read carefully)

Same shape as Story 4.5's `_TestGameWorldNotifier extends GameWorldNotifier` pattern. To pin the clock for `dailyRewardAvailableProvider`, override `clockProvider`:

```dart
final fakeClock = FakeClock(DateTime(2026, 4, 25, 12, 0));
final container = ProviderContainer(overrides: [
  clockProvider.overrideWithValue(fakeClock),
  contentRegistryProvider.overrideWith((_) async => fixtureContent),
  gameWorldProvider.overrideWith((ref) => _TestGameWorldNotifier(initialState)),
]);
addTearDown(container.dispose);

// To advance the clock for the second assertion:
fakeClock.advance(const Duration(days: 1));
container.invalidate(dailyRewardAvailableProvider);  // provider doesn't auto-watch wall clock
expect(container.read(dailyRewardAvailableProvider), isTrue);
```

The explicit `invalidate` in the test is intentional — it documents Task 8.2's caveat (provider does NOT auto-refresh at midnight in production; the next state mutation or lifecycle resume invalidates the cached value).

### Reference reducer skeleton (do NOT reinvent)

```dart
// lib/game/features/daily_rewards/daily_rewards_reducer.dart
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/game/values/result.dart';

bool dailyRewardAvailable(GameState state, DateTime now) {
  final last = state.dailyStreak.lastClaimDate;
  if (last == null) return true;
  return _localDayDelta(last.toLocal(), now.toLocal()) >= 1;
}

Result<(GameState, GameEvent?), GameError> applyClaimDailyReward(
  GameState state,
  ContentRegistry content,
  ClaimDailyReward cmd, {
  required DateTime now,
}) {
  if (!dailyRewardAvailable(state, now)) {
    return const Result.failure(
      GameError.userLocked(reason: 'daily_reward_already_claimed'),
    );
  }
  assert(content.dailyRewards.length == 7);

  final last = state.dailyStreak.lastClaimDate;
  final int newDay;
  if (last == null) {
    newDay = 1;
  } else {
    final gap = _localDayDelta(last.toLocal(), now.toLocal());
    if (gap == 1) {
      newDay = state.dailyStreak.day == 7 ? 1 : state.dailyStreak.day + 1;
    } else {
      // gap > 1; gap == 0 is unreachable due to the guard above.
      assert(gap > 1, 'gap == 0 should have been rejected by dailyRewardAvailable');
      newDay = 1;
    }
  }

  final def = content.dailyRewards[newDay - 1];
  assert(def.day == newDay);

  final influenceReward = Influence(def.influenceReward);
  final intelReward = Intel(def.intelReward);
  final newState = state.copyWith(
    totalInfluence: state.totalInfluence + influenceReward,
    totalIntel: state.totalIntel + intelReward,
    dailyStreak: DailyStreak(day: newDay, lastClaimDate: now),
  );
  final event = DailyRewardClaimed(
    now,
    day: newDay,
    influenceReward: influenceReward,
    intelReward: intelReward,
  );
  return Result.success((newState, event));
}

int _localDayDelta(DateTime aLocal, DateTime bLocal) {
  final a = DateTime(aLocal.year, aLocal.month, aLocal.day);
  final b = DateTime(bLocal.year, bLocal.month, bLocal.day);
  return b.difference(a).inDays;
}
```

(Pseudocode — adjust imports to project style and verify exact `Result.failure` const-constructor usage matches the existing pattern in `unlocks_reducer.dart`.)

### Modal queue / UI scope boundary

FR31 specifies: Modals queue sequentially with priority Offline > Daily > Celebration > Achievement. AC #1 of the original story spec mentions "Daily Reward Modal is queued ahead of Achievement modals, behind Offline Reward."

**This story implements ZERO modal/UI logic.** It exposes:

- `dailyRewardAvailableProvider` (boolean) — the data
- `DailyRewardClaimed` event — the celebration trigger

Story 7.4 ("Sequential modal queue with priority") owns the queue. When 7.4 lands, its modal-queue subscriber will read `dailyRewardAvailableProvider`; on `true` it enqueues a Daily modal at the Daily priority slot. The Daily modal's "Claim" button dispatches `ClaimDailyReward()`. Until 7.4 ships, there is no UI surface for the daily reward — that is correct and intentional.

### Persistence scope boundary

Epic 6 (`Story 6.1: Drift Schema and GameStateMapper`) explicitly lists `dailyStreak (JSON)` as a `meta`-table column. **This story does NOT touch Drift.** When 6.1 lands:

- `meta.dailyStreak` (TEXT, JSON-serialized `{day, lastClaimDate}`) — 6.1's mapper handles
- `meta.totalIntel` (TEXT via `DecimalConverter`) — 6.1's mapper handles
- `daily_rewards` Drift table — 6.1 mentions one in its AC list, but with this story's design (content-driven, no per-day persistent state beyond `dailyStreak`), the table may be redundant. If 6.1 still needs a per-claim audit log, that's its call. **Out of scope here.**

Old saves WILL break when this story ships (no migration, new state fields). Per project rule: acceptable; users reset.

### Project Structure Notes

- **Folder choice (`lib/game/features/daily_rewards/`):** matches `_bmad-output/game-architecture.md` line 580. Keeps daily-reward state + reducer cohesive and isolated.
- **Content type alongside other defs (`lib/game/content/daily_reward_def.dart`):** matches existing pattern (`country_def.dart`, `continent_def.dart`, `mission_def.dart`, etc.).
- **Provider in `feature_providers.dart`:** Story 4.5 established this file; daily reward provider lives here, not in a new file.
- **Asset path (`assets/data/daily_rewards.json`):** matches the convention of every other content JSON; `pubspec.yaml` line 90 already declares the directory as an asset, so NO pubspec change.
- **No conflict** with sibling Epic 5 stories (5.1/5.2/5.3/5.5) — they each own a separate folder under `lib/game/features/`. Land 5.4 first to establish the `Intel`-on-state pattern; siblings extend.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` ZERO Flutter imports.** All new sim files MUST be pure Dart. Enforced by `test/architecture/game_boundary_test.dart`.
- **Pure reducers.** Take `(state, content, cmd, {required DateTime now})`, return `Result<(GameState, GameEvent?), GameError>`. No clock or RNG reads inside.
- **Commands imperative, events past-tense, both sealed.** Compiler-enforced exhaustiveness on every `switch`. New variants force consumer updates.
- **Big numbers via `Influence`/`Intel` value objects** — wrap raw `Decimal` from content at the boundary, never expose raw `Decimal` from event payloads.
- **Multiplier stack** lives ONLY in `IncomeCalculator.compute`. Daily reward is a flat additive grant — DO NOT add it to the multiplier stack.
- **Configuration discipline:** reward values are CONTENT (`assets/data/daily_rewards.json`), not BalanceConfig constants. Epic 10 will tune the values; structure ships now.
- **No `freezed`, no `riverpod_generator`, no `@riverpod`.** Manual `==`/`hashCode`/`toString` on `DailyStreak`, `DailyRewardDef`, `DailyRewardClaimed`. Raw `Provider` for the new provider.
- **`StreamController.broadcast(sync: true)`** — keep synchronous emission; tests rely on it.
- **`Result<T, GameError>`** for all reducer returns — `userLocked(reason: 'daily_reward_already_claimed')` for the same-day double-claim case.
- **Logging:** `package:logging` only (NEVER `print()`). The reducer is pure — NO logging inside it. The `_applyClaimDailyReward` helper in `GameWorld` MAY log at info level for the success branch (NOT the failure — failures are user-locked, not anomalies); follow `Logger('GameWorld')` if added, but logging is OPTIONAL for this story.
- **Sealed `switch` exhaustiveness** — adding `ClaimDailyReward` and `DailyRewardClaimed` will produce compiler errors at every consumer. Walk every error and either handle the new variant or use the documented `default` fallthrough (audio/haptics services only).
- **Riverpod tests** override providers via `ProviderContainer(overrides: [...])`; always `addTearDown(container.dispose);`.
- **`MCP dart` tools** are available — prefer them over shell `dart`/`flutter` invocations for analysis and test runs during dev.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.4: 7-Day Daily Reward Streak] — original ACs and story statement (lines 1066-1084)
- [Source: _bmad-output/planning-artifacts/epics.md] — FR14 (line 38), FR31 modal priority (line 64), Epic 5 goal (line 988)
- [Source: _bmad-output/game-architecture.md] — feature folder layout (line 580: `daily_rewards/ { state, reducer }`); `meta.dailyStreak (JSON)` persistence intent (referenced in epics §Story 6.1)
- [Source: _bmad-output/project-context.md] — Engine-Specific Rules, Code Organization Rules, Testing Rules, Anti-Patterns
- [Source: _bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md] — pattern for adding new event + state field + reducer wired into `GameWorld.applyCommand`
- [Source: _bmad-output/implementation-artifacts/4-1-unlock-next-country-in-current-continent.md] — pattern for new command + reducer signature `Result<(GameState, GameEvent?), GameError>`
- [Source: _bmad-output/implementation-artifacts/4-5-next-unlock-teaser-data-on-state.md] — `feature_providers.dart` provider pattern + `_TestGameWorldNotifier` test override
- [Source: lib/game/game_world.dart] — `applyCommand` switch (lines 67-99); `_apply*` helper pattern (lines 123-171); post-success evaluator gate (lines 94-97)
- [Source: lib/game/game_state.dart] — fields, `copyWith`, `initialSeed`, equality patterns
- [Source: lib/game/game_command.dart] — `Noop`/`TapCountry`/etc. command shape with manual `==`
- [Source: lib/game/game_event.dart] — event hierarchy with `DateTime at` base + manual equality
- [Source: lib/game/values/intel.dart] — `Intel` value object (already implemented; first production use)
- [Source: lib/game/values/influence.dart] — `Influence` wrapper construction
- [Source: lib/game/content/continent_def.dart] — `MilestoneReward.fromJson` parser pattern with `ContentLoadException` rethrow
- [Source: lib/game/content/content_registry.dart] — `fromJsonStrings` named-required-args pattern; `_parseContinents` deterministic-list parsing
- [Source: lib/services/content_registry_loader.dart] — `Future.wait` over 6 asset loads; extend to 7
- [Source: lib/providers/feature_providers.dart] — provider file from Story 4.5
- [Source: lib/providers/game_providers.dart] — `gameWorldProvider` + `clockProvider` definitions
- [Source: test/game/game_state_seed_test.dart] — fixture content builder pattern (lines 15-67)
- [Source: test/game/features/continents/milestones_reducer_test.dart] — multi-event reducer test patterns
- [Source: test/helpers/fake_clock.dart] — `FakeClock` injection
- [Source: test/architecture/game_boundary_test.dart] — purity invariant enforcement
- [Source: pubspec.yaml] — `assets/data/` directory already declared (line 90); no pubspec changes needed for `daily_rewards.json`

### Review Findings

- [x] [Review][Patch] Future `lastClaimDate` is treated as claimable instead of locked [lib/game/features/daily_rewards/daily_rewards_reducer.dart:23]
- [x] [Review][Patch] DST spring-forward can reset a consecutive streak to day 1 [lib/game/features/daily_rewards/daily_rewards_reducer.dart:29]
- [x] [Review][Patch] Claim path can crash while content is still using placeholder daily rewards [lib/providers/feature_providers.dart:29]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

### Completion Notes List

- Implemented 7-day daily reward streak: `DailyStreak`, `ClaimDailyReward` / `DailyRewardClaimed`, `assets/data/daily_rewards.json`, `ContentRegistry.dailyRewards` + loader (7th asset), pure `daily_rewards_reducer` with local calendar-day rules and day-7→1 cycle, `GameWorld` wiring with post-success continent/milestone evaluators, `dailyRewardAvailableProvider` with midnight caveat comment. `GameState` had `totalIntel` already; added `dailyStreak` only. Tests: new reducer + updates across fixtures (`test/helpers/daily_rewards_test_json.dart`), `content_registry_loader_test` mock asset, `game_world_test`, `feature_providers_test`. `flutter analyze` clean; `dart format --set-exit-if-changed .` clean; full `flutter test` pass (638+).
- Final closure (dev-story run): fixed `missions_reducer_test` import to `../../../helpers/daily_rewards_test_json.dart`; `game_state_test` uses `DailyStreak.empty` (not invalid `const DailyStreak.empty`); UI map tests’ empty `ContentRegistry` includes `dailyRewards: []`; `daily_rewards_reducer_test` duplicate-day parse case; removed unused helper import from `content_registry_loader_test` (inline 7-row JSON mock). Re-verified `flutter test`, `flutter test test/architecture/`, `flutter analyze`, `dart format --set-exit-if-changed .`.

- Code review patch pass: fixed future claim-date availability, DST-safe calendar-day delta math, and loading-placeholder daily reward availability; added reducer/provider regression tests. Re-verified targeted tests, architecture tests, full `flutter test` (643), and `flutter analyze`.

### File List

- `assets/data/daily_rewards.json` (new)
- `lib/game/content/daily_reward_def.dart` (new)
- `lib/game/content/content_registry.dart` (modified)
- `lib/game/features/daily_rewards/daily_streak.dart` (new)
- `lib/game/features/daily_rewards/daily_rewards_reducer.dart` (new)
- `lib/game/game_command.dart` (modified)
- `lib/game/game_event.dart` (modified)
- `lib/game/game_state.dart` (modified)
- `lib/game/game_world.dart` (modified)
- `lib/providers/feature_providers.dart` (modified)
- `lib/providers/game_providers.dart` (modified)
- `lib/services/content_registry_loader.dart` (modified)
- `test/helpers/daily_rewards_test_json.dart` (new)
- `test/game/features/daily_rewards/daily_rewards_reducer_test.dart` (new)
- `test/services/content_registry_loader_test.dart` (modified — 7th mocked asset + expect `dailyRewards.length`)
- `test/game/features/missions/missions_reducer_test.dart` (import path fix)
- `test/ui/features/map/game_loop_test.dart` (empty `ContentRegistry`: `dailyRewards: []`)
- `test/ui/features/map/map_screen_tap_test.dart` (same)
- `test/ui/features/map/map_screen_golden_tap_test.dart` (same)
- `test/game/content/content_registry_test.dart` (modified)
- `test/game/game_command_test.dart` (modified)
- `test/game/game_event_test.dart` (modified)
- `test/game/game_state_test.dart` (modified)
- `test/game/game_state_seed_test.dart` (modified)
- `test/game/game_world_test.dart` (modified)
- `test/providers/feature_providers_test.dart` (modified)
- `test/helpers/next_unlock_test_fixtures.dart` (modified)
- Plus: all `ContentRegistry.fromJsonStrings` call sites under `test/game/**` and `test/helpers` updated with `dailyRewardsJson` (e.g. `income_calculator_test`, `milestones_reducer_test`, `missions_reducer_test`, `goldens_scheduler_test`, `unlocks`/`continents`/`countries`/`leaders`/`upgrades` reducer tests, etc.)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (development_status 5-4)

### Change Log

- 2026-04-27: Story 5-4 code review patch pass - fixed 3 review findings; status -> done

- 2026-04-26: Story 5-4 complete — 7-day daily reward streak, content + reducer + provider + tests; status → review
- 2026-04-26: Story 5-4 dev-story closure — test/import/UI fixture fixes; duplicate-day content parse test; full suite green
