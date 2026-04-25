# Requirements Inventory

### Functional Requirements

**Core Gameplay Loop**

FR1: Player can tap an owned country on the world map to collect accumulated Influence; tap provides instant haptic + number-flyout + sound feedback.
FR2: Each country accumulates Influence on a generation timer (1–79 seconds tier-based); visible countdown/ready state shown on map.
FR3: Player can spend Influence to increase a country's Influence Power (IP) up to level 200; each level applies a 1.5× cost multiplier and increases generation.
FR4: Player can bulk-purchase IP upgrades at 1×, 10×, or 25× via a toggle.
FR5: Once a country reaches IP level 10, player can hire a Leader to automate that country's income (convert timer-based to continuous passive generation).
FR6: Player can upgrade a Leader through 4 tiers with multipliers 1.0× → 1.5× → 2.0× → 3.0×.
FR7: Player can spend Influence to unlock the next country within the current continent; unlock cost = previous country × 5 (exponential).
FR8: Player can unlock a continent when total Influence reaches that continent's threshold (0, 1B, 100T, 100Qi, 1e26, 1e32, 1e38 for Africa → Oceania respectively).
FR9: Completing all countries in a continent grants a permanent global multiplier (+0.25× through +1.75× by continent).
FR10: Continent milestones at 25% / 50% / 75% / 100% completion trigger reward events and celebration modals.

**Active Play Systems**

FR11: Golden Opportunities spawn randomly on map countries with a time-limited 10×–100× multiplier burst; player taps to claim.
FR12: Player can activate a Boost (2× multiplier for 30s) by spending Intel or watching a rewarded ad (ad path deferred to Epic 13).
FR13: Missions cycle rotating active-play objectives (claim Goldens, activate Boosts, stay active); completion rewards Intel.
FR14: The game exposes a 7-day Daily Reward streak that grants Influence and Intel on consecutive daily returns without punishing absence.
FR15: Player can earn any of 27 Achievements; each grants a permanent multiplier and/or Intel reward.

**Persistence & Offline**

FR16: All game state persists locally via Drift/SQLite with a normalized schema and typed, versioned migrations.
FR17: On app resume, the game calculates offline Influence earnings from automated (Leader-equipped) countries only, capped at 8 hours of elapsed time.
FR18: Offline earnings use stable multipliers (IP × Leader × continent × achievement × global upgrades) — active Boosts and Goldens do not continue multiplying offline (default; revisable post-launch).
FR19: On resume, an Offline Reward Modal presents earned Influence before any other UI interaction.
FR20: On save-file corruption, the game restores from the most recent `schema_backup_v{n}.sqlite` or presents a Save Recovery screen.

**World Map & Interaction**

FR21: The world map is rendered via Flutter `CustomPainter` on a `Canvas` using GeoJSON polygons for 79 countries — no external map library.
FR22: Player can pan the map via drag and zoom via pinch or on-screen buttons; zoom range has a sensible max determined by the Epic 1 canvas performance spike and the Epic 2 renderer design (starting point for discussion: 10×, but the Flutter `CustomPainter` implementation may support a different ceiling than the v1 SVG approach did).
FR23: Tap hit-testing on map countries uses cached bounding boxes + point-in-polygon (ray-casting) on inverse-transformed coordinates.
FR24: Countries are rendered with state-specific colors: locked, unlocked/generating, ready-to-collect, automated.
FR25: Ready-to-collect countries display a visual affordance (e.g. breathing pulse / highlight) to draw the eye.
FR26: The map is the default screen on every cold launch.
FR27: On app launch (post-tutorial), the map auto-focuses on the player's latest unlocked or in-progress country.

**UI Shell & HUD**

FR28: The app uses a persistent bottom navigation bar with 5 tabs (tab set confirmed in Epic 8; expected: Map, Upgrades, Leaders, Achievements, Minigames placeholder).
FR29: A global HUD renders across all tabs showing primary currency (Influence) and secondary currency (Intel) with per-currency icons.
FR30: Tabs use `IndexedStack` so switching does not reparse GeoJSON or lose tab state.
FR31: Modals (Offline Reward, Daily Reward, Continent Complete, Achievement Earned, Purchase Confirm) queue sequentially — never stack — with priority order Offline > Daily > Celebration > Achievement.
FR32: The Settings screen opens as a modal overlay from a HUD gear icon rather than as a bottom-nav tab.
FR33: The Upgrades tab exposes only unlocked countries per continent plus the next-unlock teaser; locked continents are not shown as upgrade tabs.
FR34: The Leaders tab groups countries by continent (accordion / grouped rows) with hire/upgrade actions surfaced contextually per row.

