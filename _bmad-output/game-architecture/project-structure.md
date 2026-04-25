# Project Structure

### Organization Pattern: Layered + Feature Hybrid

Three top-level layers reflecting the headless-simulation invariant:

- **`lib/game/`** — pure-Dart simulation (NO Flutter imports)
- **`lib/data/`** — persistence layer (Drift, repositories, mappers)
- **`lib/ui/`** — Flutter widgets, painter, theme

Plus supporting layers: **`lib/services/`** (Flutter-aware singletons that subscribe to game events), **`lib/providers/`** (Riverpod composition root / DI), **`lib/utils/`** (leaf-level helpers).

Within `lib/game/` and `lib/ui/`, code is grouped **by feature** (countries, upgrades, leaders, missions, etc.) so a story touches one feature folder per layer.

**Rationale:** The critical invariant is "simulation is headless." Encoding that as a top-level `game/` vs `ui/` split makes violations visible in any PR diff.

### Directory Structure

```
global-domination-flutter/
├── assets/
│   ├── audio/                    # 8 SFX files (present)
│   ├── geo/
│   │   └── countries.geojson.json
│   └── data/                     # content JSON (NEW)
│       ├── countries.json
│       ├── continents.json
│       ├── leaders.json
│       ├── achievements.json
│       ├── missions.json
│       └── global_upgrades.json
│
├── lib/
│   ├── main.dart                 # entrypoint: global handlers + Riverpod scope
│   ├── app.dart                  # GlobalDominationApp (MaterialApp + theme)
│   │
│   ├── game/                     # ⚠ NO FLUTTER IMPORTS ALLOWED
│   │   ├── game_world.dart       # root aggregator (tick, applyEvent)
│   │   ├── game_state.dart       # immutable snapshot
│   │   ├── game_command.dart     # sealed command hierarchy (input → sim)
│   │   ├── game_event.dart       # sealed event hierarchy (sim → outside)
│   │   ├── game_error.dart       # sealed error hierarchy
│   │   ├── config/
│   │   │   ├── constants.dart
│   │   │   └── balance.dart
│   │   ├── values/
│   │   │   ├── influence.dart    # wraps Decimal
│   │   │   ├── intel.dart
│   │   │   ├── country_id.dart
│   │   │   └── result.dart
│   │   ├── content/
│   │   │   ├── content_registry.dart
│   │   │   ├── country_def.dart
│   │   │   ├── continent_def.dart
│   │   │   ├── leader_def.dart
│   │   │   ├── achievement_def.dart
│   │   │   └── mission_def.dart
│   │   ├── features/
│   │   │   ├── countries/     { state, reducer }
│   │   │   ├── upgrades/      { state, reducer, bulk_purchase }
│   │   │   ├── leaders/       { state, reducer }
│   │   │   ├── continents/    { state, reducer }
│   │   │   ├── missions/      { state, reducer }
│   │   │   ├── achievements/  { state, reducer }
│   │   │   ├── boosts/        { state, reducer }
│   │   │   ├── goldens/       { state, scheduler, reducer }
│   │   │   ├── daily_rewards/ { state, reducer }        # 7-day streak
│   │   │   ├── economy/
│   │   │   │   ├── income_calculator.dart   # THE multiplier stack (auth)
│   │   │   │   └── offline_catchup.dart
│   │   │   └── tutorial/      { state }
│   │   └── support/
│   │       ├── clock.dart     # injectable
│   │       ├── id_gen.dart
│   │       └── rng.dart       # seedable for determinism
│   │
│   ├── data/                     # persistence (Drift + repositories)
│   │   ├── database/
│   │   │   ├── app_database.dart
│   │   │   ├── tables/   { meta, countries, leaders, upgrades, achievements,
│   │   │   │               missions, settings, crash_logs, event_log }
│   │   │   ├── converters/  { decimal_converter, enum_converter }
│   │   │   └── migrations/  { migration_strategy, vN_to_vN+1 }
│   │   ├── repositories/ { save, settings, crash_log }
│   │   └── mappers/      { game_state_mapper }
│   │
│   ├── services/                 # Flutter-aware singletons (via Riverpod DI)
│   │   ├── audio_service.dart         # subscribes GameEvent → audioplayers
│   │   ├── haptics_service.dart
│   │   ├── crash_reporter.dart
│   │   ├── logger_setup.dart
│   │   └── lifecycle_observer.dart    # pauses ticker + offline catchup
│   │
│   ├── ui/
│   │   ├── app_scaffold.dart          # bottom nav + IndexedStack
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── extensions/ { country_colors, hud_palette, milestone_colors }
│   │   │   ├── spacing.dart
│   │   │   └── typography.dart
│   │   ├── widgets/          # cross-feature shared widgets
│   │   │   ├── influence_text.dart
│   │   │   ├── cost_badge.dart
│   │   │   ├── error_boundary.dart
│   │   │   ├── flying_number.dart
│   │   │   └── animated_counter.dart
│   │   ├── features/
│   │   │   ├── map/
│   │   │   │   ├── map_screen.dart
│   │   │   │   ├── world_map_view.dart
│   │   │   │   ├── painter/  { world_map_painter, layers/*, projection }
│   │   │   │   ├── hit_test/ { polygon_hit_tester }
│   │   │   │   ├── gestures/ { map_gesture_handler }
│   │   │   │   └── overlays/ { golden_opportunity_overlay, takeover_animation }
│   │   │   ├── upgrades/     { upgrades_screen, upgrade_card, bulk_toggle }
│   │   │   ├── leaders/      { leaders_screen, leader_card }
│   │   │   ├── missions/     { missions_screen, mission_card }
│   │   │   ├── stats/        { stats_screen }
│   │   │   ├── hud/          { global_hud, influence_meter, active_boost_indicator }
│   │   │   ├── modals/       { offline_reward, purchase_confirm,
│   │   │   │                   continent_complete, achievement_earned }
│   │   │   └── tutorial/     { tutorial_overlay, tutorial_steps }
│   │   └── debug/                     # kDebugMode-only
│   │       ├── debug_overlay.dart
│   │       ├── cheat_panel.dart
│   │       ├── state_inspector.dart
│   │       ├── event_log_viewer.dart
│   │       └── save_viewer.dart
│   │
│   ├── providers/                     # Riverpod = DI container
│   │   ├── app_providers.dart         # clock, logger, flags
│   │   ├── game_providers.dart        # gameWorld, gameState, events
│   │   ├── data_providers.dart        # database, repositories
│   │   ├── service_providers.dart     # audio, haptics, crash
│   │   └── feature_providers.dart     # derived selectors
│   │
│   └── utils/
│       ├── formatters/ { influence_formatter, duration_formatter }
│       └── constants/  { app_constants }
│
├── test/
│   ├── game/                          # pure-Dart tests, no Flutter binding
│   │   ├── game_world_test.dart
│   │   ├── features/
│   │   │   └── economy/
│   │   │       ├── income_calculator_test.dart   # multiplier stack order
│   │   │       └── offline_catchup_test.dart     # fake Clock
│   │   └── values/
│   │       └── influence_precision_test.dart     # 1e38+ property test
│   ├── data/  { app_database, migrations/*, repositories/* }
│   ├── services/
│   ├── ui/    # widget tests
│   └── helpers/ { fake_clock, fake_database, game_world_builder }
│
├── integration_test/
│   ├── golden_path_test.dart
│   └── offline_catchup_test.dart
│
├── android/, ios/                     # active platforms
├── web/, windows/, macos/, linux/     # inert — retain for future
├── docs/                              # existing project docs
├── _bmad/                             # BMAD tooling
├── _bmad-output/
│   └── game-architecture.md           # this document
├── analysis_options.yaml
├── pubspec.yaml
├── .mcp.json
└── README.md
```

