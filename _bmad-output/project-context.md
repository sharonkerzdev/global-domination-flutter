---
project_name: 'global-domination-flutter'
user_name: 'Sharon'
date: '2026-04-21'
sections_completed:
  [
    'technology_stack',
    'engine_rules',
    'performance_rules',
    'organization_rules',
    'testing_rules',
    'platform_rules',
    'anti_patterns',
  ]
status: 'complete'
optimized_for_llm: true
existing_patterns_found: 11
source_of_truth: '_bmad-output/game-architecture.md'
---

# Project Context for AI Agents

_Critical rules and patterns that AI agents MUST follow when implementing code in Global Domination. Authoritative source: [game-architecture.md](game-architecture.md). This file is the LLM-optimized digest — when in doubt, read architecture._

---

## Technology Stack & Versions

**Exact pinned versions (from [pubspec.yaml](../pubspec.yaml)) — do not bump without explicit approval:**

- **Flutter SDK:** 3.41.6 stable (Dart SDK `^3.11.4`)
- **State / DI:** `riverpod: ^2.6.1`, `flutter_riverpod: ^2.6.1` — no `riverpod_generator` for v1 (avoid `build_runner` churn)
- **Persistence:** `drift: ^2.26.1`, `sqlite3_flutter_libs: ^0.5.25`, `drift_dev: ^2.26.1`, `build_runner: ^2.4.14`, `path_provider: ^2.1.5`, `path: ^1.9.0`
- **Audio:** `audioplayers: ^6.4.0` (8 SFX assets under `assets/audio/`)
- **Fonts:** `google_fonts: ^6.2.1` (Fredoka, runtime-downloaded)
- **Big numbers:** `decimal: ^3.0.2` — MUST wrap in `Influence` / `Intel` value objects
- **Utils:** `collection: ^1.19.1`
- **Lints:** `flutter_lints: ^6.0.0`

**Forbidden packages (do NOT add without discussion):**

- `flame` or any game engine layer — rejected in architecture
- `freezed` — manual `copyWith` until type count exceeds ~30
- `go_router` / `auto_route` — Navigator 1.0 + `IndexedStack` is the decision
- `get_it` — Riverpod IS the DI container
- Any external map library (MapLibre, flutter_map, etc.) — custom `CustomPainter` over GeoJSON is mandatory
- Any analytics / crash SDK (Crashlytics, Sentry) for v1 — deferred with monetization (Epic 13)

**Platforms:** iOS 16.0+, Android API 21+ (portrait-locked). `web/`, `windows/`, `macos/`, `linux/` folders are inert — retain, do not add code under them.

---

## Critical Implementation Rules

### Engine-Specific Rules (Flutter / Dart)

**Architectural boundaries — non-negotiable, enforced as test/CI failures:**

1. **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only. This is the headless-simulation invariant and the reason the codebase can unit-test multi-hour offline catch-ups.
2. **`lib/game/` never imports from `lib/data/`.** Direction: `data/ → game/` (mappers convert DB rows to sim types). Reverse is forbidden.
3. **UI never touches Drift directly.** UI → Riverpod provider → repository → database.
4. **UI never mutates `GameState` directly.** UI dispatches a `GameCommand` via `ref.read(gameWorldProvider.notifier).apply(cmd)`.
5. **Services (audio, haptics) subscribe to events — they never emit `GameEvent`s.** Only UI (user intent) and `GameLoop` (time) drive the sim.
6. **`lib/utils/` is leaf-level.** It never imports from `game/`, `data/`, `ui/`, `services/`, `providers/`.
7. **Only `lib/providers/` imports `game/` + `data/` + `services/` together.** Providers are the composition root.

**Game loop:**

- ONE `Ticker` in the entire app, owned by `GameLoop` (dedicated widget with `SingleTickerProviderStateMixin`). Never create ad-hoc tickers.
- Variable timestep: `gameWorld.tick(elapsed)` where `elapsed` is real wall-clock delta, clamped to ≤ 0.1s (avoid tab-switch spikes).
- `WidgetsBindingObserver`: `paused/inactive` → stop ticker + `saveRepository.flush()` + record `lastSavedAt`; `resumed` → `OfflineCatchup.apply()` THEN restart ticker.
- No background processing — all offline earnings calculated on resume.

**Reducers (per feature under `lib/game/features/*/`):**

- Pure functions. NO clock reads, NO RNG reads, NO I/O. `now` and `rng` flow in as parameters.
- Return `Result<(NewState, Event), GameError>` — no exceptions for control flow.
- Only `GameWorld` calls reducers and emits events on the stream.

