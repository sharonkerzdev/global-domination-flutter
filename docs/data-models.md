# Data Models

> Global Domination Game — Generated: 2026-04-06

## Core Game Entities

All types defined in `src/types/game.ts`. Monetary values use `Decimal` from break_eternity.js.

### Country

```typescript
interface Country {
  id: string;                    // e.g., "africa_somalia"
  name: string;                  // e.g., "Somalia"
  continentId: string;           // e.g., "africa"
  unlockCost: Decimal;           // Tier-based: Decimal.pow(10, tier-1)
  baseInfluence: Decimal;        // Base influence per generation
  generationTimeSeconds: number; // Base: 4-5 seconds
  generationTimer: number;       // Current countdown (seconds remaining)
  currentGenerationProgress: number; // 0-1 progress for UI
  isUnlocked: boolean;
  isGenerating: boolean;
  isReadyToCollect: boolean;
  lastGenerationStartTime: number | null;
  order: number;                 // Display order within continent
  leaderId: string;              // Associated leader ID
  upgradeIds: string[];          // Associated upgrade IDs
}
```

**79 countries** across 7 continents. First country (Somalia) starts unlocked.

### Leader

```typescript
interface Leader {
  id: string;                    // e.g., "leader_africa_somalia"
  countryId: string;
  name: string;                  // Generated from titles list
  description: string;           // "Automates influence generation for [country]"
  baseCost: Decimal;             // ~100× country base influence
  isUnlocked: boolean;
  level: 0 | 1 | 2 | 3;        // 0 = hired but base, 3 = max
  multiplier: 1 | 1.5 | 2 | 3; // Maps to level (0→1, 1→1.5, 2→2, 3→3)
}
```

**Upgrade costs (multiplied by base influence):** Level 0→1: 500×, Level 1→2: 2000×, Level 2→3: 8000×

### Upgrade

```typescript
interface Upgrade {
  id: string;                    // e.g., "upgrade_africa_somalia"
  countryId: string;
  name: string;                  // "Influence Power"
  description: string;
  kind: 'influence_power';       // Currently only type
  baseCost: Decimal;             // ~4× country base influence
  level: number;                 // 1-200
  maxLevel: number;              // 200
}
```

**Cost formula:** `baseCost × 1.5^(level-1)` — exponential growth at 1.5× per level.

### GlobalUpgrade

```typescript
interface GlobalUpgrade {
  id: 'global_influence_amplifier' | 'global_efficiency_expert' | 'global_intel_bonus';
  name: string;
  description: string;
  baseCost: Decimal;
  level: number;
  maxLevel: number;
  effectPerLevel: number;
}
```

| Upgrade | Effect | Formula |
|---|---|---|
| **Influence Amplifier** | Multiplies all influence | `1 + level × 0.1` |
| **Efficiency Expert** | Reduces generation time | `level × 2%` (max 40% at level 20) |
| **Intel Bonus** | Multiplies mission Intel rewards | `1 + level × 0.1` |

### ContinentUpgrade

```typescript
interface ContinentUpgrade {
  id: string;                    // e.g., "continent_upgrade_africa"
  continentId: string;
  name: string;
  baseCost: Decimal;             // Scaled from first country in continent
  level: number;
  maxLevel: number;
  effectPerLevel: number;        // 0.1 (10% per level)
}
```

**Effect:** `1 + level × 0.1` multiplier applied to all countries in that continent.

### Continent

```typescript
interface Continent {
  id: string;                    // e.g., "africa"
  name: string;
  countryIds: string[];
  isCompleted: boolean;          // All countries + leaders unlocked
  completionBonus: number;       // Global multiplier bonus (0.25 - 1.75)
  claimedMilestones?: number[];  // Percent values: [25, 50, 75]
}
```

| Continent | Countries | Unlock Threshold | Completion Bonus |
|---|---|---|---|
| Africa | 19 | Free (starting) | 0.25× |
| Europe | 19 | 1B influence | 0.50× |
| Middle East | 10 | 100B | 0.75× |
| Asia | 16 | 10T | 1.00× |
| South America | 8 | 1Q | 1.25× |
| North America | 4 | 100Q | 1.50× |
| Oceania | 3 | 10Qi | 1.75× |

### Achievement

```typescript
interface Achievement {
  id: string;
  name: string;
  description: string;
  condition: string;             // Human-readable condition text
  isUnlocked: boolean;
  rewardMultiplier: number;      // Added to global multiplier
  rewardIntel?: number;          // Optional Intel bonus
}
```

**20+ achievements** across categories: unlock-based, influence thresholds, tap counts, continent completion, golden claims, regional milestones.

---

## Active Play State Types

### BoostState

