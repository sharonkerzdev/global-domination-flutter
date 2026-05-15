# Story 7.10: Continent Progression Visual Indicators

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.10 depends on the shell, theme tokens, Upgrades tab, Stats screen, milestone state, and Story 7.9 worktree:

- `lib/ui/features/upgrades/upgrades_screen.dart` already renders one section per UNLOCKED continent. `_ContinentHeader` (lines 138–176) is the slot for the new "X / Y owned" badge + horizontal progress bar with milestone ticks. The body is a flat `ListView.builder` whose first item in each section is the `_HeaderItem` (line 79). Do NOT restructure the list/section/teaser layout.
- `lib/providers/upgrades_providers.dart` already exposes `ContinentUpgradeSection { continentId, continentName, countries, teaser }` (lines 79–92) and `upgradesTabModelProvider` (line 427). The narrow `_UpgradesStateSlice` (lines 168–273) already includes `unlockedContinents` and `continentCompletions`. The Upgrades section already iterates `content.countries.values` filtered by `def.continent == continent.id` in `_buildUpgradesTabModel` (lines 320–372). Extend the DTO with `ownedCount`, `totalCount`, and `reachedMilestoneTiers: Set<int>` — do NOT compute milestones from country counts in the widget.
- `lib/ui/features/stats/stats_screen.dart` already has `_ProgressSection` (lines 105–153) using `statsProgressSummaryProvider` and the reusable `_statRow` helper (lines 278–331). Add a new **continent-progress section below `_ProgressSection`** (or as a sub-section within it) — do NOT touch the existing `_MultiplierSection` / `_TemporaryEffectsSection`.
- `lib/providers/stats_providers.dart` already has `StatsProgressSummary` (lines 25–62) returning **aggregate** counts only. This story adds a NEW per-continent provider (or extends the existing summary) — the existing fields and `statsProgressSummaryProvider` body must remain backward-compatible because they are read by the Stats screen tests at `test/ui/features/stats/stats_screen_test.dart`.
- `lib/ui/theme/milestone_colors.dart` already exists as a registered `ThemeExtension`: `MilestoneColors { track, tick, milestone25, milestone50, milestone75, milestone100, pulseAccent }`. It is registered in `lib/ui/theme/app_theme.dart` (line 23). **Read all colors from this extension — never re-declare or use raw `Color(...)` / `Colors.*`.**
- `lib/ui/theme/spacing.dart` exposes `Spacing.{xs=4, sm=8, md=16, lg=24, xl=32, xxl=48}`. Use these tokens; do not introduce raw padding/sizing literals.
- `lib/game/game_state.dart` already exposes `unlockedContinents`, `continentCompletions`, `reachedMilestones: Map<ContinentId, Set<int>>` (line 40) — the canonical source of which milestone tiers have been hit. **Do NOT recompute milestone-reached state in the UI**; read `state.reachedMilestones[continentId]` directly. Tier values are `{25, 50, 75, 100}` as integers (from `lib/game/features/continents/milestones_reducer.dart` line 42).
- `lib/game/features/continents/milestones_reducer.dart` is the SOLE owner of milestone evaluation. Threshold semantics: a tier `T` is "reached" once `owned >= (T * totalCountriesInContinent) ~/ 100` (line 43 — **integer floor division**). The UI's progress-bar geometry must match this same integer-floor math so the visual tick fill aligns exactly with state.
- `lib/providers/leaders_providers.dart` line 149 `'${section.hiredCount} / ${section.totalCount} Leaders hired'` is the **pattern** the new badge must mirror (badge in a `Container` with `scheme.surfaceContainerHighest`, `BorderRadius.circular(4)`, `Spacing.sm` horizontal padding). Adopt the same visual treatment for the "X / Y owned" badge.
- Story 7.9 is in `review` status; its artifacts (`lib/providers/map_focus_providers.dart`, `lib/ui/features/map/auto_focus_target.dart`, `_MapViewState` extension, scaffold/map tests) MUST be preserved. Do NOT revert any 7.9 file.
- Story 9-1 (tutorial state) remains in backlog. This story does NOT touch `tutorialCompletedProvider` and does NOT depend on tutorial state.

Before coding, verify with `git status --short` and inspect the current versions of `upgrades_screen.dart`, `upgrades_providers.dart`, `stats_screen.dart`, `stats_providers.dart`, `milestones_reducer.dart`, `game_state.dart`, `milestone_colors.dart`, and `leaders_screen.dart`.

## Story

As a player,
I want each continent to visually communicate how many of its countries I own and which milestone tiers I've crossed,
so that I can eyeball my progression toward the next milestone reward without counting countries.

## Acceptance Criteria

1. Given the Upgrades tab renders an unlocked-continent section, when the section header (`_ContinentHeader`) is built, then it shows "X / Y owned" inline (replacing the existing "$unlockedCount unlocked" label at line 167) where **X** = count of unlocked countries in that continent and **Y** = total countries in that continent (locked + unlocked, derived from `ContentRegistry.countries` filtered by `def.continent == section.continentId`). The badge uses the **same visual treatment** as the Leaders subtitle badge (`Container` with `Theme.of(context).colorScheme.surfaceContainerHighest`, `BorderRadius.circular(4)`, `Spacing.sm` horizontal × `2` vertical padding, `theme.textTheme.labelSmall` with `onSurfaceVariant`).

2. Given the Upgrades-tab continent section is rendered, when the header builds, then a horizontal **progress bar** appears directly beneath the title row (still inside `_ContinentHeader`) showing fill width = `ownedCount / totalCount`, with four **milestone tick marks** at the 25%, 50%, 75%, and 100% positions of the bar's total width. The bar height is `Spacing.sm` (8 logical pixels), border-radius `Spacing.xs` (4 px). The bar uses `MilestoneColors.track` for the unfilled track and a fill color based on the **highest reached tier** (see AC #5). Padding to the header's `Spacing.sm` left/right margins matches the existing header `Padding` (lines 148–153).

3. Given the Stats screen, when the user scrolls below the existing `_ProgressSection` "Continents completed" row, then a new "Continent progress" section appears (separated by `SizedBox(height: Spacing.lg)`) listing one row per UNLOCKED continent (sorted by `unlockThreshold` ascending, then `id.value` ascending — same ordering as the Upgrades tab and as `_buildLeadersTabModel`). Each row shows the continent name, "X / Y owned" text, and the same horizontal progress bar with milestone tick marks. The row container/spacing/typography mirrors the existing `_statRow` style (label + value + `48` min height + `Semantics` wrapper). LOCKED continents are NOT shown.

4. Given a continent has no unlocked countries (e.g., a continent whose threshold has been met but no countries unlocked yet — extremely unlikely with the seed but possible), then the section/row still renders with "0 / Y owned", an empty progress bar (zero fill, all four ticks unfilled), and the badge uses `MilestoneColors.track` for the fill region (i.e., empty fill is the same color as track — visually a single bar).

5. Given a continent's `state.reachedMilestones[continentId]` contains tier values, then the progress bar **fill** color reflects the **highest reached tier**:
   - No tiers reached → fill uses `MilestoneColors.track` (visually no fill, just track + grey ticks).
   - 25 reached, 50/75/100 not → fill uses `MilestoneColors.milestone25`.
   - 50 reached, 75/100 not → fill uses `MilestoneColors.milestone50`.
   - 75 reached, 100 not → fill uses `MilestoneColors.milestone75`.
   - 100 reached → fill uses `MilestoneColors.milestone100`.
   The width of the fill is **always** proportional to `ownedCount / totalCount` (not snapped to milestone positions). Only the color changes at tier boundaries.

6. Given the progress bar's milestone tick marks are rendered, when a tier is in `state.reachedMilestones[continentId]`, then that tick is **filled** using the same color tier as AC #5's fill (per-tick: tick at 25% uses `milestone25` once 25 is reached, etc.). Unfilled ticks use `MilestoneColors.tick`. Tick width is `2` logical pixels, height matches the bar height (`Spacing.sm`); each tick is centered horizontally at its tier percentage of the total bar width.

