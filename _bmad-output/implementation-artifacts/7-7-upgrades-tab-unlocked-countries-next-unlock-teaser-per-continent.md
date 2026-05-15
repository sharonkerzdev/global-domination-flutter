# Story 7.7: Upgrades Tab - Unlocked Countries + Next-Unlock Teaser per Continent

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.7 depends on the shell and gameplay foundations that are already present in the current worktree:

- `lib/ui/app_scaffold.dart` mounts `UpgradesScreen` as tab index 1 in the `IndexedStack`. Replace the placeholder `UpgradesScreen`; do not add a second upgrades route, tab, nested `MaterialApp`, or per-tab navigator.
- `lib/ui/features/upgrades/upgrades_screen.dart` currently contains only the placeholder. This story owns expanding it into the real Upgrades tab.
- `PurchaseUpgrade(countryId, bulk)` and `UnlockCountry(countryId)` already exist in `lib/game/game_command.dart` and are handled by `GameWorld`.
- `applyPurchaseUpgrade` already enforces unlocked country, max IP, full-bulk affordability, cap-to-200 behavior, and `IncomeCalculator.upgradeCost(...)`.
- `applyUnlockCountry` already enforces continent threshold, already-unlocked, unlock cost, and initializes new countries at IP level 1.
- `nextUnlockInContinentProvider` and `nextUnlockOverallProvider` already exist in `lib/providers/feature_providers.dart`. Reuse them or wrap them; do not duplicate the selector logic in widgets.
- `IncomeCalculator.compute(...)` is the only source for current per-country rate. The Upgrades tab may call it for display but must not duplicate multiplier formulas.
- `CurrencyBadge` exists in `lib/ui/widgets/currency_badge.dart`. Reuse it for Influence costs where the layout allows; otherwise still use `Influence.format()`.
- Story 7.6 is not `done` in sprint status at story creation time. Treat settings schema/modal work as concurrent and not landed unless the local worktree proves otherwise.
- The current worktree contains uncommitted/user-owned Story 7.4 and 7.5 changes plus story artifacts. Preserve them. Do not revert, rename, or "clean up" modal queue, stats, app shell, or sprint-status changes outside this story's lines.

Before coding, verify with `git status --short` and inspect the current versions of `upgrades_screen.dart`, `feature_providers.dart`, `game_command.dart`, `income_calculator.dart`, and `app_scaffold.dart`.

## Story

As a player,
I want an Upgrades tab that lists my unlocked countries grouped by continent, plus a next-unlock teaser for each unlocked continent,
so that I can efficiently spend Influence without navigating the map.

## Acceptance Criteria

1. Given the player opens the Upgrades tab, then it replaces the placeholder screen with a scrollable, token-styled tab body mounted inside the existing `AppScaffold` tab at index 1.

2. Given continents are loaded from `ContentRegistry`, then the tab shows one section for each continent where `GameState.unlockedContinents[continentId] == true`; locked continents are not rendered as sections.

3. Given a continent section renders, then its unlocked countries are listed in content order as upgrade cards. Countries in locked continents and locked countries inside the section are not shown as upgrade cards.

4. Given an unlocked continent has no unlocked countries yet, then the section still renders and contains the next-unlock teaser for that continent.

5. Given an upgrade card renders, then it shows the country display name, current IP level, current rate, selected bulk value, cost for the selected bulk purchase, and a Buy action.

6. Given current rate is displayed, then it is computed through `IncomeCalculator.compute(countryState, gameState, content)` and formatted through `Influence.format()`. No inline income multiplier math is introduced outside `IncomeCalculator` or its existing helper path.

7. Given a country is below `BalanceConfig.maxIpLevel`, then the selected bulk options are exactly 1, 10, and 25. The actual levels bought are capped by remaining room to max IP for cost display and command behavior.

8. Given a country is at max IP, then its Buy action is disabled, no upgrade command is dispatched, and the card displays a max-level state instead of an upgrade cost.

9. Given the player cannot afford the selected bulk cost, then the Buy action is disabled and no command is dispatched.

10. Given the player can afford the selected bulk cost, when they tap Buy, then `ref.read(gameWorldProvider.notifier).apply(PurchaseUpgrade(countryId: id, bulk: selectedBulk))` is called exactly once and the card updates after state changes.

