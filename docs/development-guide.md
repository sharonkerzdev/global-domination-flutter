# Development Guide

> Global Domination Game — Generated: 2026-04-06

## Prerequisites

- **Node.js** — LTS version (v18+ recommended)
- **Expo CLI** — Included via `npx expo`
- **EAS CLI** — >= 16.0.0 (`npm install -g eas-cli`)
- **Android Studio** — For Android emulator and local builds
- **Xcode** — For iOS simulator and local builds (macOS only)
- **Git** — Version control

> **Note:** This project uses a **development build** (not Expo Go) because of native modules like MapLibre. See `docs/MIGRATION.md` for details.

---

## Quick Start

```bash
# Install dependencies
npm install

# Start Expo dev server
npx expo start

# Run on Android device/emulator
npx expo run:android

# Run on iOS device/simulator (macOS only)
npx expo run:ios
```

---

## Available Scripts

| Command | Alias | Purpose |
|---|---|---|
| `npm start` | `expo start` | Start Expo development server |
| `npm run android` | `expo run:android` | Run on Android device/emulator |
| `npm run ios` | `expo run:ios` | Run on iOS device/simulator |
| `npm test` | `jest` | Run test suite |
| `npm run typecheck` | `tsc --noEmit` | TypeScript type checking (no output) |
| `npm run build:dev:android` | `eas build --profile development --platform android` | EAS development build (Android) |
| `npm run build:dev:ios` | `eas build --profile development --platform ios` | EAS development build (iOS) |

---

## Project Structure

```
src/
├── stores/        # Zustand game store (single store pattern)
├── engine/        # Pure calculation functions (formulas, achievements, milestones)
├── screens/       # 8 screen components (tab content)
├── components/    # 29+ reusable components
│   ├── ui/        #   Design system (GameButton, GameText, CurrencyBadge, etc.)
│   ├── map/       #   Map components (MapLibreMap, TopBarHUD)
│   └── leaders/   #   Leader management (ContinentCard, CountryLeaderRow)
├── data/          # Game data definitions (countries, config, mappings)
├── hooks/         # Custom React hooks (game loop, state derivation)
├── types/         # TypeScript interfaces (Country, Leader, Upgrade, etc.)
├── utils/         # Utilities (save system, sound, haptics, formatting)
└── styles/        # Theme (colors, typography, spacing)
```

---

## Development Patterns

### State Management

The entire game state lives in a **single Zustand store** (`src/stores/gameStore.ts`, ~2,225 lines). Access it via:

```typescript
import { useGameStore } from '@/stores/gameStore';

// In components — subscribe to specific slices
const influence = useGameStore(s => s.influence);
const collect = useGameStore(s => s.collect);

// Outside React — direct access
const state = useGameStore.getState();
```

**Key conventions:**
- State mutations use Zustand's `set()` — auto-persisted via persist callback
- All monetary values are `Decimal` (break_eternity.js) — never use plain numbers for influence
- Async actions (collect, purchase, boost) return promises to allow sound/haptic sequencing
- State is merged with `gameData` structure on load to support balance changes without breaking saves

### Adding a New Country

1. Add country definition to `src/data/gameData.ts` in the appropriate continent
2. Add game ID → ISO-2 mapping in `src/data/countryMapping.ts`
3. Leader and upgrade entries are auto-generated from the country definition

### Adding a New Achievement

1. Define achievement in `src/data/gameData.ts` → `achievements` section
2. Add condition check in `src/engine/achievementUnlocks.ts` → `applyAchievementUnlocks()`
3. Achievement unlock is checked automatically on every state mutation

### Balance Tuning

| What to Change | File |
|---|---|
| Country costs/rewards | `src/data/gameData.ts` |
| Active play timing (golden spawn, boost duration) | `src/data/activePlayConfig.ts` |
| Formula curves (cost scaling, multipliers) | `src/engine/formulas.ts` |
| Daily reward values | `src/data/dailyRewardsConfig.ts` |
| Milestone thresholds and rewards | `src/engine/continentMilestones.ts` |