**Commands vs Events:**

- Commands (input to sim): **imperative** — `TapCountry`, `PurchaseUpgrade`, `HireLeader`, `ClaimGolden`, `ActivateBoost`.
- Events (output from sim): **past tense** — `CountryTapped`, `UpgradePurchased`, `LeaderHired`, `GoldenClaimed`, `BoostActivated`.
- Both are **sealed class hierarchies**. Exhaustive `switch` — compiler errors when a new variant isn't handled.
- Event payloads are immutable snapshots, never mutable references.
- `StreamController.broadcast(sync: true)` — subscribers observe state + event in the same microtask.

**Event bus discipline:**

- Audio/haptics/persistence subscribe to `gameWorld.events`. They NEVER call `AudioService.play(...)` from widgets.
- UI dispatches a command; the sim emits an event; services react. No scattered `playSound()` calls anywhere in UI code.

**Big numbers:**

- All game math flows through `Influence` / `Intel` value objects (in `lib/game/values/`).
- `double` for game quantities is a bug. Raw `Decimal` outside `lib/game/values/` is a lint violation.
- Abbreviated format (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, De) via `InfluenceFormatter` — do not reinvent.

**Multiplier stack — THE single source of truth lives in `lib/game/features/economy/income_calculator.dart`. Exact order (top to bottom):**

```
baseInfluence
  × (1 + ipLevel × IP_MULT_PER_LEVEL)     // Influence Power
  × leaderMultiplier                        // 0 / 1.0 / 1.5 / 2.0 / 3.0
  × continentCompletionBonus                // 1.0 … 2.75
  × (1 + Σ achievementMultipliers)          // additive stack, then *
  × globalUpgrades.influenceAmplifier
  × goldenOpportunityMultiplier             // 1.0 or 10–100 (active)
  × boostMultiplier                         // 1.0 or 2.0 (active)
```

Any duplicate income computation elsewhere is a bug. Balance tuning (Epic 11) assumes this exact order.

**Drift:**

- Never raw SQL — always typed Drift DSL.
- Schema changes REQUIRE a new migration file under `lib/data/database/migrations/`. Never mutate an existing version.
- Big numbers stored as TEXT via `DecimalConverter`.
- Write cadence is **event-driven** (`CountryUnlocked`, `UpgradePurchased`, etc. trigger targeted row updates) + a debounced 2s `totalInfluence` snapshot. **Never per-tick writes.**
- `schema_backup_v{n}.sqlite` must be copied BEFORE running any migration (there is no OTA patch channel).
- `meta.lastSavedAt` (UTC ISO8601) is the offline clock source.

**Riverpod:**

- Use `.select()` aggressively — HUD watches only `totalInfluence`, country widget watches only its own country state.
- Tests override providers via `ProviderContainer(overrides: [...])` — Riverpod is also the DI mechanism.
- No provider generator; no `@riverpod`.

**Result / error handling:**

