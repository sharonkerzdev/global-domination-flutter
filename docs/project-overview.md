# Project Overview

> Global Domination Game — Generated: 2026-04-06

## Executive Summary

**Global Domination Game** is a mobile idle/incremental strategy game where players build political influence across the world. Starting in Africa, players tap to generate influence, unlock countries, hire leaders for automation, and purchase upgrades to grow their power exponentially. The game features 79 countries across 7 continents with a rich progression system including achievements, continent completion bonuses, golden opportunities, time-limited boosts, missions, and daily login rewards.

Built with **React Native + Expo** for cross-platform iOS/Android deployment, the game uses **Zustand** for state management, **MapLibre** for interactive map rendering, and **break_eternity.js** for handling the astronomical numbers typical of incremental games.

---

## Technology Stack

| Category | Technology | Version | Purpose |
|---|---|---|---|
| **Framework** | React Native | 0.81.5 | Cross-platform mobile framework |
| **Platform** | Expo SDK | 54 | Managed React Native platform with native modules |
| **Language** | TypeScript | 5.9.2 | Static typing (strict mode enabled) |
| **UI Library** | React | 19.1.0 | Component-based UI rendering |
| **State Management** | Zustand | 5.0.9 | Lightweight reactive state store |
| **Maps** | MapLibre React Native | 11.0.0-beta.19 | Interactive world map with country layers |
| **Animations** | react-native-reanimated | 4.1.1 | High-performance native animations |
| **Gestures** | react-native-gesture-handler | 2.28.0 | Native gesture recognition (map pan/zoom) |
| **Graphics** | react-native-svg | 15.12.1 | SVG rendering for UI elements |
| **Large Numbers** | break_eternity.js | 2.1.3 | Big number math for incremental mechanics |
| **Audio** | expo-audio | 1.1.1 | Sound effects and music playback |
| **Haptics** | expo-haptics | 15.0.8 | Tactile feedback on interactions |
| **Storage** | AsyncStorage | 2.2.0 | Persistent game save data |
| **Font** | Fredoka (Google Fonts) | 0.4.1 | Primary typeface (400–700 weights) |
| **Testing** | Jest + Testing Library | 29.7.0 / 12.4.3 | Unit and component testing |
| **Build** | EAS Build | CLI >= 16.0.0 | Cloud builds for iOS/Android |

---

## Architecture

**Type:** Monolith — single cohesive React Native codebase  
**Pattern:** 3-layer architecture (Engine → Store → UI)

```
┌──────────────────────────────────┐
│           UI Layer               │
│  Screens, Components, Hooks     │
│  (React Native + Reanimated)    │
├──────────────────────────────────┤
│         Store Layer              │
│  Single Zustand Store           │
│  (gameStore.ts — all state)     │
├──────────────────────────────────┤
│        Engine Layer              │
│  Pure Functions                 │
│  (formulas, achievements,       │
│   milestones — no side effects) │
├──────────────────────────────────┤
│         Data Layer              │
│  Static Configuration           │
│  (countries, upgrades, config)  │
└──────────────────────────────────┘
```

**Key architectural decisions:**
- Single Zustand store pattern — all game state in one place for atomic updates
- Engine layer is pure functions — testable, no React/Zustand dependency
- All monetary values use `Decimal` (break_eternity.js) for numbers up to 1e308+
- Auto-persistence via Zustand persist callback → AsyncStorage
- Save migration system (v12 → v13) for backwards compatibility

---

## Game Systems Overview

### Core Gameplay Loop
1. **Tap** countries to collect generated influence
2. **Unlock** new countries using accumulated influence (tier-based costs)
3. **Upgrade** country influence power (up to level 200 each)
4. **Hire leaders** to automate influence generation (passive income)
5. **Level leaders** for multiplier bonuses (1x → 1.5x → 2x → 3x)
6. **Complete continents** to earn global multiplier bonuses
7. **Progress** through 7 continents from Africa to Oceania