### Component Conventions

- **Text** — Always use `GameText` component (enforces Fredoka font family)
- **Buttons** — Always use `GameButton` (includes haptic feedback automatically)
- **Haptics** — Use `src/utils/haptics.ts` wrapper (light/medium/heavy/success)
- **Sound** — Use `src/utils/soundSystem.ts` (8 effects: collect, golden, milestone, unlock, upgrade, continent_complete, zoom, auto_tick)
- **Animations** — Use `react-native-reanimated` for smooth native-thread animations
- **Numbers** — Use `formatInfluence()` from `src/utils/formatInfluence.ts` for display (handles K/M/B/T/Qa/Qi... suffixes)

### Game Loop

The game tick runs on a 1-second interval via `useGameLoop` hook:

```
useGameLoop (1s interval)
  → store.tick(deltaTime)
    → Update generation timers for all countries
    → Calculate passive income from leaders
    → Spawn/expire golden opportunities
    → Track mission progress
    → Check boost expiration
```

Delta time is clamped to max 5 seconds to prevent huge jumps after app backgrounding.

---

## Testing

- **Framework:** Jest 29.7 + jest-expo preset
- **Component testing:** @testing-library/react-native
- **Test pattern:** `**/__tests__/**/*.test.[jt]s?(x)`
- **Path alias:** `@/*` → `src/$1` (configured in jest.config.js)

```bash
# Run all tests
npm test

# Run with watch mode
npx jest --watch

# Run specific test file
npx jest __tests__/formulas.test.ts
```

**Transform ignore patterns** are configured to handle native modules (react-native, expo, maplibre, etc.) in `jest.config.js`.

---

## Build & Deployment

### EAS Build Profiles (eas.json)

| Profile | Distribution | Purpose |
|---|---|---|
| `development` | Internal | Dev client build with debug tools |
| `development-simulator` | Internal | iOS simulator-specific dev build |
| `preview` | Internal | Internal testing/preview |
| `production` | Store | App Store / Google Play submission |

```bash
# Development build (Android)
npm run build:dev:android

# Development build (iOS)
npm run build:dev:ios

# Preview build
eas build --profile preview --platform all

# Production build
eas build --profile production --platform all

# Submit to stores
eas submit --profile production --platform all
```

### Key Build Configuration

- **New Architecture** enabled (`newArchEnabled: true` in app.json)
- **Expo plugins:** expo-audio, expo-font, expo-dev-client, @maplibre/maplibre-react-native, expo-asset
- **Android:** Edge-to-edge, adaptive icon, audio permissions
- **iOS:** Tablet support enabled

---

## TypeScript Configuration

- **Base:** Extends `expo/tsconfig.base`
- **Strict mode:** All strict flags enabled (`strict: true`)
- **Path alias:** `@/*` → `src/*` (for clean imports)

```bash
# Type check without emitting files
npm run typecheck
```

---

## Environment & Configuration

| File | Purpose |
|---|---|
| `app.json` | Expo app configuration (name, icons, plugins, permissions) |
| `eas.json` | EAS Build profiles and CLI version |
| `tsconfig.json` | TypeScript compiler options |
| `babel.config.js` | Babel preset expo |
| `metro.config.js` | Metro bundler configuration |
| `jest.config.js` | Jest testing configuration |

- **No `.env` files** — Configuration is static in `src/data/` and `app.json`
- **Save data** — AsyncStorage with version 13 format, auto-migration from v12
- **Decimal serialization** — `{ __decimal: "value" }` format in saved state

---

## Dev Tools

A `DevTools` component is available in development builds, providing:

- **Add influence** — Inject currency for testing
- **Unlock all countries** — Skip progression
- **Skip time** — Fast-forward game clock
- **Reset to country** — Reset state to specific progress point
- **Patch state** — Directly modify store values

Access via the in-app dev menu (development builds only).