- `Result<T, GameError>` (sealed) for anything that can fail meaningfully. NO exceptions for control flow.
- `GameError` hierarchy: `UserError` (surfaces in UI — `insufficientFunds`, `locked`, `invalidTarget`) vs `InternalError` (logged silently — `missingCountry`, `invariantBroken`, `persistenceFailure`, `migrationFailure`).
- `GameWorld` throws only on programmer-error invariants — those are bugs, caught by global handlers.
- Global handlers live in `main.dart`: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`.

**Logging:**

- `package:logging` only. NEVER `print()` (lint elevated to `error`).
- Tag = class/module name: `Logger('GameWorld')`, `Logger('SaveRepository')`.
- NO logging in hot paths (per-tick sim math, per-frame painter) — use `assert(...)` for invariants there.
- No PII — only IDs, counts, durations.

### Performance Rules

**Budgets (60fps target — ~16.67ms/frame with Impeller):**

- Game tick (`gameWorld.tick`) MUST complete in well under 1ms on mid-range 2021+ phones — profile in Epic 1.
- `WorldMapPainter.paint` is the main hot path — `shouldRepaint` must return false when only non-map state changed.
- Never allocate per-tick or per-paint if avoidable. Precompute: bounding boxes (boot), `Path` objects (load-once from GeoJSON), normalized country polygons.
- GeoJSON parsed **ONCE** on startup into `List<CountryPath>` — never re-parse on tab switch (use `IndexedStack` to keep map alive).
- Map hit-test pipeline: inverse view-transform → bounding-box reject → ring point-in-polygon. Bounding boxes are cached; never recompute per tap.
- If `Path` rebuild dominates the painter budget, cache as `Picture` / `Image` and invalidate only on country-state version change.

**Forbidden in hot paths:**

- `Logger(...).info(...)` inside `tick()` or `paint()`.
- New `Decimal.parse('$n')` in per-tick math — parse once, reuse constants.
- `rootBundle.loadString(...)` outside boot — `ContentRegistry` loads once and is immutable.
- Rebuilding widgets that watch the entire `GameState` — use `.select()`.

**Big-number precision:**

- Epic 1 spike REQUIRED: property-test `Decimal` at 1e38 × 3.0 × 1.75 × 2.0 × 100 compounded. Confirm no silent rounding and measure per-op cost. If too slow per-tick, cache computed rates (not every tick recomputes from scratch).

**Memory / assets:**

- Offline earnings cap = 8 hours. Clamp `elapsed = min(now - lastSavedAt, Duration(hours: 8))`.
- Google Fonts downloaded at runtime in v1 — consider bundling Fredoka if cold-start < 3s is missed.

### Code Organization Rules

**Top-level layout (fixed):**

```
lib/
  main.dart              # global handlers + Riverpod scope ONLY
  app.dart               # MaterialApp + theme + bootstrap gate
  game/                  # PURE DART — no Flutter imports
    game_world.dart      # aggregator (tick, applyCommand, events)
    game_state.dart      # immutable snapshot
    game_command.dart    # sealed hierarchy
    game_event.dart      # sealed hierarchy
    game_error.dart      # sealed hierarchy
    config/              # constants.dart, balance.dart (const only)
    values/              # influence, intel, country_id, result
    content/             # content_registry + *_def.dart (immutable)
    features/            # per feature: state + reducer (+ scheduler)
      countries/ upgrades/ leaders/ continents/ missions/
      achievements/ boosts/ goldens/ daily_rewards/
      economy/           # income_calculator.dart + offline_catchup.dart
      tutorial/
    support/             # clock.dart (injectable), id_gen, rng (seedable)
  data/                  # Drift, repositories, mappers
    database/
      app_database.dart
      tables/            # meta, countries, leaders, upgrades, …
      converters/        # decimal_converter, enum_converter
      migrations/        # migration_strategy + vN_to_vN+1
    repositories/        # save, settings, crash_log
    mappers/             # game_state_mapper
  services/              # Flutter-aware; subscribe to GameEvent
    audio_service.dart haptics_service.dart
    crash_reporter.dart logger_setup.dart lifecycle_observer.dart
  ui/
    app_scaffold.dart    # BottomNavigationBar + IndexedStack
    theme/               # app_theme, extensions/, spacing, typography
    widgets/             # cross-feature (influence_text, flying_number, …)
    features/            # map/, upgrades/, leaders/, missions/, stats/,
                         # hud/, modals/, tutorial/
    debug/               # kDebugMode-gated overlays ONLY
  providers/             # Riverpod = DI container (composition root)
    app_providers.dart game_providers.dart data_providers.dart
    service_providers.dart feature_providers.dart
  utils/                 # LEAF ONLY — no imports from game/data/ui/services
    formatters/ constants/
assets/
  audio/                 # collect, unlock, upgrade, milestone, golden,
                         # continent_complete, auto_tick, zoom (all .mp3)
  geo/countries.geojson.json
  data/                  # countries.json, continents.json, leaders.json,
                         # achievements.json, missions.json,
                         # global_upgrades.json