**Game Feel**

FR35: Every meaningful player action (tap, unlock, upgrade, hire, claim, milestone) emits a typed `GameEvent` that `AudioService` and `HapticsService` subscribe to and fan out SFX + haptic patterns — no scattered `playSound()` calls in UI.
FR36: Five core SFX are wired: collect, unlock, upgrade, milestone, golden. Optional extended SFX (continent-complete fanfare, auto-tick, zoom whoosh) land in Epic 9 if assets pass review.
FR37: Flying-number animations spawn on country tap showing the collected amount ascending and fading out.
FR38: Country unlock and continent-complete trigger dedicated visual celebrations (e.g. radial ripple on first-in-continent, flash on subsequent, continent fanfare animation).

**Onboarding**

FR39: First-time players receive a step-by-step tutorial overlay guiding them through: tap-to-collect → first upgrade → hire first Leader → unlock next country (minimum; full 12-step script finalized in Epic 10).
FR40: Tutorial steps auto-advance on the triggering game action rather than requiring manual "next" taps where possible.
FR41: Tutorial progress is persisted; partially-completed tutorial resumes from the same step after app restart.
FR42: After tutorial completion, contextual one-time hints surface on first exposure to new systems (Golden, Boost, Leader-ready milestone) and auto-dismiss after ~4 seconds.

**Progression & Stats**

FR43: Player has access to a Stats screen (reachable from a HUD icon, not bottom nav) showing total Influence, Intel, countries owned, continents completed, achievements earned, active multipliers.
FR44: Continent progression is communicated via visual progress indicators (count of owned vs total per continent).

**Content**

FR45: 79 countries and 7 continents are loaded once at boot from `assets/data/countries.json` + `continents.json` into an immutable `ContentRegistry`.
FR46: 27 achievements and all missions are loaded from content JSON — condition functions are data-driven, not hardcoded.

### NonFunctional Requirements

**Performance**

NFR1: The game sustains 60fps on mid-range 2021+ devices; the `CustomPainter` map must pan/zoom/tap fluidly with 79 country polygons rendered.
NFR2: Cold start to interactive map is under 3 seconds on target devices.
NFR3: No logging, large allocations, or `Path` rebuilds in per-tick sim math or per-frame painter hot paths.
NFR4: `Path` rebuilds are cached to `Picture`/`Image` and invalidated only on country-state version change if profiling shows they dominate.

**Correctness & Precision**

NFR5: All game economy math uses `Influence` / `Intel` value objects wrapping `decimal: ^3.0.2` — raw `double` for currency values is forbidden.
NFR6: Big-number precision is validated at 1e38+ with compounded multipliers via property tests (Epic 1 spike).
NFR7: The multiplier stack order is pinned exactly (IP → Leader → continent → achievement → global upgrade → Golden → Boost) and enforced in one function: `IncomeCalculator.compute`.

**Architecture Boundaries**

NFR8: `lib/game/` contains zero Flutter imports — enforced by `custom_lint` rule or CI grep.
NFR9: `lib/game/` never imports `lib/data/`; `data/` maps to `game/` types but not vice versa.
NFR10: UI never touches Drift directly and never mutates `GameState` — UI dispatches `GameCommand` via `gameWorldProvider.notifier.apply(cmd)`.
NFR11: Services subscribe to `GameEvent` but never emit — only UI and `GameLoop` drive the sim.
NFR12: Only `IncomeCalculator.compute` produces income rates; duplicates are a code-review failure.

**Persistence Integrity**

NFR13: Zero save-data corruption tolerance; schema changes require a typed Drift migration file and a `schema_backup_v{n}.sqlite` snapshot before migrating.
NFR14: Persistence writes are event-driven + 2s debounced `totalInfluence` snapshot; never per-tick.

