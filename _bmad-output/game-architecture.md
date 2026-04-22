---
title: 'Game Architecture'
project: 'global-domination-flutter'
date: '2026-04-21'
author: 'Sharon'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Flutter 3.41.6 stable (Dart 3.11.4)'
platform: 'Mobile — iOS 16+, Android API 21+'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdd.md'
epics: '_bmad-output/planning-artifacts/epics.md'
brief: null
---

# Game Architecture

## Executive Summary

**Global Domination** is a mobile-first idle/incremental strategy game — tap 79 countries across 7 continents on an interactive canvas-rendered world map — built as a v2 Flutter rewrite of a shipped React Native codebase.

The architecture follows a **strict three-layer vertical split**: a **pure-Dart `GameWorld` simulation** (zero Flutter imports), a **Drift/SQLite persistence layer** with typed migrations, and a **Flutter UI layer** using `CustomPainter` for the world map and `riverpod` for state distribution. A single `Ticker` drives the variable-timestep simulation; events from the sim flow through a typed `Stream<GameEvent>` that audio, haptics, and persistence services subscribe to — UI never calls `playSound()` or mutates state directly.

**Key architectural decisions:**

- **Framework:** Plain Flutter 3.41.6 — no game-engine layer (Flame rejected), no external map library (`CustomPainter` over GeoJSON)
- **State:** `Riverpod 2.6` wraps a headless `GameWorld`, serving both reactive rebuilds and dependency injection
- **Numbers:** `decimal` 3.0 wrapped in `Influence` / `Intel` value objects for arbitrary precision at 1e38+
- **Persistence:** Drift 2.26 normalized schema with event-driven writes + schema-backup-before-migrate (no-OTA constraint)
- **Offline earnings:** Single `OfflineEarningsEvent` on `AppLifecycleState.resumed`, deterministic via injectable `Clock`
- **Organization:** Layered + feature-hybrid — `lib/{game,data,ui,services,providers,utils}/`, with per-feature folders within each layer

**Core systems:** 12 systems mapped 1:1 to the 12 Flutter-rewrite epics from the GDD. **Patterns defined:** 5 novel + 6 standard, all with concrete code examples. **Enforcement:** `custom_lint` rules + CI grep checks + widget tests make architectural boundaries visible in PR diffs, not just aspirational.

**Ready for:** Epic-level story creation and implementation.

---

## Document Status

This architecture document was produced through the GDS Architecture Workflow (9 steps).

**Steps Completed:** 9 of 9 — **Status: COMPLETE**

---

## Project Context

### Game Overview

**Global Domination** — mobile-first idle/incremental strategy game. Players accumulate Influence to conquer 79 countries across 7 continents on an interactive canvas-rendered world map. Blends idle-game dopamine with a finite geographic progression fantasy. Core promise: *short sessions feel powerful, long-term play feels meaningful*.

This is a **fresh Flutter build**. The GDD v2 Epics 1–12 are the active scope and the sole design source of truth.

### Technical Scope

- **Platform:** Mobile — iOS 16.0+ and Android API 21+ (Flutter 3.x stable)
- **Orientation:** Portrait-locked
- **Genre:** Idle / Incremental
- **Distribution:** App Store + Google Play (no OTA updates available)
- **Networking:** None for v1.0 — fully offline, no backend, no multiplayer
- **Project Level:** Medium complexity solo-dev build

### Core Systems

| # | System | Complexity | GDD Reference |
|---|---|---|---|
| 1 | GameWorld simulation (headless, pure Dart) | High | Technical Constraints |
| 2 | World map renderer (CustomPainter + GeoJSON) | High | Art Style, Epic 2 |
| 3 | Big-number economy (1e38+, abbreviated notation) | High | Number Balancing |
| 4 | Persistence (Drift/SQLite, versioned migrations) | High | Epic 7 |
| 5 | Offline earnings calculator (8h cap, on-resume) | Medium | Automation Systems |
| 6 | Upgrade & Leader systems (1x/10x/25x bulk) | Medium | Upgrade Trees |
| 7 | Continent gating & milestones | Medium | Level Progression |
| 8 | Active play (Golden Opp, Boosts, Missions, Intel) | Medium | Epic 6 |
| 9 | Event bus for sound + haptics | Medium | Sound Design |
| 10 | UI shell, HUD, navigation (bottom tabs) | Medium | Epic 8 |
| 11 | FTUE / tutorial overlay | Low | Epic 10 |
| 12 | Accessibility (a11y semantics on map) | Medium | Accessibility |

### Technical Requirements

- **Frame rate:** 60fps sustained (Impeller rendering)
- **Cold start:** < 3s to interactive map
- **App size:** < 50MB; **crash rate:** < 1%
- **Game loop:** `Ticker`-driven, foreground only
- **Big numbers:** Scale to 1e38+ without precision loss
- **Save integrity:** 0% corruption tolerance; typed migrations via Drift
- **Offline cap:** 8 hours earnings max
- **Accessibility:** Screen-reader labels on all map countries, HUD, modals

### Complexity Drivers

1. **Custom canvas map with hit-testing** — 79 GeoJSON polygons @ 60fps with pan/zoom/tap, no map library.
2. **Big-number precision at 1e38+** — arithmetic on the tick hot-path; must validate `decimal` package at max scale.
3. **Headless simulation** — `GameWorld` as pure Dart enables deterministic testing of multi-hour offline catch-ups.
4. **Migration discipline** — Drift versioned schema is the only recovery path given no OTA.
5. **Multiplier stack ordering** — IP × Leader × continent × achievement × boost × Golden Opp must have a spec'd order of operations.

### Technical Risks

| Risk | Severity | Mitigation Focus |
|---|---|---|
| `decimal` precision at 1e38+ | Medium | Spike + property-test at max scale |
| Canvas perf on low-end Android API 21 | Medium | Profile early; optimize painter |
| Pacing curves tuned for 1s JS tick | Medium | Re-validate during balance testing |
| No OTA patch channel | Medium | Invest in migrations + crash telemetry |
| Solo-dev bottleneck | High | Scope discipline; defer Epics 13–17 |

### Pre-Existing Scaffold Decisions (to confirm in later steps)