test/                    # mirrors lib/
integration_test/
```

**Dependency graph (any reverse arrow = architectural violation):**

```
ui/         → providers/, utils/, services/ (types only)
services/   → game/ (events/state)
data/       → game/ (types for mapping)
providers/  → game/, data/, services/
game/       → (nothing — island of purity)
utils/      → (leaf)
```

**Naming conventions:**

- Files: `snake_case.dart`, one public class per file (sealed hierarchies excepted).
- Tests mirror source with `_test.dart` suffix.
- Drift: plural table (`Countries extends Table`), singular row class (`@DataClassName('Country')`), file = `countries_table.dart`.
- Classes / mixins / sealed variants: PascalCase (`GameWorld`, `WorldMapPainter`, `CountryUnlocked`).
- Functions / methods / variables / parameters: camelCase (`applyCommand`, `totalInfluence`).
- Private: leading `_`.
- `const`s: camelCase per Dart convention — `Spacing.md`, `BalanceConfig.ipCostMultiplier`. **Do NOT use SCREAMING_SNAKE_CASE.**
- Enums: PascalCase type + camelCase values — `enum LeaderTier { none, tier1, tier2, tier3 }`.
- Assets: `snake_case` — `collect.mp3`, `continent_complete.mp3`, `countries.geojson.json`, `global_upgrades.json`.

**Configuration discipline — four types kept strictly separate:**

| Type | Storage | Access |
| --- | --- | --- |
| Game constants | `const` in `lib/game/config/constants.dart` | `GameConstants.maxOfflineHours` |
| Balance values | `const` in `lib/game/config/balance.dart` | `BalanceConfig.ipCostMultiplier` |
| Content data | `assets/data/*.json` loaded at startup | `ContentRegistry.countries[id]` |
| Player settings | `settings` table in Drift | `SettingsNotifier` (Riverpod) |

Never hardcode balance numbers in UI or sim logic — always read from `BalanceConfig` or `ContentRegistry`. No remote config in v1 — balance ships with store releases.

**File content discipline:**

- No `freezed` / `json_serializable` for v1 — manual `copyWith` (~15 lines per class) and manual `==` / `hashCode`.
- Immutable state: all `GameState`, `CountryState`, content defs, and events are `@immutable`.
- Only `lib/main.dart` contains boot-time global setup (error handlers, logger, Riverpod scope). Don't spread init across multiple files.

### Testing Rules

**Pure-Dart tests for `lib/game/` (`test/game/...`):**

```dart
import 'package:test/test.dart';                        // <-- NOT flutter_test
import 'package:global_domination/game/...';
```

Using `flutter_test` inside `test/game/` is a violation — the sim is headless, tests must prove it.

**Widget tests for `lib/ui/` (`test/ui/...`):**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

Always override providers via `ProviderScope(overrides: [...])`. Never mount real `GameWorld` or real Drift in widget tests.

**Other rules:**

- `GameStateBuilder` (under `test/helpers/`) is the canonical way to construct test states. Don't hand-construct `GameState` in each test.
- Clock is always injected via `FakeClock` (under `test/helpers/`) — never use `DateTime.now()` directly in sim code or tests.
- RNG is seedable (`lib/game/support/rng.dart`) — tests pin seeds for determinism.
- Drift tests use `NativeDatabase.memory()` — never touch the real filesystem.
- `integration_test/` covers golden-path (`golden_path_test.dart`) + offline catch-up (`offline_catchup_test.dart`) — add to these, don't fork.
- Property tests are required for: multiplier stack ordering, big-number precision at 1e38+, offline catch-up determinism across clock fakes.
- Tests that assert on multiplier math should pin each multiplier in isolation AND composed — prevents silent regressions from reordering.

### Platform & Build Rules

**Targets:**

- iOS 16.0+, Android API 21+. Portrait-locked — do not add landscape layouts.
- Single shared codebase. No `dart.io` conditional imports for platform — use `defaultTargetPlatform` / `kIsWeb` sparingly and only in `lib/ui/` or `lib/services/`.
- `web/`, `windows/`, `macos/`, `linux/` folders exist but are inert. Do not add code or assets specific to them. They stay in the repo for future ports.

**Impeller:**

- iOS: on by default.
- Android: enable via manifest flag (to be added in Epic 1 / Epic 2 foundation work).

**Build commands:**

- iOS: `flutter build ipa`.
- Android: `flutter build appbundle`.
- **No OTA update mechanism.** All code changes ship via store release (~1–3 days review). This is the reason Drift migrations and `schema_backup` are non-negotiable.

**Pre-commit / CI expectations (when wired):**

- `flutter analyze` with zero warnings.
- `dart format --set-exit-if-changed .`.
- `flutter test` + `dart test` for pure-Dart packages under `lib/game/`.
- Grep check: fail CI if `package:flutter/` appears anywhere under `lib/game/**`.
- Grep check: fail CI if `print(` appears anywhere under `lib/**` (lint also promoted to error).

**Lint config (from architecture — to apply to `analysis_options.yaml`):**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    avoid_print: error
    unnecessary_null_comparison: error
    unrelated_type_equality_checks: error
  exclude:
    - lib/**/*.g.dart         # Drift-generated
    - lib/**/*.freezed.dart   # if/when adopted
    - build/**

linter:
  rules:
    - always_declare_return_types
    # avoid_returning_null_for_future — removed in Dart 3.3.0; do not re-add
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - unawaited_futures
```

### Critical Don't-Miss Rules

**Anti-patterns — these are automatic PR rejections:**

- Importing `package:flutter/*` anywhere under `lib/game/`.
- Calling `DateTime.now()` in `lib/game/` — always use the injected `Clock`.
- Calling `rootBundle.loadString` in reducers or on the tick path — content loads once via `ContentRegistry`.
- Mutating `GameState` from a widget or service. UI dispatches commands; only `GameWorld` mutates.
- Calling `audioService.play(...)` or `HapticFeedback.xxx()` from a widget's `onTap`. Dispatch a `GameCommand`; the service reacts to the emitted event.
- Writing income math anywhere other than `lib/game/features/economy/income_calculator.dart`. There is ONE multiplier stack; duplicates drift.
- Using raw `Decimal` in UI or services. Always `Influence` / `Intel`.
- Using `double` for any game quantity. It's a silent precision bug at scale.
- Raw SQL in repositories. Always typed Drift DSL.
- Modifying an existing schema version file. Always add a new migration.
- Emitting a `GameEvent` from anywhere other than `GameWorld`. Services subscribe; they don't re-emit.
- `print()` anywhere. Use `Logger('Tag')`.
- Creating a second `Ticker` in the app. Only `GameLoop` owns one.
- Per-tick `saveRepository.save(fullState)`. Writes are event-driven + debounced snapshots.

**Subtle gotchas:**

- **Boosts and Goldens do NOT apply during offline catch-up.** Leader-only income while offline. (Open question flagged in architecture — default holds until balance data says otherwise.)
- **`IndexedStack` keeps tab state alive on purpose** — switching tabs must not re-parse GeoJSON or re-init providers.
- **`StreamController.broadcast(sync: true)`** — don't change to async; tests and audio timing assume synchronous emission.
- **Clamp `tick` delta to 0.1s max** — otherwise a tab-switch spike produces minutes of income in one frame.
- **`schema_backup_v{n}.sqlite` must exist BEFORE running the migration**, not after. Ordering matters.
- **Google Fonts downloads Fredoka at runtime** — cold-start budget (< 3s) assumes network or cache hit; may need to bundle the font file.
- **Drift-generated `*.g.dart` files must be excluded from lint and committed** — they are part of the repo, not build-time-only.
- **Sealed `switch` must stay exhaustive** — when adding a new `GameCommand` or `GameEvent`, the compiler will force you to update every consumer; do NOT silence with a catch-all `case _ => …` except in `AudioService` / `HapticsService` where unhandled events are genuinely no-ops.
- **`ProviderScope(overrides: [...])` in tests** — forgetting to override `gameWorldProvider` causes the real sim to boot with real content → slow, flaky widget tests.
- **Accessibility is not optional** — every interactive widget (country on map, upgrade button, HUD element) wraps in `Semantics` with a readable label. Checked in widget tests.
- **Debug tools are `kDebugMode`-gated** — cheat panel, state inspector, event-log viewer. The lone exception is the crash-log ring buffer (active in release, 100 entries, reachable via 5s settings long-press).

**When writing a story / implementing a feature, verify:**

1. Does it touch `lib/game/`? If yes → no Flutter imports, reducer returns `Result`, event emitted, pure of `now`/`rng`.
2. Does it mutate state? Only via `GameWorld.applyCommand(cmd)`.
3. Does it introduce income math? Route through `IncomeCalculator.compute`.
4. Does it introduce a new `GameEvent`? Audio/haptics services updated? Persisted if needed?
5. Does it introduce a new Drift column? Migration file added? `schema_backup` path updated?
6. Does it allocate per-tick / per-paint? Profile first.
7. Does it call `DateTime.now()` or `Random()` inside `lib/game/`? Inject instead.
8. Does a widget call any service method directly? Refactor to command + event subscription.
9. Is every new interactive widget wrapped in `Semantics`?
10. Is the new test under `test/game/` using `package:test/test.dart` (not `flutter_test`)?

---

## Usage Guidelines

**For AI agents:**

- Read this file before implementing any code in this project.
- Follow ALL rules exactly as documented — they reflect decisions already made in [game-architecture.md](game-architecture.md).
- When in doubt, prefer the more restrictive option and cite the relevant architecture section in the PR.
- If architecture and this file disagree, architecture wins — flag the divergence and update this file.
- Do NOT add comments justifying adherence to these rules in code; the rules are assumed.

**For humans:**

- Keep this file lean. Each rule must earn its keep by preventing a real mistake.
- Update when: pinned dependency versions change, a new architectural decision is made, a repeated AI mistake reveals a missing rule, or a rule becomes obvious and can be removed.
- Review at epic boundaries (or when onboarding a new contributor).
- Never embed balance numbers, story details, or sprint state here — those live in the GDD, epics, and story files.

Last Updated: 2026-04-21
