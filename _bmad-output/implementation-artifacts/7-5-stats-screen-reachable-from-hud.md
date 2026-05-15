# Story 7.5: Stats Screen Reachable From HUD

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.5 depends on the Story 7.3 global HUD route hook. Story 7.3 is complete in sprint status and already added a placeholder `StatsScreen` plus a `Navigator.of(context).push(MaterialPageRoute(...))` action in `GlobalHud`.

Before coding, verify:

- `lib/ui/features/hud/global_hud.dart` still pushes `StatsScreen` from the HUD stats icon using Navigator 1.0.
- `lib/ui/features/stats/stats_screen.dart` still exists and is only a blank placeholder. Expand this file instead of adding a second stats route.
- `lib/ui/app_scaffold.dart` still keeps the five tabs in an `IndexedStack`; pushing Stats must not change the current tab index or dispose the Map tab.
- `GameLoop` still wraps `AppScaffold` from `lib/app.dart`; do not pause or replace the ticker while the Stats route is on top.
- `totalInfluenceProvider` and `totalIntelProvider` already exist in `lib/providers/feature_providers.dart`; reuse them for the top totals.
- Story 7.4 is in progress at story creation time. The worktree already contains edits under `lib/providers/modal_providers.dart` and new modal widgets. This story must not revert or refactor modal queue work.
- Current `assets/data/countries.json` is placeholder content with 3 countries, while the product target remains 79 countries. Compute denominators from `ContentRegistry` so tests can use fixtures and future Story 10 content automatically shows 79. If a production acceptance test loads full content, it should read `X / 79`.

If the HUD route was changed during concurrent Story 7.4 work, integrate with the current HUD route rather than replacing the HUD.

## Story

As a player,
I want a Stats screen showing total Influence, Intel, countries owned, continents completed, achievements earned, and active multipliers,
so that I can check my progress at a glance without guessing.

## Acceptance Criteria

1. Given any tab is visible, when I tap the HUD stats icon, then a full-screen Stats route is pushed above the current shell with Navigator 1.0.

2. Given the Stats route is open, when I use the app bar back affordance or system back, then the route pops back to the same tab and the tab subtree state is preserved.

3. Given the Stats route is open above the Map tab, when the underlying map had pan/zoom state before opening Stats, then returning from Stats preserves that transform because `IndexedStack` and `GameLoop` remain mounted.

4. Given `StatsScreen` renders, then it shows Total Influence and Total Intel using the existing `Influence.format()` and `Intel.format()` paths or the existing `CurrencyBadge` widgets. Do not introduce a second currency formatter.

5. Given `StatsScreen` renders, then it shows Countries Owned as `X / totalCountries`, Continents Completed as `X / totalContinents`, and Achievements Earned as `X / totalAchievements`. With full product content these are `X / 79`, `X / 7`, and `X / 27`.

6. Given current placeholder country content has fewer than 79 countries, then the country denominator comes from `ContentRegistry.countries.length` rather than a UI hardcode. Tests may use a 79-country fixture to prove the product display contract.

7. Given `StatsScreen` renders, then Active Multipliers are broken out into at least these stable rows:
   - Influence Power: total IP levels across owned countries and the aggregate additive IP bonus derived from `BalanceConfig.ipMultPerLevel`.
   - Leaders: hired leader count plus leader multiplier sum or tier breakdown derived from `BalanceConfig.leaderMultiplier`.
   - Continent Bonus: product over completed continents of `1 + ContinentDef.completionBonus`.
   - Achievement Bonus: `1 + sum(rewardValue)` for earned achievements whose `rewardType == 'influenceMultiplier'`.
   - Global Upgrade: product of `GlobalUpgradeDef.influenceAmplifier` for ids in `GameState.activeGlobalUpgradeIds`.

8. Given a Boost or Golden Opportunity multiplier is currently active, then Stats may show it in a separate temporary-effects section. If included, read only `GameState.activeBoost`, `GameState.activeGoldenEffect`, and `GameState.goldenOpportunityMultiplier`; do not change expiry behavior.

9. Given game state changes while Stats is open, when `GameWorldNotifier` updates, then the Stats values update reactively without closing/reopening the route.