- `riverpod: ^2.6.1` for state management (GDD didn't specify)
- `decimal: ^3.0.2` for big numbers
- `drift: ^2.26.1` + `sqlite3_flutter_libs` for persistence
- `audioplayers: ^6.4.0`, `google_fonts: ^6.2.1`
- 8 sound assets present (GDD listed 5 — 3 extras: `continent_complete`, `auto_tick`, `zoom`)

---

## Engine & Framework

### Selected Framework

**Flutter 3.41.6 stable** (Dart 3.11.4) — plain Flutter with `CustomPainter` + `Ticker`, **no game engine layer** (no Flame, no external map library).

**Rationale:**
- Idle game is UI-heavy (bottom nav, tabs, modals, HUD) with a single custom canvas view — plays to Flutter's strengths.
- No sprites, no physics, no scenes, no particle systems — a game-engine layer like Flame would add abstractions without pulling weight.
- Impeller rendering eliminates the JS-bridge bottleneck that constrained the v1 React Native build.
- Single codebase → iOS 16+ and Android API 21+ from day one.

### Project Initialization

Scaffold already created via `flutter create`. Entrypoint at `lib/main.dart`. Mobile target platforms (`ios/`, `android/`) are in scope for v1.0; other platform folders (`web/`, `windows/`, `macos/`, `linux/`) are inert — retain for future desktop/web ports (GDD flags these as *under consideration for later phases*) or delete if disk footprint becomes a concern.

### Framework-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendering | Impeller + `CustomPainter` for map, widgets for UI | GPU-accelerated; enable on Android via manifest flag |
| Layout | Material/Cupertino widgets | Bottom-nav, modals, HUD in widget tree |
| Input | `GestureDetector` + custom hit-testing inside `CustomPainter` | Pan/zoom via transform matrices |
| Animation | `AnimationController` + `Ticker` | Display-refresh-aligned |
| Game loop | `Ticker` driven by `SchedulerBinding` | Foreground only — no background ticks |
| Audio | `audioplayers: ^6.4.0` | Short MP3 SFX; event-bus driven |
| Haptics | `HapticFeedback` (SDK built-in) | Pairs with audio events |
| Persistence | `drift: ^2.26.1` + `sqlite3_flutter_libs: ^0.5.25` | Typed, migration-aware SQLite |
| Fonts | `google_fonts: ^6.2.1` (Fredoka) | Downloaded at runtime; consider bundling |
| Big numbers | `decimal: ^3.0.2` | Arbitrary-precision; must be validated at 1e38+ |
| Build & release | `flutter build ipa` / `appbundle` | Standard store submission |

### MCP Development Environment (already configured in `.mcp.json`)

| MCP | Purpose |
|---|---|
| `dart` (official Dart MCP) | Analyzer, hot reload, widget tree, runtime errors, tests |
| `flutter-mcp` | Flutter-specific dev tooling |
| `context7` | Up-to-date library documentation for Drift, Riverpod, etc. |
| `memory` | Persistent knowledge graph across sessions |
| `sequential-thinking` | Multi-step reasoning aid |

### Remaining Architectural Decisions

These are not resolved by picking Flutter and must be made explicitly in the next step:

1. State management layering (Riverpod + `GameWorld` boundary)
2. Game loop strategy (single `Ticker` owner, fixed vs variable timestep)
3. Persistence write cadence (per-tick vs debounced vs event-driven)
4. Offline earnings algorithm (location, re-entry, determinism)
5. Big-number representation (`Decimal` vs `Influence` value object; rounding rules)
6. Event bus design (custom vs Riverpod streams)
7. Map rendering pipeline (projection, transforms, hit-testing)
8. Navigation (Navigator 1.0 vs `go_router`)
9. Error handling, logging, crash telemetry
10. Theme / design tokens structure
11. Dependency injection + clock abstraction for tests
12. Multiplier stack ordering specification

---

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Version | Rationale |
|---|---|---|---|---|
| 1 | Simulation layering | Pure-Dart `GameWorld`; Riverpod wraps it | — | GDD mandates headless/testable simulation |
| 2 | State management | Riverpod | 2.6.1 (+ flutter_riverpod 2.6.1) | Compile-safe, fine-grained rebuilds, testable; already installed |
| 3 | Game loop | Single global `Ticker`, variable timestep `Duration dt` | Flutter SDK | Economy is rate-based; deterministic time via injectable `Clock` |
| 4 | Persistence | Drift (normalized schema, event-driven writes, backup-before-migrate) | 2.26.1 + sqlite3_flutter_libs 0.5.25 | Typed migrations critical since no OTA patch channel |
| 5 | Big numbers | `Decimal` wrapped in `Influence` / `Intel` value objects | decimal 3.0.2 | Arbitrary precision at 1e38+; type safety |
| 6 | Offline earnings | Single `OfflineEarningsEvent` on resume, Leader-only income, 8h cap | — | Deterministic; respects Offline Respectful pillar |
| 7 | Event bus | `Stream<GameEvent>` from `GameWorld`; Audio/Haptics services subscribe | — | GDD mandate: no scattered `playSound()` calls |
| 8 | Map rendering | Equirectangular projection, `Matrix4` pan/zoom, point-in-polygon hit-test, `CustomPainter` with `Path` cache | — | GDD mandate: no map library; 60fps target |
| 9 | Navigation | `Navigator 1.0` + `IndexedStack` | Flutter SDK | Offline mobile; no URL surface |
| 10 | Error/telemetry | `FlutterError.onError` + `PlatformDispatcher.onError` + local ring-buffer; Crashlytics/Sentry post-launch | — | v1 offline; SDKs deferred with IAP/ads (Epic 13) |
| 11 | Theme & tokens | `ThemeExtension`s for game tokens; Fredoka via `google_fonts` | google_fonts 6.2.1 | GDD mandate |
| 12 | DI + math | Riverpod-as-DI; multiplier stack order pinned | — | Prevents balance regressions |

### 1. Simulation Layering

**`GameWorld`** is a plain Dart class in `lib/game/` with zero Flutter imports.

- Exposes: `tick(Duration dt)`, `applyEvent(GameEvent)`, `GameState get state`, `Stream<GameEvent> get events`
- Holds all game mechanics: income, upgrades, leaders, unlocks, missions, achievements, boosts, Goldens
- Consumes an injected `Clock` for all time-based logic (testable)
- A single `StateNotifier<GameState>` (Riverpod) is the only wrapper — UI never touches `GameWorld` directly

### 2. State Management — Riverpod 2.6

- No `riverpod_generator` for v1 (avoid `build_runner` churn; revisit if provider count grows)
- Providers organized by domain: `gameWorldProvider`, `influenceProvider`, `countriesProvider`, `audioServiceProvider`, `clockProvider`, etc.
- Tests use `ProviderContainer(overrides: […])` — Riverpod is also the DI mechanism
- `.select()` used aggressively for minimal rebuilds (HUD listens only to `totalInfluence`; country widget listens only to its own country state)

### 3. Game Loop — Single `Ticker`, Variable Timestep

- `GameLoop` class (mixes in `SingleTickerProviderStateMixin` via a dedicated widget) owns the only `Ticker` in the app
- Each frame: `gameWorld.tick(elapsed)` where `elapsed` is real wall-clock delta (clamped to 0.1s to avoid tab-switch spikes)
- `WidgetsBindingObserver` hooks:
  - `paused/inactive` → stop ticker, `saveRepository.flush()`, record `lastSavedAt`
  - `resumed` → `OfflineCatchup.apply()` then restart ticker
- Sim is **variable timestep** — correct for rate-based economy; no fixed-step accumulator

### 4. Persistence — Drift 2.26

- **Schema:** normalized tables — `meta`, `countries`, `leaders`, `upgrades`, `achievements`, `missions`, `boosts`, `goldens`, `crash_logs`, `tutorial_state`
- **Big numbers:** TEXT columns with `DecimalConverter` (serializes to string, preserves precision)
- **Write cadence:** event-driven (`CountryUnlocked`, `UpgradePurchased`, etc. trigger targeted row updates) + debounced 2s `totalInfluence` snapshot. **Never per-tick.**
- **Migrations:** typed via Drift's `MigrationStrategy`; each schema version documented; `schema_backup_v{n}.sqlite` copied before migration
- **Clock source for offline:** `meta.lastSavedAt` (UTC ISO8601)
- **Recovery:** on corrupt DB, restore from `schema_backup` if present; otherwise show "save recovery" screen

### 5. Big Numbers — `Influence` / `Intel` Value Objects

```dart
class Influence {
  final Decimal value;
  const Influence(this.value);
  Influence operator +(Influence o) => Influence(value + o.value);
  Influence operator *(Decimal factor) => Influence(value * factor);
  Influence operator *(num factor) => Influence(value * Decimal.parse('$factor'));
  // ...
  String format() => InfluenceFormatter.abbreviated(value); // K/M/B/T/Qa/Qi/...
}
```

- All game math flows through `Influence` / `Intel` — double is a bug
- **Required spike (Epic 1):** property-test `Decimal` arithmetic at 1e38 × 3.0 × 1.75 × 2.0 × 100 compounded — confirm no silent rounding and measure per-op cost; if too slow per-tick, consider caching computed rates
- Formatter uses K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, De (decillion) for scale

### 6. Offline Earnings

- **Trigger:** `AppLifecycleState.resumed` → `OfflineCatchup.apply(gameWorld, clock, saveRepository)` runs before first Riverpod rebuild
- **Math:** `elapsed = min(clock.now() - meta.lastSavedAt, Duration(hours: 8))`; for each country with a Leader: `earned = automatedRate × elapsed.inSeconds × stableMultipliers`
- **Stable multipliers only:** IP × Leader × continent × achievement × global upgrades. **Boosts and Goldens do NOT apply offline** (open question flagged — default answer, to be confirmed)
- **Integration:** Applied as a single `OfflineEarningsEvent` into `GameWorld.applyEvent()` — event-sourced, replayable in tests
- **UI:** `OfflineRewardModal` shows after catch-up completes, before any other UI interaction

### 7. Event Bus

- `GameWorld` exposes `Stream<GameEvent> get events` (a `StreamController.broadcast` internally)
- `GameEvent` is a sealed class hierarchy:
  - `CountryTapped`, `CountryUnlocked`, `LeaderHired`, `LeaderUpgraded`, `UpgradePurchased`, `GoldenClaimed`, `BoostActivated`, `BoostExpired`, `MissionCompleted`, `ContinentUnlocked`, `ContinentCompleted`, `MilestoneReached`, `AchievementEarned`, `OfflineEarningsApplied`, `IntelGained`, `IntelSpent`
- `AudioService` subscribes → maps event type to SFX
- `HapticsService` subscribes → maps event type to haptic pattern
- UI widgets never call `AudioService.play(...)` — they dispatch an event via `gameWorld.applyEvent(...)` which emits the stream event as a side effect

### 8. Map Rendering Pipeline

- **Projection:** Equirectangular `(lon, lat) → ((lon+180)/360, (90-lat)/180)` into `[0,1]²`, then view transform to pixels
- **Pan/zoom:** custom `GestureDetector` that maintains a `Matrix4 viewTransform`; **no `InteractiveViewer`** (we need inverse transform for hit-tests)
- **Hit-testing:** tap → inverse-transform to normalized coords → bounding-box reject per country → point-in-polygon (ray-casting); cached bounding boxes per country
- **Painter:** `WorldMapPainter extends CustomPainter` — GeoJSON parsed once on startup to `List<CountryPath>`; `shouldRepaint` based on view-transform change OR country-state version
- **Layers (painting order):** ocean → continent fills → country fills (state color) → borders → labels → effects (halo, takeover animations, particle pings)
- **Performance guardrail:** profile on low-end Android (API 21) device in Epic 2. If `Path` rebuild dominates, cache as `Picture`/`Image` and invalidate only on country state change

### 9. Navigation

- **Bottom nav:** `BottomNavigationBar` + `IndexedStack` (keeps each tab alive so the map doesn't re-parse GeoJSON on tab switch)
- **Modals:** `showDialog` / `showModalBottomSheet` with Material 3 transitions
- **No `go_router`, no `auto_route`** — revisit if v1.x targets web

### 10. Error Handling & Telemetry

- Global handlers: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`
- `CrashReporter` writes to `crash_logs` table (bounded, last N=100 entries)
- `ErrorBoundary` widget wraps top-level screens with a fallback + restart CTA
- Logging via `package:logging` with app-wide level; no `print()`
- **Post-launch:** add Crashlytics or Sentry alongside IAP/ad SDKs (Epic 13)

### 11. Theme & Design Tokens

- `appTheme()` builder in `lib/ui/theme/app_theme.dart` composes `ThemeData`
- Game-specific tokens via `ThemeExtension`s: `CountryColors` (locked/unlocked/conquered/golden), `HudPalette`, `RarityColors`, `MilestoneColors`
- Spacing constants: `Spacing.xs/sm/md/lg/xl/xxl = 4/8/16/24/32/48`
- Typography: `GoogleFonts.fredokaTextTheme(base)` then overridden per role (headline, label, number)
- **Single theme** for v1 (no dark mode — not in GDD)

### 12. DI & Multiplier Stack Ordering

**DI:** Riverpod providers ARE the container. No `get_it`.

**Multiplier stack (authoritative order, top-to-bottom):**

```
finalIncomePerSecond =
  country.baseInfluence
  × (1 + ipLevel × IP_MULT_PER_LEVEL)               // Influence Power
  × leaderMultiplier                                 // 0 / 1.0 / 1.5 / 2.0 / 3.0
  × continentCompletionBonus                         // 1.0 … 2.75
  × (1 + Σ achievementMultipliers)                   // additive stack, then *
  × globalUpgrades.influenceAmplifier                // e.g. 1.0 … 10.0
  × goldenOpportunityMultiplier                      // 1.0 or 10–100 (active window)
  × boostMultiplier                                  // 1.0 or 2.0 (active window)
```

- Encoded in `IncomeCalculator.compute(country, state) → Influence per second` — **one pure function, one source of truth**
- Balance tuning (Epic 11) assumes this exact order
- Property tests pin each multiplier's effect in isolation and composed

### Open Question (to confirm)

- **Q6-offline:** Do Boosts / Goldens active at logout keep multiplying during offline catch-up? **Default: No** (Leader-only income offline). Can be revisited once live balance data exists.

---

## Cross-Cutting Concerns

These patterns apply to **all** systems and MUST be followed by every implementation.

### Error Handling

**Strategy:** Two tiers.

- **Top tier (catastrophic):** Global handlers (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`) route to `CrashReporter`. Fallback screen with "Restart" CTA.
- **Mid tier (recoverable game ops):** `Result<T, GameError>` (sealed class) for anything that can fail meaningfully. No exceptions for control flow.

**Rules:**
1. NEVER swallow errors silently. Minimum: log at `warning` and return `Result.failure`.
2. UI widgets never catch errors directly — dispatch `GameError` via `Result` and let `ErrorRouter` decide presentation.
3. `GameWorld` throws only on programmer errors / invariant violations. Those are bugs — `runZonedGuarded` catches and logs as crashes.
4. Only `UserError` variants surface in UI. `InternalError` is logged silently.

**`GameError` hierarchy (sealed):**
```
GameError
├── UserError
│   ├── insufficientFunds(required)
│   ├── locked(reason)
│   └── invalidTarget(detail)
└── InternalError
    ├── missingCountry(id)
    ├── invariantBroken(message)
    ├── persistenceFailure(cause)
    └── migrationFailure(fromVersion, toVersion, cause)
```

**Example:**
```dart
Result<CountryState, GameError> purchaseUpgrade(CountryId id, int bulk) {
  final country = _state.countries[id];
  if (country == null) return Result.failure(GameError.internalMissingCountry(id));
  final cost = IncomeCalculator.bulkCost(country, bulk);
  if (_state.influence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }
  // apply upgrade, emit event...
  return Result.success(newCountry);
}

// main.dart
void main() {
  FlutterError.onError = CrashReporter.instance.report;
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporter.instance.reportAsync(error, stack);
    return true;
  };
  runZonedGuarded(() => runApp(const GlobalDominationApp()),
      (error, stack) => CrashReporter.instance.reportAsync(error, stack));
}
```

### Logging

**Package:** `package:logging` (zero cost when level-gated).

**Levels:**

| Level | Use for | Persisted? |
|---|---|---|
| `SEVERE` | Crash / internal errors | ✅ `crash_logs` table |
| `WARNING` | Recoverable anomaly | ✅ bounded |
| `INFO` | Lifecycle milestones | ✅ recent only |
| `CONFIG` | Startup config (build mode, schema version) | ✅ one-shot |
| `FINE`/`FINER`/`FINEST` | Debug diagnostics | ❌ debug only |

**Rules:**
1. NEVER use `print()`. Always `Logger('Tag').info(...)`.
2. Tag = class/module name: `Logger('GameWorld')`, `Logger('SaveRepository')`, `Logger('WorldMapPainter')`.
3. Root logger configured once in `main.dart`:
   - Release: `Level.WARNING` minimum → `CrashReporter`.
   - Debug: `Level.FINE` → console with timestamp + tag.
4. **No logging in tight hot paths** (per-tick sim math, per-frame painter). Use `assert` for invariants there.
5. No PII — no account system, log only IDs, counts, durations.

**Example:**
```dart
final _log = Logger('SaveRepository');

Future<Result<void, GameError>> save(GameState state) async {
  final sw = Stopwatch()..start();
  _log.info('save start: schemaVersion=${state.meta.schemaVersion}');
  try {
    await _db.transaction(() async { /* ... */ });
    _log.info('save ok in ${sw.elapsedMilliseconds}ms');
    return const Result.success(null);
  } catch (e, s) {
    _log.severe('save failed', e, s);
    return Result.failure(GameError.persistenceFailure(e.toString()));
  }
}
```

### Configuration Management

**Four distinct config types, kept strictly separate:**

| Type | Storage | Access | Example |
|---|---|---|---|
| Game constants | `const` in `lib/game/config/constants.dart` | `GameConstants.maxOfflineHours` | `maxOfflineHours = 8`, `ipMaxLevel = 200` |
| Balance values | `const` in `lib/game/config/balance.dart` | `BalanceConfig.ipCostMultiplier` | `ipCostMultiplier = 1.5`, `leaderUnlockIpLevel = 10` |
| Content data | `assets/data/*.json` loaded at startup | `ContentRegistry.countries[id]` | 79 countries, 27 achievements |
| Player settings | `settings` table in Drift | `SettingsNotifier` (Riverpod) | `soundEnabled: true` |

**Rules:**
1. Never hardcode balance numbers in UI or sim logic — always read from `BalanceConfig` or `ContentRegistry`.
2. Content files are the source of truth for tunable game data.
3. No remote config for v1 — balance tuning ships with store releases.

**Content example (`assets/data/countries.json`):**
```json
[
  { "id": "egypt", "continent": "africa", "baseInfluence": "1",
    "unlockCost": "0", "tier": 1, "generationSeconds": 1 },
  { "id": "nigeria", "continent": "africa", "baseInfluence": "5",
    "unlockCost": "5", "tier": 1, "generationSeconds": 1 }
]
```

### Event System

**Pattern:** Sealed class hierarchy + `StreamController.broadcast()` owned by `GameWorld`.

**Rules:**
1. Typed events only — no `String` event names. Consumers use exhaustive `switch`.
2. Sync emission, async consumers. `GameWorld` emits after state update; subscribers process on microtask.
3. Immutable event payloads — snapshot values, not mutable references.
4. Past-tense naming: `CountryUnlocked`, not `UnlockCountry`. Future-tense inputs go through `applyEvent(GameCommand)`.
5. No cross-service event chains. Only `GameWorld` emits `GameEvent`s — services never re-emit.
6. Debug builds record events to `event_log` table for replay.

**Example:**
```dart
sealed class GameEvent {
  final DateTime at;
  const GameEvent(this.at);
}

final class CountryUnlocked extends GameEvent {
  final CountryId id;
  final Continent continent;
  final Influence cost;
  const CountryUnlocked(super.at, this.id, this.continent, this.cost);
}

// Audio subscriber
audioService.events.listen((event) {
  switch (event) {
    case CountryTapped():       _sfx.play(Sfx.collect);
    case CountryUnlocked():     _sfx.play(Sfx.unlock);
    case LeaderHired():         _sfx.play(Sfx.upgrade);
    case UpgradePurchased():    _sfx.play(Sfx.upgrade);
    case GoldenClaimed():       _sfx.play(Sfx.golden);
    case ContinentCompleted():  _sfx.play(Sfx.milestone);
    case _:                     break;
  }
});
```

### Debug / Development Tools

All gated on `kDebugMode` — zero code size impact in release.

| Tool | Activation | Purpose |
|---|---|---|
| Debug overlay | 5-tap HUD title | FPS, tick duration, events/s, provider count |
| Cheat panel | Long-press HUD | Grant Influence, unlock continent, trigger Golden, skip tutorial, force offline catch-up |
| State inspector | Menu in debug overlay | Dumps `GameState` as JSON |
| Event log viewer | Menu in debug overlay | Last 200 `GameEvent`s |
| Save viewer | Menu in debug overlay | Row-level Drift query UI |
| Performance HUD | Toggle in debug overlay | Flutter's `showPerformanceOverlay` |
| Assertion-heavy mode | Always on in debug | `assert(invariant)` in sim hot paths |

**Rules:**
1. All debug entry points MUST be behind `if (kDebugMode)` or `assert(() { …; return true; }())`.
2. Cheats never ship — both the activator and the code are `kDebugMode`-gated.
3. Crash log ring buffer is the ONE exception: active in release, bounded 100 entries, reachable only via a 5-second settings long-press ("Support" screen) — for field debugging.

---

## Project Structure

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

## Implementation Patterns

These patterns are mandatory. AI agents MUST follow them; deviations require explicit justification in the story.

### Novel Patterns (Game-Specific)

#### 1. Reducer Composition with `GameWorld` Aggregator

**Purpose:** Keep `GameWorld` small; domain logic lives in per-feature pure-function reducers.

**Reducer contract:**
```dart
// lib/game/features/upgrades/upgrade_reducer.dart
class UpgradeReducer {
  /// Pure function. No side effects. No I/O. No clock reads.
  /// Returns either the new state + the event to emit, or a GameError.
  Result<(GameState, GameEvent), GameError> purchaseIP(
    GameState state,
    PurchaseUpgrade cmd,
    {required DateTime now},
  ) {
    final country = state.countries[cmd.countryId];
    if (country == null) return Result.failure(GameError.internalMissingCountry(cmd.countryId));
    final cost = IncomeCalculator.bulkCost(country, cmd.bulk);
    if (state.influence < cost) return Result.failure(GameError.userInsufficientFunds(required: cost));

    final newCountry = country.copyWith(
      ipLevel: (country.ipLevel + cmd.bulk).clamp(0, GameConstants.ipMaxLevel),
    );
    final newState = state.copyWith(
      influence: state.influence - cost,
      countries: {...state.countries, cmd.countryId: newCountry},
    );
    return Result.success((newState, UpgradePurchased(now, cmd.countryId, cmd.bulk, cost)));
  }
}
```

**Rules:**
1. Reducers are pure — `now` and `rng` flow in as parameters.
2. Reducers return `Result<(NewState, Event), GameError>`.
3. Only `GameWorld` calls reducers and emits events.

#### 2. Sealed Command / Event Dispatch

**Purpose:** Type-safe command handling via exhaustive switches.

```dart
sealed class GameCommand { const GameCommand(); }
final class TapCountry extends GameCommand      { final CountryId id; const TapCountry(this.id); }
final class PurchaseUpgrade extends GameCommand { final CountryId countryId; final int bulk; const PurchaseUpgrade(this.countryId, this.bulk); }
final class HireLeader extends GameCommand      { final CountryId countryId; const HireLeader(this.countryId); }
// ... etc

class GameWorld {
  Result<void, GameError> applyCommand(GameCommand cmd) {
    final now = _clock.now();
    final result = switch (cmd) {
      TapCountry(id: final id)          => _countryReducer.tap(_state, id, now: now),
      PurchaseUpgrade()                  => _upgradeReducer.purchaseIP(_state, cmd, now: now),
      HireLeader(countryId: final id)    => _leaderReducer.hire(_state, id, now: now),
      // exhaustive — compiler error if a new command is added without a case
    };
    return switch (result) {
      Success(value: (final newState, final event)) => () {
          _state = newState;
          _events.add(event);
          return const Result.success(null);
        }(),
      Failure(error: final e) => Result.failure(e),
    };
  }
}
```

**Rules:**
1. Adding a new command REQUIRES updating the switch — compiler enforces.
2. Commands imperative; events past-tense.
3. `StreamController` uses `sync: true` — subscribers observe state + event in same microtask.

#### 3. Declarative Rule Engine for Achievements & Missions

```dart
class AchievementDef {
  final String id;
  final Predicate<GameState> condition;
  final GameState Function(GameState) apply;
  final AchievementReward reward;
}

class AchievementEvaluator {
  GameState evaluate(GameState state, List<AchievementDef> defs) {
    var s = state;
    for (final def in defs) {
      if (s.earnedAchievements.contains(def.id)) continue;
      if (def.condition(s)) {
        s = def.apply(s).copyWith(
          earnedAchievements: {...s.earnedAchievements, def.id},
        );
      }
    }
    return s;
  }
}
```

**Rules:**
1. Achievements and missions are data, not code. Condition functions are pure.
2. Evaluator runs after every `applyCommand`, skipping already-earned achievements.
3. `AchievementEarned` events emitted in the same microtask as the triggering event.

#### 4. Map Hit-Test Pipeline

```dart
class PolygonHitTester {
  final List<CountryPath> _paths;
  final Map<CountryId, Rect> _bboxCache;

  CountryId? hitTest(Offset normalizedPoint) {
    for (final path in _paths) {
      final bbox = _bboxCache[path.id]!;
      if (!bbox.contains(normalizedPoint)) continue; // early reject
      if (_pointInPolygon(normalizedPoint, path.rings)) return path.id;
    }
    return null;
  }

  bool _pointInPolygon(Offset p, List<List<Offset>> rings) {
    bool inside = false;
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final vi = ring[i], vj = ring[j];
        final intersect = ((vi.dy > p.dy) != (vj.dy > p.dy)) &&
            (p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx);
        if (intersect) inside = !inside;
      }
    }
    return inside;
  }
}
```

**Rules:**
1. Bounding boxes precomputed once from GeoJSON at boot.
2. Early-reject with bbox before ring test.
3. Operates on `[0,1]²` normalized coords AFTER inverse view-transform.

#### 5. Content Loading — Load-Once, Immutable

```dart
class ContentRegistry {
  final Map<CountryId, CountryDef> countries;
  final Map<ContinentId, ContinentDef> continents;
  final List<AchievementDef> achievements;
  final List<MissionDef> missions;
  final List<LeaderDef> leaders;

  const ContentRegistry({ /* ... */ });

  static Future<ContentRegistry> loadFromAssets() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/countries.json'),
      rootBundle.loadString('assets/data/continents.json'),
      rootBundle.loadString('assets/data/achievements.json'),
      rootBundle.loadString('assets/data/missions.json'),
      rootBundle.loadString('assets/data/leaders.json'),
    ]);
    // parse → freeze → return
  }
}

final contentRegistryProvider = FutureProvider<ContentRegistry>(
  (ref) async => ContentRegistry.loadFromAssets(),
);
```

**Rules:**
1. Loaded ONCE at boot; failure triggers error screen + reinstall prompt.
2. Immutable for the session.
3. Reducers receive `ContentRegistry` via DI — never call `rootBundle` themselves.

### Standard Implementation Patterns

#### A. Immutable State with Manual `copyWith`

```dart
@immutable
class CountryState {
  final CountryId id;
  final bool unlocked;
  final int ipLevel;
  final LeaderTier leaderTier;
  final Decimal bankedInfluence;
  final DateTime? lastCollectedAt;

  const CountryState({
    required this.id,
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
    required this.bankedInfluence,
    required this.lastCollectedAt,
  });

  CountryState copyWith({
    bool? unlocked,
    int? ipLevel,
    LeaderTier? leaderTier,
    Decimal? bankedInfluence,
    DateTime? lastCollectedAt,
  }) => CountryState(
    id: id,
    unlocked: unlocked ?? this.unlocked,
    ipLevel: ipLevel ?? this.ipLevel,
    leaderTier: leaderTier ?? this.leaderTier,
    bankedInfluence: bankedInfluence ?? this.bankedInfluence,
    lastCollectedAt: lastCollectedAt ?? this.lastCollectedAt,
  );

  @override bool operator ==(Object other) => /* ... */;
  @override int get hashCode => /* ... */;
}
```

**No `freezed`** for v1 — manual copyWith is ~15 lines per class and costs zero tooling. Revisit if type count grows past ~30.

#### B. Widget → Provider → Notifier → GameWorld (The one true UI path)

```dart
// ui/features/upgrades/upgrade_card.dart
class UpgradeCard extends ConsumerWidget {
  final CountryId countryId;
  const UpgradeCard({required this.countryId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryProvider(countryId));
    final canAfford = ref.watch(canAffordUpgradeProvider(countryId));

    return ElevatedButton(
      onPressed: canAfford
        ? () {
            final result = ref.read(gameWorldProvider.notifier)
              .apply(PurchaseUpgrade(countryId, 1));
            if (result.isFailure) {
              ErrorRouter.of(context).show(result.error!);
            }
          }
        : null,
      child: Text('Upgrade (L${country.ipLevel})'),
    );
  }
}

// providers/game_providers.dart
final gameWorldProvider = StateNotifierProvider<GameWorldNotifier, GameState>((ref) {
  final content = ref.watch(contentRegistryProvider).requireValue;
  final clock = ref.watch(clockProvider);
  return GameWorldNotifier(GameWorld(content: content, clock: clock));
});

class GameWorldNotifier extends StateNotifier<GameState> {
  final GameWorld _world;
  late final StreamSubscription _sub;
  GameWorldNotifier(this._world) : super(_world.state) {
    _sub = _world.events.listen((_) => state = _world.state);
  }
  Result<void, GameError> apply(GameCommand cmd) => _world.applyCommand(cmd);
  @override void dispose() { _sub.cancel(); super.dispose(); }
}

// Fine-grained selector — rebuilds only when this country changes
final countryProvider = Provider.family<CountryState, CountryId>(
  (ref, id) => ref.watch(gameWorldProvider.select((s) => s.countries[id]!)),
);
```

#### C. Async Initialization Gate

```dart
// app.dart
class GlobalDominationApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    return MaterialApp(
      theme: appTheme(),
      home: boot.when(
        loading: () => const SplashScreen(),
        error: (err, _) => BootErrorScreen(error: err),
        data: (_) => const AppScaffold(),
      ),
    );
  }
}

final bootstrapProvider = FutureProvider<GameState>((ref) async {
  final content = await ref.watch(contentRegistryProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final repo = ref.read(saveRepositoryProvider);
  final state = await repo.loadOrCreateInitial(content);
  return OfflineCatchup.apply(state, ref.read(clockProvider));
});
```

#### D. Test Patterns

**Pure-Dart tests for `lib/game/`:**
```dart
import 'package:test/test.dart';   // NOT flutter_test
import 'package:global_domination/game/…';

void main() {
  group('IncomeCalculator multiplier stack', () {
    test('applies IP, leader, continent, achievement, global in documented order', () {
      final s = GameStateBuilder()
        .withCountry('egypt', ipLevel: 100, leaderTier: LeaderTier.tier2)
        .withContinentComplete('africa')
        .withAchievement('first_leader')
        .withGlobalUpgrade(influenceAmplifier: Decimal.parse('2.0'))
        .build();
      final rate = IncomeCalculator.compute(s.countries['egypt']!, s);
      expect(rate, Influence(Decimal.parse('…')));
    });
  });
}
```

**Widget tests for `lib/ui/`:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('disables button when unaffordable', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameWorldProvider.overrideWith((ref) => FakeGameWorldNotifier(
          seedState: GameStateBuilder().withPoorPlayer().build(),
        )),
      ],
      child: const MaterialApp(home: UpgradeCard(countryId: CountryId('egypt'))),
    ));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
  });
}
```

**Rules:**
1. `lib/game/` tests import `package:test/test.dart` — never `flutter_test`.
2. Widget tests always override providers.
3. `GameStateBuilder` is the canonical way to construct test states.

#### E. Animation Pattern

Event-driven animations use `AnimationController` + event stream trigger:

```dart
class FlyingNumberLayer extends ConsumerStatefulWidget { /* ... */ }

