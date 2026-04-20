# Architecture

> Global Domination Game — Generated: 2026-04-06

## Executive Summary

Global Domination Game is a mobile idle/incremental strategy game built with React Native and Expo. Players build political influence across 79 countries spanning 7 continents through tapping, upgrading, leader automation, and active play systems (golden opportunities, boosts, missions). The architecture follows a strict 3-layer pattern (Engine → Store → UI) with a single Zustand store managing all game state and break_eternity.js handling large number arithmetic.

---

## Technology Stack

| Category | Technology | Version | Purpose |
|---|---|---|---|
| Framework | React Native | 0.81.5 | Cross-platform mobile framework |
| Platform | Expo SDK | 54 | Managed native platform with plugins |
| Language | TypeScript | 5.9.2 | Static typing (strict mode) |
| UI | React | 19.1.0 | Component rendering |
| State | Zustand | 5.0.9 | Reactive state management |
| Maps | MapLibre React Native | 11.0.0-beta.19 | Interactive world map |
| Animation | react-native-reanimated | 4.1.1 | Native-thread animations |
| Gestures | react-native-gesture-handler | 2.28.0 | Native gesture recognition |
| Graphics | react-native-svg | 15.12.1 | SVG rendering |
| Large Numbers | break_eternity.js | 2.1.3 | Big number math (1e308+) |
| Audio | expo-audio | 1.1.1 | Sound effects |
| Haptics | expo-haptics | 15.0.8 | Tactile feedback |
| Storage | AsyncStorage | 2.2.0 | Persistent save data |
| Font | Fredoka (Google Fonts) | 0.4.1 | Primary typeface |
| Testing | Jest + RTL | 29.7.0 / 12.4.3 | Unit and component tests |
| Build | EAS Build | CLI >= 16.0.0 | Cloud builds |

---

## Architecture Pattern

**3-Layer Architecture: Engine → Store → UI**

```
┌─────────────────────────────────────────────────────────┐
│                      UI LAYER                           │
│                                                         │
│  App.tsx (entry, tabs, tutorial)                        │
│  ├── src/screens/    (8 screen components)              │
│  ├── src/components/ (29+ reusable components)          │
│  └── src/hooks/      (7 custom hooks)                   │
│                                                         │
│  Reads state via useGameStore hook                      │
│  Dispatches actions to store                            │
├─────────────────────────────────────────────────────────┤
│                     STORE LAYER                         │
│                                                         │
│  src/stores/gameStore.ts (~2,225 lines)                 │
│  Single Zustand store — ALL game state and actions      │
│                                                         │
│  Calls engine for calculations                          │
│  Auto-persists via persist callback → AsyncStorage      │
├─────────────────────────────────────────────────────────┤
│                    ENGINE LAYER                          │
│                                                         │
│  src/engine/formulas.ts          (economic math)        │
│  src/engine/achievementUnlocks.ts (achievement logic)   │
│  src/engine/continentMilestones.ts (milestone tracking) │
│                                                         │
│  Pure functions — zero side effects, fully testable     │
├─────────────────────────────────────────────────────────┤
│                     DATA LAYER                          │
│                                                         │
│  src/data/gameData.ts          (79 countries, configs)  │
│  src/data/activePlayConfig.ts  (golden/boost/mission)   │
│  src/data/countryMapping.ts    (game ID ↔ map ID)       │
│  src/data/dailyRewardsConfig.ts (7-day rewards)         │
│                                                         │
│  Static configuration — balance tuning happens here     │
└─────────────────────────────────────────────────────────┘
```

**Key principles:**
1. **Single source of truth** — One Zustand store holds all game state
2. **Pure engine** — All economic/logic calculations are side-effect-free functions
3. **Decimal everywhere** — All monetary values use break_eternity.js `Decimal`
4. **Auto-persistence** — State auto-saves after mutations via Zustand persist callback
5. **Save compatibility** — Migration system (v12 → v13) allows balance changes without breaking saves

---

## Data Flow

### Application Lifecycle

```
1. App.tsx mounts
   → Load fonts (Fredoka 400-700)
   → Setup SafeArea + GestureHandler
   → Call store.initializeGame()

2. initializeGame()
   → Load save from AsyncStorage (v13 key, fallback to v12)
   → Merge saved state with current gameData structure
   → Calculate offline earnings (max 8 hours)
   → Set initial UI state

3. Game Loop (useGameLoop, 1s interval)
   → store.tick(deltaTime)
     → Update generation timers for all countries
     → Calculate leader passive income
     → Spawn/expire golden opportunities
     → Track mission progress
     → Check boost expiration

4. User Interaction
   → Tap country → store.collect(countryId)
   → Purchase upgrade → store.purchaseUpgrade(countryId)
   → Hire leader → store.purchaseLeader(countryId)
   → Each action: engine formula → state update → auto-save → UI re-render
```