7. Given a milestone tier is "newly reached" during the current widget lifetime (i.e., its tick transitions from unfilled to filled while the widget is mounted), then the tick is decorated with a subtle **pulse** animation around `MilestoneColors.pulseAccent` (a `TweenAnimationBuilder<double>` or `AnimatedContainer` based color/opacity transition; duration **≈600ms**, runs **once**, then settles into the static filled state). The pulse MUST NOT use `AnimationController`, `Ticker`, or `SingleTickerProviderStateMixin` — only declarative `AnimatedContainer`, `AnimatedOpacity`, or `TweenAnimationBuilder` (Flutter manages these internally without a long-lived ticker). When the widget is first built and a tier is already reached (e.g., reopening the app after past unlocks), there is **no pulse** — only the new transition pulses. (See Task 4.5 for tracking-state implementation.)

8. Given a state change causes `ownedCount` to increase (a country unlocks) and the same change crosses a 25/50/75/100% threshold, then the progress bar fill widens animatedly (`AnimatedContainer` with `Spacing.md` × 1ms = ~150–250ms duration; explicit value: `Duration(milliseconds: 250)` with `Curves.easeOut`) AND the newly-crossed tick triggers AC #7's pulse. Crossing **multiple** tiers in one state change (e.g., a content-heavy continent where two milestones land at once) pulses **each** newly-crossed tier independently.

9. Given the Upgrades tab is scrolled or the user pans/zooms the Map tab, when `gameWorldProvider` ticks (per-second income), then the continent progress bar/header does NOT rebuild from a `Tick` event alone — only when one of the relevant slice fields (`unlockedContinents`, `continentCompletions`, `reachedMilestones`, or unlocked-count-per-continent) changes. Use `ref.watch(gameWorldProvider.select(...))` with a narrow slice and `MapEquality`/`SetEquality` for equality, identical to the existing `_UpgradesStateSlice` / `_StatsMultiplierSlice` patterns. **Per-tick rebuilds are a regression and will be caught by the existing HUD/runtime ticker guard test**.

10. Given continent ordering, when continents are displayed in both the Upgrades tab and Stats screen continent-progress section, then the order MUST match the existing Upgrades-tab ordering: `content.continents.values` sorted by `unlockThreshold` ascending, ties broken by `id.value` ascending. The Stats screen continent-progress list MUST reuse the same sort (do not introduce a second sort policy).

11. Given a continent reaches 100%, when the bar is rendered, then the entire fill width equals 100%, all four ticks are filled in `milestone100`, and the highest-tier color (`milestone100`) is applied to both the fill AND all ticks. No special "completed" badge is added in this story (Epic 8 owns celebratory polish); only the color tier flips.

12. Given the progress bar geometry, when the milestone-tick positions are computed, then the integer-floor math from `milestones_reducer.dart` is mirrored: tier `T`'s required owned count is `(T * totalCount) ~/ 100`. The tick's **visual** horizontal position is at `T%` of the bar width (i.e., 25%, 50%, 75%, 100% — geometric position is exact percentage), but the tick's **filled state** uses `reachedMilestones[continentId]?.contains(T) ?? false`. The fill width is `ownedCount / totalCount` (no clamping math required — `ownedCount <= totalCount` always holds in valid state).

13. Given a continent has only one country (degenerate but possible in test fixtures), when the bar is rendered, then `(25 * 1) ~/ 100 == 0` (so 25% is reached at 0 owned per the reducer, but the reducer also early-returns when `total == 0` and tier-25 is reached only after `owned >= 0` which is always true — see reducer lines 36–40). The UI **must not assert** on this edge case; just read `reachedMilestones` and render accordingly. With `totalCount == 0` (an empty continent — should not occur but defensive), the section is **suppressed entirely** (do not divide by zero; return early in the section builder).

14. Given content has not loaded (`contentRegistryProvider` is loading or errored), when Upgrades / Stats render, then the existing loading/error branches are preserved (Upgrades: `modelAsync.when(...)`, Stats: `if (summary == null) return CircularProgressIndicator()`). The new continent-progress UI is gated by the same `when` / null-guard — no new top-level error handling is introduced.

15. Given UI uses spacing, colors, typography, then it uses `Spacing.*`, `Theme.of(context).colorScheme`, `theme.textTheme`, and `Theme.of(context).extension<MilestoneColors>()!` only — no raw `Color(...)`, `Colors.*`, emoji icons, bitmap assets, or one-off typography. The existing `ui_design_tokens_test.dart` sweeps `lib/ui/` for raw color usage and must keep passing.

