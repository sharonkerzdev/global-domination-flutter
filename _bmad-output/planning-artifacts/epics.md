---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - '_bmad-output/planning-artifacts/gdd.md'
  - '_bmad-output/game-architecture.md'
---

# global-domination-flutter - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for global-domination-flutter, decomposing the requirements from the GDD v2 and the Game Architecture into implementable stories.

The GDD v2 defines 12 active Flutter-rewrite epics (Epics 1-12) plus 5 future epics (13-17) out of scope for v1.0. **This is a fresh Flutter build — the GDD v2 is the sole design source of truth.**

## Requirements Inventory

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

## Epic List

### Epic 1: Foundation — Architecture Boundaries, Persistence Scaffold, and Safety Net
Deliver a stable Flutter app scaffold that enforces the headless-simulation boundary, loads game content, persists player settings, handles errors without crashing to white, and passes the two Epic-1 risk spikes (big-number precision and canvas performance). After this epic the app boots to a placeholder screen with guaranteed-safe foundations — not yet playable, but every subsequent epic can build on proven primitives without re-litigating architecture.
**FRs covered:** FR45, FR46
**NFRs covered:** NFR5, NFR6, NFR8, NFR9, NFR10, NFR15, NFR16, NFR17, NFR25, NFR26

### Epic 2: Playable Map — Tap a Country, Earn Influence
Deliver the minimum playable vertical slice: a custom-rendered world map with a handful of unlocked countries the player can pan, zoom, and tap to collect Influence. The `GameWorld` tick system drives generation; `CustomPainter` renders state-colored country polygons; hit-testing routes taps into `GameCommand`s. After this epic a player can tap the map and watch Influence go up — the core dopamine loop is proven end-to-end on the Flutter stack.
**FRs covered:** FR1, FR2, FR21, FR22, FR23, FR24
**NFRs covered:** (none exclusive — NFR1/NFR2/NFR3/NFR11 validated incrementally across Epics 2, 8, 11)

### Epic 3: Power Up — Upgrades, Leaders, and Automation
Deliver the "feel more powerful" layer: players spend Influence to raise Influence Power (1×/10×/25× bulk), hire Leaders at IP 10 to automate income, and upgrade Leader tiers. The multiplier stack lives in a single `IncomeCalculator` — the authoritative source for all rate math. After this epic, manual tapping transitions naturally to idle generation.
**FRs covered:** FR3, FR4, FR5, FR6
**NFRs covered:** NFR7, NFR12

### Epic 4: Expand — Unlocks, Continents, and Completion Bonuses
Deliver the geographic-progression promise: players unlock new countries with exponential cost scaling, unlock new continents at Influence thresholds, hit 25/50/75/100% continent milestones for bonus rewards, and receive a permanent global multiplier on continent completion. After this epic, the map fills up over time and the "conquer the world" arc is real, not a promise.
**FRs covered:** FR7, FR8, FR9, FR10

### Epic 5: Active Play — Goldens, Boosts, Missions, Dailies, Achievements
Deliver the burst / retention layer: Golden Opportunities spawn on the map for 10–100× tap-to-claim bursts, Boosts give 2× for 30s in exchange for Intel, rotating Missions reward Intel for active play, the 7-day Daily Reward streak encourages return visits, and 27 Achievements grant permanent multiplier rewards. After this epic there are reasons to open the app beyond just collecting.
**FRs covered:** FR11, FR12, FR13, FR14, FR15

### Epic 6: Never Lose Progress — Persistence and Offline Earnings
Deliver the Offline Respectful pillar: all state persists to Drift/SQLite via a normalized schema with typed migrations; on resume, offline earnings are computed from Leader-automated countries only (capped at 8h) with stable multipliers, presented via an Offline Reward Modal before any other UI interaction; save corruption has a defined recovery path. After this epic, players can close the app for days without anxiety.
**FRs covered:** FR16, FR17, FR18, FR19, FR20
**NFRs covered:** NFR13, NFR14

### Epic 7: Complete the Shell — Navigation, HUD, Stats, Settings, Upgrades & Leaders Screens
Deliver the productized app shell around the map: 5-tab bottom navigation (Map / Upgrades / Leaders / Achievements / Minigames placeholder), global HUD with Influence + Intel currency badges across all tabs, Stats screen reachable from a HUD icon, Settings as a HUD-gear modal, Upgrades tab showing unlocked countries + next-unlock teaser per continent, Leaders tab with grouped-by-continent accordion, sequential modal queue with priority. After this epic the app feels like a shipped product, not a prototype.
**FRs covered:** FR26, FR27, FR28, FR29, FR30, FR31, FR32, FR33, FR34, FR43, FR44
**NFRs covered:** NFR21, NFR22, NFR23

### Epic 8: Juice — Game Feel Layer
Deliver the sensory polish layer: every typed `GameEvent` routes through `AudioService` and `HapticsService` (no scattered `playSound()` calls in UI); five core SFX (collect / unlock / upgrade / milestone / golden) are wired; flying numbers spawn on tap; ready-to-collect countries breathe; unlocks and continent-completes get dedicated celebration animations. After this epic every interaction has weight.
**FRs covered:** FR25, FR35, FR36, FR37, FR38
**NFRs covered:** NFR11

### Epic 9: Onboard — Tutorial and Contextual Hints
Deliver a first-time player journey: a step-by-step tutorial overlay covers tap-to-collect → first upgrade → first Leader → first unlock; steps auto-advance on the triggering action; progress survives app restart; post-tutorial one-time contextual hints fire on first exposure to Golden / Boost / Leader-ready moments and auto-dismiss. After this epic a cold first-time player understands the loop without external explanation.
**FRs covered:** FR39, FR40, FR41, FR42

