# Source Tree Analysis

> Global Domination Game — Generated: 2026-04-06

## Directory Tree

```
global-domination-game/
├── App.tsx                        # Main entry point — tab navigation, tutorial system, font loading
├── index.ts                       # Expo entry point (registerRootComponent)
├── package.json                   # Dependencies and npm scripts
├── app.json                       # Expo configuration (plugins, permissions, icons)
├── tsconfig.json                  # TypeScript strict mode, extends expo/tsconfig.base
├── babel.config.js                # Babel preset expo
├── metro.config.js                # Metro bundler configuration
├── jest.config.js                 # Jest + jest-expo preset, path alias @/*
├── eas.json                       # EAS Build profiles (dev, preview, production)
├── ARCHITECTURE.md                # Architecture overview document
├── PRD.md                         # Product requirements document
├── MVP_SCOPE.md                   # Current MVP scope definition
├── TECH_DECISIONS.md              # Technology decision records
├── dev-loop.sh / dev-loop.ps1     # Development loop scripts (Unix/Windows)
│
├── android/                       # Native Android project (Gradle, manifests)
├── assets/                        # App icons, splash screens, adaptive icons
├── scripts/                       # Build and utility scripts
├── __tests__/                     # Root-level test files
├── __mocks__/                     # Jest mock modules
│
├── docs/                          # ★ Generated project documentation
│   ├── index.md                   # Documentation master index
│   ├── architecture.md            # Full architecture documentation
│   ├── project-overview.md        # Executive summary and tech stack
│   ├── source-tree-analysis.md    # This file
│   ├── component-inventory.md     # All 29+ components cataloged
│   ├── data-models.md             # TypeScript interfaces and data structures
│   ├── development-guide.md       # Dev setup, scripts, patterns
│   └── MIGRATION.md               # Expo Go → Development Build migration
│
├── _bmad/                         # BMAD workflow system (skills, agents)
├── _bmad-output/                  # BMAD-generated planning/implementation artifacts
│   ├── index.md                   # Artifact index
│   ├── project-context.md         # AI-optimized project context (28 rules)
│   ├── playtest-plan.md           # Structured playtesting plan
│   ├── project-scan-report.json   # Documentation workflow state
│   ├── planning-artifacts/
│   │   ├── gdd.md                 # Game Design Document
│   │   ├── epics/                 # 18 epic breakdowns + indexes
│   │   │   ├── index.md           # Epic table of contents
│   │   │   ├── overview.md        # Epic decomposition overview
│   │   │   ├── epic-list.md       # Summary table of all epics
│   │   │   ├── requirements-inventory.md
│   │   │   └── epic-1 through epic-18 .md
│   │   └── sprint-change-proposal-*.md  # Sprint change proposals
│   └── implementation-artifacts/
│       ├── index.md               # Implementation artifact index
│       ├── sprint-status.yaml     # Sprint planning and status tracking
│       └── archive/               # 85+ completed story artifacts (Epics 1-17)
│
└── src/                           # ★ Application source code
    ├── components/                # ★ Reusable UI components (29+)
    │   ├── ui/                    # Design system primitives
    │   │   ├── GameButton.tsx     #   Standardized button with haptic feedback
    │   │   ├── GameText.tsx       #   Typography (Fredoka font variants)
    │   │   ├── CurrencyBadge.tsx  #   Influence/Intel display with icons
    │   │   ├── ProgressBar.tsx    #   Animated progress indicator
    │   │   ├── Badge.tsx          #   Simple status badge
    │   │   ├── GameCard.tsx       #   Card container with shadow
    │   │   └── BottomNavBar.tsx   #   5-tab navigation bar
    │   ├── map/                   # Map-specific components
    │   │   ├── MapLibreMap.tsx    #   MapLibre GL renderer with country layers
    │   │   ├── TopBarHUD.tsx      #   Influence display, stats/settings buttons
    │   │   └── OfflineTileOverlay.tsx  # Tile download progress
    │   ├── leaders/               # Leader management components
    │   │   ├── ContinentCard.tsx  #   Continent section with country list
    │   │   └── CountryLeaderRow.tsx  # Country + leader status row
    │   ├── BoostModal.tsx         # Boost activation (ad or Intel)
    │   ├── BoostPill.tsx          # Active boost countdown
    │   ├── CelebrationModal.tsx   # Continent completion celebration
    │   ├── ContextualHint.tsx     # Post-tutorial hints
    │   ├── CountryCard.tsx        # Country detail popup
    │   ├── DailyRewardModal.tsx   # 7-day reward cycle
    │   ├── DevTools.tsx           # Dev cheat menu
    │   ├── EmptyStateScreen.tsx   # First launch welcome screen
    │   ├── ErrorBoundary.tsx      # React error boundary wrapper
    │   ├── ErrorStateScreen.tsx   # Save/load error recovery
    │   ├── GoldenSpawnBanner.tsx  # Active golden opportunity indicator
    │   ├── LeaderHireCelebration.tsx  # Leader hire overlay
    │   ├── OfflineModal.tsx       # Offline reward collection
    │   ├── TapFlyout.tsx          # Floating influence numbers on tap
    │   ├── TutorialOverlay.tsx    # 12-step spotlight tutorial
    │   ├── AchievementToast.tsx   # Achievement unlock notification
    │   └── ActiveBonusToast.tsx   # Mission/milestone completion toast
    │
    ├── data/                      # ★ Game data definitions and configuration
    │   ├── gameData.ts            #   79 countries, 7 continents, upgrades, achievements
    │   ├── activePlayConfig.ts    #   Golden/boost/mission parameters
    │   ├── countryMapping.ts      #   Game ID ↔ SVG ISO-2 code mapping
    │   ├── dailyRewardsConfig.ts  #   7-day reward cycle definition
    │   └── index.ts               #   Barrel exports
    │
    ├── engine/                    # ★ Pure game logic (no side effects)
    │   ├── formulas.ts            #   Economic calculations (costs, multipliers, offline income)
    │   ├── achievementUnlocks.ts  #   Achievement condition checking (20+ achievements)
    │   ├── continentMilestones.ts #   Continent progress milestones (25/50/75%)
    │   └── index.ts               #   Barrel exports
    │
    ├── hooks/                     # ★ Custom React hooks
    │   ├── useGameLoop.ts         #   1s interval game tick (calls store.tick)
    │   ├── useCountryStates.ts    #   Memoized 79-country state computation
    │   ├── useModalQueue.ts       #   Priority modal queue (offline→daily→celebration→achievement→bonus)
    │   ├── useContextualHints.ts  #   Post-tutorial hint system (golden/boost/milestone/leader)
    │   ├── useMilestoneBadge.ts   #   Upgrade tab badge logic
    │   ├── useModalAnimation.ts   #   Modal transition animations
    │   ├── useOfflineTiles.ts     #   Map tile download management
    │   └── index.ts               #   Barrel exports
    │
    ├── screens/                   # ★ Screen-level components (tab content)
    │   ├── GameScreen.tsx         #   Primary screen — interactive map, modals, tutorial
    │   ├── UpgradesScreen.tsx     #   Country upgrade purchasing
    │   ├── LeadersScreen.tsx      #   Leader hiring and leveling
    │   ├── SettingsScreen.tsx     #   Preferences (haptics, sound, tiles)
    │   ├── StatsScreen.tsx        #   Game statistics overlay
    │   ├── MilestonesScreen.tsx   #   Continent milestone tracking
    │   ├── AchievementsPlaceholderScreen.tsx  # Future achievements gallery
    │   └── MinigamesPlaceholderScreen.tsx     # Future minigames
    │
    ├── stores/                    # ★ State management
    │   └── gameStore.ts           #   Single Zustand store (~2,225 lines) — all game state and actions
    │
    ├── styles/                    # ★ Design tokens
    │   └── theme.ts               #   Colors, typography (Fredoka), spacing, shadows, durations
    │
    ├── types/                     # ★ TypeScript type definitions
    │   └── game.ts                #   Core interfaces: Country, Leader, Upgrade, Achievement, GameState
    │
    └── utils/                     # ★ Shared utilities
        ├── formatInfluence.ts     #   Big number formatting (K/M/B/T/Qa/Qi... 30+ suffixes)
        ├── saveSystem.ts          #   AsyncStorage persistence (v13, Decimal serialization, migration)
        ├── soundSystem.ts         #   8 sound effects (collect, golden, milestone, unlock, etc.)
        ├── haptics.ts             #   Haptic feedback wrapper (light/medium/heavy/success)
        ├── countryAccessibilityLabels.ts  # Accessibility descriptions
        └── index.ts               #   Barrel exports
```