class _FlyingNumberLayerState extends ConsumerState<FlyingNumberLayer>
    with TickerProviderStateMixin {
  late final StreamSubscription _sub;
  final List<_FlyingNumber> _active = [];

  @override
  void initState() {
    super.initState();
    _sub = ref.read(gameEventsProvider).listen((event) {
      if (event is CountryTapped) _spawnFlyingNumber(event.country, event.amount);
    });
  }
}
```

#### F. Drift Typed Query Pattern

```dart
class SaveRepository {
  final AppDatabase _db;
  final _log = Logger('SaveRepository');

  Future<Result<void, GameError>> persistEvent(GameEvent event) async {
    try {
      await _db.transaction(() async {
        switch (event) {
          case CountryUnlocked(id: final id):
            await (_db.update(_db.countries)..where((t) => t.id.equals(id.value)))
              .write(const CountriesCompanion(unlocked: Value(true)));
          case UpgradePurchased():  /* typed update */
          case LeaderHired():       /* typed update */
          case _: break; // e.g. CountryTapped — not persisted per-event
        }
      });
      return const Result.success(null);
    } catch (e, s) {
      _log.severe('persistEvent failed for ${event.runtimeType}', e, s);
      return Result.failure(GameError.persistenceFailure(e.toString()));
    }
  }
}
```

**Rule:** Never raw SQL — always typed Drift DSL. Schema changes REQUIRE a migration file.

### Consistency Rules Summary

| Rule | Convention | Enforcement |
|---|---|---|
| No Flutter in `lib/game/` | `package:flutter/*` forbidden under `lib/game/**` | `custom_lint` rule + CI grep check |
| Commands imperative; events past-tense | `PurchaseUpgrade` vs `UpgradePurchased` | Code review + naming regex |
| Reducers pure | No clock/RNG/IO; `now`/`rng` as params | Unit tests + review |
| Single multiplier stack | Only `IncomeCalculator.compute` produces income | Grep for duplicates + review |
| All big-number math through `Influence` | No raw `Decimal` outside `values/` | `custom_lint` rule |
| No `print()` | Always `Logger('Tag')` | `avoid_print: error` |
| UI → Command only | Widgets never mutate state directly | Review; private state in Notifier |
| Content is immutable | `ContentRegistry` loaded once | No setters; `@immutable` |
| Every interactive widget has `Semantics` | A11y first | Widget test checks + review |
| `snake_case.dart` + mirror test files | | `flutter_lints` + review |

### Lint Configuration

Add to `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    avoid_print: error
    unnecessary_null_comparison: error
    unrelated_type_equality_checks: error
  exclude:
    - lib/**/*.g.dart         # Drift-generated
    - lib/**/*.freezed.dart   # if/when we adopt
    - build/**

linter:
  rules:
    - always_declare_return_types
    - avoid_returning_null_for_future
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - unawaited_futures
```

---

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
|---|---|---|
| Decision Compatibility | ✅ PASS | Stack components idiomatic and mutually compatible |
| GDD Coverage | ✅ PASS | 12/12 systems and all technical requirements mapped |
| Pattern Completeness | ✅ PASS | 12/12 scenarios covered with code examples |
| Epic Mapping | ✅ PASS | All 12 Flutter-rewrite epics have concrete homes |
| Document Completeness | ✅ PASS | No placeholders; Development Environment in Step 9 |

### Coverage Report

- Systems covered: **12/12**
- Architectural decisions: **12**
- Cross-cutting concerns: **5**
- Novel patterns: **5** (reducers, sealed dispatch, achievement rules, map hit-test, content loading)
- Standard patterns: **6**
- Consistency rules: **10**

### Epic → Architecture Mapping

| Epic | Name | Primary Location | Key Patterns |
|---|---|---|---|
| 1 | Foundation & Project Setup | `lib/main.dart`, `lib/app.dart`, `lib/providers/` | Async init gate, lint config |
| 2 | World Map Renderer | `lib/ui/features/map/` | CustomPainter, hit-test pipeline |
| 3 | Core Game Loop | `lib/game/game_world.dart`, `lib/game/features/{countries,economy}/` | Reducer composition, sealed commands |
| 4 | Upgrade & Leader Systems | `lib/game/features/{upgrades,leaders}/` + UI mirror | Reducer + bulk purchase |
| 5 | Continent & Unlock Progression | `lib/game/features/continents/` + modals | Milestone triggers, multiplier |
| 6 | Active Play Systems | `lib/game/features/{goldens,boosts,missions}/` | Scheduler, declarative missions |
| 7 | Persistence & Offline | `lib/data/`, `lib/services/lifecycle_observer.dart`, `lib/game/features/economy/offline_catchup.dart` | Typed migrations, event-driven writes |
| 8 | UI Shell & Navigation | `lib/ui/app_scaffold.dart`, `lib/ui/features/hud/` | IndexedStack, bottom nav |
| 9 | Game Feel & Juice | `lib/ui/widgets/flying_number.dart`, `lib/services/{audio,haptics}_service.dart` | Event-driven animation |
| 10 | Onboarding & Tutorial | `lib/game/features/tutorial/` + `lib/ui/features/tutorial/` | Tutorial state in sim |
| 11 | Balance & Economy Tuning | `lib/game/config/balance.dart`, `assets/data/*.json` | Content-data-driven tuning |
| 12 | Accessibility & Performance | Semantics conventions, DevTools profiling | Lint + widget test enforcement |

### Issues Resolved Inline

1. Added `lib/game/features/daily_rewards/` for 7-day streak system.
2. Portrait orientation lock flagged for Step 9 Development Environment section.

### Open Questions (Documented, Non-Blocking)

1. **Offline catch-up w/ active boosts/goldens:** Default = Leader-only income offline. Revisit with live balance data.
2. **`decimal` per-tick cost:** Spike required in Epic 1 — flagged as a risk, not architectural ambiguity.

### Validation Date

2026-04-21

**Overall Status: ✅ PASS — Ready for Implementation**

---

## Development Environment

### Prerequisites

| Tool | Version | Verified |
|---|---|---|
| Flutter SDK | **3.41.6 stable** | ✅ (`flutter --version` on 2026-04-21) |
| Dart | **3.11.4** (bundled) | ✅ |
| Xcode | 16.x (iOS builds) | Per Flutter 3.41 support matrix |
| Android Studio / command-line tools | NDK 27, cmdline-tools latest | Per Flutter 3.41 support matrix |
| CocoaPods | 1.15+ (iOS) | |
| Git | 2.40+ | |

### AI Tooling (MCP Servers — already configured)

These are registered in [.mcp.json](.mcp.json) at the project root — no manual setup required:

| MCP Server | Purpose | Install Type |
|---|---|---|
| `dart` (official Dart MCP) | Analyzer, hot reload, widget tree, runtime errors, tests | `dart mcp-server` (bundled with Dart SDK 3.11+) |
| `flutter-mcp` | Flutter-specific dev tooling | `npx flutter-mcp` |
| `context7` | Up-to-date library documentation | `npx @upstash/context7-mcp` |
| `memory` | Persistent knowledge graph across sessions | `npx @modelcontextprotocol/server-memory` |
| `sequential-thinking` | Multi-step reasoning aid | `npx @modelcontextprotocol/server-sequential-thinking` |

These give the AI direct access to Flutter for scene inspection, widget tree queries, hot reload, and context-aware code generation.

### Setup Commands

```bash
# Clone and enter project
git clone <repo-url> global-domination-flutter
cd global-domination-flutter

# Verify Flutter version
flutter --version
# Expected: Flutter 3.41.6 stable, Dart 3.11.4

# Install dependencies
flutter pub get

# Run code generation (Drift tables)
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test                    # widget + unit tests
dart test                       # pure-Dart tests under test/game/ (no Flutter binding)

# Launch on connected device / simulator
flutter devices
flutter run                      # debug mode with hot reload
flutter run --release           # release build for performance profiling
```

### First-Time Setup Notes

1. **Portrait lock** — add to `lib/main.dart`:
   ```dart
   import 'package:flutter/services.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
     // ...global error handlers and runApp()
   }
   ```
2. **Impeller on Android** — enabled by default in Flutter 3.27+; confirm with `flutter doctor -v`. If perf regressions appear on specific devices, opt out via `AndroidManifest.xml` `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`.
3. **Drift `build.yaml`** — add at project root:
   ```yaml
   targets:
     $default:
       builders:
         drift_dev:
           options:
             store_date_time_values_as_text: true
             named_parameters: true
             write_from_json_string_constructor: false
   ```
4. **Google Fonts offline bundling** (consider post-launch): Google Fonts downloads Fredoka at runtime by default — fine for v1 (first use caches). For production, bundle the TTF in `assets/fonts/` to avoid first-launch network fetch.
5. **Analysis options** — apply the lint config from the Implementation Patterns section of this document to `analysis_options.yaml`.

### First Steps for Epic 1 (Foundation & Project Setup)

1. Apply `analysis_options.yaml` with the lint configuration above
2. Wire `main.dart` with global error handlers + portrait lock
3. Set up Drift: create `lib/data/database/app_database.dart` with empty table list, generate via `build_runner`, verify migrations scaffold works
4. Create `lib/game/game_world.dart` skeleton with empty `applyCommand` + `tick`
5. Create `lib/providers/app_providers.dart` with `clockProvider` + `appDatabaseProvider`
6. Run the **big-number precision spike** (property-test `Decimal` at 1e38+ with compounded multipliers) — this is the earliest risk to validate
7. Run the **canvas performance spike** on Android API 21 device (parse `countries.geojson.json`, render all 79 polygons, pan/zoom — confirm 60fps baseline)

### CI Minimum Pipeline (add in Epic 1)

```yaml
# .github/workflows/ci.yml (sketch — tune to your runner)
- flutter pub get
- dart run build_runner build --delete-conflicting-outputs
- flutter analyze --fatal-infos
- dart test test/game/              # pure-Dart tests
- flutter test test/                 # widget tests
- flutter build apk --debug          # smoke-test build
- flutter build ios --no-codesign --debug
```

---

## Handoff Guidance

### What's Next

The architecture is complete and ready to drive implementation. Two parallel paths:

1. **Generate Project Context** (`gds-generate-project-context` skill) — produces a `project-context.md` optimized for AI agent consumption. Condenses this architecture into rules agents read before each story.
2. **Create Epics & Stories** (`gds-create-epics-and-stories` skill) — converts the 12 Flutter-rewrite epics in the GDD into implementable stories that reference the architecture's file locations and patterns.

### Input for Downstream Workflows

Downstream skills should use:
- This document (`_bmad-output/game-architecture.md`)
- The GDD (`_bmad-output/planning-artifacts/gdd.md`)
- The Flutter epics (`_bmad-output/planning-artifacts/epics.md`)

### Document Location

**Saved to:** [_bmad-output/game-architecture.md](_bmad-output/game-architecture.md)

---

_End of Game Architecture document._
