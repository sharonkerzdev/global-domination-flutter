# Architectural Decisions

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