### System → Location Mapping

| System | Home | Responsibility |
|---|---|---|
| GameWorld simulation | `lib/game/game_world.dart` + `lib/game/features/*/reducer.dart` | Pure-Dart mechanics |
| World map renderer | `lib/ui/features/map/painter/` | CustomPainter + layers |
| Big-number economy | `lib/game/values/influence.dart` + `lib/utils/formatters/influence_formatter.dart` | Value objects, abbreviations |
| Persistence | `lib/data/database/` + `lib/data/repositories/save_repository.dart` | Schema, migrations, writes |
| Offline earnings | `lib/game/features/economy/offline_catchup.dart` + `lib/services/lifecycle_observer.dart` | Deterministic, injectable clock |
| Upgrade & Leader | `lib/game/features/{upgrades,leaders}/` + `lib/ui/features/{upgrades,leaders}/` |  |
| Continent gating | `lib/game/features/continents/` | Unlock thresholds, milestones |
| Active play (Goldens/Boosts/Missions) | `lib/game/features/{goldens,boosts,missions}/` | Schedulers + reducers |
| Event bus | `lib/game/game_event.dart` (stream owned by `GameWorld`) | Sealed event types |
| Sound + haptics | `lib/services/audio_service.dart`, `haptics_service.dart` | Subscribe to event stream |
| UI shell + HUD + nav | `lib/ui/app_scaffold.dart` + `lib/ui/features/hud/` | Bottom nav, IndexedStack, HUD |
| Tutorial | `lib/game/features/tutorial/` (state) + `lib/ui/features/tutorial/` (overlay) |  |
| Accessibility | Woven through `lib/ui/` — every interactive widget wraps in `Semantics` |  |
| DI container | `lib/providers/` | Riverpod providers |
| Multiplier stack | `lib/game/features/economy/income_calculator.dart` | Single source of truth |