### Dependency Graph

```
App.tsx (entry)
  ├─→ stores/gameStore.ts (all game logic)
  │    ├─→ engine/formulas.ts (economic calculations)
  │    ├─→ engine/achievementUnlocks.ts
  │    ├─→ engine/continentMilestones.ts
  │    ├─→ data/gameData.ts (country/leader/upgrade definitions)
  │    ├─→ data/activePlayConfig.ts (timing parameters)
  │    ├─→ utils/saveSystem.ts (AsyncStorage persistence)
  │    └─→ utils/soundSystem.ts (audio effects)
  │
  ├─→ screens/GameScreen.tsx (primary view)
  │    ├─→ hooks/useGameLoop.ts (1s tick)
  │    ├─→ hooks/useCountryStates.ts (derived state for 79 countries)
  │    ├─→ hooks/useModalQueue.ts (priority modal system)
  │    ├─→ hooks/useContextualHints.ts (post-tutorial hints)
  │    ├─→ components/map/MapLibreMap.tsx (interactive map)
  │    └─→ components/* (modals, toasts, flyouts)
  │
  ├─→ screens/UpgradesScreen.tsx
  ├─→ screens/LeadersScreen.tsx
  ├─→ screens/SettingsScreen.tsx
  ├─→ screens/StatsScreen.tsx
  ├─→ screens/MilestonesScreen.tsx
  │
  └─→ components/TutorialOverlay.tsx (12-step onboarding)
```

---

## Game Systems

### Core Progression

| System | Mechanic | Formula |
|---|---|---|
| **Tap Collection** | Player taps ready country | `baseInfluence × upgradeLevel × leaderMult × globalMult × globalUpgradeBonus × continentUpgradeBonus` |
| **Upgrade Power** | Increase country influence | Cost: `baseCost × 1.5^(level-1)`, max 200 levels |
| **Leader Automation** | Passive income per second | `generationReward / effectiveSeconds` (Efficiency Expert reduces time) |
| **Leader Leveling** | Increase leader multiplier | Levels 0→3, multipliers: 1→1.5→2→3x, costs: 100x/500x/2000x/8000x base |
| **Continent Completion** | Global multiplier bonus | All countries + leaders unlocked → permanent multiplier (0.25x–1.75x) |
| **Global Multiplier** | Stacking bonuses | Product of all continent bonuses × all achievement bonuses |

### Active Play Systems

| System | Trigger | Duration | Reward |
|---|---|---|---|
| **Golden Opportunities** | Random spawn (8-14s delay) | 8-15s window | 10-100x multiplier on random country |
| **Boosts** | Player-activated (ad or 18 Intel) | 30 seconds | 2x global multiplier |
| **Missions** | Auto-assigned, 3 types | Varies | 4-6 Intel per completion |
| **Daily Rewards** | Once per calendar day | 7-day cycle | Influence, Intel, or multiplier bonus |

### Continent Milestones

Per-continent milestones at 25%, 50%, 75% progress. Progress = (unlocked countries + unlocked leaders) / (2 × total slots) × 100. Rewards: Intel (5/10/15) + influence burst (1 min idle income).

### Offline System

- Leaders generate passive income while app is closed
- Max offline period: 8 hours
- Calculated on app resume: `totalIdleRate × min(elapsed, 28800)`
- Presented via OfflineModal with claim button

---

## State Management

### Zustand Store (gameStore.ts)

Single store (~2,225 lines) managing:

| State Category | Key Fields |
|---|---|
| **Currency** | `influence` (Decimal), `totalInfluenceEarned`, `totalTaps`, `intel` (number) |
| **Entities** | `countries` (79), `leaders`, `upgrades`, `globalUpgrades`, `continentUpgrades`, `continents`, `achievements` — all `Record<string, T>` |
| **Active Play** | `boost: BoostState \| null`, `golden: GoldenState \| null`, `mission: MissionState \| null` |
| **Progression** | `globalMultiplier` (Decimal), `dailyStreak`, `lastDailyRewardDate` |
| **Tutorial** | `tutorialStep` (0-12), `tutorialCompleted`, `tutorialHints` |
| **UI Queue** | `pendingCelebrations`, `pendingAchievements`, `pendingBonuses` |

### Key Actions

| Action | Purpose |
|---|---|
| `initializeGame()` | Async load from storage or fresh start |
| `tick(deltaTime)` | Game loop: timers, income, spawns |
| `collect(countryId)` | Tap country for influence |
| `purchaseUpgrade(countryId, amount?)` | Level up country influence |
| `purchaseLeader(countryId)` | Hire automation leader |
| `upgradeLeader(countryId)` | Level up leader multiplier |
| `unlockCountry(countryId)` | Pay to unlock new country |
| `activateBoostViaAd()` / `activateBoostViaIntel()` | Activate 30s 2x boost |
| `claimGolden(countryId)` | Claim golden opportunity |
| `claimDailyReward()` | Claim daily login reward |
| `collectOfflineReward()` | Calculate and claim offline earnings |
| `saveGame()` / `loadGame()` / `resetGame()` | Persistence operations |

