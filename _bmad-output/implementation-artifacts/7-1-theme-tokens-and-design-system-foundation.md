# Story 7.1: Theme Tokens and Design System Foundation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

This is the first Epic 7 story. It may start while Story 6.6 is still in progress, but it must not undo any boot, save-recovery, offline-catchup, or offline-reward-modal behavior from Epic 6.

Before coding, verify:

- `lib/ui/theme/app_theme.dart` already exists and returns `appTheme()`.
- `lib/ui/theme/country_colors.dart` already exists and is consumed by `MapScreen` and `CountryPaints`.
- `lib/ui/features/map/country_paints.dart` still caches `Paint` objects outside the painter hot path.
- `lib/app.dart` still watches `offlineRewardModalControllerProvider.notifier` before `offlineCatchupBootProvider`; preserve that ordering when applying theme to `MaterialApp` branches.
- If Story 6.6 has modified `SaveRecoveryScreen` or `app.dart`, integrate theme tokens with those changes instead of reverting recovery behavior.

If any of these files moved, follow the current codebase shape and keep compatibility imports/exports where practical. Do not introduce navigation, HUD, modal queue, settings persistence, Upgrades tab, or Leaders tab work in this story.

## Story

As a developer,
I want a single `appTheme()` builder composing `ThemeData`, game `ThemeExtension`s, Fredoka typography via `google_fonts`, and a `Spacing` constants class,
so that every widget reads colors, spacing, and typography from one source.

## Acceptance Criteria

1. **Given** `lib/ui/theme/app_theme.dart`
   **When** `appTheme()` is called
   **Then** it returns the single app theme used by all runtime `MaterialApp` branches and composes:
   - a Flutter `ThemeData` / `ColorScheme`;
   - Fredoka typography via `GoogleFonts.fredokaTextTheme(...)`;
   - `CountryColors`;
   - `HudPalette`;
   - `MilestoneColors`.

2. **Given** `Spacing`
   **When** used by widgets
   **Then** it exposes exactly these public constants as `static const double`: `xs = 4`, `sm = 8`, `md = 16`, `lg = 24`, `xl = 32`, `xxl = 48`.