11. Given a bulk selector is changed on one card, then only that card's selected bulk state changes. Bulk selection is UI state only; it is not stored in `GameState`, Drift, content JSON, or any repository.

12. Given a continent has a locked country remaining in content order, then the section ends with one next-unlock teaser card for that country showing display name, cost, and an Unlock action.

13. Given the player cannot afford the teaser unlock cost, then the Unlock action is disabled and no command is dispatched.

14. Given the player can afford the teaser unlock cost, when they tap Unlock, then `ref.read(gameWorldProvider.notifier).apply(UnlockCountry(countryId: id))` is called exactly once and the country transitions into the upgrade-card list after state changes.

15. Given a continent has no locked countries remaining, then the section still ends with a single non-actionable completion/future-unlock teaser slot. If `nextUnlockOverallProvider` points to a later continent, the slot may name that future continent; it must not render a locked future continent as a full section.

16. Given all countries in all available content are unlocked, then the tab handles the world-complete state without crashing, duplicate teaser cards, or disabled command buttons that look actionable.

17. Given `CountryDef` currently has no friendly `name` field, then display names are derived consistently from `CountryId.value` for this story, such as `united_states` -> `United States`. Do not add a content model field or rewrite assets in this story.

18. Given command buttons render, then they use Material buttons/icons, have readable semantics, and meet 44/48dp-class mobile touch targets.

19. Given the tab is viewed on narrow mobile widths or larger text scale, then cards, segmented controls, long country names, formatted big numbers, and buttons wrap or constrain cleanly without overflow.

20. Given Upgrades UI uses colors, spacing, icons, typography, surfaces, dividers, and card styling, then it uses `Theme.of(context).colorScheme`, `textTheme`, existing `ThemeExtension`s where relevant, Material icons, and `Spacing.*`. Do not add raw `Color(...)`, `Colors.*`, emoji icons, bitmap assets, or one-off typography.

21. Given the Upgrades tab reads state, then providers/selectors keep rebuilds narrow enough for up to 79 countries. Do not make every row watch unrelated state if a provider/DTO can isolate the row model.

22. Given implementation is complete, then `flutter analyze`, Upgrades provider tests, Upgrades widget tests, AppScaffold tab integration tests if touched, UI token guardrails, no-duplicate-income-math guardrails, and game boundary tests pass.

## Tasks / Subtasks