### Persistence

- **Storage:** AsyncStorage with key `global-domination-save-v13`
- **Serialization:** Decimal values → `{ __decimal: "value" }` JSON format
- **Auto-save:** Persist callback fires after every state mutation
- **Migration:** v12 → v13 (adds `tutorialHints`, resets incomplete tutorials)
- **Merge on load:** Saved state merged with current `gameData` to absorb balance changes

---

## UI Architecture

### Navigation

Tab-based navigation managed in `App.tsx` (no React Navigation):
- **Game** — Primary map screen (default tab)
- **Leaders** — Leader hiring and leveling
- **Minigames** — Placeholder for future content
- **Upgrades** — Country upgrade purchasing
- **Achievements** — Placeholder for future content
- **Settings** — Preferences overlay
- **Stats** — Statistics overlay

Tab switching is blocked during the 12-step tutorial. Tutorial auto-switches tabs at step 9 (leaders).

### Modal Priority Queue

Managed by `useModalQueue` hook with priority-based display:

| Priority | Modal | Trigger |
|---|---|---|
| 1 | OfflineModal | App resume with offline earnings |
| 2 | DailyRewardModal | Once per calendar day |
| 3 | CelebrationModal | Continent completion |
| 4 | AchievementToast | Achievement unlock |
| 5 | ActiveBonusToast | Mission/milestone completion |

150ms transition between modals. Only one modal visible at a time.

### Map Rendering

MapLibre GL renders the world map with:
- **Country state layers** — Color-coded by state (locked grey, unlockable green, unlocked, automated)
- **Breathing glow** — Ready-to-collect countries pulse
- **Tap handling** — Country taps routed through `onCountryTap` callback
- **Zoom animations** — Smooth zoom to continent/country on interaction
- **Offline tiles** — Downloadable map tile caching for offline play
- **Dark gaming style** — Custom dark map theme

---

## Entry Points

| Entry | File | Purpose |
|---|---|---|
| Expo Bootstrap | `index.ts` | `registerRootComponent(App)` |
| App Root | `App.tsx` | Font loading, safe area, tab nav, tutorial, error handling |
| Game Store Init | `stores/gameStore.ts → initializeGame()` | Load save data or initialize fresh game |
| Game Loop | `hooks/useGameLoop.ts` | 1s interval tick driving all real-time mechanics |

---

## Testing Strategy

| Layer | Approach | Tools |
|---|---|---|
| Engine | Unit tests on pure functions | Jest |
| Store | State mutation tests | Jest + Zustand |
| Components | Render + interaction tests | Jest + @testing-library/react-native |

- **Preset:** jest-expo (Expo-specific configuration)
- **Path alias:** `@/*` → `src/$1`
- **Transform ignores:** Configured for native modules (react-native, expo, maplibre)
- **Test pattern:** `**/__tests__/**/*.test.[jt]s?(x)`

---

## Build & Deployment

### EAS Build Profiles

| Profile | Distribution | Purpose |
|---|---|---|
| `development` | Internal | Dev client with debug tools |
| `development-simulator` | Internal | iOS simulator builds |
| `preview` | Internal | Internal testing |
| `production` | Store | App Store / Google Play |

### Platform Configuration

- **New Architecture** enabled (React Native Fabric renderer)
- **Android:** Edge-to-edge, adaptive icon, audio permissions, package `com.anonymous.globaldominationgame`
- **iOS:** Tablet support enabled
- **Expo Plugins:** expo-audio, expo-font, expo-dev-client, @maplibre/maplibre-react-native, expo-asset
- **Orientation:** Portrait only

---

## Design System

### Typography
- **Font:** Fredoka (Google Fonts) — weights 400, 500, 600, 700
- **Sizes:** giant (36), header (24), title (18), body (14), small (12)

### Color Palette

| Token | Hex | Usage |
|---|---|---|
| Background | `#CFE6F5` | Primary screen background |
| Surface | `#FFFFFF` | Cards and modals |
| Primary Action | `#56B72D` | Buttons, positive states |
| Secondary Action | `#FFC800` | Gold/highlight elements |
| Golden | `#FFD700` | Golden opportunity state |
| Unlockable | `#22C55E` | Affordable unlock state |
| Locked | `#BDC3C7` | Locked country/feature |
| Automated | `#4AB856` | Leader-automated countries |
| Ocean | `#3A8FD6` | Map ocean color |
| Error | `#EF4444` | Error states |
| Milestone Glow | `#F59E0B` | Amber milestone indicator |

### Spacing
xs (4), sm (8), md (12), lg (16), xl (24)

### Animation Durations
fast (150ms), normal (300ms), slow (500ms)