---

## Entry Points

| Entry Point | File | Purpose |
|---|---|---|
| **Expo Bootstrap** | `index.ts` | Registers root component via `registerRootComponent(App)` |
| **App Root** | `App.tsx` | Font loading, safe area, tab navigation, tutorial overlay, error handling |
| **Game Store Init** | `src/stores/gameStore.ts → initializeGame()` | Loads saved state from AsyncStorage or initializes fresh game |
| **Game Loop** | `src/hooks/useGameLoop.ts` | 1-second interval tick driving all real-time game mechanics |

---

## Critical Folders Explained

### `src/stores/` — Single Source of Truth
One file (`gameStore.ts`, ~2,225 lines) manages ALL game state via Zustand. Every screen reads from and dispatches to this store. State includes: influence (Decimal), 79 countries, leaders, upgrades, active play (golden/boost/mission), achievements, tutorial progress, daily rewards, and pending UI notifications.

### `src/engine/` — Pure Calculation Layer
Three files of pure functions with zero side effects. The store calls these for economic calculations (costs, multipliers, income rates), achievement condition checks, and continent milestone progress. This separation ensures game logic is testable independently of React/Zustand.

### `src/data/` — Game Configuration
Static data definitions: 79 countries across 7 continents with tier-based costs, 3 global upgrade types, 20+ achievements, active play timing (golden spawn rates, boost durations), country-to-map ID mappings, and daily reward schedules. Balance tuning happens here.