10. Given only Influence changes, then the Influence total updates without forcing provider work that depends only on Intel. Given only Intel changes, then the Intel total updates without forcing provider work that depends only on Influence.

11. Given countries unlock, continents complete, achievements earn, leader tiers change, IP levels change, or global upgrades activate, then the relevant Stats count or multiplier row updates through Riverpod providers.

12. Given stats providers calculate counts and multiplier display data, then they do not compute per-second income, do not read `CountryDef.baseInfluence` or `generationSeconds`, and do not duplicate `IncomeCalculator.compute`.

13. Given currency and multiplier values may reach late-game scale, then Stats never converts game quantities to `double` for meaning. Use `Influence`, `Intel`, and `Decimal` display helpers.

14. Given the screen is viewed on narrow mobile widths and larger text scale, then all labels and values wrap or scale cleanly without overflow.

15. Given accessibility tooling inspects the Stats route, then the route has a readable title, the back button is reachable, and every interactive element has Material/semantic accessibility with 44/48dp-class targets.

16. Given the screen uses colors, spacing, icons, and typography, then it uses `Theme.of(context).colorScheme`, `textTheme`, `HudPalette` or other existing theme extensions, Material icons, and `Spacing.*`. Do not add raw `Color(...)`, `Colors.*`, emoji icons, or bitmap assets.

17. Given this story is complete, then `flutter analyze`, stats provider tests, Stats screen widget tests, HUD route tests, app scaffold route-preservation tests, UI design-token guardrails, no-duplicate-income-math guardrails, and game boundary tests pass.

## Tasks / Subtasks