### Active Play Systems
- **Golden Opportunities** — Random country lights up with 10–100x multiplier, 8–15 second claim window
- **Boosts** — 30-second 2x multiplier (via ad watch or 18 Intel currency)
- **Missions** — Short objectives (claim goldens, activate boost, stay active) rewarding Intel currency

### Progression Systems
- **Continent Milestones** — Intel rewards at 25%, 50%, 75% continent progress
- **Achievements** — 20+ unlock conditions (tap count, influence thresholds, continent completion)
- **Global Multipliers** — Stack from completed continents + unlocked achievements
- **Daily Login Rewards** — 7-day cycle with influence, Intel, and multiplier bonuses

### Idle Mechanics
- Leaders generate influence passively per second
- Offline earnings calculated on app resume (max 8 hours)
- Efficiency Expert global upgrade reduces generation time

---

## Content Inventory

| Content Type | Count | Details |
|---|---|---|
| **Countries** | 79 | Spread across 7 continents |
| **Continents** | 7 | Africa (19), Europe (19), Middle East (10), Asia (16), South America (8), North America (4), Oceania (3) |
| **Achievements** | 20+ | Unlock, influence, tap, continent, golden, regional categories |
| **Global Upgrades** | 3 | Influence Amplifier, Efficiency Expert, Intel Bonus |
| **Continent Upgrades** | 7 | One per continent |
| **Sound Effects** | 8 | collect, golden, milestone, unlock, upgrade, continent_complete, zoom, auto_tick |
| **Tutorial Steps** | 12 | Guided onboarding with spotlight system |
| **Mission Types** | 3 | Claim goldens, activate boost, stay active |
| **Daily Reward Days** | 7 | Cycling influence/Intel/multiplier rewards |
| **Screens** | 8 | Game, Upgrades, Leaders, Settings, Stats, Milestones, Achievements*, Minigames* |
| **Components** | 29+ | Design system, map, leaders, modals, toasts, system |

\* Placeholder screens for future features

---

## Repository Structure

```
global-domination-game/
├── src/               # Application source (65+ TypeScript files)
│   ├── components/    #   29+ UI components (ui/, map/, leaders/ subdirs)
│   ├── screens/       #   8 screen components
│   ├── stores/        #   Single Zustand store (gameStore.ts)
│   ├── engine/        #   Pure game logic (formulas, achievements, milestones)
│   ├── data/          #   Game data definitions and configuration
│   ├── hooks/         #   7 custom React hooks
│   ├── types/         #   TypeScript interfaces
│   ├── utils/         #   Utilities (save, sound, haptics, formatting)
│   └── styles/        #   Theme and design tokens
├── docs/              # Generated project documentation
├── _bmad-output/      # Planning artifacts (GDD, 18 epics, 85+ stories)
├── android/           # Native Android project
├── assets/            # App icons and splash screens
├── __tests__/         # Root-level test files
└── __mocks__/         # Jest mock modules
```

---

## Existing Documentation

| Document | Location | Purpose |
|---|---|---|
| Architecture Overview | `ARCHITECTURE.md` | High-level architecture principles |
| Product Requirements | `PRD.md` | Product vision, features, monetization |
| MVP Scope | `MVP_SCOPE.md` | Current implemented feature set |
| Tech Decisions | `TECH_DECISIONS.md` | Technology stack rationale |
| Game Design Document | `_bmad-output/planning-artifacts/gdd.md` | Full game mechanics and systems |
| Project Context | `_bmad-output/project-context.md` | AI-optimized rules (28 rules) |
| Playtest Plan | `_bmad-output/playtest-plan.md` | Structured playtesting methodology |
| Migration Guide | `docs/MIGRATION.md` | Expo Go → Development Build migration |
| Epic Breakdowns | `_bmad-output/planning-artifacts/epics/` | 18 epics with story-level detail |
| Sprint Status | `_bmad-output/implementation-artifacts/sprint-status.yaml` | Current sprint tracking |