3. **Given** any non-debug widget under `lib/ui/**`
   **When** it references a color, spacing, or font
   **Then** it uses `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, `Theme.of(context).extension<CountryColors>()!`, `Theme.of(context).extension<HudPalette>()!`, `Theme.of(context).extension<MilestoneColors>()!`, or `Spacing.*`; it must not introduce raw `Color(...)`, `Colors.*`, `TextStyle(fontSize: ...)`, or numeric `EdgeInsets`/`SizedBox` spacing literals in widgets.

4. **Given** the existing map renderer
   **When** this theme story lands
   **Then** `CountryColors` remains the map color source, `CountryPaints` still pre-allocates `Paint`s from the active theme, and `WorldMapPainter` still avoids allocating paints in `paint()`.

5. **Given** the existing temporary Influence pill in `MapScreen`
   **When** it renders before Story 7.3 replaces it with the real HUD
   **Then** it uses `HudPalette`, `Spacing`, and `textTheme` tokens while preserving the current displayed Influence value and map interaction behavior.

6. **Given** loading, boot-error, save-recovery, support, and offline-reward UI
   **When** rendered
   **Then** each screen/modal has a themed `MaterialApp`/`Theme` ancestor where needed and uses tokens for colors, spacing, and text styles without changing its recovery, diagnostics, or modal behavior.

7. **Given** a future story adds a hardcoded color literal to a non-theme, non-debug widget
   **When** tests run
   **Then** a guardrail catches it. Minimum required implementation: an architecture test scanning `lib/ui/**` and failing on raw `Color(...)` / `Colors.*` outside allowed theme/debug locations. A full `custom_lint` rule is allowed as a stretch goal but is not required.

8. **Given** the theme extensions
   **When** `flutter test test/ui/theme` runs
   **Then** each extension has tests for default registration through `appTheme()`, `copyWith`, `lerp`, equality/hash stability, and required token values.

9. **Given** the app is still pre-Epic-7 shell
   **When** this story is complete
   **Then** no bottom navigation, global HUD, generic modal queue, settings modal, Upgrades screen, Leaders screen, or Stats screen is implemented. Those remain in Stories 7.2 through 7.10.

## Tasks / Subtasks

- [x] Task 1: Expand the theme foundation (AC: #1, #2, #4, #8)
  - [x] 1.1 Keep `lib/ui/theme/country_colors.dart` as the existing public import path unless there is a compelling reason to move it. If moving into `lib/ui/theme/extensions/`, leave a compatibility export at the old path.
  - [x] 1.2 Add `lib/ui/theme/spacing.dart` with the exact `Spacing.xs/sm/md/lg/xl/xxl` constants from AC #2. Do not use screaming-snake-case names.
  - [x] 1.3 Add `lib/ui/theme/hud_palette.dart` as a `ThemeExtension<HudPalette>` for shell/HUD/currency presentation. Include enough tokens for current temporary Influence UI and upcoming Story 7.3, such as badge background, badge foreground, influence accent, intel accent, icon foreground, and elevated surface.
  - [x] 1.4 Add `lib/ui/theme/milestone_colors.dart` as a `ThemeExtension<MilestoneColors>` for continent progress/milestone visuals needed by Stories 7.10 and Epic 8. Include track, tick, 25/50/75/100 milestone, and pulse/accent colors.
  - [x] 1.5 Update `CountryColors` rather than replacing it. Preserve existing fields used by `CountryPaints`; add only story-relevant missing fields such as `conquered` and `golden` if needed by the architecture/future stories.
  - [x] 1.6 Ensure every ThemeExtension has `const defaults`, `copyWith`, `lerp`, `==`, and `hashCode`. For map fields, keep continent fill keys stable for all seven continents.
  - [x] 1.7 Optionally add `lib/ui/theme/typography.dart` if it keeps `app_theme.dart` small. Typography must still flow into `ThemeData.textTheme`, not a parallel widget-only style registry.
  - [x] 1.8 Update `appTheme()` so it composes the color scheme, Fredoka text theme, and all extensions in one place. Do not add dark mode; architecture says single v1 theme.

- [x] Task 2: Apply the single theme consistently at app roots (AC: #1, #6)
  - [x] 2.1 Update every `MaterialApp` created in `lib/app.dart` to use the same cached `_theme = appTheme()`.
  - [x] 2.2 Ensure early loading and boot-error branches still have `Directionality`, `Material`, and theme context. If a branch currently returns a bare `Scaffold`/screen, wrap it in a `MaterialApp(theme: _theme, home: ...)` without changing bootstrap sequencing.
  - [x] 2.3 Preserve database bootstrap, content registry, persisted snapshot, offline catch-up, save repository bootstrap, and offline modal host ordering. This story should be visually foundational only.
  - [x] 2.4 Do not move global setup into `main.dart`.

- [x] Task 3: Refactor existing non-debug UI to consume tokens (AC: #3, #5, #6)
  - [x] 3.1 Update `lib/ui/features/map/map_screen.dart` temporary Influence pill to use `HudPalette`, `Spacing`, `theme.textTheme`, and a tokenized border radius/shape. Do not implement Story 7.3's real HUD.
  - [x] 3.2 Update `lib/ui/features/modals/offline_reward_modal.dart` to replace raw spacing literals with `Spacing.*`. Keep `Influence.format()`, elapsed formatting, `Collect` behavior, non-overflow layout, and semantics unchanged.
  - [x] 3.3 Update `lib/ui/boot_error_screen.dart`, `lib/ui/save_recovery_screen.dart`, `lib/ui/fallback_error_widget.dart`, and `lib/ui/debug/support_screen.dart` to use `colorScheme`, `textTheme`, `HudPalette` when appropriate, and `Spacing.*`.
  - [x] 3.4 Exclude throwaway spike/debug painter files from required token refactors only if they are already excluded from analyzer or clearly marked debug-only. Do not use spike files as a pattern for production widgets.
  - [x] 3.5 Keep all existing semantics labels, recovery actions, clipboard behavior, and modal dismissal rules intact.

- [x] Task 4: Add token guardrails (AC: #3, #7)
  - [x] 4.1 Add `test/architecture/ui_design_tokens_test.dart` or equivalent.
  - [x] 4.2 The test must scan production widget files under `lib/ui/**` and fail if raw `Color(...)` or `Colors.*` appears outside allowlisted paths:
    - `lib/ui/theme/**`
    - generated files if any
    - explicitly debug-only spike files such as `lib/ui/debug/spike_*`
  - [x] 4.3 Keep the allowlist narrow and documented in the test. Do not broadly allow all `lib/ui/debug/**` unless `support_screen.dart` has been tokenized or intentionally justified.
  - [x] 4.4 Add review guidance in the test failure message or a short comment: spacing and typography literals are also forbidden in widgets and must use `Spacing.*` / `textTheme`, even if the automated regex initially enforces only color literals.
  - [x] 4.5 Stretch goal only: add a `custom_lint` rule for color/spacing/text-style literals. If chosen, do not add new packages without checking the dependency impact.

- [x] Task 5: Theme tests (AC: #1, #2, #4, #8)
  - [x] 5.1 Extend `test/ui/theme/country_colors_test.dart` for any new `CountryColors` fields and stable continent fill coverage.
  - [x] 5.2 Add `test/ui/theme/app_theme_test.dart` proving `appTheme().extension<CountryColors>()`, `HudPalette`, and `MilestoneColors` are non-null and `textTheme` uses Fredoka-derived styles.
  - [x] 5.3 Add `test/ui/theme/spacing_test.dart` covering the exact six values and type.
  - [x] 5.4 Add `test/ui/theme/hud_palette_test.dart` and `test/ui/theme/milestone_colors_test.dart` for defaults, `copyWith`, `lerp`, equality, and hash behavior.
  - [x] 5.5 Update impacted widget tests to pump `MaterialApp(theme: appTheme(), ...)` if they currently rely on default Material styling.

- [x] Task 6: Verification (AC: all)
  - [x] 6.1 Run `dart format --set-exit-if-changed` on changed Dart files.
  - [x] 6.2 Run:
    - `flutter test test/ui/theme`
    - `flutter test test/architecture`
    - `flutter test test/ui/features/map`
    - `flutter test test/ui/features/modals`
  - [x] 6.3 Run `flutter analyze`.
  - [x] 6.4 If Story 6.6 has landed before implementation, run its recovery-screen tests too because this story touches shared recovery UI styling.
  - [x] 6.5 Run full `flutter test` if time permits.

### Review Findings

- [x] [Review][Patch] Remove or complete the partial Fredoka asset bundle; Story 7.1 marks font asset bundling out of scope unless a cold-start regression was measured, and bundling only `Fredoka-Regular.ttf` still leaves non-400 Fredoka variants to runtime fetching. [`pubspec.yaml`:100]
- [x] [Review][Patch] Constrain the temporary Influence pill text so late-game abbreviated totals and larger text scales cannot overflow the map overlay. [`lib/ui/features/map/map_screen.dart`:214]
- [x] [Review][Patch] Make `CountryColors.hashCode` consistent with `_mapsEqual` for equal `continentFills` maps inserted in different orders, and add the required hash-stability regression coverage. [`lib/ui/theme/country_colors.dart`:118]

## Dev Notes

### Implementation Scope

This story creates the design-token foundation for the rest of Epic 7. It is not the shell implementation. The only visible production changes should be that existing screens/widgets pull colors, spacing, and text styles from the theme and look consistent enough for later shell work.

The intended token access pattern is:

```dart
final theme = Theme.of(context);
final hud = theme.extension<HudPalette>()!;
final countries = theme.extension<CountryColors>()!;

Container(
  padding: const EdgeInsets.symmetric(
    horizontal: Spacing.md,
    vertical: Spacing.sm,
  ),
  color: hud.badgeBackground,
  child: Text(
    value,
    style: theme.textTheme.labelLarge?.copyWith(color: hud.badgeForeground),
  ),
);
```

Use `ColorScheme` for standard Material surfaces/errors and ThemeExtensions for game-specific palettes. Raw colors belong in theme token definitions only.

### Current Codebase Observations

- `lib/ui/theme/app_theme.dart` currently only applies Fredoka and `CountryColors.defaults`.
- `lib/ui/theme/country_colors.dart` already defines a `ThemeExtension<CountryColors>` consumed by `MapScreen` and `CountryPaints`.
- `lib/ui/features/map/country_paints.dart` correctly pre-allocates `Paint` objects from `CountryColors`; preserve this to avoid per-frame allocations.
- `lib/ui/features/map/map_screen.dart` still has hardcoded overlay colors, text style, padding, and radius in the temporary Influence pill. This is the most visible production token cleanup.
- `OfflineRewardModal` already uses `colorScheme`/`textTheme` for colors and text; it mainly needs `Spacing`.
- Boot/recovery/support screens contain several raw colors, font sizes, and spacing literals. Tokenize those without changing recovery semantics.
- There is no UX design spec file in `_bmad-output/planning-artifacts`; use the GDD, Epic 7 story text, and architecture as the sources of truth for this foundation.

### Previous Work Intelligence

- Story 6.5 explicitly deferred the full design-token system to Story 7.1 and used `Theme.of(context)` only as a temporary bridge. This story should now provide the reusable palettes that future HUD/modals/screens consume.
- Story 6.5 review found that boot-time event ordering matters. When touching `app.dart`, keep the offline modal queue subscribed before offline catch-up emits `OfflineEarningsApplied`.
- Story 6.6 is in progress and may edit `SaveRecoveryScreen` and `app.dart`. Treat any local changes there as authoritative and layer token usage over them rather than overwriting them.
- Recent commits focus on offline catch-up, reward modal, migrations, and save recovery. This story should avoid data-layer, migration, and event contracts entirely.

### Architecture Compliance

- Theme files live under `lib/ui/theme/`; Flutter imports stay out of `lib/game/**`.
- Do not add packages. `google_fonts` already exists in `pubspec.yaml`.
- Do not bump `google_fonts`, Flutter, Riverpod, Drift, or any other dependency.
- Do not introduce `go_router`, `freezed`, `flame`, a map library, or a service locator.
- Do not add a second ticker, persistence write path, or new `GameEvent`.
- Use Riverpod/provider patterns only where needed for existing widgets; theme tokens should be plain Flutter theme data.
- Every interactive widget touched must retain or improve `Semantics`.

### Library / Framework Requirements

- Flutter `ThemeExtension` is the correct mechanism for custom game palettes. Each extension must implement `copyWith` and `lerp` so Flutter can interpolate theme values during theme changes. [Source: Flutter ThemeExtension API](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)
- `google_fonts` supports applying a font across a `TextTheme` via `GoogleFonts.<font>TextTheme(baseTextTheme)`. Keep using Fredoka through `appTheme()`. [Source: google_fonts package docs](https://pub.dev/packages/google_fonts)
- Pub.dev currently documents newer `google_fonts` versions than this repo uses, but this project is pinned by `pubspec.yaml`/`pubspec.lock` (`google_fonts` constraint `^6.2.1`, lockfile currently `6.3.3`). Do not upgrade as part of this story.
- `google_fonts` can use bundled font files when matching assets are listed in `pubspec.yaml`; architecture says runtime download/cache is acceptable for v1, with bundling considered only if cold-start misses the budget.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/ui/theme/spacing.dart` | Exact spacing constants `xs/sm/md/lg/xl/xxl` |
| `lib/ui/theme/hud_palette.dart` | HUD/currency/shell game palette ThemeExtension |
| `lib/ui/theme/milestone_colors.dart` | Progress/milestone ThemeExtension |
| `test/ui/theme/app_theme_test.dart` | Theme registration and Fredoka coverage |
| `test/ui/theme/spacing_test.dart` | Exact spacing values |
| `test/ui/theme/hud_palette_test.dart` | HudPalette ThemeExtension behavior |
| `test/ui/theme/milestone_colors_test.dart` | MilestoneColors ThemeExtension behavior |
| `test/architecture/ui_design_tokens_test.dart` | Raw color guardrail for production UI |

**Modify:**

| File | Purpose |
|---|---|
| `lib/ui/theme/app_theme.dart` | Compose all theme data/extensions |
| `lib/ui/theme/country_colors.dart` | Preserve/extend existing CountryColors if needed |
| `lib/ui/features/map/map_screen.dart` | Tokenize temporary Influence pill |
| `lib/ui/features/modals/offline_reward_modal.dart` | Use Spacing constants |
| `lib/app.dart` | Apply same theme to all MaterialApp branches while preserving boot order |
| `lib/ui/boot_error_screen.dart` | Tokenize error UI |
| `lib/ui/save_recovery_screen.dart` | Tokenize recovery UI without changing actions |
| `lib/ui/fallback_error_widget.dart` | Tokenize fallback UI |
| `lib/ui/debug/support_screen.dart` | Tokenize support UI |
| `test/ui/theme/country_colors_test.dart` | Update for any CountryColors additions |

### Out of Scope

- Bottom navigation and `IndexedStack` (Story 7.2).
- Real global HUD, `CurrencyBadge`, animated counters, stats/settings buttons (Story 7.3).
- Generic priority modal queue (Story 7.4).
- Settings persistence and settings modal (Story 7.6).
- Upgrades, Leaders, Stats, and progression indicator screens (Stories 7.5, 7.7, 7.8, 7.10).
- Font asset bundling unless a cold-start regression is measured during implementation.
- Full custom lint package setup unless chosen as a stretch goal.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.1]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - NFR21, NFR23, UI Shell & HUD]
- [Source: `_bmad-output/planning-artifacts/gdd.md` - Art and Audio Direction, Technical Specifications, Asset Requirements]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Theme & Design Tokens]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `lib/ui/theme` layout and naming conventions]
- [Source: `_bmad-output/project-context.md` - Technology Stack, Code Organization Rules, Anti-patterns]
- [Source: `lib/ui/theme/app_theme.dart` - current appTheme baseline]
- [Source: `lib/ui/theme/country_colors.dart` - existing CountryColors extension]
- [Source: `lib/ui/features/map/country_paints.dart` - paint caching pattern]
- [Source: `lib/ui/features/map/map_screen.dart` - current temporary Influence pill]
- [Source: `pubspec.yaml` and `pubspec.lock` - existing google_fonts dependency]
- [Source: Flutter ThemeExtension API - https://api.flutter.dev/flutter/material/ThemeExtension-class.html]
- [Source: google_fonts package docs - https://pub.dev/packages/google_fonts]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent).

### Debug Log References

### Completion Notes List

- Implemented `Spacing`, `HudPalette`, `MilestoneColors`, extended `CountryColors` (conquered/golden), `appTheme()` with Material 3 `ColorScheme` + Fredoka + all extensions.
- Themed every `MaterialApp` bootstrap branch in `app.dart`; `BootErrorScreen`, `SaveRecoveryScreen`, `FallbackErrorWidget` use `appTheme()`; tokenized map Influence pill, offline reward spacing, support screen, map load states.
- Added `lib/ui/theme/typography.dart` with `appTextTheme` (Fredoka) used by `appTheme()`.
- Added `test/architecture/ui_design_tokens_test.dart` color literal guardrail (allowlist: `lib/ui/theme/**`, `lib/ui/debug/spike_*`).
- Stretch `custom_lint` (Task 4.5): not implemented.
- Review patches removed app-bundled Fredoka assets, added test-only Google Fonts fixture loading, capped the temporary Influence pill width, and stabilized `CountryColors.hashCode`.
- `dart format`, `flutter analyze`, and full `flutter test` (832 passed).

### File List

- `lib/ui/theme/spacing.dart`
- `lib/ui/theme/hud_palette.dart`
- `lib/ui/theme/milestone_colors.dart`
- `lib/ui/theme/typography.dart`
- `lib/ui/theme/app_theme.dart`
- `lib/ui/theme/country_colors.dart`
- `lib/app.dart`
- `lib/ui/features/map/map_screen.dart`
- `lib/ui/features/modals/offline_reward_modal.dart`
- `lib/ui/boot_error_screen.dart`
- `lib/ui/save_recovery_screen.dart`
- `lib/ui/fallback_error_widget.dart`
- `lib/ui/debug/support_screen.dart`
- `test/architecture/ui_design_tokens_test.dart`
- `test/flutter_test_config.dart`
- `test/fixtures/google_fonts/4005e941354c2352a3570e1f7c54b10005633b5f2869eeb63867754c0c680e49.ttf`
- `test/fixtures/google_fonts/125cc34039587d0926961da82659002e686518af02c0771f7224c40a63f2c144.ttf`
- `test/fixtures/google_fonts/fa3c58dcf129a67237d2f4284691f0cb1455816149c446a873d29e3868dcc53a.ttf`
- `test/fixtures/google_fonts/70d1c0745883e965e3ae80c61a32ee2e547f444e0804649d673a700989447a29.ttf`
- `test/fixtures/google_fonts/e646f1ecd8e27d6468396ddecc96774207d41706edee7fd82d1a1385ba98d29f.ttf`
- `test/ui/theme/app_theme_test.dart`
- `test/ui/theme/spacing_test.dart`
- `test/ui/theme/hud_palette_test.dart`
- `test/ui/theme/milestone_colors_test.dart`
- `test/ui/theme/country_colors_test.dart`
- `test/helpers/map_screen_test_providers.dart`
- `test/ui/features/map/world_map_painter_test.dart`
- `test/providers/offline_catchup_boot_provider_test.dart` (dart format only)