- [x] Task 1: Preflight current HUD, Stats placeholder, and concurrent Story 7.4 state (AC: #1, #2, #3)
  - [x] 1.1 Confirm `GlobalHud` still pushes `const StatsScreen()` with `Navigator.of(context).push`.
  - [x] 1.2 Confirm `StatsScreen` is the placeholder in `lib/ui/features/stats/stats_screen.dart`; replace its body rather than creating another route.
  - [x] 1.3 Confirm `AppScaffold` still uses `IndexedStack` and the Map tab remains mounted across route push/pop.
  - [x] 1.4 Confirm Story 7.4 modal files are in progress or complete; do not edit `lib/providers/modal_providers.dart` or `lib/ui/features/modals/**` for this stats story.

- [x] Task 2: Add stats summary provider models (AC: #5, #7, #8, #9, #10, #11, #12, #13)
  - [x] 2.1 Create `lib/providers/stats_providers.dart` for Stats-specific derived providers. If the team strongly prefers one derived-provider file, add to `feature_providers.dart`, but keep the public surface easy to test.
  - [x] 2.2 Add immutable DTOs such as `StatsProgressSummary` and `StatsMultiplierBreakdown`; keep them small, value-comparable, and UI-independent.
  - [x] 2.3 `StatsProgressSummary` should expose `ownedCountries`, `totalCountries`, `completedContinents`, `totalContinents`, `earnedAchievements`, and `totalAchievements`.
  - [x] 2.4 `StatsMultiplierBreakdown` should expose stable rows for IP, leaders, continent bonus, achievement bonus, and global upgrade. Use `Decimal` for multipliers and sums.
  - [x] 2.5 Use `ref.watch(gameWorldProvider.select(...))` for the state slices each provider needs. Do not watch the entire `GameState` from Stats UI widgets.
  - [x] 2.6 Use `contentRegistryProvider` for denominators and definitions. In the booted app it should be loaded already; in tests, override it with fixtures.
  - [x] 2.7 Reuse `totalInfluenceProvider` and `totalIntelProvider`; do not reimplement those selectors in the stats provider file.

- [x] Task 3: Implement count calculations (AC: #5, #6, #9, #11)
  - [x] 3.1 Countries Owned = `state.countries.values.where((c) => c.unlocked).length`.
  - [x] 3.2 Total countries = `content.countries.length`. Do not hardcode 79 in production UI.
  - [x] 3.3 Continents Completed = `state.continentCompletions.values.where((v) => v).length`.
  - [x] 3.4 Total continents = `content.continents.length`.
  - [x] 3.5 Achievements Earned = `state.earnedAchievementIds.length`.
  - [x] 3.6 Total achievements = `content.achievements.length`.
  - [x] 3.7 Unknown ids in state should not crash the screen. Count owned/completed state truth, but definition-derived labels/multipliers should ignore missing content ids and remain test-covered.

- [x] Task 4: Implement multiplier breakdown calculations (AC: #7, #8, #12, #13)
  - [x] 4.1 Influence Power row: sum `ipLevel` across unlocked countries. Also compute aggregate additive IP bonus as `Decimal.fromInt(ipLevelSum) * BalanceConfig.ipMultPerLevel` for display only.
  - [x] 4.2 Leaders row: count countries with `leaderTier != LeaderTier.none`. Add either a tier breakdown (`tier1/tier2/tier3`) or a Decimal sum of `BalanceConfig.leaderMultiplier(tier)` for hired leaders.
  - [x] 4.3 Continent Bonus row: multiply `Decimal.one + content.continents[id]!.completionBonus` for completed continent ids that exist in content. Default product is `Decimal.one`.
  - [x] 4.4 Achievement Bonus row: sum `AchievementDef.rewardValue` only for earned ids whose definition exists and `rewardType == 'influenceMultiplier'`; display multiplier as `Decimal.one + sum`. Intel reward achievements count toward earned achievements but not this multiplier.
  - [x] 4.5 Global Upgrade row: multiply `GlobalUpgradeDef.influenceAmplifier` for active ids that exist in content. Default product is `Decimal.one`.
  - [x] 4.6 Optional temporary rows: show current Golden and Boost multipliers only from current state fields. Do not modify boost/golden reducers, schedulers, persistence, or expiry.
  - [x] 4.7 Do not call or duplicate `IncomeCalculator.compute`; this screen is a breakdown of current state, not an income-rate calculator. If helper reuse is needed, extract pure non-UI multiplier helpers and keep `IncomeCalculator` tests green.
  - [x] 4.8 Add a small display-only multiplier formatter if needed. It must format `Decimal` directly, strip noisy trailing zeros, and append `x` or `+...x` without converting to `double`.

- [x] Task 5: Replace the Stats placeholder with a token-styled route (AC: #4, #5, #7, #8, #9, #14, #15, #16)
  - [x] 5.1 Modify `lib/ui/features/stats/stats_screen.dart`.
  - [x] 5.2 Keep a full-screen `Scaffold` with `AppBar(title: Text('Stats'))` so the route has a familiar back affordance.
  - [x] 5.3 Build a scrollable portrait-first body. Prefer simple full-width sections/lists over decorative nested cards.
  - [x] 5.4 Show Total Influence and Total Intel near the top using existing `CurrencyBadge` widgets or text that calls `Influence.format()` and `Intel.format()`.
  - [x] 5.5 Show progress rows for Countries Owned, Continents Completed, and Achievements Earned.
  - [x] 5.6 Show the stable Active Multipliers rows. Labels should be concise: `Influence Power`, `Leaders`, `Continents`, `Achievements`, `Global Upgrades`.
  - [x] 5.7 If temporary rows are implemented, separate them from stable multipliers with concise labels such as `Golden Opportunity` and `Boost`.
  - [x] 5.8 Use `Consumer` or small `ConsumerWidget` subtrees so total currency rows and summary rows can update independently.
  - [x] 5.9 Avoid explanatory copy such as "coming soon" or instructions. This is now the real Stats screen.
  - [x] 5.10 Use `Spacing.*`, `textTheme`, `ColorScheme`, and existing theme extensions. Do not add raw colors or one-off typography.

- [x] Task 6: Preserve route integration and shell behavior (AC: #1, #2, #3, #15)
  - [x] 6.1 Keep the HUD stats button route push in `GlobalHud` unless a tiny import/path update is required.
  - [x] 6.2 Do not add a Stats bottom-nav tab, nested `MaterialApp`, nested `ProviderScope`, per-tab `Navigator`, or `go_router`/`auto_route`.
  - [x] 6.3 Do not move `GameLoop`, save bootstrap, content bootstrap, modal host, support long-press, or offline catch-up logic.
  - [x] 6.4 Ensure back navigation returns to the same shell instance.

- [x] Task 7: Provider tests (AC: #5, #6, #7, #8, #9, #10, #11, #12, #13)
  - [x] 7.1 Add `test/providers/stats_providers_test.dart`.
  - [x] 7.2 Test progress counts with a fixture that has multiple countries, continents, and 27 achievements.
  - [x] 7.3 Test a 79-country fixture or generated content fixture proves the product denominator can display `X / 79` without a UI hardcode.
  - [x] 7.4 Test placeholder content with 3 countries displays denominator `3` from content.
  - [x] 7.5 Test IP sum and IP bonus use unlocked countries only.
  - [x] 7.6 Test leader count and leader tier/sum calculations for none, tier1, tier2, and tier3.
  - [x] 7.7 Test continent bonus product ignores missing ids and defaults to `1`.
  - [x] 7.8 Test achievement bonus includes only `rewardType == 'influenceMultiplier'` and ignores intel-only achievements for multiplier math.
  - [x] 7.9 Test global upgrade product defaults to `1` and multiplies known active upgrade ids.
  - [x] 7.10 Test active Boost/Golden rows if implemented.
  - [x] 7.11 Test provider listening/select behavior enough to prove Influence-only and Intel-only updates do not notify unrelated selectors.

- [x] Task 8: Widget and shell tests (AC: #1, #2, #3, #4, #5, #7, #8, #9, #14, #15, #16)
  - [x] 8.1 Add `test/ui/features/stats/stats_screen_test.dart`.
  - [x] 8.2 Test Stats screen renders title, total Influence, total Intel, progress rows, and required multiplier rows.
  - [x] 8.3 Test large values such as `Influence(Decimal.parse('1e38'))` render through existing formatters without overflow.
  - [x] 8.4 Test narrow width and increased text scale do not throw overflow errors.
  - [x] 8.5 Extend `test/ui/features/hud/global_hud_test.dart` only if needed to keep the stats icon route assertion current.
  - [x] 8.6 Extend `test/ui/app_scaffold_test.dart` or add a focused route test proving Stats push/pop preserves selected tab and Map transform.
  - [x] 8.7 Test route/app bar semantics and back affordance.

- [x] Task 9: Architecture and regression guardrails (AC: #12, #13, #16, #17)
  - [x] 9.1 Run `test/architecture/ui_design_tokens_test.dart`; new Stats widgets must avoid raw widget colors.
  - [x] 9.2 Run `test/architecture/no_duplicate_income_math_test.dart`; Stats must not introduce duplicate base-influence income computations.
  - [x] 9.3 Run `test/architecture/game_boundary_test.dart`; no Flutter imports under `lib/game/**`.
  - [x] 9.4 Add a small source guard if needed to ensure `StatsScreen` does not import Drift/database/repository classes.
  - [x] 9.5 Ensure no new packages are added to `pubspec.yaml`.

- [x] Task 10: Verification (AC: all)
  - [x] 10.1 Run `dart format --set-exit-if-changed` on changed Dart and test files.
  - [x] 10.2 Run `flutter test test/providers/stats_providers_test.dart`.
  - [x] 10.3 Run `flutter test test/ui/features/stats/stats_screen_test.dart`.
  - [x] 10.4 Run `flutter test test/ui/features/hud/global_hud_test.dart`.
  - [x] 10.5 Run `flutter test test/ui/app_scaffold_test.dart`.
  - [x] 10.6 Run `flutter test test/architecture`.
  - [x] 10.7 Run `flutter analyze`.
  - [x] 10.8 Run full `flutter test` if time permits.

### Review Findings

- [x] [Review][Patch] Golden temporary effect is rendered twice [lib/ui/features/stats/stats_screen.dart:252] -- A claimed Golden stores the same multiplier in both `GameState.goldenOpportunityMultiplier` and `GameState.activeGoldenEffect.multiplier`; `applyClaimGolden` writes both together. The Stats temporary section renders one row from `goldenOpportunityMultiplier` and another from `goldenEffectMultiplier`, so normal claimed-Golden state shows two separate Golden rows even though the income stack has only one Golden multiplier slot. This violates AC #8's intent to show the active Golden multiplier without changing or duplicating expiry semantics.

## Dev Notes

### Implementation Scope

This story replaces the blank Stats placeholder with the real progress overview reachable from the HUD. It should not change the shell, modal queue, settings modal, upgrades tab, leaders tab, persistence, or game simulation.

The intended route shape is already in place:

```dart
Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => const StatsScreen(),
  ),
);
```

Keep this Navigator 1.0 route. The Stats screen is not a bottom tab.

### Current Codebase Observations

- `lib/ui/features/stats/stats_screen.dart` currently renders a `Scaffold` with an app bar and `SizedBox.shrink()` body.
- `lib/ui/features/hud/global_hud.dart` already has a `Stats` tooltip, `Semantics(label: 'Stats', button: true)`, and route push to `StatsScreen`.
- `lib/ui/app_scaffold.dart` mounts `GlobalHud` once above the tab `IndexedStack`.
- `lib/providers/feature_providers.dart` already exposes `totalInfluenceProvider` and `totalIntelProvider` as narrow selectors.
- `lib/providers/app_providers.dart` exposes `contentRegistryProvider` as a `FutureProvider<ContentRegistry>`.
- `GameState` already contains all required stats inputs: `countries`, `totalInfluence`, `totalIntel`, `continentCompletions`, `earnedAchievementIds`, `activeGlobalUpgradeIds`, `goldenOpportunityMultiplier`, `activeBoost`, and `activeGoldenEffect`.
- `ContentRegistry` contains `countries`, `continents`, `achievements`, and `globalUpgrades` definitions.
- `IncomeCalculator` documents the authoritative stack and has private helper logic for continent, achievement, and global-upgrade multiplier slots. Do not fork this into a second income calculator.
- `assets/data/countries.json` has 3 placeholder rows at story creation time; `continents.json` has 7 and `achievements.json` has 27.
- `test/helpers/game_state_builder.dart`, `test/helpers/test_content_registry.dart`, and achievement fixture helpers already provide useful test setup.

### Previous Story Intelligence

- Story 7.1 established `appTheme()`, `Spacing.*`, `HudPalette`, and token guardrails. Stats must consume those tokens.
- Story 7.2 established `AppScaffold` with `BottomNavigationBar` plus `IndexedStack`. Stats should push above that shell, not become a tab.
- Story 7.3 established the HUD route hook, currency providers, `CurrencyBadge`, `AnimatedCounter`, and the current Stats placeholder. Reuse them.
- Story 7.4 is currently in progress and owns the modal queue. Stats does not need modal queue changes.
- Story 5.5 established exactly 27 achievement definitions and `earnedAchievementIds`. Use the ledger for counts; do not re-evaluate achievements.
- Story 4.4 made continent completion bonuses global products. Stats should display that same product concept, not a per-country-only bonus.
- Story 3.1 pinned `IncomeCalculator` as the single source of truth for income-rate computation. Stats must not calculate income per second.

### Architecture Compliance

- UI can import providers and game value objects, but must not import Drift database classes or repositories directly.
- Providers are the composition root. Derived stats belong in `lib/providers/`.
- If pure helper extraction is required for multiplier reuse, keep it under `lib/game/features/economy/`, pure Dart only, with `package:test/test.dart` tests.
- No commands, events, reducers, database schema, migrations, repositories, or persistence writes are needed.
- No new ticker, animation controller, app lifecycle observer, or background process.
- No new package, `go_router`, `auto_route`, `freezed`, `riverpod_generator`, or external charting library.
- Do not add charts in this story. Dense text/row summaries are enough and safer for mobile layout.

### Library / Framework Requirements

- Use existing pinned dependencies from `pubspec.yaml`: Flutter SDK, Dart `^3.11.4`, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `decimal: ^3.0.2`, and `flutter_lints: ^6.0.0`.
- Flutter Navigator 1.0 is the selected navigation architecture. Official Flutter docs describe `Navigator.push()` as adding a route to the Navigator stack and `Navigator.pop()` as removing the current route.
- Riverpod `select` is the right rebuild-narrowing primitive. Official Riverpod docs state `select` listens only to the projected property and skips rebuilds when that projected value is equal.
- No web-driven dependency upgrade is required for this story.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/providers/stats_providers.dart` | Stats progress and multiplier summary providers/DTOs |
| `test/providers/stats_providers_test.dart` | Count, denominator, multiplier, and selector behavior tests |
| `test/ui/features/stats/stats_screen_test.dart` | Stats route rendering, accessibility, large values, responsive layout |

Modify:

| File | Purpose |
| --- | --- |
| `lib/ui/features/stats/stats_screen.dart` | Replace placeholder with the real reactive Stats screen |
| `test/ui/features/hud/global_hud_test.dart` | Keep route-push test current if needed |
| `test/ui/app_scaffold_test.dart` | Add route-preservation coverage if not better placed in stats widget tests |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/providers/modal_providers.dart` and `lib/ui/features/modals/**` | Story 7.4 owns modal queue work |
| `lib/ui/features/settings/**` | Story 7.6 owns settings |
| `lib/ui/features/upgrades/**` | Story 7.7 owns upgrades UI |
| `lib/ui/features/leaders/**` | Story 7.8 owns leaders UI |
| `lib/data/**` | No persistence/schema work in this story |
| `assets/**` | No content-population work in this story |
| `pubspec.yaml` | No dependency changes |

### Testing Requirements

Use Riverpod provider overrides. Do not mount real Drift in Stats widget tests.

Recommended provider-test shape:

```dart
final content = testMapperContentRegistry();
final notifier = _TestGameWorldNotifier(
  content: content,
  initialState: GameStateBuilder.fullyPopulated(
    content: content,
    savedAtUtc: DateTime.utc(2026, 4, 28),
  ),
);
final container = ProviderContainer(
  overrides: [
    contentRegistryProvider.overrideWith((_) async => content),
    gameWorldProvider.overrideWith((_) => notifier),
  ],
);
```

Recommended widget-test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => notifier),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const StatsScreen(),
    ),
  ),
);
```

For the route preservation test:

1. Pump `AppScaffold` with fake map/content/game providers.
2. Pan or zoom the Map tab and capture the `WorldMapPainter.viewTransform`.
3. Tap the HUD Stats button.
4. Pop the Stats route.
5. Assert the selected tab remains Map and the captured transform is still present.

### Out of Scope

- Generic sequential modal queue behavior (Story 7.4).
- Settings modal implementation, sound/haptics toggles, credits, or Support long-press migration (Story 7.6).
- Upgrades tab country cards, bulk purchase, next unlock teaser UI, purchase confirms (Story 7.7).
- Leaders tab accordion and hire/upgrade actions (Story 7.8).
- Map default cold-launch and post-tutorial auto-focus (Story 7.9).
- Continent progression progress bars with milestone tick animations (Story 7.10).
- Charts, historical graphs, analytics, event logs, debug state inspector, or cheat panels.
- New game commands/events/reducers, content JSON expansion, Drift schema, migrations, or save repository writes.

### Latest Technical Information

- Flutter Navigator docs confirm `Navigator.push()` adds a route to the stack and `Navigator.pop()` removes the current route. Use `MaterialPageRoute<void>` for the Stats route. Source: https://docs.flutter.dev/cookbook/navigation/navigation-basics
- Flutter `PopScope` is current for explicit pop interception, but this story should not need it. Use default route popping unless a test exposes a route-specific issue. Source: https://api.flutter.dev/flutter/widgets/PopScope-class.html
- Riverpod docs confirm `select` narrows rebuilds by projecting only the property a widget/provider cares about. Use this for stats slices instead of broad UI watches. Source: https://docs-v2.riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds

### Git Intelligence Summary

Recent commits are directly relevant:

- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` - Story 7.3 route hook, currency badges, and Stats placeholder exist.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` - Story 7.2 shell and map preservation are in place.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` - token usage and raw-color guardrails are active.
- `ef0faba feat: save recovery on corrupt database and related UI` - do not disturb save recovery.
- `c442514 feat: offline catchup and reward modal on resume` - modal/resume ordering remains outside this stats story.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.5]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR29, FR30, FR43, NFR5, NFR7, NFR10, NFR12, NFR18, NFR21]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Navigation, Riverpod, Big Numbers, Multiplier Stack]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `lib/ui/features/stats/`, `lib/providers/`, architectural boundaries]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` - provider selectors and widget test patterns]
- [Source: `_bmad-output/project-context.md` - value-object, token, accessibility, and no-duplicate-income rules]
- [Source: `_bmad-output/implementation-artifacts/7-3-global-hud-with-influence-and-intel-currency-badges.md` - HUD route and placeholder Stats dependency]
- [Source: `_bmad-output/implementation-artifacts/7-2-app-scaffold-with-5-tab-bottom-navigation-and-indexedstack.md` - shell and map preservation dependency]
- [Source: `_bmad-output/implementation-artifacts/7-4-sequential-modal-queue-with-priority.md` - concurrent modal queue ownership boundary]
- [Source: `lib/ui/features/hud/global_hud.dart` - current stats icon route push]
- [Source: `lib/ui/features/stats/stats_screen.dart` - placeholder to replace]
- [Source: `lib/providers/feature_providers.dart` - total currency providers]
- [Source: `lib/providers/app_providers.dart` - `contentRegistryProvider`]
- [Source: `lib/game/game_state.dart` - stats state inputs]
- [Source: `lib/game/features/economy/income_calculator.dart` - authoritative multiplier stack]
- [Source: `lib/game/config/balance.dart` - IP and leader multiplier constants]
- [Source: `lib/game/content/content_registry.dart`, `country_def.dart`, `continent_def.dart`, `achievement_def.dart`, `global_upgrade_def.dart` - definitions used for counts/breakdown]
- [Source: `test/helpers/game_state_builder.dart` and `test/helpers/test_content_registry.dart` - test fixtures]
- [Source: Flutter Navigator basics - https://docs.flutter.dev/cookbook/navigation/navigation-basics]
- [Source: Flutter PopScope API - https://api.flutter.dev/flutter/widgets/PopScope-class.html]
- [Source: Riverpod select docs - https://docs-v2.riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent).

### Debug Log References

(none)

### Completion Notes List

- Implemented `stats_providers.dart` with `StatsProgressSummary`, `StatsMultiplierBreakdown`, narrow `gameWorldProvider.select` via `_StatsMultiplierSlice`, and `formatStatMultiplier` (Decimal-only display).
- Replaced Stats placeholder with scrollable token-themed sections: totals (`CurrencyBadge` + `Consumer`), progress, active multipliers, temporary Golden/Boost/burst rows.
- Extracted `MultiplierStackHelpers` from income stack math; `IncomeCalculator` now delegates continent/achievement/global slots to keep a single formula source.
- Tests: `stats_providers_test.dart`, `stats_screen_test.dart`, extended `app_scaffold_test.dart` (Stats push/pop + map transform), `global_hud_test.dart` (provider overrides so pushed Stats route resolves).
- Verified `dart format`, `flutter analyze`, `flutter test` (full suite), and `test/architecture` pass.

### File List

- lib/game/features/economy/multiplier_stack_helpers.dart
- lib/game/features/economy/income_calculator.dart
- lib/providers/stats_providers.dart
- lib/ui/features/stats/stats_screen.dart
- test/providers/stats_providers_test.dart
- test/ui/features/stats/stats_screen_test.dart
- test/ui/app_scaffold_test.dart
- test/ui/features/hud/global_hud_test.dart
- _bmad-output/implementation-artifacts/7-5-stats-screen-reachable-from-hud.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-04-28: Story 7.5 implementation — Stats screen, stats providers, shared multiplier helpers, HUD/scaffold/widget/provider tests; `flutter analyze` + full `flutter test` green.
- 2026-04-29: Code review patch — collapsed Golden temporary effects to one displayed multiplier row and added regression coverage; `flutter analyze` + full `flutter test` green.

## Story Completion Status

Implementation complete; review finding patched; story marked **done**.
