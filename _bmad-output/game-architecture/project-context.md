# Project Context

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