### Epic 10: Tune — Economy and Balance
Deliver tuned progression curves on the Flutter engine: content JSON (`countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, `global_upgrades.json`) is populated and validated; balance constants (`BalanceConfig`) tuned against playtest data; pacing walls revisited against the new smoother game loop; late-game balance refined via instrumented runs. After this epic the numbers feel right — not too fast, not grindy.
**FRs covered:** _(no new FR coverage — tunes data underlying FR3, FR7, FR8, FR9, FR11, FR12, FR13, FR15 across prior epics)_
**NFRs covered:** NFR27

### Epic 11: Harden — Accessibility and Performance
Deliver shippable quality: every interactive widget wraps in `Semantics` with proper labels; country states have non-color cues; touch targets meet platform minimums; app sustains 60fps on low-end Android (API 21); cold start stays under 3s; `Path` rebuilds are cached where profiling flags them; app size stays under 50MB. After this epic the game is store-submission ready.
**FRs covered:** _(covers NFRs only — polish applies across all epics)_
**NFRs covered:** NFR1, NFR2, NFR3, NFR4, NFR18, NFR19, NFR20, NFR24

### Future Epics (Out of Scope for v1.0)

- **Epic 12 (future): In-App Purchases & Monetization** — rewarded ads, IAP store, premium value packs. Dependencies: Epics 1–11 stable.
- **Epic 13 (future): Research Trees & Diplomatic Influence** — branching upgrade paths and alternative strategies. Dependencies: Epic 10 (balance) + Epic 7 (UI shell).
- **Epic 14 (future): Prestige/Reset System** — optional voluntary reset for permanent multipliers. Dependencies: Epic 10 (balance) + Epic 13 (research trees).
- **Epic 15 (future): Social Features** — asynchronous leaderboards, ghost progress, seasonal challenges. Dependencies: Epic 12 (IAP for seasonal rewards).
- **Epic 16 (future): Art Evolution** — illustrated countries, animated map elements, richer visual effects. Dependencies: Epic 7 (UI shell) + Epic 8 (game feel).

These are intentionally NOT broken into stories in this document — they will be elaborated during the sprint cycle where they enter active development.

### Epic Sequencing and Dependencies

**Phase 1 — Engine (Epic 1 → Epic 2):** Foundation unblocks Playable Map. Epic 2 depends on Epic 1's `GameWorld` + `ContentRegistry` + persistence scaffold existing.

**Phase 2 — Mechanics (Epic 3 → Epic 4 → Epic 5):** Each builds on the prior. Upgrades/Leaders (3) must exist before Continent completion bonuses (4) matter; Continents (4) must exist before Missions referencing continent progress (5) can author conditions. Daily Rewards and Achievements within Epic 5 are largely independent.

**Phase 3 — Durability (Epic 6):** Persistence can start in parallel with Epic 2 (event-driven write points need to exist as mechanics land) but event-driven writes for Epic 5 features must be wired before Epic 6 closes. Offline earnings flow depends on Leader system (Epic 3).

**Phase 4 — Experience (Epic 7 → Epic 8 → Epic 9):** Shell first, then juice, then onboarding. Shell provides the surfaces (tabs, HUD, modals) where juice (Epic 8) fires and tutorial (Epic 9) spotlights.

**Phase 5 — Polish (Epic 10 → Epic 11):** Balance tuning needs real runs of the full game (Epics 1–9 landed); accessibility + performance hardening benefits from frozen surfaces.

Epics are **standalone in the user-value sense** — each delivers a distinguishable player-visible outcome — but Flutter-rewrite scope means they are **implementation-sequenced**: Epic 2 cannot ship before Epic 1, Epic 4 needs Epic 3's Leader system, etc. This is expected for a ground-up rewrite and is documented here so story ordering respects it.

---

## Epic 1: Foundation — Architecture Boundaries, Persistence Scaffold, and Safety Net

**Goal:** Deliver a Flutter app that boots safely, enforces the headless-simulation boundary, loads game content, persists settings, handles errors gracefully, and proves the two Epic-1 risk spikes (big-number precision at 1e38+, canvas performance on low-end Android). After this epic the app boots to a placeholder screen on safe foundations.

### Story 1.1: Wire Global Safety Net and Portrait Lock in `main.dart`

As a developer,
I want global error handlers, portrait orientation lock, and a Riverpod `ProviderScope` configured in `main.dart`,
So that uncaught errors are captured instead of crashing the app silently and orientation is guaranteed from first frame.

**Acceptance Criteria:**

**Given** the app is launched
**When** an uncaught error occurs in a Flutter widget, platform error, or zoned code
**Then** `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` all route the error to a `CrashReporter` singleton
**And** the app does not crash to a blank white screen — it displays a fallback screen with a "Restart" CTA.

**Given** the app launches on any supported device
**When** the first frame renders
**Then** `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` has been awaited before `runApp()`
**And** the device cannot rotate the app to landscape.

**Given** the `main.dart` entry point
**When** the app starts
**Then** `runApp()` is wrapped in a `ProviderScope` so Riverpod providers are available throughout the widget tree.

### Story 1.2: Configure Lint and Analysis Options

As a developer,
I want `analysis_options.yaml` configured with the project's lint rules,
So that architectural violations and style inconsistencies are caught at analyze time, not review time.

**Acceptance Criteria:**

**Given** `analysis_options.yaml` at the project root
**When** `flutter analyze --fatal-infos` runs
**Then** the analyzer uses `package:flutter_lints/flutter.yaml` as a base
**And** `avoid_print: error`, `unnecessary_null_comparison: error`, `unrelated_type_equality_checks: error` are enforced as errors
**And** `always_declare_return_types`, `prefer_final_fields`, `prefer_final_locals`, `require_trailing_commas`, `unawaited_futures` are enabled as lints
**And** generated files (`**/*.g.dart`, `**/*.freezed.dart`, `build/**`) are excluded.

**Given** a developer adds `print('debug')` anywhere under `lib/`
**When** `flutter analyze` runs
**Then** the analyze step fails.

### Story 1.3: Enforce "No Flutter in `lib/game/`" Boundary

As an architect,
I want a mechanized check that fails CI if any file under `lib/game/` imports `package:flutter/*`,
So that the headless-simulation invariant cannot silently drift.

**Acceptance Criteria:**

**Given** the project CI pipeline
**When** any file under `lib/game/**/*.dart` contains a line matching `import 'package:flutter/` or `import "package:flutter/`
**Then** the CI step fails with a clear error naming the offending file and line
**And** the check is implemented either as a `custom_lint` rule or a CI grep script, whichever is simpler.

**Given** a developer tries to add `import 'package:flutter/material.dart';` to a new file in `lib/game/`
**When** they run `flutter analyze` or push to CI
**Then** the build fails before tests run.

### Story 1.4: Scaffold Drift Database and Apply Migrations

As a developer,
I want Drift configured with a minimal `AppDatabase` (empty or near-empty table list), code generation running via `build_runner`, and a `MigrationStrategy` wired,
So that future stories can add tables incrementally without re-scaffolding persistence.

**Acceptance Criteria:**

**Given** the project has `drift: ^2.26.1` and `sqlite3_flutter_libs: ^0.5.25` in `pubspec.yaml`
**When** a developer runs `dart run build_runner build --delete-conflicting-outputs`
**Then** `*.g.dart` files generate cleanly under `lib/data/database/`
**And** no errors or warnings are produced.

**Given** `build.yaml` at the project root
**When** Drift generates code
**Then** it uses `store_date_time_values_as_text: true` and `named_parameters: true`.

**Given** the app launches for the first time on a fresh install
**When** `AppDatabase` initializes
**Then** the database opens at schema version 1 with zero rows in zero custom tables (only Drift's internal metadata is present)
**And** no migration runs.

**Given** a schema version bump (e.g. v1 → v2) is introduced in a later story
**When** the app launches against a v1 database
**Then** a backup file `schema_backup_v1.sqlite` is written to app documents before the migration executes
**And** the migration runs via Drift's typed `MigrationStrategy`.

### Story 1.5: Create `Influence` and `Intel` Value Objects Wrapping `decimal`

As a developer,
I want `Influence` and `Intel` value objects that wrap `package:decimal` with typed arithmetic operators and a formatter,
So that all game math flows through typed currency types and raw `double` cannot silently be used for economy values.

**Acceptance Criteria:**

**Given** `lib/game/values/influence.dart` and `lib/game/values/intel.dart`
**When** a developer imports them
**Then** each exposes `+`, `-`, `*` (with `Decimal` and `num` overloads), `<`, `>`, `==`, `hashCode`, and a `format()` method that returns an abbreviated string (K / M / B / T / Qa / Qi / Sx / Sp / Oc / No / De).

**Given** the value objects
**When** unit tests add `Influence(Decimal.parse('1e20'))` and `Influence(Decimal.parse('3e20'))`
**Then** the result equals `Influence(Decimal.parse('4e20'))` with no precision loss.

**Given** the value objects
**When** `Influence(Decimal.parse('1e35')).format()` is called
**Then** the returned string uses the abbreviated notation documented in the formatter (not scientific notation).

### Story 1.6: Big-Number Precision Spike (Property Tests at 1e38+)

As an architect,
I want property tests that validate `decimal` arithmetic at 1e38 with the full compounded multiplier stack,
So that we confirm before building more that no silent rounding occurs and per-op cost is acceptable on the tick hot path.

**Acceptance Criteria:**

**Given** a property-test suite under `test/game/values/influence_precision_test.dart`
**When** it runs `Decimal` operations representing `1e38 × 3.0 × 1.75 × 2.0 × 100` compounded across many iterations
**Then** the result exactly matches the expected symbolic value (computed separately) with zero rounding error.

**Given** a per-op micro-benchmark in the same test file (documented as a reference, not asserted)
**When** it runs 10,000 multiplications
**Then** the measured per-op cost is recorded in a comment or small JSON report for team review
**And** if the per-op cost is above a documented threshold (e.g. 10µs), a follow-up story "Cache per-country rates" is added to the Epic 10 (Tune) backlog.

### Story 1.7: `ContentRegistry` Loads from Assets at Boot

As a developer,
I want a `ContentRegistry` that loads `countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, and `global_upgrades.json` from `assets/data/` once at boot and exposes immutable typed collections,
So that reducers and UI read from one in-memory source of truth and never call `rootBundle` themselves.

**Acceptance Criteria:**

**Given** minimal placeholder JSON files exist at `assets/data/*.json` (even if most are empty arrays for now)
**When** `ContentRegistry.loadFromAssets()` is awaited
**Then** it returns an immutable `ContentRegistry` with `Map<CountryId, CountryDef>`, `Map<ContinentId, ContinentDef>`, and lists for achievements/missions/leaders/global upgrades.

**Given** a `contentRegistryProvider` defined in `lib/providers/app_providers.dart` as a `FutureProvider<ContentRegistry>`
**When** any widget calls `ref.watch(contentRegistryProvider)`
**Then** it resolves to the same registry instance across the app lifetime (no duplicate loads).

**Given** a malformed JSON file in `assets/data/`
**When** the app boots
**Then** `ContentRegistry.loadFromAssets()` surfaces a `BootError` and the `GlobalDominationApp` displays a `BootErrorScreen` with reinstall guidance.

### Story 1.8: Define `GameError` Sealed Hierarchy and `Result<T, GameError>`

As a developer,
I want a `GameError` sealed class hierarchy (`UserError` / `InternalError` variants) and a `Result<T, E>` sealed type,
So that recoverable game-logic failures flow through typed returns rather than exceptions.

**Acceptance Criteria:**

**Given** `lib/game/values/result.dart` and `lib/game/game_error.dart`
**When** a reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))`
**Then** the caller can pattern-match on `Success` / `Failure` exhaustively.

**Given** the `GameError` hierarchy
**When** it is exhaustively pattern-matched
**Then** `UserError` variants include at minimum `insufficientFunds`, `locked`, `invalidTarget`
**And** `InternalError` variants include at minimum `missingCountry`, `invariantBroken`, `persistenceFailure`, `migrationFailure`.

**Given** unit tests
**When** they construct each variant
**Then** equality, `hashCode`, and `toString` behave per Dart conventions and are covered.

### Story 1.9: Skeleton `GameWorld` With `tick` and `applyCommand` (No-Op)

As a developer,
I want a `GameWorld` class in `lib/game/game_world.dart` with `tick(Duration dt)`, `applyCommand(GameCommand)`, `GameState get state`, and `Stream<GameEvent> get events`, initially returning no-ops or empty state,
So that subsequent epics have a stable aggregator to attach reducers and events to.

**Acceptance Criteria:**

**Given** `GameWorld` is instantiated with an injected `Clock` and a `ContentRegistry`
**When** `tick(Duration.zero)` is called
**Then** it returns without error and `state` is unchanged.

**Given** `GameWorld`
**When** `applyCommand(cmd)` is called for any `GameCommand` variant defined so far (initially an empty sealed hierarchy or a single `Noop`)
**Then** it returns `Result.success(null)` and emits no event — a placeholder ready to be extended.

**Given** the `events` stream
**When** a subscriber attaches before any event emission
**Then** the stream is a broadcast stream that survives multiple subscribers.

**Given** `GameWorld`
**When** imported
**Then** it has zero `package:flutter/*` imports (enforced by Story 1.3).

### Story 1.10: Crash Log Ring Buffer and Support Screen

As a player,
I want a hidden "Support" screen (reachable via a 5-second long-press on a settings element in release) that shows the last 100 crash/warning entries,
So that if the app misbehaves I can share the recent error log without needing developer tools.

**Acceptance Criteria:**

**Given** a `crash_logs` Drift table with bounded `N=100` entries
**When** `CrashReporter.report()` is called (from any of the three global handlers)
**Then** a new row is inserted with timestamp, level, tag, message, and stack trace
**And** if the row count exceeds 100, the oldest is deleted.

**Given** a "Support" screen reachable via a 5-second long-press on a settings element in release (wiring placeholder — actual Settings screen ships in Epic 7)
**When** opened
**Then** it displays the last 100 entries, newest first, with a "Copy All" button.

**Given** `kDebugMode` is `false`
**When** the long-press is triggered
**Then** the Support screen opens (this path remains in release, unlike debug-only cheats).

### Story 1.11: Canvas Performance Spike on Low-End Android

As an architect,
I want a throwaway spike screen that parses `countries.geojson.json`, renders all 79 country polygons with a naive `CustomPainter`, and supports pan + zoom,
So that we measure frame rate on a low-end Android API 21 device before committing to the renderer design in Epic 2.

**Acceptance Criteria:**

**Given** a debug-only spike screen (`kDebugMode`-gated, reachable via a dev flag)
**When** opened on a low-end Android API 21 device (via `flutter run --profile`)
**Then** 79 polygons render and pan/zoom sustains at least 45fps average over 30 seconds with stretch-goal 60fps.

**Given** the spike measurements
**When** the story is closed
**Then** a written note is added to the architecture document or this epic file recording the measured fps and any optimization needed (e.g. "cache Path to Picture") before Epic 2.1 proceeds.

**Given** the spike is a throwaway
**When** Epic 2 begins
**Then** the spike file is deleted or clearly marked for deletion so it does not linger as dead code.

---

## Epic 2: Playable Map — Tap a Country, Earn Influence

**Goal:** Deliver the minimum playable vertical slice — a custom-rendered world map with unlocked countries that generate Influence on a timer, pan/zoom controls, and tap-to-collect wired end-to-end through `GameCommand` → `GameWorld` → event → UI update.

### Story 2.1: GeoJSON Parser and `CountryPath` Cache

As a developer,
I want `assets/geo/countries.geojson.json` parsed once at boot into a `List<CountryPath>` with precomputed bounding boxes and cached `Path` objects,
So that the map painter and hit-tester operate on ready-to-use data without reparsing on every frame.

**Acceptance Criteria:**

**Given** `assets/geo/countries.geojson.json` exists
**When** the parser loads it at boot
**Then** it produces a `List<CountryPath>` with 79 entries, each containing the `CountryId`, continent, GeoJSON rings projected to `[0,1]²` equirectangular, bbox, and a built `Path`.

**Given** a `geoProvider` as a `FutureProvider<List<CountryPath>>`
**When** multiple widgets watch it
**Then** they share the same parsed result — parsing happens exactly once per app lifetime.

**Given** a `CountryPath`
**When** its bbox is read
**Then** the bbox exactly encloses all ring vertices (unit-tested on a sample country).

### Story 2.2: `WorldMapPainter` Renders Ocean + Country Fills + Borders

As a player,
I want to see a world map with distinct colors for ocean and countries,
So that I can visually orient myself on the globe before interacting.

**Acceptance Criteria:**

**Given** the map screen loads
**When** the `CustomPainter` runs
**Then** it paints, in this order: ocean background → continent background fills → country state-colored fills → country borders.

**Given** a country's state is `locked` / `unlocked` / `ready-to-collect` / `automated`
**When** it is painted
**Then** its fill color comes from the `CountryColors` `ThemeExtension`, not hardcoded literals.

**Given** `shouldRepaint(oldDelegate)` is called
**When** only the view transform has changed (pan/zoom)
**Then** it returns `true` (so pan/zoom re-paints), and country fills are not recomputed from scratch.

**Given** `shouldRepaint` is called
**When** neither the view transform nor any country state has changed
**Then** it returns `false`.

### Story 2.3: Pan and Zoom With `Matrix4` View Transform

As a player,
I want to drag to pan and pinch to zoom the world map,
So that I can explore the globe and focus on the region I care about.

**Acceptance Criteria:**

**Given** the map screen is visible
**When** I drag with one finger
**Then** the map translates in the direction of the drag with no noticeable lag.

**Given** the map screen
**When** I pinch with two fingers
**Then** the map zooms smoothly around the pinch midpoint.

**Given** zoom limits defined in the painter / gesture handler
**When** I try to zoom beyond the maximum scale (initial default 10×, confirm against spike output) or below the minimum (fit-to-screen)
**Then** zoom clamps at the limits.

**Given** a pan or zoom gesture
**When** it completes
**Then** the painter repaints exactly once at the final transform — no redundant frames.

### Story 2.4: Point-in-Polygon Hit Testing on Tap

As a player,
I want to tap a specific country and have the app register that exact country,
So that I can collect Influence from the country I intended.

**Acceptance Criteria:**

**Given** the map is at any pan/zoom
**When** I tap inside a country's polygon
**Then** the hit-tester inverse-transforms the tap point, runs bbox reject per country, then point-in-polygon ray-casting, and returns that `CountryId`.

**Given** I tap on ocean (outside all polygons)
**When** the hit-tester runs
**Then** it returns `null` and no command fires.

**Given** overlapping or adjacent countries
**When** I tap on the boundary
**Then** the hit-tester returns the first match in `CountryPath` list order (stable) — unit-tested for consistency.

**Given** a tap
**When** hit-test succeeds
**Then** the gesture handler dispatches `ref.read(gameWorldProvider.notifier).apply(TapCountry(id))`.

### Story 2.5: `GameWorld` Tick Drives Influence Generation per Country

As a player,
I want each owned country to accumulate Influence over time based on its tier's generation seconds,
So that sitting with the map open produces ready-to-collect countries without tapping.

**Acceptance Criteria:**

**Given** a `GameLoop` widget owns the single `Ticker`
**When** the app is foreground and the loop runs
**Then** each frame calls `gameWorld.tick(elapsed)` with real wall-clock delta, clamped to `Duration(milliseconds: 100)` to avoid tab-switch spikes.

**Given** a country with `generationSeconds = 1`, `baseInfluence = Decimal.parse('1')`, and no upgrades
**When** 1 second of ticks elapses
**Then** the country's banked influence increases by `1.0 ±` floating tolerance — verified via unit test with an injected `FakeClock`.

**Given** the app transitions to `AppLifecycleState.paused` or `inactive`
**When** the lifecycle observer fires
**Then** the ticker stops and no further `tick` calls happen.

**Given** the app returns to `resumed`
**When** the lifecycle observer fires
**Then** the ticker restarts (offline catch-up is handled in Epic 6 — this story only requires the ticker to resume, not apply offline gains).

### Story 2.6: Tap-to-Collect Collects Banked Influence

As a player,
I want tapping an unlocked country to collect its banked Influence and add it to my total,
So that I can see the number go up and feel the core loop.

**Acceptance Criteria:**

**Given** a country has banked influence > 0
**When** the `TapCountry` command is applied
**Then** the country's banked influence resets to 0, the world's `totalInfluence` increases by that amount, and a `CountryTapped` event is emitted with the collected amount.

**Given** a country has banked influence = 0
**When** `TapCountry` is applied
**Then** the reducer returns `Result.success` but emits no `CountryTapped` event (UI treats zero as no-op) — or emits a distinguishable zero-amount event that UI discards. Choice documented in the reducer; either is acceptable so long as UI doesn't animate a "0" flyout.

**Given** a `CountryTapped` event
**When** the HUD is watching `totalInfluenceProvider`
**Then** the HUD updates to the new total in the next frame.

### Story 2.7: Initial Seed — One or More Countries Unlocked by Default

As a first-time player,
I want at least one country (Egypt in Africa) already unlocked when I launch the game,
So that I can immediately tap and start the core loop without first needing unlocks (which don't exist until Epic 4).

**Acceptance Criteria:**

**Given** a fresh install (empty save)
**When** the `GameWorld` initializes from `ContentRegistry`
**Then** the first country (`egypt`) is flagged `unlocked = true` with `ipLevel = 1` and `leaderTier = LeaderTier.none`.

**Given** the initial state
**When** the map renders
**Then** Egypt is painted in the "generating" / "ready" state colors (per its banked influence) and all other countries are painted in the "locked" color.

**Given** the seed state is re-applied on subsequent launches after Epic 6 persistence lands
**When** the player has progressed past the seed
**Then** their actual progression state loads, not the seed.

---

## Epic 3: Power Up — Upgrades, Leaders, and Automation

**Goal:** Deliver the "feel more powerful" layer. Players spend Influence to raise Influence Power (1×/10×/25× bulk), hire Leaders at IP 10 to automate income, and upgrade Leaders through tiers. The single `IncomeCalculator` is the authoritative source for all multiplier math.

### Story 3.1: Authoritative `IncomeCalculator.compute` Function

As an architect,
I want a pure function `IncomeCalculator.compute(country, state) → Influence per second` that encodes the exact multiplier stack order from the architecture,
So that there is one source of truth for income rates and no duplicate math can drift.

**Acceptance Criteria:**

**Given** a country with IP level, leader tier, continent membership, and achievement-backed global multipliers
**When** `IncomeCalculator.compute(country, state)` is called
**Then** the returned rate equals `baseInfluence × (1 + ipLevel × IP_MULT_PER_LEVEL) × leaderMultiplier × continentCompletionBonus × (1 + Σ achievementMultipliers) × globalUpgrades.influenceAmplifier × goldenOpportunityMultiplier × boostMultiplier` applied in exactly that order.

**Given** property tests over the multiplier stack
**When** each multiplier is varied in isolation
**Then** the test pins the observed effect on the rate, preventing regression.

**Given** the reducer code
**When** grep'd for duplicate inline income math (e.g. `baseInfluence *` outside `IncomeCalculator`)
**Then** no duplicates exist.

### Story 3.2: IP Upgrade — Single and Bulk Purchase (1×/10×/25×)

As a player,
I want to spend Influence to increase a country's IP level, with a toggle for 1×, 10×, or 25× bulk purchases,
So that I can power up efficiently without tapping Upgrade repeatedly.

**Acceptance Criteria:**

**Given** a country with `ipLevel < 200` and I have enough Influence
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)`
**Then** my `totalInfluence` decreases by the cost, the country's `ipLevel` increments by 1, and an `UpgradePurchased` event fires.

**Given** I do not have enough Influence
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 1)`
**Then** the reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))` and no state mutates.

**Given** a country at `ipLevel == 200`
**When** I dispatch the upgrade
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'max_level'))`.

**Given** the cost calculation
**When** `ipLevel = L` and `baseCost = B`
**Then** cost = `B × (1.5 ^ L)` per the GDD (tuned values land in Epic 10).

**Given** a country with `ipLevel + bulk ≤ 200` and enough Influence for the full stack
**When** I dispatch `PurchaseUpgrade(countryId, bulk: 10)` or `bulk: 25`
**Then** `ipLevel` increments by exactly 10 or 25, Influence decreases by the summed geometric-series cost, and one `UpgradePurchased` event fires with `bulk` and `totalCost` fields.

**Given** `ipLevel + bulk > 200`
**When** I dispatch the bulk upgrade
**Then** the reducer caps the purchase at 200 (partial purchase), charges only for the levels actually bought, and fires `UpgradePurchased` with the actual count.

**Given** I cannot afford the full bulk
**When** I dispatch the upgrade
**Then** the reducer returns `Result.failure(userInsufficientFunds)` and no state mutates — it does NOT partial-buy as many as I can afford (explicit, documented behavior).

**Given** the cost math
**When** `bulk` purchases from level L
**Then** `cost = B × (1.5^L) × (1.5^bulk - 1) / (1.5 - 1)` — exact geometric sum, unit-tested.

### Story 3.3: Leader Hire and Tier System

As a player,
I want to hire a Leader for a country once its IP reaches level 10, then upgrade that Leader through tiers,
So that my countries generate Influence passively and grow more powerful over time.

**Acceptance Criteria:**

**Given** a country with `ipLevel ≥ 10` and `leaderTier == LeaderTier.none`, and I have enough Influence
**When** I dispatch `HireLeader(countryId)`
**Then** `leaderTier` becomes `LeaderTier.tier1`, Influence decreases by the hire cost, and `LeaderHired` event fires.

**Given** a country with `ipLevel < 10`
**When** I dispatch `HireLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'ip_below_10'))`.

**Given** a country with an existing Leader
**When** I dispatch `HireLeader` again
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_already_hired'))`.

**Given** a country with a Leader and the tick runs
**When** the game loop processes the country
**Then** the country's income is continuous (per-second) rather than timer-gated — banked influence accumulates without needing a generation cycle to complete.

**Given** a country with `leaderTier == tier1` and enough Influence
**When** I dispatch `UpgradeLeader(countryId)`
**Then** `leaderTier` becomes `tier2`, Influence decreases by the tier-2 cost, and `LeaderUpgraded` fires with the new tier.

**Given** `leaderTier == tier2` → upgrade to `tier3` works identically.

**Given** `leaderTier == tier3`
**When** I dispatch `UpgradeLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_max_tier'))`.

**Given** `leaderTier == none`
**When** I dispatch `UpgradeLeader`
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'no_leader_hired'))` — upgrade only applies after hire.

**Given** the multiplier lookup
**When** `LeaderTier` values are read
**Then** they map per the final mapping pinned in `BalanceConfig` at Epic 10 — the GDD documents `1.0× → 1.5× → 2.0× → 3.0×` across 4 tiers. This story implements the lookup as a single named-constant table; exact values may be adjusted during Epic 10 tuning without code changes beyond that table.

> **Design note:** Pin the tier-count decision (3 upgradeable tiers vs 4) at kickoff and reflect it in both the `LeaderTier` enum AND `BalanceConfig.leaderMultipliers`.

---

## Epic 4: Expand — Unlocks, Continents, and Completion Bonuses

**Goal:** Deliver the geographic-progression promise. Players unlock new countries with exponential cost scaling, unlock new continents at Influence thresholds, hit 25/50/75/100% continent milestones, and receive permanent global multipliers on continent completion.

### Story 4.1: Unlock Next Country in Current Continent

As a player,
I want to spend Influence to unlock the next locked country in my current continent,
So that I can expand my influence footprint geographically.

**Acceptance Criteria:**

**Given** a continent with at least one locked country whose prerequisites are met, and enough Influence
**When** I dispatch `UnlockCountry(countryId)`
**Then** the country's `unlocked` flag becomes `true`, its `ipLevel` starts at 1, Influence decreases by `unlockCost`, and `CountryUnlocked` event fires.

**Given** `unlockCost` formula per GDD
**When** the Nth country in a continent unlocks
**Then** `unlockCost = previousCountry.unlockCost × 5` (with the continent's base unlock cost seeding N=1).

**Given** I try to unlock a country in a continent not yet unlocked
**When** `UnlockCountry` is dispatched
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'continent_locked'))`.

**Given** all countries in the current continent are unlocked
**When** I look for the next unlock
**Then** no country in that continent is unlockable; only the next continent is.

### Story 4.2: Unlock Continent at Influence Threshold

As a player,
I want the next continent to unlock automatically when my total Influence crosses its threshold,
So that new geography opens as my power grows without extra friction.

**Acceptance Criteria:**

**Given** the continent thresholds (Africa=0, Europe=1e9, Middle East=1e14, Asia=1e20, South America=1e26, North America=1e32, Oceania=1e38)
**When** my `totalInfluence` crosses a threshold
**Then** the `ContinentUnlocked(continentId)` event fires exactly once, the continent's `unlocked` flag becomes `true`, and its countries become `UnlockCountry`-eligible.

**Given** my total Influence is already past multiple thresholds (e.g. fresh state loaded after a jump)
**When** the game ticks
**Then** all crossed-but-unhandled continents unlock in order with separate events.

**Given** a continent is unlocked
**When** I check the state
**Then** the `ContinentUnlocked` event is emitted only once per continent per game — idempotent.

### Story 4.3: Continent Milestone Rewards at 25/50/75/100 %

As a player,
I want rewards when I own 25%, 50%, 75%, and 100% of the countries in a continent,
So that I feel celebrated for making steady progress, not just final completion.

**Acceptance Criteria:**

**Given** a continent with N countries and I own `floor(0.25 × N)`, `floor(0.50 × N)`, `floor(0.75 × N)`, or all N
**When** the reducer evaluates milestone progress after each `CountryUnlocked`
**Then** the corresponding `MilestoneReached(continentId, tier)` event fires exactly once per tier per continent.

**Given** a `MilestoneReached` event
**When** the reward effect is applied
**Then** the reward type and amount is defined in content JSON (Influence boost, Intel boost, or permanent multiplier snippet) — no hardcoded values.

**Given** the 100% milestone
**When** fired
**Then** `ContinentCompleted(continentId)` is ALSO fired in the same microtask (Story 4.4 handles the completion bonus).

### Story 4.4: Continent Completion Permanent Multiplier

As a player,
I want a permanent global multiplier when I own 100% of a continent's countries,
So that every subsequent action is amplified by my completed conquests.

**Acceptance Criteria:**

**Given** I own all countries in a continent
**When** `ContinentCompleted(continentId)` fires
**Then** `state.continentCompletions[continentId] = true` and the `continentCompletionBonus` factor in `IncomeCalculator` uses the per-continent bonus (Africa +0.25×, Europe +0.50× ... Oceania +1.75×).

**Given** multiple continents are complete
**When** `IncomeCalculator.compute` runs
**Then** the `continentCompletionBonus` factor is the product `∏(1 + bonus)` over all completed continents.

**Given** a continent was previously completed and is loaded from save
**When** the game boots
**Then** the bonus applies without re-firing `ContinentCompleted` (idempotent — save records completion state, not just event log).

### Story 4.5: Next-Unlock Teaser Data on State

As a player,
I want to know which country is next and what it will cost,
So that I have a clear near-term goal.

**Acceptance Criteria:**

**Given** the player is in continent C with unlocked and locked countries
**When** a UI watches `nextUnlockInContinentProvider(C)`
**Then** it returns `{ countryId, unlockCost }` for the next locked country in continent order, or `null` if C is fully unlocked.

**Given** multiple continents are unlocked
**When** a UI watches `nextUnlockOverallProvider`
**Then** it returns `{ countryId, unlockCost, continent }` for the next locked country in the earliest-unlocked continent with locked countries, or `null` if world is complete.

_(UI rendering of this teaser lands in Epic 7 — this story provides the derived state only.)_

---

## Epic 5: Active Play — Goldens, Boosts, Missions, Dailies, Achievements

**Goal:** Deliver the burst / retention layer. Golden Opportunities spawn for 10–100× bursts, Boosts give 2× for 30s, Missions reward Intel for active play, Daily Rewards encourage streaks, and Achievements grant permanent multipliers.

### Story 5.1: Golden Opportunity — Spawn and Claim

As a player,
I want Golden Opportunities to randomly spawn on my owned countries and be claimable by tapping for a 10–100× multiplier burst,
So that active play feels explosive and rewarding.

**Acceptance Criteria:**

**Given** the `GoldenScheduler` runs on tick
**When** the current RNG seed + elapsed time crosses a spawn probability threshold (defined in `BalanceConfig`)
**Then** a `GoldenSpawned(countryId, multiplier, expiresAt)` event fires and the golden is added to `state.activeGoldens`.

**Given** an active Golden with `expiresAt` in the past
**When** the scheduler runs
**Then** the Golden is removed from state and a `GoldenExpired` event fires — it is not claimable.

**Given** the RNG is seeded (test) OR live-random (release)
**When** tests run
**Then** golden spawns are deterministic — exactly reproducible from seed + clock.

**Given** an active Golden on country X
**When** I tap the Golden (hit-test resolves to a Golden overlay, not just the country)
**Then** `ClaimGolden(goldenId)` fires, the Golden is removed from `activeGoldens`, a `GoldenClaimed(multiplier, duration)` event fires, and `state.activeGoldenEffect` is set with `expiresAt = now + duration`.

**Given** an active `goldenEffect`
**When** `IncomeCalculator` runs
**Then** the `goldenOpportunityMultiplier` slot uses the effect's multiplier.

**Given** `goldenEffect.expiresAt` has passed
**When** tick runs
**Then** the effect is cleared and `GoldenExpired` fires.

### Story 5.2: Activate Boost (2× / 30s) Using Intel

As a player,
I want to spend Intel to activate a 30-second 2× Boost,
So that I can amplify a tap burst on my own schedule.

**Acceptance Criteria:**

**Given** I have at least `boostCost` Intel and no active Boost
**When** I dispatch `ActivateBoost()`
**Then** Intel decreases by `boostCost`, `state.activeBoost = { multiplier: 2.0, expiresAt: now + 30s }`, and `BoostActivated` event fires.

**Given** an active Boost
**When** I dispatch `ActivateBoost` again
**Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'boost_already_active'))` — boosts do not stack (refresh-or-queue deferred to Epic 10 if balance calls for it).

**Given** Intel < boostCost
**When** I dispatch `ActivateBoost`
**Then** the reducer returns `Result.failure(userInsufficientFunds)`.

**Given** `activeBoost.expiresAt` passes
**When** tick runs
**Then** the boost clears and `BoostExpired` fires.

### Story 5.3: Missions Cycle Rotating Objectives Rewarding Intel

As a player,
I want a small set of rotating missions ("claim 3 Goldens," "activate 2 Boosts," "stay active 5 minutes") visible in a Missions UI,
So that I have short-term goals that pay Intel for active engagement.

**Acceptance Criteria:**

**Given** the mission catalog in `assets/data/missions.json` with data-driven conditions
**When** the game boots
**Then** exactly N active missions (N defined in `BalanceConfig`) are populated, each with `id`, `progress`, `target`, `rewardIntel`.

**Given** a `GameEvent` fires that advances a mission's condition (e.g. `GoldenClaimed` advances a "claim 3 Goldens" mission)
**When** the mission evaluator runs after `applyCommand`
**Then** the mission's `progress` increments, and if `progress ≥ target`, `MissionCompleted(missionId, rewardIntel)` fires and Intel increases.

**Given** a mission completes
**When** the rotation logic runs
**Then** a new mission is drawn from the catalog (excluding currently-active missions) to replace it.

### Story 5.4: 7-Day Daily Reward Streak

As a player,
I want a once-per-day reward that grows over a 7-day consecutive-return streak,
So that I have gentle reason to return daily without being punished for missing.

**Acceptance Criteria:**

**Given** I haven't claimed today's daily reward and today's local date ≠ `lastDailyClaimDate`
**When** I open the app
**Then** the Daily Reward Modal is queued (ahead of Achievement modals, behind Offline Reward per the priority order).

**Given** I claim the daily reward
**When** the reducer runs
**Then** `totalInfluence` and `totalIntel` increase per the streak day's reward table in content JSON, `state.dailyStreak.day` increments up to 7 (then resets to 1 on day 8), `lastDailyClaimDate = today`, and `DailyRewardClaimed` fires.

**Given** I miss a day (today's date - `lastDailyClaimDate` > 1 day)
**When** I next open the app
**Then** the streak resets to day 1 — the game does NOT penalize past progress, only resets the streak counter.

### Story 5.5: 27 Achievements Granting Permanent Multipliers

As a player,
I want 27 discoverable achievements with permanent multiplier rewards,
So that my long-term play is rewarded with growing base power.

**Acceptance Criteria:**

**Given** `assets/data/achievements.json` with 27 entries, each having `id`, `condition` (data-driven predicate), `rewardType` (`multiplier` or `intel`), `rewardValue`
**When** the game boots
**Then** all 27 achievements load into `ContentRegistry` and their definitions are available to the evaluator.

**Given** the `AchievementEvaluator` runs after every `applyCommand`
**When** a not-yet-earned achievement's condition evaluates `true` against current `GameState`
**Then** `state.earnedAchievements` adds the id, `AchievementEarned(id, reward)` fires, and the reward is applied (either added to `Σ achievementMultipliers` in `IncomeCalculator` or added to `totalIntel`).

**Given** an already-earned achievement
**When** the evaluator runs
**Then** it is skipped (no re-firing).

**Given** 27 achievements are loaded
**When** counted
**Then** exactly 27 entries exist — parse-time assertion in content validation.

---

## Epic 6: Never Lose Progress — Persistence and Offline Earnings

**Goal:** Deliver the Offline Respectful pillar. All state persists to Drift/SQLite with typed migrations and `schema_backup_v{n}.sqlite` snapshots. On resume, offline earnings are computed from Leader-automated countries only (8h cap, stable multipliers) and presented via the Offline Reward Modal before any other UI.

### Story 6.1: Drift Schema and `GameStateMapper`

As a developer,
I want a normalized Drift schema for all game state tables and a `GameStateMapper` that converts between `GameState` and Drift rows,
So that the simulation layer stays ignorant of persistence details and state round-trips losslessly.

**Acceptance Criteria:**

**Given** the Drift schema at the end of this story
**When** `dart run build_runner build` runs
**Then** generated code compiles cleanly for all listed tables: `meta`, `countries`, `leaders`, `upgrades`, `achievements`, `missions`, `boosts`, `goldens`, `daily_rewards`, `settings`, `crash_logs`, `tutorial_state`.

**Given** each table
**When** examined
**Then** it has a primary key, clear foreign-key relationships where applicable, and `big number` fields use TEXT columns with a `DecimalConverter`.

**Given** the `meta` table
**When** queried
**Then** it contains `schemaVersion`, `lastSavedAt` (UTC ISO8601), `totalInfluence`, `totalIntel`, `dailyStreak` (JSON), `tutorialCompleted` flag.

**Given** a fully-populated `GameState`
**When** `mapper.toRows(state)` is called
**Then** it returns typed Drift companion objects for every table in the schema.

**Given** a complete set of Drift rows from `AppDatabase.loadAll()`
**When** `mapper.fromRows(rows)` is called
**Then** it returns an equivalent `GameState` such that `mapper.toRows(mapper.fromRows(rows))` round-trips losslessly (unit-tested).

**Given** an empty database (first launch)
**When** `mapper.fromRows` is called
**Then** it returns the initial `GameState` seeded from `ContentRegistry`.

### Story 6.2: Persistence Write Strategy — Event-Driven Writes and Debounced Snapshot

As a developer,
I want the `SaveRepository` to persist targeted row updates per `GameEvent` and a 2-second debounced snapshot of currency totals,
So that saves happen with minimal DB churn and no per-tick writes.

**Acceptance Criteria:**

**Given** the event → table mapping
**When** a `CountryUnlocked` fires
**Then** the repository runs a typed Drift `update(countries).where(id = event.id).write(Companion(unlocked: Value(true), ...))`.

**Given** similar mappings for `UpgradePurchased`, `LeaderHired`, `LeaderUpgraded`, `ContinentUnlocked`, `ContinentCompleted`, `AchievementEarned`, `MissionCompleted`, `DailyRewardClaimed`, `BoostActivated/Expired`, `GoldenSpawned/Claimed/Expired`
**When** each fires
**Then** exactly the affected row(s) are written — no full-state dump.

**Given** per-tick events like `CountryTapped`
**When** they fire
**Then** they do NOT trigger a DB write (handled by the debounced snapshot below).

**Given** `totalInfluence` or `totalIntel` changes
**When** 2 seconds elapse without another change
**Then** a single `UPDATE meta SET totalInfluence = ?, totalIntel = ?, lastSavedAt = ?` fires.

**Given** rapid changes within the debounce window
**When** they occur
**Then** only one write executes at the end of the window.

**Given** the app transitions to `AppLifecycleState.paused`
**When** the lifecycle observer fires
**Then** any pending debounced write is flushed immediately before the ticker stops.

### Story 6.3: Typed Migrations and `schema_backup_v{n}.sqlite`

As a developer,
I want Drift's `MigrationStrategy` wired such that every schema version bump has a typed migration, and a backup `schema_backup_v{n}.sqlite` is copied before the migration runs,
So that migration failures are recoverable without data loss.

**Acceptance Criteria:**

**Given** a schema version bump from v1 to v2 in a future story
**When** the app launches on a v1 database
**Then** Drift opens the database, detects version mismatch, copies the current DB file to `schema_backup_v1.sqlite` in app documents, runs the typed `MigrationStrategy.onUpgrade`, and the database is at v2.

**Given** a migration throws
**When** caught
**Then** `GameError.migrationFailure(fromVersion, toVersion, cause)` is logged via CrashReporter and the app displays a Save Recovery screen with options to restore from `schema_backup_v1.sqlite` or start fresh (with a dire warning).

**Given** a successful migration
**When** complete
**Then** `schema_backup_v{n}.sqlite` from before the migration is retained (not deleted) for at least 3 subsequent launches as a safety net.

### Story 6.4: Offline Earnings Calculation on Resume

As a player,
I want my Leader-automated countries to have earned Influence while the app was closed (up to 8 hours), presented to me when I return,
So that closing the app feels respectful of my time.

**Acceptance Criteria:**

**Given** `meta.lastSavedAt` and an injected `Clock`
**When** the app enters `AppLifecycleState.resumed`
**Then** `OfflineCatchup.apply(state, clock)` runs before the first Riverpod rebuild past boot, computing `elapsed = min(clock.now() - lastSavedAt, Duration(hours: 8))`.

**Given** `elapsed > Duration.zero`
**When** catch-up runs
**Then** for each country with a Leader, `earned = IncomeCalculator.computeAutomatedRate(country, state) × elapsed.inSeconds` using STABLE multipliers only (IP × Leader × continent × achievement × globalUpgrades).

**Given** active Boosts or Goldens at pause time
**When** offline catch-up computes earnings
**Then** their multipliers do NOT apply offline (per architecture default). If a Boost was active and expires during the offline window, no partial-time credit is given.

**Given** offline earnings computed
**When** applied
**Then** a single `OfflineEarningsApplied(totalEarned, elapsed)` event fires and `totalInfluence` increments by `totalEarned`.

### Story 6.5: Offline Reward Modal On Resume

As a player,
I want a modal that shows how much Influence I earned while away when I return,
So that the reward is celebrated instead of silently appearing in my total.

**Acceptance Criteria:**

**Given** `OfflineEarningsApplied` event with `totalEarned > 0`
**When** the UI wakes on resume
**Then** the Offline Reward Modal is shown BEFORE any other UI interaction is possible (enters the modal queue at top priority per Epic 7 rules — this story requires only the modal widget + trigger; queue logic lives in Epic 7).

**Given** `totalEarned == 0` (e.g. no Leaders hired yet, or elapsed = 0)
**When** the resume path runs
**Then** the modal is NOT shown.

**Given** the Offline Reward Modal
**When** shown
**Then** it displays the formatted earned amount, elapsed duration, and a single "Collect" CTA that dismisses.

### Story 6.6: Save Recovery Path on Corrupt Database

As a player,
I want a clear path to recover if my save file becomes corrupt,
So that I don't silently lose progress or get stuck in a crash loop.

**Acceptance Criteria:**

**Given** `AppDatabase` fails to open with a corruption error
**When** boot runs
**Then** the app shows a "Save Recovery" screen with three options: (1) Restore from latest `schema_backup_v{n}.sqlite` if present, (2) Start Fresh (warned and confirmed twice), (3) Contact Support (copies the crash log to clipboard).

**Given** option (1) is selected and a backup exists
**When** restore runs
**Then** the corrupt DB is renamed to `app_v{n}_corrupt_{timestamp}.sqlite` for forensics, the backup is copied into place, and the app reloads.

**Given** no backup exists and the user chooses (2) Start Fresh
**When** confirmed twice
**Then** the corrupt DB is renamed with a timestamp, a fresh DB initializes from `ContentRegistry`, and the app proceeds.

---

## Epic 7: Complete the Shell — Navigation, HUD, Stats, Settings, Upgrades & Leaders Screens

**Goal:** Deliver the productized app shell. 5-tab bottom navigation (Map / Upgrades / Leaders / Achievements / Minigames placeholder), global HUD, Stats screen, Settings as HUD modal, Upgrades and Leaders tab UIs, sequential modal queue.

### Story 7.1: Theme Tokens and Design System Foundation

As a developer,
I want a single `appTheme()` builder composing `ThemeData` + `ThemeExtension`s (`CountryColors`, `HudPalette`, `MilestoneColors`), Fredoka typography via `google_fonts`, and a `Spacing` constants class,
So that every widget reads colors/spacing/typography from one source.

**Acceptance Criteria:**

**Given** `lib/ui/theme/app_theme.dart` and its extensions/constants
**When** any widget references a color, spacing, or font
**Then** it uses `Theme.of(context).extension<CountryColors>()!.locked` (or similar) or `Spacing.md` — never a raw literal.

**Given** `flutter analyze`
**When** a new story introduces a hardcoded color literal in a widget
**Then** a custom_lint rule OR a code-review convention catches it (minimum: documented review criterion; custom_lint rule is a stretch goal).

**Given** `Spacing`
**When** used
**Then** it exposes `xs/sm/md/lg/xl/xxl = 4/8/16/24/32/48` as `static const` doubles.

### Story 7.2: App Scaffold with 5-Tab Bottom Navigation and `IndexedStack`

As a player,
I want five tabs across the bottom (Map / Upgrades / Leaders / Achievements / Minigames) and switching between them should not reparse the world map,
So that the app feels snappy and the map preserves pan/zoom state.

**Acceptance Criteria:**

**Given** the `AppScaffold`
**When** the app is open
**Then** a `BottomNavigationBar` shows 5 tabs with icons + labels; the scaffold uses an `IndexedStack` so each tab's widget tree stays alive across switches.

**Given** I pan/zoom on the Map tab, switch to Upgrades, then switch back
**When** the Map tab re-appears
**Then** it shows at the exact pan/zoom it was left at and the GeoJSON is NOT reparsed.

**Given** the Minigames tab
**When** I tap it
**Then** it shows a "Coming Soon" placeholder screen with a brief message.

### Story 7.3: Global HUD With Influence and Intel Currency Badges

As a player,
I want a top-bar HUD visible on all tabs showing my Influence and Intel totals with icons,
So that I always know my resources without switching screens.

**Acceptance Criteria:**

**Given** any tab is visible
**When** rendered
**Then** a top-bar HUD renders above the tab content showing: Influence badge (icon + abbreviated number), Intel badge (icon + abbreviated number), a stats icon (tap → Stats screen), a settings gear (tap → Settings modal).

**Given** Influence or Intel changes
**When** `totalInfluenceProvider` or `totalIntelProvider` emits
**Then** the HUD badge updates with the new value and an `AnimatedCounter` tweens from the old to the new value over ~400ms.

**Given** the HUD uses a reusable `CurrencyBadge` widget
**When** applied in the HUD AND in upgrade cards, reward modals, mission rows, etc.
**Then** currencies render identically everywhere — icon, color, formatting all from tokens.

### Story 7.4: Sequential Modal Queue With Priority

As a player,
I want modals (Offline Reward, Daily Reward, Continent Complete, Achievement Earned, Purchase Confirm) to appear one after another, never stacked,
So that I'm not overwhelmed by overlapping celebrations.

**Acceptance Criteria:**

**Given** multiple modal-triggering events happen in a short window (e.g. resume fires Offline Reward + Daily Reward, then an Achievement Earned)
**When** the modal queue processes them
**Then** they display in priority order Offline > Daily > Celebration (Continent) > Achievement > Purchase Confirm, each dismissing before the next is shown.

**Given** a modal is showing
**When** a new trigger fires
**Then** the new modal is enqueued and will show after the current dismisses — it never overlays.

**Given** the queue
**When** inspected
**Then** it is exposed via `modalQueueProvider` and testable with a fake dismiss stream.

### Story 7.5: Stats Screen Reachable From HUD

As a player,
I want a Stats screen showing total Influence, Intel, countries owned, continents completed, achievements earned, and active multipliers,
So that I can check my progress at a glance without guessing.

**Acceptance Criteria:**

**Given** I tap the stats icon in the HUD
**When** navigation runs
**Then** a full-screen Stats screen pushes on top of the current tab (Navigator 1.0 push).

**Given** the Stats screen
**When** rendered
**Then** it shows: Total Influence, Total Intel, Countries Owned (X / 79), Continents Completed (X / 7), Achievements Earned (X / 27), and Active Multipliers (IP sum, Leader sum, continent bonus, achievement bonus, global upgrade) broken out.

**Given** the Stats screen is open
**When** state changes (e.g. a country is collected in the background? — actually the Stats screen pauses ticker? — no, ticker continues; Stats reads reactive providers)
**Then** the stats values update reactively.

### Story 7.6: Settings Modal Overlay From HUD Gear Icon

As a player,
I want a Settings screen that opens as a modal overlay from the HUD gear,
So that I can adjust sound/haptics/notifications without leaving my current tab.

**Acceptance Criteria:**

**Given** I tap the gear icon in the HUD
**When** the tap completes
**Then** a modal bottom sheet (or full-screen modal) opens over the current tab — the bottom nav is still visible but dimmed.

**Given** the Settings modal
**When** rendered
**Then** it contains at minimum: Sound on/off, Haptics on/off, Credits link, a 5-second long-press activator for the Support (crash logs) screen from Story 1.10.

**Given** I toggle a setting
**When** I dismiss the modal
**Then** the setting persists via the Drift `settings` table and takes effect immediately.

### Story 7.7: Upgrades Tab — Unlocked Countries + Next-Unlock Teaser per Continent

As a player,
I want an Upgrades tab that lists my unlocked countries grouped by continent, plus a "Next unlock" teaser for the next locked country,
So that I can efficiently spend Influence without navigating the map.

**Acceptance Criteria:**

**Given** the Upgrades tab
**When** rendered
**Then** it shows one section per UNLOCKED continent (locked continents are not shown as sections).

**Given** each continent section
**When** rendered
**Then** it lists unlocked countries as cards with current IP level, current rate, bulk toggle (1×/10×/25×), cost for next upgrade, and a Buy button
**And** it ends with a single "Next unlock" teaser card showing the next locked country's name, cost, and an Unlock button (or an "Unlock in current continent" placeholder if next locked is in a future continent).

**Given** I use the bulk toggle
**When** I tap Buy
**Then** `PurchaseUpgrade(countryId, bulk)` dispatches and the card updates.

**Given** I tap Unlock on the teaser
**When** I have enough Influence
**Then** `UnlockCountry(countryId)` dispatches and the card transitions into a regular upgrade card.

### Story 7.8: Leaders Tab — Grouped-by-Continent Accordion

As a player,
I want a Leaders tab that groups countries by continent in expandable cards, showing leader status per country (not-eligible / hire available / hired / upgrade available / max tier),
So that I can manage automation across the whole game from one screen.

**Acceptance Criteria:**

**Given** the Leaders tab
**When** rendered
**Then** one accordion continent card appears per unlocked continent, each showing "X / Y Leaders hired" and a gold highlight if ANY hire-eligible leader is affordable.

**Given** I expand a continent card
**When** the rows render
**Then** each shows a `CountryLeaderRow` with country name, IP level, leader tier/status, and a contextual action button whose label depends on state: "Hire (cost)" / "Upgrade to tier N (cost)" / "Max tier reached" / "Reach IP 10 first" (disabled).

**Given** I tap the action button
**When** it dispatches
**Then** the appropriate command (`HireLeader` or `UpgradeLeader`) fires and the row updates on event.

**Given** a country approaches a leader threshold (IP ≥ 8 for hire, ≥ 48 for tier 2, ≥ 98 for tier 3)
**When** the row renders
**Then** it shows a subtle "approaching threshold" visual hint (gold border or similar, tokens only — full milestone glow polish is Epic 8).

### Story 7.9: Map as Default Cold-Launch Screen, Auto-Focus Post-Tutorial

As a player,
I want the app to open directly on the Map tab every cold launch, and (after tutorial is complete) zoom focused on my latest unlocked country,
So that I land on the gameplay surface, oriented on my current frontier.

**Acceptance Criteria:**

**Given** the app cold-launches
**When** `AppScaffold` initializes
**Then** the selected tab index is 0 (Map) regardless of the last tab used in the previous session.

**Given** the tutorial is completed (`state.tutorialCompleted == true`)
**When** the Map tab first renders
**Then** the view transform auto-focuses on the most-recently-unlocked country (or the first unlocked country if no unlocks yet) with zoom level approximately equal to "continent fit."

**Given** the tutorial is NOT yet completed
**When** the Map tab renders
**Then** auto-focus is suppressed and the map shows whatever pan/zoom the tutorial expects at its current step.

### Story 7.10: Continent Progression Visual Indicators

As a player,
I want each continent to visually communicate how many of its countries I own,
So that I can eyeball progress without counting.

**Acceptance Criteria:**

**Given** I'm on the Upgrades tab or Stats screen
**When** a continent is displayed
**Then** it shows "X / Y owned" and a horizontal progress bar with 25% / 50% / 75% milestone tick marks.

**Given** I hit 25/50/75% milestones
**When** the progress bar is visible in real time
**Then** the corresponding tick mark fills in with a subtle pulse animation (token-based; polish in Epic 8).

---

## Epic 8: Juice — Game Feel Layer

**Goal:** Every `GameEvent` routes through `AudioService` and `HapticsService` (no scattered `playSound()` in UI). Five core SFX wired. Flying numbers on tap. Ready-to-collect breathing pulse. Unlock + continent-complete celebrations.

### Story 8.1: SFX and Haptics Event Bus Wiring

As a developer,
I want `AudioService` and `HapticsService` that both subscribe to `GameWorld.events` and play mapped SFX / haptic patterns,
So that every meaningful action has audio and tactile feedback with no scattered `playSound()` calls in UI code.

**Acceptance Criteria:**

**Given** `AudioService` initialized at app boot
**When** `CountryTapped` fires with nonzero amount
**Then** `assets/audio/collect.mp3` plays.

**Given** other events fire
**When** they match the mapping — `CountryUnlocked → unlock`, `UpgradePurchased → upgrade`, `LeaderHired → upgrade`, `GoldenClaimed → golden`, `ContinentCompleted → milestone`
**Then** the corresponding SFX plays.

**Given** `Settings.soundEnabled == false`
**When** an event fires
**Then** no SFX plays.

**Given** rapid-fire taps
**When** 10 `CountryTapped` events fire in 500ms
**Then** the service rate-limits / polyphones so SFX don't stutter or lag (validated on device).

**Given** `AudioService`
**When** grep'd
**Then** it is the ONLY place `AudioPlayer.play` is called — no UI widget calls `audioplayers` directly.

**Given** `HapticsService` initialized
**When** `CountryTapped` fires
**Then** a light impact haptic fires.

**Given** other events fire
**When** they match — `CountryUnlocked → medium`, `LeaderHired → medium`, `ContinentCompleted → heavy`, `GoldenClaimed → medium + selection`
**Then** the corresponding haptic pattern plays.

**Given** `Settings.hapticsEnabled == false`
**When** events fire
**Then** no haptics play.

### Story 8.2: Flying Number Animation on Country Tap

As a player,
I want a floating "+X" number to rise and fade above a tapped country,
So that the collect action has satisfying visual weight.

**Acceptance Criteria:**

**Given** I tap a country with nonzero banked influence
**When** `CountryTapped(amount)` fires
**Then** a flying-number widget spawns at the country's screen position showing `+{amount.format()}`, tweens up ~40 logical pixels, fades out over ~800ms, then removes itself from the widget tree.

**Given** I rapid-tap 10 times in 500ms
**When** the flying-number layer processes the events
**Then** 10 distinct flying numbers are visible simultaneously (no pooling race) and all clean up without leaks.

**Given** a tap where `amount == 0` (edge case from Story 2.6)
**When** processed
**Then** no flying number spawns.

### Story 8.3: Breathing Pulse Animation on Ready-To-Collect Countries

As a player,
I want ready-to-collect countries to subtly pulse,
So that my eye is drawn to where I can collect right now.

**Acceptance Criteria:**

**Given** a country's state is "ready-to-collect" (banked influence > 0 and no Leader)
**When** the painter renders
**Then** its fill opacity (or a glow overlay) tweens between ~0.6 and ~1.0 on a ~1.5s ease-in-out infinite loop.

**Given** multiple ready countries
**When** rendered
**Then** they share a single `AnimationController` value (one ticker-driven animation drives all pulses) to keep paint cost bounded.

**Given** a country transitions to "automated" (Leader hired)
**When** the state changes
**Then** the pulse stops on that country.

### Story 8.4: Celebration Animations — Country Unlock and Continent Completion

As a player,
I want a visual celebration when I unlock a country and a bigger fanfare when I complete an entire continent,
So that both moments feel earned and proportionally rewarding.

**Acceptance Criteria:**

**Given** `CountryUnlocked` event fires
**When** the map receives it
**Then** the unlocked country plays a celebration animation — first unlock in a continent uses a radial ripple; subsequent unlocks in that continent use a white-flash.

**Given** the animation
**When** it completes (~800ms)
**Then** the country settles into its new state color and no stray paint artifacts remain.

**Given** I am NOT on the Map tab when the unlock fires (unlikely but possible via HUD actions)
**When** I switch to the Map tab
**Then** the animation does not replay — it fired once when the event occurred.

**Given** `ContinentCompleted` event fires
**When** the UI receives it
**Then** a full-screen celebration modal (queued per Epic 7 modal queue) shows the continent name, "+X.XX× Global Multiplier" reward, and a "Continue" CTA — with a continent-complete fanfare SFX if available in `assets/audio/continent_complete.mp3`.

**Given** the modal
**When** dismissed
**Then** the queue advances to the next modal (if any) and the map smoothly animates a highlight over the completed continent region.

### Story 8.5: Number Flyout, HUD Counter, Country Pulse All Share One `Ticker` Budget

As a developer,
I want all decorative animations (HUD counter tweens, flying numbers, breathing pulses, celebration animations) to respect frame budget,
So that the map's 60fps target is never compromised by UI polish.

**Acceptance Criteria:**

**Given** profiling on a low-end Android device
**When** 20 rapid taps spawn 20 flying numbers, the HUD tweens, and 5 countries pulse simultaneously
**Then** sustained fps stays above 45 with stretch goal 60.

**Given** any animation
**When** it completes
**Then** its controller is disposed or reset — no leaked `AnimationController`s (verified by a simple counter assertion in debug mode).

---

## Epic 9: Onboard — Tutorial and Contextual Hints

**Goal:** First-time players get a guided tutorial through the core loop (tap, upgrade, hire Leader, unlock). Steps auto-advance on the triggering action. Progress survives restart. Post-tutorial one-time hints fire on new-system first-exposures.

### Story 9.1: Tutorial State, Persistence, and Overlay UI

As a developer and first-time player,
I want tutorial state managed in `GameWorld`, persisted via Drift, and rendered as a spotlight overlay that guides me through the core loop,
So that the tutorial survives app restarts and I learn the game without trial and error.

**Acceptance Criteria:**

**Given** a fresh install
**When** the app boots
**Then** `state.tutorial.currentStepId == 'tap_to_collect'` (first step), `completed == false`.

**Given** I complete a tutorial step
**When** `AdvanceTutorial(stepId)` dispatches
**Then** `currentStepId` moves to the next step per the tutorial script in content JSON, a `TutorialAdvanced` event fires, and the `tutorial_state` Drift row updates.

**Given** I close and relaunch the app mid-tutorial
**When** the app loads
**Then** `state.tutorial.currentStepId` loads from Drift and the tutorial resumes at the same step.

**Given** `state.tutorial.currentStepId != null` and `completed == false`
**When** the app renders
**Then** a `TutorialOverlay` renders above the current screen with a dim layer, a spotlight cutout at the step's target (screen-space Rect defined in the step data), and a step card with text + optional arrow.

**Given** the tutorial is active
**When** I interact with non-target UI
**Then** that interaction is blocked by the overlay's IgnorePointer layer — only the spotlit target is tappable.

**Given** the tutorial is active
**When** the target is on a different tab (e.g. step 9+ is on Leaders tab)
**Then** the overlay coordinates with the tab system to switch tabs before spotlighting — or the step explicitly instructs me to tap the Leaders tab (which is its own spotlit target).

### Story 9.2: Auto-Advance on Triggering Action

As a player,
I want the tutorial to advance automatically when I perform the action it's teaching (e.g. tap a country → next step),
So that I don't have to tap "Next" after doing exactly what I was told.

**Acceptance Criteria:**

**Given** a tutorial step whose trigger is "`CountryTapped`" (or a specific action condition like "IP reaches 10")
**When** that event fires
**Then** the step auto-advances via an `AdvanceTutorial` command.

**Given** a step with no game-event trigger (pure informational)
**When** displayed
**Then** its step card has a "Next" button that dispatches `AdvanceTutorial`.

**Given** the final tutorial step
**When** advanced
**Then** `state.tutorial.completed = true`, `TutorialCompleted` event fires, and the overlay unmounts permanently.

### Story 9.3: Skip Tutorial Option (Returning Player)

As a returning player or a genre-familiar player,
I want a "Skip Tutorial" button,
So that I can jump straight to playing without being forced through basics I already know.

**Acceptance Criteria:**

**Given** the tutorial overlay is visible
**When** I tap a "Skip" button on the step card
**Then** a confirmation dialog asks "Skip tutorial? You can replay it from Settings." and two buttons (Cancel, Skip).

**Given** I confirm Skip
**When** the command dispatches
**Then** `state.tutorial.completed = true`, `state.tutorial.skipped = true`, `TutorialSkipped` fires, and the overlay unmounts.

**Given** a Settings option "Replay Tutorial"
**When** tapped
**Then** `state.tutorial.completed = false`, `currentStepId = 'tap_to_collect'`, and the overlay re-appears (useful for QA and curious players).

### Story 9.4: Post-Tutorial Contextual Hints (One-Shot)

As a player who finished the tutorial,
I want a one-time contextual hint the first time I encounter a new system (Golden Opportunity, Boost-ready, Leader-eligible, milestone approaching),
So that new mechanics don't surprise me without explanation.

**Acceptance Criteria:**

**Given** `state.tutorial.completed == true` and a Golden spawns for the first time ever
**When** the player's view can see the Golden
**Then** a hint tooltip pops near it saying "Golden Opportunity! Tap for a huge burst" and auto-dismisses after 4 seconds.

**Given** `state.tutorial.hintsShown['golden'] == true`
**When** a subsequent Golden spawns
**Then** no hint shows.

**Given** the same pattern for hints keyed by event/condition: `boost_ready`, `leader_eligible` (first time any country hits IP 10), `milestone_approaching` (first time a continent crosses 20% completion)
**When** each condition first occurs
**Then** the matching hint shows once and is recorded in `hintsShown`.

---

## Epic 10: Tune — Economy and Balance

**Goal:** Populate content JSON with tuned values; populate `BalanceConfig` constants; revisit pacing walls on the new smoother Flutter tick loop; refine late-game curves via instrumented runs.

### Story 10.1: Populate Core Content JSON Files

As a developer,
I want `countries.json`, `continents.json`, and `achievements.json` fully populated with real game data,
So that all content-driven systems have the values they need to function correctly.

**Acceptance Criteria:**

**Given** `assets/data/countries.json`
**When** parsed
**Then** it contains exactly 79 entries with valid schema (all required fields present, `continent` matches a valid continent id, numeric fields parseable as `Decimal`).

**Given** the geographic distribution
**When** counted per continent
**Then** it matches GDD: Africa 19, Europe 19, Middle East 10, Asia 16, South America 8, North America 4, Oceania 3.

**Given** the values
**When** ported from v1 or authored fresh
**Then** exponential scaling holds: within each continent, consecutive countries' `unlockCost` increases by ~5× (loose validation; Story 10.2 refines).

**Given** `assets/data/continents.json`
**When** parsed
**Then** it contains 7 entries with unlock thresholds (0, 1e9, 1e14, 1e20, 1e26, 1e32, 1e38) and completion bonuses (+0.25×, +0.50×, +0.75×, +1.00×, +1.25×, +1.50×, +1.75×) per GDD.

**Given** each continent
**When** checked for milestone rewards
**Then** 25/50/75/100% milestone rewards are defined (type + value per tier).

**Given** `assets/data/achievements.json`
**When** parsed
**Then** exactly 27 achievements load, spanning the three GDD categories (milestone, activity, completion).

**Given** each achievement condition
**When** the `AchievementEvaluator` runs against varying game states
**Then** the condition function evaluates correctly (unit-tested with fixture states).

### Story 10.2: `BalanceConfig` Constants Pinned and Playtest-Reviewed

As a game designer,
I want `lib/game/config/balance.dart` to contain all tunable constants (`ipCostMultiplier`, `leaderUnlockIpLevel`, `maxIpLevel`, `boostMultiplier`, `boostDurationSeconds`, `boostIntelCost`, `goldenSpawnProbability`, `goldenMinMultiplier`, `goldenMaxMultiplier`, `goldenDurationSeconds`, `missionCatalogSize`, `ipMultPerLevel`, `offlineCapHours`, etc.),
So that all balance tuning happens in one file without touching code.

**Acceptance Criteria:**

**Given** `BalanceConfig`
**When** audited
**Then** no magic numbers exist anywhere in `lib/game/` that affect balance — all such constants reference `BalanceConfig`.

**Given** a playtest run-through of 0 → Africa complete
**When** measured
**Then** pacing matches GDD's "Early Game (0-2 hours)" feel — tuning adjustments made until this is true.

**Given** a playtest run-through mid-to-late (continents 2–4)
**When** measured
**Then** pacing matches "Mid Game (Days 2-7)" — adjustments made as needed.

### Story 10.3: Instrumented Late-Game Run and Final Tuning Pass

As a game designer,
I want a debug cheat panel that fast-forwards to late-game states (fully unlocked continents 1–4, partial 5+) and an instrumentation dump of effective rates per continent,
So that I can observe and tune late-game pacing walls without grinding.

**Acceptance Criteria:**

**Given** the debug cheat panel (`kDebugMode`-only from Epic 1's debug tools)
**When** I invoke "Fast Forward to Asia complete"
**Then** `state` is set to the target milestone configuration and I can continue play from there.

**Given** an instrumentation dump command in the cheat panel
**When** invoked
**Then** it prints per-continent effective rates, bottleneck countries, and estimated time-to-next-milestone at the current play rate.

**Given** late-game observation
**When** walls are identified (excessive time between milestones)
**Then** `BalanceConfig` and content JSON are adjusted and a brief changelog of tuning decisions is appended to a `docs/balance-changes.md` (or equivalent) for future reference.

---

## Epic 11: Harden — Accessibility and Performance

**Goal:** Every interactive widget wrapped in `Semantics`. Non-color cues on country states. Touch targets meet platform minimums. 60fps sustained on low-end Android. Cold start < 3s. App size < 50MB.

### Story 11.1: Accessibility Pass — Semantics, Non-Color Cues, and Touch Targets

As a player using a screen reader, having color blindness, or with limited dexterity,
I want every interactive element to be screen-reader labelled, distinguishable without color, and large enough to tap reliably,
So that the game is playable regardless of accessibility needs.

**Acceptance Criteria:**

**Given** any interactive widget (ElevatedButton, InkWell, GestureDetector wrapping a tappable region, etc.)
**When** the widget tree is inspected (widget test)
**Then** it is wrapped in a `Semantics` widget with a `label` and, where applicable, `value`, `hint`, and `button: true` or `enabled: false`.

**Given** map countries (rendered via `CustomPainter`, not widgets)
**When** a screen reader focuses the map region
**Then** a `Semantics` layer or `MergeSemantics` exposes focusable country regions each announced as "{countryName}, {state}, tap to {action}" — exact implementation documented in the story.

**Given** widget tests
**When** run with a11y checks
**Then** no interactive widget is missing a label.

**Given** a country in each state (locked / generating / ready / automated)
**When** rendered
**Then** it has a non-color cue in addition to fill color: locked = no border animation, generating = empty, ready = breathing pulse (Epic 8), automated = subtle dotted or solid outline pattern.

**Given** a high-contrast simulation or color-blind filter applied
**When** the map renders
**Then** all four states are distinguishable (verified by visual review during QA — no automated check).

**Given** any tappable widget in UI code
**When** audited
**Then** its hit-area is at least `Size(44, 44)` logical px (iOS standard) or wraps a larger-padding area around smaller visuals.

**Given** country hit-testing on the map
**When** a country renders small at low zoom
**Then** the hit-test accepts taps within a small radius around tiny-country polygons (documented padding in px), making them reachable without maxing zoom.

### Story 11.2: Cold-Start Performance Profiling and Fix

As a player launching the app
I want cold start to be under 3 seconds on mid-range devices,
So that the game feels responsive and I don't lose interest before it loads.

**Acceptance Criteria:**

**Given** a profile build on a mid-range target device (iPhone 12 / Pixel 5-class)
**When** I cold-launch (app fully killed, device cold)
**Then** time from tap-app-icon to interactive map is ≤ 3.0 seconds measured with `Timeline` events or Flutter DevTools.

**Given** a profile run
**When** the startup trace is analyzed
**Then** GeoJSON parsing, content JSON loading, and Drift boot are identified; any single step > 500ms is optimized (deferred parsing, background isolate, cached Path blob, etc.) until the total fits under 3s.

### Story 11.3: 60fps Map Performance on Low-End Android (API 21)

As a player on a low-end Android device,
I want the world map to pan, zoom, and display animations at 60fps,
So that the core gameplay surface feels smooth regardless of my phone.

**Acceptance Criteria:**

**Given** a low-end Android API 21 device (emulator or physical)
**When** I pan, zoom, tap, and interact with active animations (flying numbers, pulses)
**Then** sustained fps measured via Flutter DevTools stays at 60fps ± occasional drops ≤ 5 frames.

**Given** the canvas performance spike from Story 1.11 identified any hot paths
**When** Epic 11 runs
**Then** those optimizations are implemented (e.g. `Path → Picture` cache invalidated only on country-state version change).

### Story 11.4: App Size Under 50MB

As a player downloading the app
I want the install footprint to be under 50MB,
So that the download is fast and doesn't fill my storage.

**Acceptance Criteria:**

**Given** a release build via `flutter build appbundle` and `flutter build ipa`
**When** the output is measured
**Then** the base APK/AAB is ≤ 50MB and the iOS IPA is ≤ 50MB.

**Given** assets audit
**When** performed
**Then** no redundant GeoJSON variants, no unused SFX files, and unused platform folders (web/windows/macos/linux) are either removed or confirmed to not contribute to mobile build size.

---