- [x] Task 1: Preflight current shell, placeholder, and concurrent work (AC: #1, #2)
  - [x] 1.1 Run `git status --short` and note existing user-owned/uncommitted Story 7.4, 7.5, and 7.6 files. Preserve them.
  - [x] 1.2 Confirm `AppScaffold` still renders tabs in Map, Upgrades, Leaders, Achievements, Minigames order with `IndexedStack`.
  - [x] 1.3 Confirm `UpgradesScreen` is still the placeholder in `lib/ui/features/upgrades/upgrades_screen.dart`; expand this file rather than adding another route.
  - [x] 1.4 Confirm `feature_providers.dart` still exposes `nextUnlockInContinentProvider` and `nextUnlockOverallProvider`.
  - [x] 1.5 Confirm `PurchaseUpgrade` and `UnlockCountry` signatures match the story expectations.
  - [x] 1.6 Confirm current Story 7.6 settings work has not landed before touching shared HUD/app files. This story should not edit settings.

- [x] Task 2: Add Upgrades tab provider models (AC: #2, #3, #4, #5, #6, #7, #12, #15, #17, #21)
  - [x] 2.1 Create `lib/providers/upgrades_providers.dart` unless the team strongly prefers `feature_providers.dart`. Keep derived Upgrades models UI-independent.
  - [x] 2.2 Add immutable DTOs such as `UpgradesTabModel`, `ContinentUpgradeSection`, `CountryUpgradeRow`, and `NextUnlockTeaserRow`.
  - [x] 2.3 Sections should be built from `ContentRegistry.continents` sorted by unlock threshold, then id for deterministic ordering.
  - [x] 2.4 Show only sections where `state.unlockedContinents[continent.id] == true`.
  - [x] 2.5 Country rows should be built from `ContentRegistry.countries.values` in content order, filtered to the section continent and `state.countries[id]?.unlocked == true`.
  - [x] 2.6 Derive country display names from id with a single helper, for example split on `_`/`-`, capitalize words, and preserve stable output in tests.
  - [x] 2.7 For each row, include `countryId`, display name, `ipLevel`, `isMaxLevel`, and `currentRate = IncomeCalculator.compute(...)`.
  - [x] 2.8 Do not read `CountryDef.baseInfluence` in UI for rate display. It is acceptable inside provider code only as part of the `IncomeCalculator.compute(...)` call.
  - [x] 2.9 Expose a pure helper for upgrade affordability/cost, such as `upgradePurchasePreview(row, bulk, totalInfluence)` or a provider family. It must use `IncomeCalculator.upgradeCost(...)`.
  - [x] 2.10 Reuse `nextUnlockInContinentProvider` semantics for teaser country choice. If wrapping it in an Upgrades provider, keep the underlying selector behavior aligned with Story 4.5.
  - [x] 2.11 Include a model state for completed sections / future continent teaser / world complete so the widget never guesses from nulls.

- [x] Task 3: Replace placeholder with real Upgrades tab UI (AC: #1, #2, #3, #4, #5, #12, #15, #16, #18, #19, #20)
  - [x] 3.1 Modify `lib/ui/features/upgrades/upgrades_screen.dart`.
  - [x] 3.2 Prefer `ConsumerStatefulWidget` or small child widgets so per-card bulk selection can be local UI state.
  - [x] 3.3 Remove the nested placeholder copy. The Upgrades tab should be a real tool surface, not a "coming soon" screen.
  - [x] 3.4 Avoid a nested `Scaffold` unless a concrete Flutter issue requires it; `AppScaffold` already provides the shell.
  - [x] 3.5 Use a single vertical scrollable layout. `ListView.builder` or slivers are preferred for scaling to 79 countries.
  - [x] 3.6 Render continent headers as unframed section headers with the continent name and count of unlocked countries in that section.
  - [x] 3.7 Render cards only for individual country rows and teaser rows. Do not put cards inside other cards.
  - [x] 3.8 Use compact, repeatable card layout: country name, IP level, rate, cost, bulk selector, Buy button.
  - [x] 3.9 Use Material icons where helpful (`Icons.trending_up`, `Icons.lock_open`, `Icons.public`, etc.); no emoji or new assets.
  - [x] 3.10 Make long values resilient with `Flexible`, wrapping text, `FittedBox` only for compact numeric chips, and stable card constraints.

- [x] Task 4: Implement per-card bulk selector and Buy command path (AC: #5, #7, #8, #9, #10, #11, #18)
  - [x] 4.1 Use `SegmentedButton<int>` with `ButtonSegment<int>` values 1, 10, and 25, or a token-consistent Material equivalent if layout tests prove segmented buttons do not fit.
  - [x] 4.2 Keep selected bulk in widget state keyed by `CountryId`; default to 1.
  - [x] 4.3 When computing cost, calculate `actualLevels = min(selectedBulk, BalanceConfig.maxIpLevel - ipLevel)` and call `IncomeCalculator.upgradeCost(def, ipLevel, actualLevels)`.
  - [x] 4.4 Disable Buy if `actualLevels < 1`, `cost == null`, or `state.totalInfluence < cost`.
  - [x] 4.5 On Buy, call `gameWorldProvider.notifier.apply(PurchaseUpgrade(countryId: id, bulk: selectedBulk))`.
  - [x] 4.6 Do not rely on `GameWorldNotifier.apply` returning a `Result`; it currently returns `void`. If exposing command failures becomes necessary, make that a tiny, tested refactor and update all affected call sites.
  - [x] 4.7 Do not route Buy through the modal queue or purchase-confirm modal in this story. Epic 7.4 made that queue available for future flows, but Story 7.7 acceptance expects direct dispatch.

- [x] Task 5: Implement next-unlock teaser behavior (AC: #12, #13, #14, #15, #16, #17, #18)
  - [x] 5.1 Use `nextUnlockInContinentProvider(continentId)` or equivalent wrapper data for the section's active teaser.
  - [x] 5.2 If a same-continent teaser exists, render display name, `unlockCost.format()`, and an Unlock button.
  - [x] 5.3 Disable Unlock if `state.totalInfluence < unlockCost`.
  - [x] 5.4 On Unlock, call `gameWorldProvider.notifier.apply(UnlockCountry(countryId: teaser.countryId))`.
  - [x] 5.5 If no same-continent teaser exists, render one non-actionable teaser slot. Use clear state such as complete, future continent, or world complete; do not create a command button.
  - [x] 5.6 If using `nextUnlockOverallProvider` to name a future target, never render a full section for a locked future continent.
  - [x] 5.7 Do not alter content JSON, country ordering, continent thresholds, unlock reducer logic, or milestone/completion reducers.

- [x] Task 6: Preserve architecture boundaries and state ownership (AC: #6, #10, #14, #20, #21, #22)
  - [x] 6.1 UI dispatches commands only through `gameWorldProvider.notifier.apply(...)`; UI never mutates `GameState`.
  - [x] 6.2 UI and providers do not import Drift database classes, table classes, or repositories.
  - [x] 6.3 No `lib/game/**` changes are required. If a pure helper is extracted, keep it Flutter-free and covered by `package:test/test.dart`.
  - [x] 6.4 No `lib/data/**` changes, schema migrations, generated Drift files, save repository edits, or persistence write changes belong to this story.
  - [x] 6.5 No package additions, router additions, custom map libraries, global event bus changes, service calls, haptics, audio, or animations.
  - [x] 6.6 Keep `AppScaffold`, `GlobalHud`, `ModalQueueHost`, stats, settings, and `GameLoop` wiring intact.

- [x] Task 7: Provider tests (AC: #2, #3, #4, #6, #7, #8, #12, #15, #16, #17, #21)
  - [x] 7.1 Add `test/providers/upgrades_providers_test.dart`.
  - [x] 7.2 Test locked continents are not included as sections.
  - [x] 7.3 Test an unlocked continent with no unlocked countries still has a teaser row.
  - [x] 7.4 Test unlocked country rows are grouped by continent and follow content order.
  - [x] 7.5 Test current rate for a country equals `IncomeCalculator.compute(...)`.
  - [x] 7.6 Test bulk cost uses `IncomeCalculator.upgradeCost(...)` for 1, 10, and 25.
  - [x] 7.7 Test bulk cost caps levels at `BalanceConfig.maxIpLevel` and reports max state at level 200.
  - [x] 7.8 Test affordability booleans for upgrade and unlock costs.
  - [x] 7.9 Test same-continent next unlock, completed-continent teaser, future-continent teaser, and world-complete model states.
  - [x] 7.10 Test display-name formatting from country ids including underscores and hyphens.
  - [x] 7.11 Test missing country state or missing content ids do not crash and are ignored or treated as locked according to selector behavior.

- [x] Task 8: Widget and shell tests (AC: #1, #5, #9, #10, #11, #12, #13, #14, #18, #19, #20)
  - [x] 8.1 Add `test/ui/features/upgrades/upgrades_screen_test.dart`.
  - [x] 8.2 Pump `UpgradesScreen` with provider overrides; do not boot real Drift or production filesystem paths.
  - [x] 8.3 Test section headers, country upgrade cards, teaser cards, and absence of locked continent sections.
  - [x] 8.4 Test changing a card's bulk selector updates that card's displayed cost without changing another card.
  - [x] 8.5 Test Buy dispatches `PurchaseUpgrade` with selected bulk exactly once when enabled.
  - [x] 8.6 Test Buy is disabled when unaffordable or max level.
  - [x] 8.7 Test Unlock dispatches `UnlockCountry` exactly once when enabled.
  - [x] 8.8 Test Unlock is disabled when unaffordable.
  - [x] 8.9 Test large numbers such as `Influence(Decimal.parse('1e38'))` render through existing formatters without overflow.
  - [x] 8.10 Test narrow width and increased text scale do not throw overflow errors.
  - [x] 8.11 If `AppScaffold` tests need updates, assert the Upgrades tab still appears at index 1 and the HUD/bottom nav remain mounted.

- [x] Task 9: Architecture and regression guardrails (AC: #6, #20, #21, #22)
  - [x] 9.1 Run `test/architecture/ui_design_tokens_test.dart`; Upgrades UI must avoid raw widget color literals.
  - [x] 9.2 Run `test/architecture/no_duplicate_income_math_test.dart`; Upgrades must not introduce duplicate `baseInfluence` math.
  - [x] 9.3 Run `test/architecture/game_boundary_test.dart`; no Flutter imports under `lib/game/**`.
  - [x] 9.4 Add a small source guard if needed to ensure `upgrades_screen.dart` does not import Drift/database/repository classes directly.
  - [x] 9.5 Ensure `pubspec.yaml` is unchanged.

- [x] Task 10: Verification (AC: all)
  - [x] 10.1 Run `dart format --set-exit-if-changed` on changed Dart/test files.
  - [x] 10.2 Run `flutter test test/providers/upgrades_providers_test.dart`.
  - [x] 10.3 Run `flutter test test/ui/features/upgrades/upgrades_screen_test.dart`.
  - [x] 10.4 Run `flutter test test/ui/app_scaffold_test.dart` if touched.
  - [x] 10.5 Run `flutter test test/architecture`.
  - [x] 10.6 Run `flutter analyze`.
  - [x] 10.7 Run full `flutter test` if time permits.

### Review Findings

- [x] [Review][Patch] Upgrades model watches full GameState and rebuilds all hidden rows on every tick [lib/providers/upgrades_providers.dart:268]
- [x] [Review][Patch] Buy buttons use a repeated generic semantics label [lib/ui/features/upgrades/upgrades_screen.dart:354]

## Dev Notes

### Implementation Scope

This story turns the Upgrades bottom tab into the primary management screen for Influence Power upgrades and same-continent country unlocks. It is a UI/provider story over existing simulation commands and reducers.

It should not implement leaders, global upgrades, settings, stats, modal queue changes, content population, persistence, migrations, map autofocus, progress bars, tutorial, SFX, haptics, or animations.

### Current Codebase Observations

- `lib/ui/features/upgrades/upgrades_screen.dart` is a placeholder with a centered title and explanatory placeholder copy.
- `lib/ui/app_scaffold.dart` already imports `UpgradesScreen` and places it second in the `IndexedStack`.
- `lib/providers/feature_providers.dart` exposes `totalInfluenceProvider`, `totalIntelProvider`, `nextUnlockInContinentProvider`, `nextUnlockOverallProvider`, and `dailyRewardAvailableProvider`.
- `nextUnlockInContinent(...)` scans `content.countries.values` in content order and returns the first country in that continent where state is missing or not unlocked.
- `nextUnlockOverall(...)` uses effective unlock threshold order and returns the first locked country in the earliest available continent.
- `PurchaseUpgrade` has the signature `PurchaseUpgrade({required CountryId countryId, int bulk = 1})`.
- `UnlockCountry` has the signature `UnlockCountry({required CountryId countryId})`.
- `GameWorldNotifier.apply(GameCommand cmd)` currently returns `void`; it updates state from the world after dispatch.
- `applyPurchaseUpgrade` rejects locked countries, negative IP, max level, non-positive base influence, and insufficient Influence. It caps only by max-level room, not by affordability.
- `applyUnlockCountry` spends `CountryDef.unlockCost`, checks continent threshold against `state.totalInfluence`, and initializes the newly unlocked country at IP level 1.
- `IncomeCalculator.compute(...)` returns per-second `Influence`; `IncomeCalculator.upgradeCost(...)` returns exact Decimal-backed geometric bulk cost.
- `CountryDef` currently has `id`, `continent`, `baseInfluence`, `unlockCost`, `tier`, and `generationSeconds`, but no player-facing country name.
- `ContinentDef` has a friendly `name`; use that for section headings.
- `assets/data/countries.json` is still placeholder-sized in this phase. Tests should use fixtures with multiple countries/continents rather than hardcoding the future 79-country production count in the UI.

### Previous Story Intelligence

- Story 7.1 established `appTheme()`, `Spacing.*`, `HudPalette`, `CountryColors`, `MilestoneColors`, and raw-color guardrails. Upgrades must consume tokens.
- Story 7.2 established the bottom navigation shell with `IndexedStack`; Upgrades should stay a tab body and preserve map state.
- Story 7.3 established `GlobalHud`, `CurrencyBadge`, total currency providers, and minimal Upgrades placeholder. Reuse the badge/formatter path.
- Story 7.4 established the generic modal queue. This story does not need queue changes and should not route Buy/Unlock through purchase confirmation.
- Story 7.5 established `stats_providers.dart` and `MultiplierStackHelpers`. Upgrades may rely on `IncomeCalculator.compute(...)` and must preserve no-duplicate-income guardrails.
- Story 7.6 is story-created/concurrent but not done. Do not assume settings schema/providers exist or edit settings files here.
- Story 4.5 created next-unlock selectors specifically so Epic 7 UI could render teasers. Reuse those selectors instead of recomputing next unlock in widgets.
- Story 4.1 created `UnlockCountry`; Story 3.2 created `PurchaseUpgrade`; this story is their tab UI.
- Story 6.2 save repository persists upgrade/unlock events. Do not add UI-driven database writes.

### Architecture Compliance

- UI reads Riverpod providers and dispatches commands. UI never mutates `GameState` directly.
- Providers are the composition root. Upgrades-derived DTOs belong in `lib/providers/`, not inside widgets if they mix content, game state, and calculator calls.
- `lib/game/**` remains pure Dart. No Flutter imports, no widget helpers, no service calls.
- `lib/data/**` remains untouched. No Drift, repository, mapper, schema, migration, or generated-file work.
- All game quantities remain `Influence`, `Intel`, or `Decimal` through existing value objects/helpers. Do not convert to `double` for costs, rates, or affordability.
- Income rate display routes through `IncomeCalculator.compute(...)`. Upgrade cost display routes through `IncomeCalculator.upgradeCost(...)`.
- Balance constants come from `BalanceConfig`; content values come from `ContentRegistry`. Do not hardcode max IP, cost curves, continent thresholds, or country counts in widgets.
- Navigation remains `BottomNavigationBar` plus `IndexedStack`; no router package or extra navigator.
- No new explicit ticker or animation controller. Epic 8 owns polish animation budgets.

### Library / Framework Requirements

- Use the pinned project dependencies from `pubspec.yaml`: Flutter/Dart SDK, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `decimal: ^3.0.2`, `collection: ^1.19.1`, and `flutter_lints: ^6.0.0`. Do not bump packages.
- Use manual Riverpod providers; the project does not use `riverpod_generator`.
- Flutter `SegmentedButton<int>` is a good fit for the 1/10/25 mutually exclusive bulk selector because Flutter documents it for limited option sets and single-select behavior.
- Use `ListView.builder`/slivers when practical so rows are created on demand. If using `ListView.builder`, provide `itemCount`.
- Use Riverpod `select` for narrow watches where the model can remain immutable and the complexity is justified by row count.
- If a later implementation exposes command failures to the UI, use `ScaffoldMessenger` for transient user errors. Do not add a bespoke error overlay in this story.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/providers/upgrades_providers.dart` | Upgrades tab section/row/teaser DTOs and derived providers |
| `test/providers/upgrades_providers_test.dart` | Section filtering, row ordering, costs, rates, teasers, display names |
| `test/ui/features/upgrades/upgrades_screen_test.dart` | Rendering, bulk selector, Buy/Unlock dispatch, disabled states, responsive/a11y |

Modify:

| File | Purpose |
| --- | --- |
| `lib/ui/features/upgrades/upgrades_screen.dart` | Replace placeholder with real Upgrades tab |
| `test/ui/app_scaffold_test.dart` | Only if needed to keep tab integration assertions current |
| `test/architecture/*` | Only if adding a focused source guard is needed |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/**` | Existing commands/reducers/calculators already support this UI |
| `lib/data/**` | No persistence/schema work |
| `lib/providers/modal_providers.dart` and `lib/ui/features/modals/**` | Story 7.4 owns modal queue |
| `lib/ui/features/stats/**` and `lib/providers/stats_providers.dart` | Story 7.5 owns Stats |
| `lib/ui/features/settings/**` | Story 7.6 owns Settings |
| `lib/ui/features/leaders/**` | Story 7.8 owns Leaders |
| `assets/**` | No content population or display-name asset changes |
| `pubspec.yaml` | No new dependency |

### Testing Requirements

Provider tests can use `ProviderContainer` with `contentRegistryProvider` and `gameWorldProvider` overrides. Widget tests should use `ProviderScope` overrides and avoid real Drift.

Recommended provider-test shape:

```dart
final content = testMapperContentRegistry();
final notifier = TestGameWorldNotifier(
  content: content,
  initialState: GameState(
    countries: {
      // construct specific locked/unlocked country states
    },
    unlockedContinents: const {
      ContinentId('africa'): true,
    },
    totalInfluence: Influence(Decimal.parse('1000')),
  ),
);
final container = ProviderContainer(
  overrides: [
    contentRegistryProvider.overrideWith((_) async => content),
    gameWorldProvider.overrideWith((_) => notifier),
  ],
);
addTearDown(container.dispose);
```

Recommended widget-test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => spyNotifier),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const UpgradesScreen(),
    ),
  ),
);
await tester.pump();
```

Use a spy `GameWorldNotifier` for command-dispatch tests. For state-transition tests, a real `GameWorldNotifier` with fixture content is acceptable if it stays deterministic and does not touch Drift.

### Out of Scope

- Leaders tab, leader hire UI, leader upgrade UI, or leader accordion behavior.
- Global upgrades, research trees, diplomatic influence, prestige, or any new upgrade system.
- Purchase confirmation modal wiring for Buy/Unlock.
- Settings modal implementation or settings persistence.
- Stats route/provider changes.
- Modal queue behavior, modal host ordering, daily/achievement/offline modal changes.
- Content JSON expansion to all 79 countries, new country display-name fields, or asset edits.
- Drift schema, migrations, save repository changes, or generated Drift files.
- Game command/event/reducer changes unless a tiny command-result UI seam is explicitly chosen and tested.
- Map default launch/autofocus, tutorial behavior, continent progress bars, milestone tick indicators.
- SFX, haptics, flying numbers, pulses, celebrations, or animation polish.

### Latest Technical Information

- Flutter `SegmentedButton<T>` is a Material widget for selecting from a limited set of options; its `selected` set and `onSelectionChanged` callback are the correct single-select path for 1/10/25 bulk selection. Source: https://api.flutter.dev/flutter/material/SegmentedButton-class.html
- Flutter `ListView.builder` creates children on demand and benefits from a non-null `itemCount` for scroll extent estimation. Source: https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html
- Riverpod `select` lets consumers/providers listen to selected immutable properties instead of rebuilding on every state-object change. Use it where it materially reduces row churn. Source: https://riverpod.dev/docs/how_to/select
- Flutter `ScaffoldMessenger` is the built-in API for snack bars if command failures are surfaced later. Source: https://api.flutter.dev/flutter/material/ScaffoldMessenger-class.html

### Git Intelligence Summary

Recent commits are directly relevant:

- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` - current HUD, `CurrencyBadge`, Stats implementation, and Upgrades placeholder lineage.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` - tab order and `IndexedStack` are established.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` - token guardrails are active.
- `ef0faba feat: save recovery on corrupt database and related UI` - do not disturb boot/recovery paths.
- `c442514 feat: offline catchup and reward modal on resume` - do not disturb offline/modal ordering now generalized by Story 7.4.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.7]
- [Source: `_bmad-output/planning-artifacts/epics/epic-3-power-up-upgrades-leaders-and-automation.md` - Story 3.2]
- [Source: `_bmad-output/planning-artifacts/epics/epic-4-expand-unlocks-continents-and-completion-bonuses.md` - Stories 4.1 and 4.5]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR3, FR4, FR7, FR8, FR28, FR30, FR33, NFR18, NFR19, NFR21, NFR22, NFR27]
- [Source: `_bmad-output/planning-artifacts/gdd.md` - Core loop, Upgrade, Unlock, Level Progression, Controls and Input]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Riverpod, Navigation, Big Numbers, Multiplier Stack]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `lib/ui/features/upgrades/`, `lib/providers/`, architectural boundaries]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` - Widget -> Provider -> Notifier -> GameWorld and typed test patterns]
- [Source: `_bmad-output/project-context.md` - architecture boundaries, token rules, value objects, forbidden packages, accessibility]
- [Source: `_bmad-output/implementation-artifacts/7-3-global-hud-with-influence-and-intel-currency-badges.md` - CurrencyBadge, HUD, Upgrades placeholder]
- [Source: `_bmad-output/implementation-artifacts/7-4-sequential-modal-queue-with-priority.md` - modal queue ownership boundary]
- [Source: `_bmad-output/implementation-artifacts/7-5-stats-screen-reachable-from-hud.md` - `IncomeCalculator`/multiplier helper guardrails and concurrent stats ownership]
- [Source: `_bmad-output/implementation-artifacts/7-6-settings-modal-overlay-from-hud-gear-icon.md` - settings ownership boundary]
- [Source: `lib/ui/features/upgrades/upgrades_screen.dart` - placeholder to replace]
- [Source: `lib/ui/app_scaffold.dart` - tab order and `IndexedStack` integration]
- [Source: `lib/providers/feature_providers.dart` - next unlock and currency providers]
- [Source: `lib/game/game_command.dart` - `PurchaseUpgrade` and `UnlockCountry` commands]
- [Source: `lib/game/features/upgrades/upgrades_reducer.dart` - upgrade validation, cost, max-level cap, event]
- [Source: `lib/game/features/continents/unlocks_reducer.dart` - unlock validation and event]
- [Source: `lib/game/features/continents/next_unlock_selector.dart` - next unlock selector behavior]
- [Source: `lib/game/features/economy/income_calculator.dart` - current rate and upgrade cost source of truth]
- [Source: `lib/game/config/balance.dart` - max IP, bulk cost constants, IP multiplier]
- [Source: `lib/game/content/country_def.dart` and `continent_def.dart` - available display/content fields]
- [Source: `lib/ui/widgets/currency_badge.dart` - reusable currency display]
- [Source: `test/helpers/game_state_builder.dart` and `test/helpers/test_content_registry.dart` - fixture patterns]
- [Source: `test/architecture/ui_design_tokens_test.dart`, `no_duplicate_income_math_test.dart`, `game_boundary_test.dart` - guardrails]
- [Source: Flutter SegmentedButton API - https://api.flutter.dev/flutter/material/SegmentedButton-class.html]
- [Source: Flutter ListView.builder API - https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html]
- [Source: Riverpod select guide - https://riverpod.dev/docs/how_to/select]
- [Source: Flutter ScaffoldMessenger API - https://api.flutter.dev/flutter/material/ScaffoldMessenger-class.html]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Created `lib/providers/upgrades_providers.dart` with `UpgradesTabModel`, `ContinentUpgradeSection`, `CountryUpgradeRow`, `NextUnlockTeaserRow`, `UpgradePurchasePreview`, `TeaserKind` enum, `countryDisplayName` helper, `upgradePurchasePreview` pure function, and `upgradesTabModelProvider`.
- Replaced `lib/ui/features/upgrades/upgrades_screen.dart` placeholder with real `UpgradesScreen` (`ConsumerWidget`) using `ListView.builder`, `_UpgradesBody` (`StatefulWidget`) for per-country bulk state keyed by `CountryId`, `SegmentedButton<int>` for 1/10/25 bulk, `FilledButton.tonal` for Buy/Unlock, continent section headers, country upgrade cards, and teaser cards for all four `TeaserKind` states.
- Added 21 provider tests covering: display name formatting, locked continent filtering, unlocked country rows, income rate via `IncomeCalculator.compute`, bulk cost via `IncomeCalculator.upgradeCost`, level capping, affordability, teaser states, missing country state, section ordering, and tick-only banked-influence rebuild isolation.
- Added 15 widget tests covering: rendering, locked continent hidden, teaser display, empty state, Buy dispatch, bulk selection dispatch, Buy semantics, Buy disabled states, MAX badge, Unlock dispatch, Unlock disabled, bulk isolation across cards, overflow on narrow widths, large numbers, world complete state.
- Code review patch pass: narrowed `upgradesTabModelProvider` to an immutable upgrade-relevant `GameState` slice and made Buy semantics country/bulk-specific.
- All architecture guardrails pass (ui_design_tokens, no_duplicate_income_math, game_boundary).
- No changes to `lib/game/**`, `lib/data/**`, `pubspec.yaml`, settings, stats, modal queue, or AppScaffold.
- Full flutter test: 943 tests passed (no regressions).

### File List

- `lib/providers/upgrades_providers.dart` (created)
- `lib/ui/features/upgrades/upgrades_screen.dart` (modified)
- `test/providers/upgrades_providers_test.dart` (created)
- `test/ui/features/upgrades/upgrades_screen_test.dart` (created)

## Change Log

- Story 7.7 implementation: Upgrades tab — unlocked country cards, bulk selector, Buy/Unlock commands, continent teaser, provider DTOs, 36 tests added (Date: 2026-05-15)
- Story 7.7 code review patch pass: provider rebuild isolation + Buy semantics (Date: 2026-05-15)

## Story Completion Status

done