### Naming Conventions

**Files:** `snake_case.dart`; one public class per file (sealed hierarchies excepted). Tests mirror source with `_test.dart` suffix.

**Drift tables:** `countries_table.dart` exports `@DataClassName('Country') class Countries extends Table { … }` — plural table, singular row class.

**Code elements:**

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `GameWorld`, `WorldMapPainter` |
| Mixins | PascalCase | `LoggerMixin` |
| Enums + values | PascalCase / camelCase | `enum LeaderTier { none, tier1, tier2, tier3 }` |
| Sealed variants | PascalCase | `CountryUnlocked`, `LeaderHired` |
| Functions / methods | camelCase | `applyEvent`, `computeIncome` |
| Variables / parameters | camelCase | `totalInfluence`, `elapsed` |
| Private members | leading `_` | `_state`, `_reduce` |
| Top-level / class `const`s | camelCase (Dart convention — NOT SCREAMING_SNAKE) | `Spacing.md`, `BalanceConfig.ipCostMultiplier` |

**Game assets:**

| Asset | Convention | Example |
|---|---|---|
| SFX | `snake_case.mp3` | `collect.mp3`, `continent_complete.mp3` |
| GeoJSON | as-is | `countries.geojson.json` |
| Content JSON | `snake_case.json` | `countries.json`, `global_upgrades.json` |
| Fonts | runtime via `google_fonts` — no bundled files | |

**Commands vs Events:**

- **Commands** (input to sim): imperative/infinitive → `PurchaseUpgrade`, `HireLeader`, `ClaimGolden`, `ActivateBoost`, `TapCountry`
- **Events** (output from sim): past tense → `UpgradePurchased`, `LeaderHired`, `GoldenClaimed`, `BoostActivated`, `CountryTapped`

Both are sealed classes.

### Architectural Boundaries (enforced, non-negotiable)

1. **No Flutter imports in `lib/game/`.** Enforced via a `custom_lint` rule or CI grep. Breakage is a test failure, not a style suggestion.
2. **`lib/game/` never imports from `lib/data/`.** Direction: `data/` → `game/` (data maps TO sim types). Reverse is forbidden.
3. **UI never touches Drift directly.** UI → Riverpod providers → repositories → database.
4. **UI never mutates `GameState`.** UI emits `GameCommand` via `gameWorldProvider.notifier.apply(cmd)`.
5. **Services subscribe, never emit game events.** Only UI (user intent) and `GameLoop` (time) drive the sim.
6. **`utils/` is leaf-level.** No imports from `game/`, `data/`, `ui/`, `services/`, `providers/`.
7. **Providers are the composition root.** Only `providers/` imports `game/`+`data/`+`services/`. Widgets access them via `ref.watch`/`ref.read`.

### Dependency Graph

```
ui/         → providers/, utils/, services/ (types only)
services/   → game/ (events/state)
data/       → game/ (types for mapping)
providers/  → game/, data/, services/
game/       → (nothing — island of purity)
utils/      → (leaf)
```

Any arrow pointing the wrong way is an architectural violation.

---