**Reliability & Telemetry**

NFR15: Crash rate target < 1% of sessions; global handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`) route to `CrashReporter`.
NFR16: Recoverable game errors use `Result<T, GameError>` sealed hierarchy — no exceptions for control flow.
NFR17: Crash log ring buffer (bounded 100 entries) is reachable in release via a Support screen for field debugging.

**Accessibility**

NFR18: Every interactive widget is wrapped in `Semantics` with an accessible label; map countries, HUD elements, and all modals are screen-reader navigable.
NFR19: Touch targets for primary actions meet platform a11y minimum (iOS 44pt / Android 48dp).
NFR20: Country states are distinguishable by high-contrast color AND a non-color cue (e.g. pulse, badge) for color-blind players.

**Design System**

NFR21: All colors, spacing, and typography reference centralized tokens via `ThemeExtension`s and `Spacing.*` constants — no hardcoded color literals in widgets.
NFR22: All icons use vector sources (Material Icons or `flutter_svg`) — no emoji icons.
NFR23: Typography uses Fredoka loaded via `google_fonts`.

**Build & Release**

NFR24: App size stays under 50MB (build output monitored per release).
NFR25: No OTA patching — all code changes ship via App Store + Play Store submission; release cadence must tolerate 1–3 day store review.
NFR26: Supported platforms for v1: iOS 16.0+, Android API 21+; portrait orientation locked.

**Content & Configuration**

NFR27: Game constants (`lib/game/config/constants.dart`), balance values (`lib/game/config/balance.dart`), content JSON (`assets/data/`), and player settings (Drift `settings` table) are kept strictly separate — no balance numbers hardcoded in UI or sim logic.

### Additional Requirements

**From Architecture — Setup & Foundation**

- No starter template; scaffold already exists via `flutter create`. Epic 1 Story 1 is about wiring foundations (Riverpod scope, global handlers, portrait lock, Drift scaffold, `GameWorld` skeleton), not scaffold creation.
- Apply `analysis_options.yaml` with the specified lint config (`include: flutter_lints`, `avoid_print: error`, `always_declare_return_types`, `require_trailing_commas`, etc.) in Epic 1.
- Configure `build.yaml` for Drift code generation (`store_date_time_values_as_text: true`, `named_parameters: true`).
- Set up CI pipeline: `flutter pub get` → `build_runner build` → `flutter analyze --fatal-infos` → `dart test test/game/` → `flutter test` → smoke builds for iOS and Android.
- Add `custom_lint` rule OR CI grep check that fails if `lib/game/**` imports `package:flutter/*`.

**From Architecture — Development Environment**

- MCP servers already registered in `.mcp.json`: `dart`, `flutter-mcp`, `context7`, `memory`, `sequential-thinking`. Agents should prefer `dart` MCP tools over shell for Dart/Flutter operations.

**From Architecture — Risk Spikes (Epic 1)**

- **Big-number precision spike**: property-test `Decimal` arithmetic at 1e38 with compounded multipliers (×3.0 × 1.75 × 2.0 × 100) — confirm no silent rounding, measure per-op cost. Spike outcome may add a "cache per-country rate" story if per-tick cost is too high.
- **Canvas performance spike**: parse `countries.geojson.json`, render all 79 polygons, pan + zoom + tap on a low-end Android API 21 device — confirm 60fps baseline before committing to the renderer design.

**From Architecture — Asset Inventory**

- GeoJSON world map (`assets/geo/countries.geojson.json`) is present — ported from v1.
- 8 SFX files already present in `assets/audio/` (GDD lists 5 core; 3 extras `continent_complete`, `auto_tick`, `zoom` available for Epic 9 use).
- Content JSON files (`countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, `global_upgrades.json`) to be authored during relevant feature epics (content ported from v1 where possible).

**From Architecture — Open Questions Carried Forward**

- Offline catch-up with active Boosts / Goldens: default "Leader-only income offline" — revisit post-launch with live balance data. Flag for Epic 7 story acceptance.

**From GDD — Out of Scope (Not to be stored as epics/stories here)**

- IAP & rewarded ads → future Epic 13
- Research trees & diplomatic influence → future Epic 14
- Prestige / reset mechanics → future Epic 15
- Social features (leaderboards, ghost progress, seasonal challenges) → future Epic 16
- Art evolution (rich illustrations, animated country effects) → future Epic 17
- Background music → not v1.0
- Web / PC / desktop ports → deferred
- Localization → English only for v1.0
- Real-time multiplayer → never planned

### UX Design Requirements

All UI is built fresh on Flutter widgets, `CustomPainter`, Riverpod, and Drift. UX intent comes from the GDD sections "Controls and Input," "Art and Audio Direction," and "Level Design Framework."

**Strongly recommended: author a Flutter UX Design Specification via `gds-create-ux-design` before Epic 7 stories are picked up.**

Why before Epic 7 specifically: Epic 7 ("Complete the Shell") locks in the concrete app structure — tab set and order, HUD layout and typography, screen wireframes for Upgrades / Leaders / Stats / Settings, modal system behavior, country-state visual palette, and the reusable component inventory (currency badges, upgrade cards, leader rows, floating action cards, etc.). These are cheap to decide up front and expensive to rework once six stories have implemented against prose descriptions. A UX spec lets Epic 7 stories cite a wireframe and design tokens instead of re-describing layout in acceptance criteria.

The following Epic 7 decisions still need explicit confirmation from Sharon before stories are written:

- **Story 7.2 — 5-tab bottom nav set and order.** Current GDD default: Map / Upgrades / Leaders / Achievements / Minigames (Settings via HUD gear).
- **Story 7.3 — HUD content and layout.** Currencies + icons + stats icon + gear — positions and sizes unspecified.
- **Story 7.4 — Modal queue priority.** Currently: Offline > Daily > Continent-complete > Achievement > Purchase confirm.
- **Story 7.7 — Upgrades tab structure.** Unlocked countries + next-unlock teaser per continent — layout and interaction detail unspecified.
- **Story 7.8 — Leaders tab accordion design.** Grouped-by-continent — expand/collapse behavior, row design unspecified.
- **Epic 8 visuals** — country-state palette (locked / generating / ready / automated colors), breathing-pulse animation parameters, celebration-animation choreography.

Two valid paths forward:

1. **Author a Flutter UX spec first** (invoke `gds-create-ux-design`), then resume sprint planning with Epic 7 stories referencing concrete wireframes. Adds ~1–2 days of planning; saves rework risk.
2. **Proceed without a UX spec** and make UX decisions inside each Epic 7 story's implementation — the developer proposes a design in the PR, the product owner reviews and iterates in-thread. Faster to start; higher risk of mid-epic reshuffling if a decision made in Story 7.2 conflicts with one surfaced in Story 7.7.

Either is workable for a solo-dev project. The recommendation leans toward option 1 because Epic 7 touches six screens and their consistency benefits from a single pass of deliberate design.

### FR Coverage Map

| FR | Epic | Description |
|---|---|---|
| FR1 | Epic 2 | Tap-to-collect Influence with haptic + flyout + sound |
| FR2 | Epic 2 | Country generation timer + ready state |
| FR3 | Epic 3 | Influence Power upgrades to level 200 |
| FR4 | Epic 3 | Bulk purchase 1×/10×/25× |
| FR5 | Epic 3 | Leader hire at IP level 10 |
| FR6 | Epic 3 | Leader tier upgrades (1.0× → 3.0×) |
| FR7 | Epic 4 | Country unlock cost = previous × 5 |
| FR8 | Epic 4 | Continent unlock Influence thresholds |
| FR9 | Epic 4 | Continent completion permanent multipliers |
| FR10 | Epic 4 | Continent milestones (25/50/75/100%) |
| FR11 | Epic 5 | Golden Opportunity spawn + claim |
| FR12 | Epic 5 | Boost activation (2× / 30s) |
| FR13 | Epic 5 | Missions with Intel rewards |
| FR14 | Epic 5 | 7-day Daily Reward streak |
| FR15 | Epic 5 | 27 Achievements with multiplier rewards |
| FR16 | Epic 6 | Drift/SQLite normalized persistence |
| FR17 | Epic 6 | Offline earnings (Leader-only, 8h cap) |
| FR18 | Epic 6 | Stable multipliers only offline |
| FR19 | Epic 6 | Offline Reward Modal on resume |
| FR20 | Epic 6 | Save corruption recovery |
| FR21 | Epic 2 | CustomPainter GeoJSON world map (no external lib) |
| FR22 | Epic 2 | Map pan/zoom controls |
| FR23 | Epic 2 | Hit-testing (bbox + point-in-polygon) |
| FR24 | Epic 2 | Country state colors (locked/generating/ready/automated) |
| FR25 | Epic 8 | Ready-to-collect visual affordance (breathing pulse) |
| FR26 | Epic 7 | Map is default cold-launch screen |
| FR27 | Epic 7 | Auto-focus on latest country post-tutorial |
| FR28 | Epic 7 | Bottom navigation with 5 tabs |
| FR29 | Epic 7 | Global HUD with Influence + Intel |
| FR30 | Epic 7 | IndexedStack-backed tabs (preserve map state) |
| FR31 | Epic 7 | Sequential modal queue with priority |
| FR32 | Epic 7 | Settings as HUD-gear modal overlay |
| FR33 | Epic 7 | Upgrades tab: unlocked countries + next teaser |
| FR34 | Epic 7 | Leaders tab: grouped-by-continent accordion |
| FR35 | Epic 8 | Event bus drives all SFX / haptics |
| FR36 | Epic 8 | Five core SFX wired |
| FR37 | Epic 8 | Flying-number animation on tap |
| FR38 | Epic 8 | Unlock + continent-complete celebration animations |
| FR39 | Epic 9 | First-time tutorial overlay (minimum script) |
| FR40 | Epic 9 | Auto-advance tutorial on triggering action |
| FR41 | Epic 9 | Tutorial progress persisted across restarts |
| FR42 | Epic 9 | Post-tutorial contextual one-time hints |
| FR43 | Epic 7 | Stats screen reachable from HUD |
| FR44 | Epic 7 | Continent progression visual indicators |
| FR45 | Epic 1 | ContentRegistry loads countries/continents at boot |
| FR46 | Epic 1 | Achievements + missions loaded from content JSON |
| NFR1 | Epic 11 | 60fps sustained on mid-range devices |
| NFR2 | Epic 11 | Cold start < 3s to interactive map |
| NFR3 | Epic 11 | No logging/allocations in hot paths |
| NFR4 | Epic 11 | Path caching as Picture/Image when dominant |
| NFR5 | Epic 1 | Influence/Intel value objects wrap decimal |
| NFR6 | Epic 1 | Big-number precision spike (1e38+) |
| NFR7 | Epic 3 | Multiplier stack pinned in IncomeCalculator |
| NFR8 | Epic 1 | No Flutter imports in lib/game/ |
| NFR9 | Epic 1 | lib/game/ never imports lib/data/ |
| NFR10 | Epic 1 | UI dispatches GameCommand only |
| NFR11 | Epic 8 | Services subscribe only — never emit |
| NFR12 | Epic 3 | Single IncomeCalculator source of truth |
| NFR13 | Epic 6 | Typed migrations + schema backup |
| NFR14 | Epic 6 | Event-driven + debounced writes |
| NFR15 | Epic 1 | Global crash handlers + CrashReporter |
| NFR16 | Epic 1 | Result<T, GameError> for recoverable errors |
| NFR17 | Epic 1 | Release-accessible crash ring buffer |
| NFR18 | Epic 11 | Semantics on every interactive widget |
| NFR19 | Epic 11 | Touch targets meet platform a11y minimum |
| NFR20 | Epic 11 | Non-color cue on country states |
| NFR21 | Epic 7 | Centralized theme tokens — no hardcoded colors |
| NFR22 | Epic 7 | Vector icons only |
| NFR23 | Epic 7 | Fredoka via google_fonts |
| NFR24 | Epic 11 | App size < 50MB |
| NFR25 | Epic 1 | No OTA — plan release cadence accordingly |
| NFR26 | Epic 1 | iOS 16+ / Android API 21+ / portrait lock |
| NFR27 | Epic 10 | Constants / balance / content / settings separated |