16. Given the progress bar widget is a reusable building block, then it lives in `lib/ui/features/continents/continent_progress_bar.dart` (new feature folder `continents/`) as a `StatelessWidget` (or `StatefulWidget` only if AC #7 pulse-tracking demands local state — see Task 4 for the structural decision). It takes `ownedCount: int`, `totalCount: int`, `reachedMilestoneTiers: Set<int>` parameters and reads `MilestoneColors` from `Theme.of(context).extension<MilestoneColors>()!`. The widget is consumed by **both** the Upgrades header AND the new Stats continent rows (DRY — no duplicate paint logic).

17. Given accessibility, when the progress bar is rendered, then it is wrapped in `Semantics(label: '${section.continentName} progress, $ownedCount of $totalCount owned, $highestReachedTier percent reached')` (set `highestReachedTier` to `0` when none reached). Tap targets in this story are **read-only**; the progress bar is not interactive. The "X / Y owned" text is included as semantic content via the parent header `Semantics` (Upgrades header) or the existing `_statRow` semantics (Stats row).

18. Given implementation is complete, then `flutter analyze`, the existing upgrades_screen_test.dart, stats_screen_test.dart, leaders_screen_test.dart, app_scaffold_test.dart, all architecture tests (`ui_design_tokens_test.dart`, `no_duplicate_income_math_test.dart`, `game_boundary_test.dart`, `data_boundary_test.dart`, `hud_runtime_ticker_guard_test.dart`), the new `continent_progress_bar_test.dart` widget tests, the new `continent_progress_providers_test.dart` provider tests, the extended `upgrades_providers_test.dart`, and extended `stats_providers_test.dart` all pass.

19. Given Story 7.10 is a UI/provider-only change, then `lib/game/**`, `lib/data/**`, `assets/**`, and `pubspec.yaml` are NOT modified. No new commands, events, reducers, balance constants, content fields, schema migrations, or persistence write changes belong to this story. **In particular, no changes to `milestones_reducer.dart` or `GameState.reachedMilestones`.**

20. Given the continent-progress DTO lives in providers, then the new `ContinentProgressRow` DTO (with fields `continentId, continentName, ownedCount, totalCount, reachedMilestoneTiers, highestReachedTier`) is defined in `lib/providers/continent_progress_providers.dart` (new file). The `continentProgressRowsProvider` (a `Provider<AsyncValue<List<ContinentProgressRow>>>` or `Provider<List<ContinentProgressRow>?>` — your choice; mirror existing pattern from `statsProgressSummaryProvider` which returns `Provider<StatsProgressSummary?>` gated by content registry valueOrNull) returns a sorted list of unlocked continents only. The Upgrades section DTO (`ContinentUpgradeSection`) is extended with the same three counts so the Upgrades header does NOT need to call into the new provider directly (cleaner: each tab reads its own narrow DTO, but both derive from the same pure helper). Pure helper `buildContinentProgressFor(continentId, slice, content)` returning `ContinentProgressRow` lives in this new providers file or a sibling pure-Dart file under `lib/ui/features/continents/` — see Task 2.

21. Given the pulse animation in AC #7/#8, when implemented, then it uses ONLY declarative Flutter animations (`AnimatedContainer`, `AnimatedOpacity`, `TweenAnimationBuilder<double>`) — never `AnimationController`, `Ticker`, `SingleTickerProviderStateMixin`. The "one `Ticker` in the app" rule (architecture line: `lib/game/features/economy/game_loop.dart` owns the sole `Ticker`) MUST NOT be violated. The test `hud_runtime_ticker_guard_test.dart` MUST keep passing.

## Tasks / Subtasks

- [ ] Task 1: Preflight current shell, theme, milestones, and architecture (AC: #1, #19, #21)
  - [ ] 1.1 Run `git status --short` and capture current worktree. Story 7.9 artifacts (`lib/providers/map_focus_providers.dart`, `lib/ui/features/map/auto_focus_target.dart`, modified `lib/ui/features/map/map_screen.dart`, modified `test/ui/app_scaffold_test.dart`) are in `review` — do not revert.
  - [ ] 1.2 Re-confirm `lib/ui/theme/milestone_colors.dart` exposes `track / tick / milestone25 / milestone50 / milestone75 / milestone100 / pulseAccent` and that `appTheme()` registers `MilestoneColors.defaults` in extensions (line 23 of `app_theme.dart`).
  - [ ] 1.3 Re-confirm `GameState.reachedMilestones: Map<ContinentId, Set<int>>` exists with `{25, 50, 75, 100}` tier semantics from `milestones_reducer.dart` lines 42–50.
  - [ ] 1.4 Re-confirm `lib/ui/features/upgrades/upgrades_screen.dart`'s `_ContinentHeader` (lines 138–176) takes `name` + `unlockedCount` and renders a single `Row`. Replace this with title row + progress bar in a `Column`.
  - [ ] 1.5 Re-confirm `lib/ui/features/stats/stats_screen.dart`'s `_ProgressSection` (lines 105–153) uses `statsProgressSummaryProvider` and `_statRow` helper. The new continent-progress section is appended to `_StatsBody`'s Column (line 43–54) **after** `_ProgressSection`.
  - [ ] 1.6 Re-confirm `lib/providers/leaders_providers.dart` line 149's `'${section.hiredCount} / ${section.totalCount} Leaders hired'` badge is the **visual** pattern to mirror (container background `surfaceContainerHighest`, radius 4, `labelSmall` text, `Spacing.sm × 2` padding).
  - [ ] 1.7 Re-confirm Epic 8 owns animated camera / celebratory animations. Our pulse MUST be a single-shot declarative animation, not a long-lived `Ticker`.

- [ ] Task 2: Add the pure continent-progress DTO + builder (AC: #1, #2, #5, #10, #12, #13, #20)
  - [ ] 2.1 Create `lib/providers/continent_progress_providers.dart`. Imports: `package:meta/meta.dart`, `package:collection/collection.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `game/content/content_registry.dart`, `game/game_state.dart`, `game/values/continent_id.dart`, `providers/app_providers.dart`, `providers/game_providers.dart`. Do NOT import `lib/data/**`, `lib/ui/**`, or `package:flutter/material.dart`.
  - [ ] 2.2 Define `@immutable class ContinentProgressRow` with fields:
    ```dart
    final ContinentId continentId;
    final String continentName;
    final int ownedCount;     // unlocked countries in this continent
    final int totalCount;     // all countries in this continent
    final Set<int> reachedMilestoneTiers;  // subset of {25, 50, 75, 100}
    final int highestReachedTier; // 0 / 25 / 50 / 75 / 100
    ```
    Include `==` and `hashCode` using `SetEquality<int>()` for `reachedMilestoneTiers`. Include `const` constructor.
  - [ ] 2.3 Define narrow state slice `_ContinentProgressSlice` (mirror `_UpgradesStateSlice` pattern lines 168–273) with fields:
    - `Map<CountryId, bool> unlockedByCountry` (immutable map of `countryId → cs.unlocked`).
    - `Map<ContinentId, bool> unlockedContinents`.
    - `Map<ContinentId, Set<int>> reachedMilestones` (deep-immutable; clone each Set to unmodifiable).
    Provide `_ContinentProgressSlice.fromState(GameState s)` static factory. Use `MapEquality` + nested `SetEquality<int>` for `reachedMilestones`.
  - [ ] 2.4 Define pure top-level function `List<ContinentProgressRow> buildContinentProgressRows(_ContinentProgressSlice slice, ContentRegistry content)`:
    - Sort continents by `unlockThreshold` ascending, ties broken by `id.value` ascending (same as `_buildUpgradesTabModel` lines 325–330 and `_buildLeadersTabModel` lines 212–217).
    - For each continent: if `slice.unlockedContinents[c.id] != true`, skip.
    - Compute `totalCount` = `content.countries.values.where((d) => d.continent == c.id).length`. **If `totalCount == 0`, skip entirely** (AC #13 degenerate guard).
    - Compute `ownedCount` = count of `def` in same iterator whose `slice.unlockedByCountry[def.id] == true`.
    - `reachedTiers` = `slice.reachedMilestones[c.id] ?? <int>{}`.
    - `highest` = the max element of `reachedTiers` intersected with `{25, 50, 75, 100}`, or `0` if empty.
    - Emit `ContinentProgressRow(...)`.
    - Return `List.unmodifiable(...)`.
  - [ ] 2.5 Define provider:
    ```dart
    final continentProgressRowsProvider = Provider<List<ContinentProgressRow>?>((ref) {
      final content = ref.watch(contentRegistryProvider).valueOrNull;
      if (content == null) return null;
      final slice = ref.watch(
        gameWorldProvider.select(_ContinentProgressSlice.fromState),
      );
      return buildContinentProgressRows(slice, content);
    });
    ```
    Use `null`-gated pattern matching `statsProgressSummaryProvider` (line 263) — Stats screen's existing `if (summary == null) return CircularProgressIndicator()` idiom carries over.
  - [ ] 2.6 Do NOT inline this provider into `stats_providers.dart` or `upgrades_providers.dart`. Keeping it in its own file makes the Upgrades-and-Stats consumer fan-out explicit.

- [ ] Task 3: Extend `ContinentUpgradeSection` DTO with progress fields (AC: #1, #2, #5, #9, #20)
  - [ ] 3.1 In `lib/providers/upgrades_providers.dart`, extend `_UpgradesStateSlice` (line 169) with one new field: `Map<ContinentId, Set<int>> reachedMilestones` (deep-immutable, using the same nested-Set-equality pattern as `GameState`'s `_reachedMilestonesEq`). Update `fromState`, `==`, `hashCode`, and `toGameState` accordingly. **Be careful**: `toGameState()` is consumed by `_buildUpgradesTabModel`, so the synthesized `GameState` needs `reachedMilestones` populated.
  - [ ] 3.2 Extend `ContinentUpgradeSection` (line 80) with three new fields:
    ```dart
    final int ownedCount;
    final int totalCount;
    final Set<int> reachedMilestoneTiers;
    ```
    `ownedCount == countries.length` is **true today** (the existing list only contains unlocked countries) — but compute it explicitly to keep the DTO self-documenting and to make it the SOLE place that filters for "unlocked." Include `const` constructor + ordered constructor args (continentId first, then name, then ownedCount, totalCount, reachedMilestoneTiers, then countries, then teaser).
  - [ ] 3.3 In `_buildUpgradesTabModel` (line 320), after building `rows`, compute:
    ```dart
    final totalCount = content.countries.values
        .where((d) => d.continent == continent.id).length;
    final ownedCount = rows.length;
    final reachedTiers = state.reachedMilestones[continent.id] ?? const <int>{};
    ```
    Pass these into the new `ContinentUpgradeSection` constructor.
  - [ ] 3.4 Update existing call sites: the Upgrades widget tests in `test/ui/features/upgrades/upgrades_screen_test.dart` and provider tests in `test/providers/upgrades_providers_test.dart` will need `reachedMilestoneTiers` argument added to any direct-construction of `ContinentUpgradeSection` — search for `ContinentUpgradeSection(` usages and update each.

- [ ] Task 4: Build the reusable `ContinentProgressBar` widget (AC: #2, #5, #6, #7, #8, #11, #12, #16, #17, #21)
  - [ ] 4.1 Create `lib/ui/features/continents/continent_progress_bar.dart`. Imports: `package:flutter/material.dart`, `lib/ui/theme/spacing.dart`, `lib/ui/theme/milestone_colors.dart`. Do NOT import `lib/game/**` or `lib/data/**`.
  - [ ] 4.2 Define `StatefulWidget ContinentProgressBar`. Fields:
    ```dart
    final int ownedCount;
    final int totalCount;
    final Set<int> reachedMilestoneTiers;
    final String? semanticLabel;  // optional; if null, sibling widget supplies semantics
    ```
    `StatefulWidget` is required because AC #7's "pulse only when newly reached" needs the widget to remember the previous `reachedMilestoneTiers` value across builds (`didUpdateWidget`).
  - [ ] 4.3 In `_ContinentProgressBarState`, track `Set<int> _previousTiers = const {};`. In `didUpdateWidget`, compute `final newlyReached = widget.reachedMilestoneTiers.difference(oldWidget.reachedMilestoneTiers);` and store it in `Set<int> _activelyPulsingTiers` for the next `build`. After the pulse duration completes, clear via `setState`. (Hint: use `TweenAnimationBuilder<double>` with `onEnd` to clear the entry for that tier — or store a single `_activelyPulsingTiers` and rely on `AnimatedContainer.onEnd` which fires once per transition.) **Initial build (initState)**: `_previousTiers = widget.reachedMilestoneTiers` (no pulse on first paint, AC #7 second sentence).
  - [ ] 4.4 Build layout:
    ```
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Existing title row stays in the parent (_ContinentHeader / Stats row).
        // This widget renders ONLY the bar.
        SizedBox(
          height: Spacing.sm, // 8px
          child: LayoutBuilder(builder: (context, c) {
            final barWidth = c.maxWidth;
            return Stack(children: [
              // 1) Track background
              Container(
                decoration: BoxDecoration(
                  color: milestones.track,
                  borderRadius: BorderRadius.circular(Spacing.xs),
                ),
              ),
              // 2) Animated fill (AC #8)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: widget.totalCount == 0
                    ? 0
                    : barWidth * (widget.ownedCount / widget.totalCount),
                decoration: BoxDecoration(
                  color: _fillColorFor(highestReached, milestones),
                  borderRadius: BorderRadius.circular(Spacing.xs),
                ),
              ),
              // 3) Tick marks at 25 / 50 / 75 / 100 (AC #6)
              for (final tier in const [25, 50, 75, 100])
                Positioned(
                  left: (barWidth * tier / 100) - 1, // 2-px tick centered
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: _Tick(tier: tier,
                               filled: widget.reachedMilestoneTiers.contains(tier),
                               pulsing: _activelyPulsingTiers.contains(tier),
                               milestones: milestones),
                ),
            ]);
          }),
        ),
      ],
    );
    ```
    where `milestones = Theme.of(context).extension<MilestoneColors>()!` and `highestReached` = the max of `widget.reachedMilestoneTiers ∪ {0}`.
  - [ ] 4.5 Private `_Tick` widget (StatelessWidget):
    - If `pulsing == true` and `filled == true` → render `TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: Duration(milliseconds: 600), builder: (ctx, t, child) { return Container(decoration: BoxDecoration(color: Color.lerp(milestones.pulseAccent, milestones.colorForTier(tier), t)); })`. **WAIT** — that would violate AC #15 (no raw `Color.lerp` blends a token with another token, which is allowed because both are theme tokens; `Color.lerp` is a Flutter function, not a raw `Color(...)` literal — confirmed safe per the test allowlist which only checks `Color(` constructor calls and `Colors.` swatches). Use `Color.lerp(start, end, t) ?? end`.
    - If `pulsing == false` and `filled == true` → render solid `Container(color: milestones.colorForTier(tier))`.
    - If `filled == false` → render `Container(color: milestones.tick)`.
    - Add `onEnd: () => widget._onPulseFinished(tier)` callback so the parent `_ContinentProgressBarState` can `setState` to remove the tier from `_activelyPulsingTiers` after 600ms.
  - [ ] 4.6 Add helper extension or static helper `Color _milestoneColorForTier(int tier, MilestoneColors m)`:
    ```dart
    Color _milestoneColorForTier(int tier, MilestoneColors m) {
      switch (tier) {
        case 25: return m.milestone25;
        case 50: return m.milestone50;
        case 75: return m.milestone75;
        case 100: return m.milestone100;
        default: return m.track;
      }
    }
    ```
  - [ ] 4.7 Add `Color _fillColorFor(int highestReached, MilestoneColors m)` using the same switch but defaulting to `m.track` when `highestReached == 0`.
  - [ ] 4.8 If `widget.semanticLabel != null`, wrap the whole `Stack` in `Semantics(container: true, label: widget.semanticLabel, child: ...)` — see AC #17. Otherwise leave semantics to the parent.
  - [ ] 4.9 Add a one-line `///` summary on the public class. No multi-paragraph docstrings.

- [ ] Task 5: Wire the bar into the Upgrades tab header (AC: #1, #2, #9, #14, #15, #17)
  - [ ] 5.1 In `lib/ui/features/upgrades/upgrades_screen.dart`, modify `_ContinentHeader` (lines 138–176) constructor to take `ContinentUpgradeSection section` (the full DTO) instead of `name` + `unlockedCount` — this gives access to `ownedCount`, `totalCount`, `reachedMilestoneTiers` without parameter explosion.
  - [ ] 5.2 Update call site in `_UpgradesBodyState.build` (line 96–100): change `_ContinentHeader(name: item.section.continentName, unlockedCount: item.section.countries.length)` to `_ContinentHeader(section: item.section)`.
  - [ ] 5.3 Rewrite `_ContinentHeader.build` (lines 145–175) to:
    ```dart
    Padding(
      padding: const EdgeInsets.only(
        left: Spacing.sm, right: Spacing.sm,
        top: Spacing.lg, bottom: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.public, size: 18, color: theme.colorScheme.primary),
            SizedBox(width: Spacing.xs),
            Text(section.continentName, style: titleStyle),
            Spacer(),
            _OwnedBadge(ownedCount: section.ownedCount, totalCount: section.totalCount),
          ]),
          SizedBox(height: Spacing.xs),
          ContinentProgressBar(
            ownedCount: section.ownedCount,
            totalCount: section.totalCount,
            reachedMilestoneTiers: section.reachedMilestoneTiers,
            semanticLabel: '${section.continentName} progress, ${section.ownedCount} of ${section.totalCount} owned, ${_highestTierOf(section.reachedMilestoneTiers)} percent reached',
          ),
        ],
      ),
    )
    ```
  - [ ] 5.4 Add private `_OwnedBadge` widget mirroring `_HeaderSubtitle` from `leaders_screen.dart` (lines 128–157): `Container` with `scheme.surfaceContainerHighest` background, `BorderRadius.circular(4)`, `Spacing.sm × 2` padding, `theme.textTheme.labelSmall.copyWith(color: scheme.onSurfaceVariant)` text `'${ownedCount} / ${totalCount} owned'`. **Do not** factor this out to a shared widget file — the Leaders subtitle and our owned-badge are visually-similar but contextually-distinct; copy the ~12-line pattern.
  - [ ] 5.5 Helper `int _highestTierOf(Set<int> tiers)` is a top-level private function in `upgrades_screen.dart` (or imported from the new providers file): `return tiers.isEmpty ? 0 : tiers.reduce(math.max);`.

- [ ] Task 6: Wire the bar into the Stats screen (AC: #3, #10, #15, #17)
  - [ ] 6.1 In `lib/ui/features/stats/stats_screen.dart`, add a new private `_ContinentProgressSection extends ConsumerWidget` placed in `_StatsBody`'s Column **after** `_ProgressSection` and **before** `_MultiplierSection`. Add `SizedBox(height: Spacing.lg)` separators around it (matching existing spacing between sections at line 49–52).
  - [ ] 6.2 Inside `_ContinentProgressSection.build`:
    ```dart
    final rows = ref.watch(continentProgressRowsProvider);
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    // Padding + 'Continent progress' header (mirror _ProgressSection's titleMedium pattern).
    // ListView is overkill; render as a Column inside the existing SingleChildScrollView.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Continent progress', style: titleStyle),
          SizedBox(height: Spacing.sm),
          for (final row in rows) _ContinentProgressRow(row: row),
        ],
      ),
    );
    ```
  - [ ] 6.3 Add `_ContinentProgressRow` private StatelessWidget that lays out:
    - Column: top row = name (`bodyLarge`) on the left + "X / Y owned" `_OwnedBadge` on the right (reuse the visual pattern from Task 5.4 — copy it again here to keep both screens self-contained; do NOT factor into a shared widget file unless a third caller arrives later).
    - SizedBox(`Spacing.xs`).
    - `ContinentProgressBar(...)` with semantic label.
    - SizedBox(`Spacing.sm`).
    Wrap the whole row in `Semantics(container: true, label: '${row.continentName} progress, ${row.ownedCount} of ${row.totalCount} owned, ${row.highestReachedTier} percent reached', child: ...)` — matches `_statRow`'s semantic pattern (line 296).
  - [ ] 6.4 The `_StatsBody` Column tree changes from `[CurrencyHeader, SizedBox(md), _ProgressSection, SizedBox(lg), _MultiplierSection, SizedBox(lg), _TemporaryEffectsSection]` to insert `_ContinentProgressSection` between `_ProgressSection` and `_MultiplierSection`, with `SizedBox(Spacing.lg)` separators. Final tree: `[CurrencyHeader, SizedBox(md), _ProgressSection, SizedBox(lg), _ContinentProgressSection, SizedBox(lg), _MultiplierSection, SizedBox(lg), _TemporaryEffectsSection]`.

- [ ] Task 7: Preserve architecture boundaries and state ownership (AC: #15, #19, #21)
  - [ ] 7.1 UI dispatches commands only through `gameWorldProvider.notifier.apply(...)` (this story does not dispatch any new commands).
  - [ ] 7.2 No `lib/game/**` changes. Do not touch `milestones_reducer.dart`, `game_state.dart`, `continent_def.dart`, or `content_registry.dart`. Do not add balance constants. Tier values stay encoded in `milestones_reducer.dart` line 42 — the UI hardcodes `const [25, 50, 75, 100]` mirror because making this a shared `BalanceConfig` constant adds churn and crosses the `lib/game/` → UI boundary (the architecture says `BalanceConfig` is for sim, not UI tokens).
  - [ ] 7.3 No `lib/data/**` changes, schema migrations, generated Drift files, save repository edits, or persistence write changes. `reachedMilestones` is already persisted via Story 6.1's `GameStateMapper`; UI consumes it read-only.
  - [ ] 7.4 No package additions (no `animations`, `lottie`, `rive`, etc.). Use Flutter built-ins only.
  - [ ] 7.5 No new `Ticker` or `AnimationController`. Pulse is `TweenAnimationBuilder` (declarative; Flutter internally batches with the existing vsync — no app-owned ticker).
  - [ ] 7.6 No SFX, no haptics, no flying numbers, no celebrations (Epic 8 owns those).
  - [ ] 7.7 `lib/providers/continent_progress_providers.dart` MUST NOT import anything under `lib/data/**` or `lib/ui/**`. Verify with the data-boundary architecture test.
  - [ ] 7.8 `lib/ui/features/continents/continent_progress_bar.dart` MAY import `lib/ui/theme/` and `package:flutter/material.dart`. It MUST NOT import `lib/data/**`, `lib/game/**`, `lib/providers/**`, or `flutter_riverpod`. It is a pure presentation widget driven entirely by constructor arguments.

- [ ] Task 8: Provider tests (AC: #9, #10, #12, #13, #20)
  - [ ] 8.1 Add `test/providers/continent_progress_providers_test.dart`. Mirror the `_twoContinent` fixture pattern from `test/providers/upgrades_providers_test.dart` (lines 30–85). Use the same Africa (`unlockThreshold: '0'`) + Europe (`unlockThreshold: '1000'`) setup. Add milestone rewards to Africa for tier-by-tier reachability testing:
    ```dart
    'milestoneRewards': [
      {'percent': 25, 'rewardType': 'influence', 'rewardValue': '0'},
      {'percent': 50, 'rewardType': 'influence', 'rewardValue': '0'},
      {'percent': 75, 'rewardType': 'influence', 'rewardValue': '0'},
      {'percent': 100, 'rewardType': 'influence', 'rewardValue': '0'},
    ],
    ```
  - [ ] 8.2 Cover these cases:
    1. `null` when content is loading (`contentRegistryProvider` overridden to never resolve / AsyncValue.loading).
    2. Empty list when no continents unlocked.
    3. Single-continent rendering: Africa unlocked with 3 countries total, 1 unlocked (Egypt), `reachedMilestones[africa] = {}` → `ContinentProgressRow(ownedCount: 1, totalCount: 3, reachedMilestoneTiers: {}, highestReachedTier: 0)`.
    4. Tier-25 reached: with `reachedMilestones[africa] = {25}` → row has `highestReachedTier: 25` and `reachedMilestoneTiers: {25}`.
    5. Multi-tier reached: with `reachedMilestones[africa] = {25, 50, 75}` → `highestReachedTier: 75`.
    6. 100% reached: `reachedMilestoneTiers: {25, 50, 75, 100}` → `highestReachedTier: 100`.
    7. Locked continent: Europe `unlockedContinents[europe] = false` → omitted from list.
    8. Ordering: `unlockThreshold` ascending → Africa before Europe; with two same-threshold continents test `id.value` tiebreak.
    9. Degenerate empty continent (zero countries) → skipped entirely (AC #13).
    10. Equality / `MapEquality` short-circuit: two consecutive `ref.read`s with the same underlying state return the SAME `ContinentProgressRow` list (not a rebuilt list); verify by `identical()` semantics or by listening with `ProviderContainer.listen` and asserting only one emission.
  - [ ] 8.3 Extend `test/providers/upgrades_providers_test.dart` with at minimum two new tests:
    1. `ContinentUpgradeSection` exposes `ownedCount`, `totalCount`, `reachedMilestoneTiers` matching the GameState.
    2. Per-tick state churn (e.g., changing `totalInfluence` only) does NOT cause `upgradesTabModelProvider` to rebuild a new `UpgradesTabModel` instance — assert via slice equality semantics. (Mirror the existing reactivity assertions; should already be covered.)

- [ ] Task 9: Widget tests (AC: #2, #5, #6, #7, #8, #11, #15, #16, #17)
  - [ ] 9.1 Add `test/ui/features/continents/continent_progress_bar_test.dart` covering the widget in isolation:
    1. Renders track-only when `ownedCount == 0`, `totalCount == 10`, `reachedMilestoneTiers == {}`.
    2. Renders fill at ~25% with `ownedCount: 3, totalCount: 10, reachedMilestoneTiers: {25}` — assert fill width using `tester.getSize(find.byKey(const Key('continent_progress_bar.fill')))` (add stable `Key`s for testability inside the widget).
    3. All four ticks rendered (find them by key `continent_progress_bar.tick.25/.50/.75/.100`).
    4. Filled tick color follows highest reached tier: with `{25}` → tick-25 has color matching `MilestoneColors.defaults.milestone25`; tick-50/75/100 have color `MilestoneColors.defaults.tick`.
    5. Initial build with `reachedMilestoneTiers: {25, 50}` does NOT trigger a pulse on either tick (no `TweenAnimationBuilder` activated for already-reached tiers on first paint).
    6. `didUpdateWidget` from `{}` to `{25}` triggers a pulse on tick-25 only — verify via finding the `TweenAnimationBuilder` widget keyed to tick-25 and checking it animates (use `tester.pump(Duration(milliseconds: 300))` to mid-animation, assert tween value > 0 and < 1; then `pump(Duration(milliseconds: 400))` to settle).
    7. `didUpdateWidget` from `{25}` to `{25, 50, 75}` triggers pulses on tick-50 AND tick-75 (multi-tier crossing, AC #8 last sentence) — both `TweenAnimationBuilder`s exist post-update.
    8. `totalCount == 0` guard: widget builds without throw, fill width is 0.
    9. Semantic label is rendered when passed.
  - [ ] 9.2 Extend `test/ui/features/upgrades/upgrades_screen_test.dart` with:
    1. Upgrades header shows "1 / 3 owned" badge for Africa (Egypt unlocked, Nigeria + South Africa locked).
    2. `ContinentProgressBar` is mounted under the header for Africa (`find.byType(ContinentProgressBar)`).
    3. The bar's `reachedMilestoneTiers` reflects `GameState.reachedMilestones[africa]`.
  - [ ] 9.3 Extend `test/ui/features/stats/stats_screen_test.dart` with:
    1. `_ContinentProgressSection` renders the "Continent progress" header when at least one continent is unlocked.
    2. `_ContinentProgressSection` is **hidden** (returns `SizedBox.shrink`) when no continents are unlocked (e.g., a contrived state with `unlockedContinents == {}`).
    3. Each unlocked continent in the test state appears as a row with name + badge + bar.
    4. The Multiplier section + Temporary effects section still render below the new continent-progress section (regression: do not push them off-screen or break section ordering).
  - [ ] 9.4 Do NOT add a new test-only widget to surface internal state; rely on `Key`s placed on the `ContinentProgressBar`'s sub-elements.

- [ ] Task 10: Architecture and regression guardrails (AC: #15, #18, #19, #21)
  - [ ] 10.1 Run `test/architecture/ui_design_tokens_test.dart`; the new `continent_progress_bar.dart` must not introduce raw `Color(...)` constructors or `Colors.*` swatches. `Color.lerp(tokenA, tokenB, t)` is **allowed** (the regex `\bColor\s*\(` matches `Color(0xFF...)` constructor calls; `Color.lerp` is a static method and does not match — verify against the regex pattern at line 17 of `ui_design_tokens_test.dart`).
  - [ ] 10.2 Run `test/architecture/no_duplicate_income_math_test.dart`; this story does not introduce `def.baseInfluence *` math or any income computation.
  - [ ] 10.3 Run `test/architecture/game_boundary_test.dart`; no Flutter imports under `lib/game/**`. This story does not touch `lib/game/**`; confirm.
  - [ ] 10.4 Run `test/architecture/data_boundary_test.dart`; the new provider and UI files must not import `lib/data/**`.
  - [ ] 10.5 Run `test/architecture/hud_runtime_ticker_guard_test.dart`; this story uses only `TweenAnimationBuilder` and `AnimatedContainer` — no `AnimationController` / `Ticker` / `SingleTickerProviderStateMixin`. Verify by grepping the new files for `AnimationController` / `with .*TickerProviderStateMixin` (should be zero hits).
  - [ ] 10.6 Ensure `pubspec.yaml` is unchanged.

- [ ] Task 11: Verification (AC: all)
  - [ ] 11.1 Run `dart format --set-exit-if-changed` on changed Dart/test files.
  - [ ] 11.2 Run `flutter test test/providers/continent_progress_providers_test.dart`.
  - [ ] 11.3 Run `flutter test test/providers/upgrades_providers_test.dart`.
  - [ ] 11.4 Run `flutter test test/ui/features/continents/continent_progress_bar_test.dart`.
  - [ ] 11.5 Run `flutter test test/ui/features/upgrades/upgrades_screen_test.dart`.
  - [ ] 11.6 Run `flutter test test/ui/features/stats/stats_screen_test.dart`.
  - [ ] 11.7 Run `flutter test test/ui/app_scaffold_test.dart`.
  - [ ] 11.8 Run `flutter test test/architecture`.
  - [ ] 11.9 Run `flutter analyze`.
  - [ ] 11.10 Run full `flutter test`. Expect zero regressions over the Story 7.9 baseline (~1014 tests). Stories 7.9 and 7.10 should both be in the worktree.

## Dev Notes

### Implementation Scope

This story adds two visual surfaces:

1. **Upgrades-tab continent header** — replaces the existing "X unlocked" label with a "X / Y owned" badge and adds a horizontal progress bar with 25/50/75/100% milestone ticks beneath the title.
2. **Stats-screen continent-progress section** — a new section between "Progress" and "Active multipliers" listing one row per unlocked continent with the same badge + bar treatment.

A single reusable widget (`ContinentProgressBar`) renders the bar in both surfaces. State flows: `GameState.reachedMilestones` + per-country `unlocked` → `_ContinentProgressSlice` → `ContinentProgressRow` DTO → widget.

It does NOT implement: continent-completion celebration polish, milestone glow polish beyond the one-shot pulse, world-map progress overlays, continent unlock animations, performance profiling, or any persistence/migration work. Those belong to Epic 8 / Epic 11.

### Current Codebase Observations

- `lib/ui/features/upgrades/upgrades_screen.dart` `_ContinentHeader` (lines 138–176) currently shows `"$unlockedCount unlocked"` on the right side. Replace with the new badge.
- `lib/providers/upgrades_providers.dart` `ContinentUpgradeSection` (lines 79–92) currently has `countries: List<CountryUpgradeRow>` (unlocked only). Extend with `ownedCount`, `totalCount`, `reachedMilestoneTiers`.
- `lib/providers/leaders_providers.dart` line 149 `'${section.hiredCount} / ${section.totalCount} Leaders hired'` — **this is the badge style to mirror**. Note: Leaders' `totalCount = rows.length` (unlocked only) — that is INTENTIONAL for Leaders ("Y leaders can be hired") but **wrong** for our use case where Y must be ALL countries (unlocked + locked). Do not reuse `LeadersTabModel.totalCount`.
- `lib/ui/features/stats/stats_screen.dart` `_ProgressSection` (lines 105–153) uses `_statRow` helper. The new continent-progress section follows this stylistic pattern (titled section, `bodyLarge` label, padding, `Semantics`) but renders a **bar** not just a text row — so it does not use `_statRow` directly.
- `lib/providers/stats_providers.dart` `statsProgressSummaryProvider` (line 263) — already gates on `content.valueOrNull == null`. Mirror this pattern in the new provider.
- `lib/ui/theme/milestone_colors.dart` has the exact colors needed (`track / tick / milestone25 / milestone50 / milestone75 / milestone100 / pulseAccent`) and is already registered in `appTheme()` line 23 — **no theme registration work required**.
- `lib/game/features/continents/milestones_reducer.dart` line 42 hardcodes the tier list `[25, 50, 75, 100]`. The UI mirrors this constant **inline** in `continent_progress_bar.dart` — making it a shared `BalanceConfig` constant would cross the UI / sim boundary unnecessarily, and tier values are unlikely to change.
- `GameState.reachedMilestones: Map<ContinentId, Set<int>>` — already deep-immutable (line 76–80). Safe to read in the slice's deep-immutable clone.
- `IndexedStack` keeps Upgrades and Stats widget trees alive across tab switches, so `_ContinentProgressBarState._previousTiers` survives across tab switches — pulses fire only on actual state transitions.
- Tutorial state (`tutorialCompletedProvider` from Story 7.9) is **not** relevant — the progress bar always renders when the Upgrades tab / Stats screen are visible. No tutorial gating.

### Previous Story Intelligence

- Story 7.1 established `Spacing.*`, `Theme.of(context).colorScheme`, `MilestoneColors` extension, and raw-color guardrails. All MilestoneColors fields are pre-built and registered — this story is the FIRST consumer.
- Story 7.2 established `AppScaffold` + `IndexedStack`. `IndexedStack` keeps Upgrades widget alive so per-tab state (like `_ContinentProgressBarState._previousTiers`) persists across tab switches.
- Story 7.5 established `_statRow` helper pattern and `_ProgressSection` row layout. Mirror that pattern in `_ContinentProgressSection`.
- Story 7.7 established Upgrades-tab `ContinentUpgradeSection` DTO + Tab DTO + Provider pattern. Extend the existing DTO; do not create a parallel one.
- Story 7.8 established Leaders' `_HeaderSubtitle` "X / Y Leaders hired" badge — visual treatment we mirror.
- Story 7.9 added `lib/providers/map_focus_providers.dart` and `lib/ui/features/map/auto_focus_target.dart`. Do not revert; do not touch `_MapView` or `MapScreen`.
- Story 6.1 made `GameState.reachedMilestones` persistable via `GameStateMapper`. UI just reads.
- Story 4.3 introduced `evaluateMilestones` and the `MilestoneReached` / `ContinentCompleted` events. UI does NOT subscribe to these events directly — `reachedMilestones` state is the canonical read source.
- Story 4.4 added `state.continentCompletions[id] = true` at 100%. UI MAY read this as a redundant "is 100% reached" check, but the simpler/canonical path is `reachedMilestones[id].contains(100)`.
- Story 7.6 settings modal is unrelated; do not touch.

### Architecture Compliance

- UI reads Riverpod providers and dispatches commands. UI never mutates `GameState` directly. This story dispatches no commands.
- Providers are the composition root. `continentProgressRowsProvider` belongs in `lib/providers/`, not inside widgets.
- `lib/game/**` remains pure Dart. No Flutter imports, no widget helpers, no service calls. No new sim fields.
- `lib/data/**` remains untouched. `reachedMilestones` persistence is already done via Story 6.1.
- Multiplier stack untouched. No income math.
- One `Ticker` rule preserved (Epic 8 owns animated camera; this story uses only declarative animations).
- Sealed `switch` exhaustiveness preserved: we add no new commands, events, or reducers.
- Accessibility: every progress bar carries a semantic label; the Stats row uses the `_statRow`-style `Semantics(container: true, label: ...)` wrapper.

### Library / Framework Requirements

- Use the pinned project dependencies from `pubspec.yaml`: Flutter/Dart SDK, `flutter_riverpod: ^2.6.1`, `decimal: ^3.0.2`, `collection: ^1.19.1`. Do not bump packages.
- Use manual Riverpod providers; the project does not use `riverpod_generator`.
- Flutter `TweenAnimationBuilder<double>` provides single-shot declarative animation without a `Ticker` (Flutter manages the vsync internally per-animation, not via the long-lived app `Ticker`). Source: https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html
- Flutter `AnimatedContainer` animates layout/decoration changes declaratively. Use for the fill-width animation. Source: https://api.flutter.dev/flutter/widgets/AnimatedContainer-class.html
- `Color.lerp(a, b, t)` is a static method, not the `Color(...)` constructor — the existing `ui_design_tokens_test.dart` regex (`\bColor\s*\(` at line 17) does not match `Color.lerp(`. Verified safe.
- Use `Theme.of(context).extension<MilestoneColors>()!` for theme tokens. The `!` non-null assertion is safe because `appTheme()` registers `MilestoneColors.defaults` unconditionally.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/providers/continent_progress_providers.dart` | `ContinentProgressRow` DTO + `continentProgressRowsProvider` + pure `buildContinentProgressRows` helper |
| `lib/ui/features/continents/continent_progress_bar.dart` | Reusable `ContinentProgressBar` widget |
| `test/providers/continent_progress_providers_test.dart` | Provider tests (10 cases) |
| `test/ui/features/continents/continent_progress_bar_test.dart` | Widget tests for the bar in isolation |

Modify:

| File | Purpose |
| --- | --- |
| `lib/providers/upgrades_providers.dart` | Extend `_UpgradesStateSlice` with `reachedMilestones`; extend `ContinentUpgradeSection` with `ownedCount/totalCount/reachedMilestoneTiers`; update `_buildUpgradesTabModel` |
| `lib/ui/features/upgrades/upgrades_screen.dart` | Rewrite `_ContinentHeader`; add private `_OwnedBadge`; add `_highestTierOf` helper |
| `lib/ui/features/stats/stats_screen.dart` | Add `_ContinentProgressSection` between `_ProgressSection` and `_MultiplierSection` |
| `test/providers/upgrades_providers_test.dart` | Add tests for new DTO fields; update existing `ContinentUpgradeSection(...)` calls |
| `test/ui/features/upgrades/upgrades_screen_test.dart` | Add tests for badge + bar in header |
| `test/ui/features/stats/stats_screen_test.dart` | Add tests for new continent-progress section |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/**` | No new state, commands, events, or balance constants (milestones tier list stays in `milestones_reducer.dart`) |
| `lib/data/**` | No persistence/schema work; `reachedMilestones` already persisted via Story 6.1 |
| `lib/providers/map_focus_providers.dart`, `auto_focus_target.dart`, `map_screen.dart` (Story 7.9) | In `review`; preserve verbatim |
| `lib/providers/leaders_providers.dart`, `lib/ui/features/leaders/**` | Out of scope; do NOT change Leaders' `totalCount = rows.length` semantics |
| `lib/providers/stats_providers.dart` `statsProgressSummaryProvider`/`StatsProgressSummary` | Keep as-is; new continent provider is a sibling, not an extension |
| `lib/ui/theme/milestone_colors.dart`, `app_theme.dart` | All tokens already exist and are registered |
| `assets/**` | No content edits |
| `pubspec.yaml` | No new dependency |

### Testing Requirements

Provider tests should use `ProviderContainer` with overrides; do not boot real Drift.

Recommended provider-test shape (mirror `test/providers/upgrades_providers_test.dart`):

```dart
final container = ProviderContainer(
  overrides: [
    contentRegistryProvider.overrideWith((_) async => content),
    gameWorldProvider.overrideWith((ref) => _SpyNotifier(
      content: content,
      initialState: GameStateBuilder(content: content)
        .withCountryUnlocked('egypt')
        .withContinentUnlocked('africa')
        .withReachedMilestones({const ContinentId('africa'): {25}})
        .build(),
    )),
  ],
);
addTearDown(container.dispose);

final rows = container.read(continentProgressRowsProvider);
expect(rows, isNotNull);
expect(rows!.length, 1);
expect(rows.first.continentId, const ContinentId('africa'));
expect(rows.first.ownedCount, 1);
expect(rows.first.totalCount, 3);
expect(rows.first.reachedMilestoneTiers, {25});
expect(rows.first.highestReachedTier, 25);
```

Widget-test shape for the bar in isolation:

```dart
await tester.pumpWidget(
  MaterialApp(
    theme: appTheme(),
    home: const Scaffold(
      body: ContinentProgressBar(
        ownedCount: 3,
        totalCount: 10,
        reachedMilestoneTiers: {25},
      ),
    ),
  ),
);
await tester.pumpAndSettle();
// Assert tick keys, fill width, and color.
```

Use the existing `GameStateBuilder` helper in `test/helpers/game_state_builder.dart` to construct test states with specific `reachedMilestones` — if a `withReachedMilestones` method does not exist yet, add it to the helper following the existing `withCountryUnlocked` pattern. **Hint**: check `test/helpers/game_state_builder.dart` for the canonical builder methods and extend it; do NOT hand-construct `GameState` in test files.

### Out of Scope

- Continent-completion celebration modal (Epic 7's modal queue + Epic 8's polish).
- World-map progress overlays (continent fills, country glow on milestone) — Epic 8 polish.
- Animated camera moves / continent-fit zoom on milestone (Epic 8).
- Per-tick income-rate visual indicators within the progress bar.
- Hover/tap interactions on the progress bar (read-only display in this story).
- Sound effects / haptics on milestone crossings (Epic 8).
- Per-country progress within a continent (the bar shows continent ownership only).
- Tutorial-driven highlight of the bar (Stories 9-1 through 9-4).
- New `GameCommand`, `GameEvent`, reducer, balance constant, or content field.
- Persistence write changes, Drift migrations, save repository edits.
- New packages or dependency bumps.
- Map tab progress visuals (Map tab does not get a progress bar; it gets continent fill coloring in Epic 8).

### Latest Technical Information

- Flutter `TweenAnimationBuilder<T>` schedules a single-shot animation between `tween.begin` and `tween.end` for the given `duration`, calling `builder(context, value, child)` on each frame. The widget exposes `onEnd: VoidCallback?` that fires once when the animation completes. No external `AnimationController` or `Ticker` is needed — Flutter manages the vsync per-build. Source: https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html
- Flutter `AnimatedContainer` animates implicit changes to `decoration`, `width`, `height`, `padding`, `transform`, etc. over `duration` with `curve`. No `AnimationController` required. Source: https://api.flutter.dev/flutter/widgets/AnimatedContainer-class.html
- Flutter `Color.lerp(Color? a, Color? b, double t)` returns a linearly interpolated color. Safe to use with theme tokens; does not match the `Color(...)` constructor regex used in `ui_design_tokens_test.dart`. Source: https://api.flutter.dev/flutter/dart-ui/Color/lerp.html
- Riverpod `Provider<T?>` returning `null` when content is loading is a deliberate pattern matched by `statsProgressSummaryProvider` (line 263 of `stats_providers.dart`). The Stats screen's `if (summary == null) return CircularProgressIndicator();` pattern (line 32 of `stats_screen.dart`) is reused for the continent-progress section.
- Riverpod `select` with `_ContinentProgressSlice.fromState` ensures rebuilds happen only on field changes, not per-tick. Identical to `_UpgradesStateSlice` / `_StatsMultiplierSlice` patterns. Source: https://riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds

### Git Intelligence Summary

Recent commits frame the current shell:

- `a6bbe42 feat(ui): priority modal queue, stats screen, and settings overlay` — Stories 7.4/7.5/7.6 wiring; Stats screen `_StatsBody` Column is the insertion target. Do not touch existing sections.
- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` — `CurrencyBadge` lineage; reused unchanged.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` — `IndexedStack` keeps tab state alive so per-bar pulse-tracking persists.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` — `MilestoneColors` extension registered here.

Uncommitted in the working tree at story-creation time (Stories 7.7 and 7.8 are `done`; 7.9 is `review`):

- `M lib/ui/features/leaders/leaders_screen.dart`, `M lib/ui/features/upgrades/upgrades_screen.dart`, `M lib/ui/features/map/map_screen.dart`, `M test/ui/app_scaffold_test.dart`, plus 7-9/7-10 story-implementation-artifact files and provider/test files from 7.7/7.8/7.9 — preserve all. Do not "clean up" 7.9's `lib/providers/map_focus_providers.dart`, `lib/ui/features/map/auto_focus_target.dart`, or their tests.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` — Story 7.10]
- [Source: `_bmad-output/planning-artifacts/gdd.md` — Progression visibility]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` — Riverpod, theme tokens, one Ticker rule]
- [Source: `_bmad-output/game-architecture/project-structure.md` — `lib/ui/features/`, `lib/providers/`, architectural boundaries]
- [Source: `_bmad-output/project-context.md` — architecture boundaries, token rules, forbidden packages, accessibility]
- [Source: `_bmad-output/implementation-artifacts/7-7-upgrades-tab-unlocked-countries-next-unlock-teaser-per-continent.md` — Tab DTO + Provider pattern, `ContinentUpgradeSection`]
- [Source: `_bmad-output/implementation-artifacts/7-8-leaders-tab-grouped-by-continent-accordion.md` — `_HeaderSubtitle` badge visual pattern]
- [Source: `_bmad-output/implementation-artifacts/7-5-stats-screen-reachable-from-hud.md` — `_statRow` pattern + `_ProgressSection` structure]
- [Source: `_bmad-output/implementation-artifacts/7-9-map-as-default-cold-launch-screen-auto-focus-post-tutorial.md` — Preserved worktree, no overlap]
- [Source: `_bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md` — milestones_reducer canonical owner]
- [Source: `lib/ui/features/upgrades/upgrades_screen.dart` — `_ContinentHeader` to rewrite]
- [Source: `lib/providers/upgrades_providers.dart` — `_UpgradesStateSlice` + `ContinentUpgradeSection` to extend]
- [Source: `lib/ui/features/stats/stats_screen.dart` — `_StatsBody` Column for insertion]
- [Source: `lib/providers/stats_providers.dart` — `statsProgressSummaryProvider` nullable pattern]
- [Source: `lib/providers/leaders_providers.dart` — `_HeaderSubtitle` badge style; `_LeadersStateSlice` shape]
- [Source: `lib/ui/features/leaders/leaders_screen.dart` — line 149 badge visual to mirror]
- [Source: `lib/ui/theme/milestone_colors.dart` — all tier + track + tick + pulseAccent colors]
- [Source: `lib/ui/theme/app_theme.dart` — `MilestoneColors.defaults` registration]
- [Source: `lib/ui/theme/spacing.dart` — `Spacing.{xs,sm,md,lg,xl,xxl}` tokens]
- [Source: `lib/game/features/continents/milestones_reducer.dart` — `[25, 50, 75, 100]` tier list + integer-floor math `(tier * total) ~/ 100`]
- [Source: `lib/game/game_state.dart` — `reachedMilestones`, `unlockedContinents`, `continentCompletions`]
- [Source: `lib/game/content/continent_def.dart` — `ContinentDef { id, name, unlockThreshold, completionBonus, milestoneRewards }`]
- [Source: `lib/game/content/content_registry.dart` — `Map<ContinentId, ContinentDef> continents`, `Map<CountryId, CountryDef> countries`]
- [Source: `test/architecture/ui_design_tokens_test.dart` — regex at line 17 only matches `Color(...)` constructor; `Color.lerp(` is safe]
- [Source: `test/architecture/hud_runtime_ticker_guard_test.dart` — enforces single-Ticker rule]
- [Source: `test/helpers/game_state_builder.dart` — canonical state builder; extend with `withReachedMilestones` if missing]
- [Source: Flutter TweenAnimationBuilder API — https://api.flutter.dev/flutter/widgets/TweenAnimationBuilder-class.html]
- [Source: Flutter AnimatedContainer API — https://api.flutter.dev/flutter/widgets/AnimatedContainer-class.html]
- [Source: Flutter Color.lerp API — https://api.flutter.dev/flutter/dart-ui/Color/lerp.html]
- [Source: Riverpod select pattern — https://riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds]

### Project Context Rules

Extracted from `_bmad-output/project-context.md` (authoritative source: `_bmad-output/game-architecture.md`):

- **Pinned versions only.** Flutter 3.41.6 / Dart `^3.11.4`, `flutter_riverpod ^2.6.1`, `decimal ^3.0.2`, `collection ^1.19.1`, `flutter_lints ^6.0.0`. Do not bump or add packages. No `freezed`, no `go_router`/`auto_route`, no `get_it`, no animation packages (`animations`, `lottie`, `rive`, etc.).
- **`lib/game/` has zero Flutter imports** and never imports from `lib/data/`. This story does not touch `lib/game/**` at all.
- **UI never touches Drift directly.** `reachedMilestones` is read via `gameWorldProvider`, persisted via Story 6.1's mapper.
- **UI never mutates `GameState` directly.** This story does not dispatch any commands.
- **Services subscribe to events; they never emit `GameEvent`s.** This story does not introduce any service.
- **Only `lib/providers/` imports `game/` + `data/` + `services/` together.** `continentProgressRowsProvider` lives there.
- **One `Ticker` only — owned by `GameLoop`.** Do not introduce `AnimationController`, `Ticker`, or `SingleTickerProviderStateMixin`. Use ONLY `TweenAnimationBuilder` / `AnimatedContainer` / `AnimatedOpacity` for the pulse (Flutter manages the vsync internally per-instance).
- **Multiplier stack is locked in `IncomeCalculator`.** This story introduces zero income math.
- **Big numbers** flow through `Influence` / `Intel` value objects. Not used here (integer counts only).
- **Riverpod `ref.read` for side effects, `ref.watch` for rebuilds.** Both consumers use `ref.watch(continentProgressRowsProvider)` / `ref.watch(upgradesTabModelProvider)`.
- **Sealed switch exhaustiveness.** Not applicable; no new sealed variants.
- **Accessibility is not optional.** Every progress bar carries a semantic label.
- **Tokens only — no raw colors.** `Theme.of(context).colorScheme`, `MilestoneColors` extension, `Spacing.*`. The `ui_design_tokens_test.dart` regex matches `\bColor\s*\(` (constructor) and `\bColors\.` (swatch); `Color.lerp(...)` is allowed because it does not match either pattern.
- **Naming.** `snake_case.dart` files (`continent_progress_bar.dart`, `continent_progress_providers.dart`, `continent_progress_bar_test.dart`, `continent_progress_providers_test.dart`), `PascalCase` classes (`ContinentProgressBar`, `ContinentProgressRow`), `camelCase` providers (`continentProgressRowsProvider`), `camelCase` functions (`buildContinentProgressRows`).
- **No `print`.** Use `Logger('ContinentProgress')` only if logging becomes necessary (not expected; the progress bar is silent on failure).
- **No hot-path logging.** The progress bar rebuilds rarely (only on slice changes).

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