### `src/components/` — UI Building Blocks
29+ components organized into subdirectories: `ui/` (design system primitives), `map/` (MapLibre integration), `leaders/` (leader management). Modals, toasts, and game-specific components live at the root level. All text uses `GameText` (Fredoka font), all buttons use `GameButton` (haptic feedback).

### `src/hooks/` — Reactive Logic Bridges
Custom hooks bridge the store and UI: `useGameLoop` drives the tick, `useCountryStates` memoizes derived state for 79 countries, `useModalQueue` manages a priority queue of modals, `useContextualHints` triggers post-tutorial guidance.

### `src/screens/` — Tab Content
Eight screen components, one per tab or overlay. `GameScreen` is the primary view (map + modals + tutorial). Other screens handle upgrades, leaders, settings, stats, milestones, and placeholder screens for future features.

### `_bmad-output/` — Planning & Implementation History
Contains the Game Design Document, 18 epic breakdowns with story-level detail, sprint status tracking, and 85+ archived implementation story artifacts. This is the project's planning memory.

---

## Data Flow Between Folders

```
┌─────────────┐     reads      ┌─────────────┐     calls      ┌─────────────┐
│  src/data/   │ ◄──────────── │ src/stores/  │ ──────────────► │ src/engine/ │
│  (static     │               │ gameStore.ts │                │ (pure calc)  │
│   config)    │               │ (state +     │                │              │
└─────────────┘               │  actions)    │                └─────────────┘
                               └──────┬───────┘
                                      │ subscribes via useGameStore
                              ┌───────┴────────┐
                              │                │
                    ┌─────────▼──┐    ┌────────▼────────┐
                    │ src/hooks/ │    │ src/screens/     │
                    │ (derived   │    │ (tab views)      │
                    │  state)    │    │                  │
                    └─────┬──────┘    └────────┬─────────┘
                          │                    │ renders
                          │           ┌────────▼─────────┐
                          └──────────►│ src/components/  │
                                      │ (UI primitives)  │
                                      └──────────────────┘

  Utilities (src/utils/) are used across all layers:
  - saveSystem.ts ← stores (persistence)
  - soundSystem.ts ← stores (audio feedback)
  - haptics.ts ← components (tactile feedback)
  - formatInfluence.ts ← components (number display)
```

**Key Data Flow:**
1. `App.tsx` mounts → calls `initializeGame()` → loads state from AsyncStorage
2. `useGameLoop` starts 1s tick → calls `store.tick(deltaTime)`
3. `tick()` updates generation timers, spawns goldens, checks missions
4. Screens subscribe to store slices → re-render on state changes
5. User interactions (tap, purchase, boost) → store actions → engine formulas → state update
6. State mutations trigger auto-save via persist callback → AsyncStorage

---

## Multi-Platform Considerations

### Android
- Native project in `android/` directory
- Edge-to-edge display enabled
- Adaptive icon configured
- Audio permissions (RECORD_AUDIO, MODIFY_AUDIO_SETTINGS) for expo-audio
- Package: `com.anonymous.globaldominationgame`
- EAS Build for development and production APKs

### iOS
- Tablet support enabled (`supportsTablet: true`)
- Native project generated via Expo prebuild
- Xcode required for local builds
- EAS Build for development and App Store builds

### Shared Concerns
- **New Architecture enabled** — React Native Fabric renderer active
- **Safe area handling** — `react-native-safe-area-context` for notches/islands
- **Gesture handling** — `react-native-gesture-handler` wraps root
- **MapLibre** — Requires native module (development build, not Expo Go)
- **Offline tiles** — Map tiles downloadable for offline play
- **Portrait only** — App locked to portrait orientation