```typescript
interface BoostState {
  activeUntil: number;           // Timestamp (ms) when boost expires
  multiplier: number;            // Always 2
}
```

Duration: 30 seconds. Activated via ad watch (free) or 18 Intel (paid). Does NOT affect golden claims.

### GoldenState

```typescript
interface GoldenState {
  countryId: string;             // Random unlocked country
  expiresAt: number;             // Timestamp (ms) when golden disappears
  multiplier: number;            // Random 10-100
}
```

Spawn timing: 8-14s initial delay, 8-15s active window, 15-25s cooldown. New game grace period: 120s.

### MissionState

```typescript
interface MissionState {
  id: string;
  kind: 'claim_goldens' | 'activate_boost' | 'stay_active';
  progress: number;              // Current progress toward target
  target: number;                // 3 goldens | 1 boost | 45 seconds
  rewardIntel: number;           // 6 | 5 | 4 Intel (base)
}
```

Intel rewards are multiplied by the Intel Bonus global upgrade.

### BonusToast

```typescript
interface BonusToast {
  id: string;
  title: string;
  body?: string;
}
```

Queued notifications for mission completions and milestone rewards.

---

## Full GameState (Zustand Store)

```typescript
interface GameState {
  // Core currency
  influence: Decimal;
  totalInfluenceEarned: Decimal;
  totalTaps: Decimal;

  // Entity records (keyed by ID)
  countries: Record<string, Country>;
  leaders: Record<string, Leader>;
  upgrades: Record<string, Upgrade>;
  globalUpgrades: Record<string, GlobalUpgrade>;
  continentUpgrades: Record<string, ContinentUpgrade>;
  continents: Record<string, Continent>;
  achievements: Record<string, Achievement>;

  // Computed multiplier
  globalMultiplier: Decimal;     // Product of continent bonuses + achievement bonuses

  // Secondary currency
  intel: number;

  // Active play state
  boost: BoostState | null;
  golden: GoldenState | null;
  mission: MissionState | null;

  // Daily rewards
  dailyStreak: number;
  lastDailyRewardDate: string | null;

  // Tutorial
  tutorialStep: number;         // 0-12
  tutorialCompleted: boolean;
  tutorialHints: Record<string, boolean>;  // Shown hints tracking

  // Pending UI notifications
  pendingCelebrations: string[];  // Continent IDs
  pendingAchievements: string[];  // Achievement IDs
  pendingBonuses: BonusToast[];

  // Persistence
  savedAt: string | null;
}
```

---

## Serialization & Persistence

### Storage Format
- **Engine:** AsyncStorage (platform-native key-value store)
- **Save version:** 13
- **Key:** `global-domination-save-v13`

### Decimal Serialization
All `Decimal` values are serialized as:
```json
{ "__decimal": "1.5e10" }
```

The save system recursively walks the state tree, converting `Decimal` instances to this format on save and restoring them on load.

### Migration
- Auto-migrates from v12 save key on load
- v12 → v13 changes: adds `tutorialHints` field, resets incomplete 5-step tutorials to 0
- State is merged with current `gameData` structure on load — allows balance changes without breaking saves

### Offline Calculation
- Max offline period: **8 hours** (28,800 seconds)
- Formula: `totalIdleRatePerSecond × min(elapsedSeconds, 28800)`
- Only countries with unlocked leaders contribute to offline income
- Calculated once on app resume via `collectOfflineReward()`

---

## Data Configuration Files

### gameData.ts (src/data/)
Static definitions for all game content:
- **79 countries** with base influence, generation time, unlock costs
- **79 leaders** (1 per country) with auto-generated names
- **79 upgrades** (Influence Power, 1-200 levels per country)
- **3 global upgrades** (Influence Amplifier, Efficiency Expert, Intel Bonus)
- **7 continent upgrades** (one per continent)
- **20+ achievements** with conditions and rewards

### activePlayConfig.ts (src/data/)
Timing and reward parameters:
- **Golden:** spawn delay (8-14s), window (8-15s), cooldown (15-25s), multiplier (10-100x)
- **Boost:** duration (30s), multiplier (2x), Intel cost (18)
- **Missions:** 3 types with targets and Intel rewards

### countryMapping.ts (src/data/)
Bidirectional mappings between game IDs and map rendering:
- `GAME_TO_SVG`: `"africa_somalia"` → `"SO"`
- `SVG_TO_GAME`: `"SO"` → `"africa_somalia"`
- `SVG_CONTINENT_MAP`: `"SO"` → `"africa"`

### dailyRewardsConfig.ts (src/data/)
7-day reward cycle:
- Days 1-6: Alternating influence (1K, 5K, 25K) and Intel (5, 10, 20)
- Day 7: Combo reward — 100K influence + 0.05× global multiplier bonus
