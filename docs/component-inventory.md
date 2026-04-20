# Component Inventory

> Global Domination Game — Generated: 2026-04-06

## Summary

**Total Components:** 29+  
**Categories:** 7 (Design System, Map, Leaders, Game Modals, Toast/Banner, Game Feature, System)  
**Design System:** Fredoka font family, green/gold action palette, haptic feedback on all interactions

---

## Design System Components (src/components/ui/) — 7 components

| Component | Purpose | Key Props/Features |
|---|---|---|
| **GameButton.tsx** | Standardized button with haptic feedback | Primary/secondary variants, disabled state, onPress with haptic trigger |
| **GameText.tsx** | Typography with Fredoka font variants | Variants: giant (36), header (24), title (18), body (14), small (12); weight: regular/medium/semibold/bold |
| **CurrencyBadge.tsx** | Displays influence or Intel amounts with icons | Formats large numbers via `formatInfluence()`, currency type selector |
| **ProgressBar.tsx** | Animated progress indicator | Percentage fill with color theming, used in milestones and generation timers |
| **Badge.tsx** | Simple status badge | Text label with colored background |
| **GameCard.tsx** | Card container with shadow | Consistent padding, border radius, shadow elevation |
| **BottomNavBar.tsx** | 5-tab navigation bar | Tabs: Game, Leaders, Minigames, Upgrades, Achievements; active state highlighting, badge indicators |

**Conventions:** All text rendering goes through `GameText`. All interactive elements use `GameButton` which automatically triggers haptic feedback. Cards use `GameCard` for consistent elevation and spacing.

---

## Map Components (src/components/map/) — 3 components

| Component | Purpose | Key Props/Features |
|---|---|---|
| **MapLibreMap.tsx** | MapLibre GL map renderer | Country state layers (locked/unlockable/unlocked/automated), tap handling via `onCountryTap`, zoom animations, dark gaming style, GeoJSON country overlays, breathing glow on ready-to-collect |
| **TopBarHUD.tsx** | Status bar above map | Influence display (CurrencyBadge), Intel display, stats button, settings button; global across all tabs |
| **OfflineTileOverlay.tsx** | Map tile download progress | Download progress bar, retry button, shown during offline tile caching |

**Conventions:** Map components handle all MapLibre integration. Country visual states (colors, glows) are driven by `useCountryStates` hook data.

---

## Leader Components (src/components/leaders/) — 2 components

| Component | Purpose | Key Props/Features |
|---|---|---|
| **ContinentCard.tsx** | Continent section with expandable country list | Shows continent name, completion %, country count, expandable list of CountryLeaderRows |
| **CountryLeaderRow.tsx** | Country + leader status row | Country name, leader name/status (locked/unlocked/level), hire/upgrade button, cost display |

---

## Game Modals — 4 components

| Component | Purpose | Trigger |
|---|---|---|
| **OfflineModal.tsx** | Shows offline earnings on app resume | Auto-shown when `collectOfflineReward()` calculates > 0 earnings; max 8 hours |
| **DailyRewardModal.tsx** | 7-day reward cycle display | Auto-shown once per calendar day; rewards alternate influence/Intel/multiplier |
| **CelebrationModal.tsx** | Continent completion celebration | Triggered when all countries + leaders in a continent are unlocked |
| **BoostModal.tsx** | Boost activation interface | User-triggered; offers 30s 2x boost via ad watch (free) or 18 Intel (paid) |

**Modal Queue Priority:** offline (1) → daily (2) → celebration (3) → achievement (4) → bonus (5). Managed by `useModalQueue` hook with 150ms transitions between modals.

---

## Toast/Banner Components — 3 components

| Component | Purpose | Duration |
|---|---|---|
| **AchievementToast.tsx** | Achievement unlock notification | Auto-dismiss; shows achievement name, description, and multiplier reward |
| **ActiveBonusToast.tsx** | Mission/milestone completion toast | Auto-dismiss; shows Intel reward and bonus description |
| **GoldenSpawnBanner.tsx** | Active golden opportunity indicator | Shown while golden is active (8–15s); indicates which country has the golden multiplier |

---

## Game Feature Components — 5 components

| Component | Purpose | Key Details |
|---|---|---|
| **CountryCard.tsx** | Country detail popup | Shows country stats: influence rate, upgrade level, leader status, generation timer |
| **BoostPill.tsx** | Active boost countdown display | Floating pill showing remaining boost seconds; visible during 30s boost |
| **TapFlyout.tsx** | Floating influence numbers on tap | Animated numbers that float upward and fade; shows collected influence amount |
| **ContextualHint.tsx** | Post-tutorial contextual hints | 4 hint types: golden ("Tap glowing country!"), boost, milestone, leader nudge; priority-based, one at a time |
| **LeaderHireCelebration.tsx** | Leader hire celebration overlay | Full-screen celebration animation when player hires their first leader or special leaders |

---

## System Components — 5 components

| Component | Purpose | Key Details |
|---|---|---|
| **TutorialOverlay.tsx** | 12-step spotlight tutorial | Guided onboarding with spotlight targeting, step navigation, auto-tab-switching (step 9 → leaders tab) |
| **DevTools.tsx** | Development cheat menu | Add influence, unlock all countries, skip time, reset to country, patch state; dev builds only |
| **ErrorBoundary.tsx** | React error boundary | Wraps app, catches render errors, shows fallback UI with retry option |
| **EmptyStateScreen.tsx** | First launch welcome screen | Shown on fresh install before game initialization; introduces game concept |
| **ErrorStateScreen.tsx** | Save/load error recovery | Shown when save data is corrupted; offers retry load or full reset options |

---

## Architectural Patterns

### State Access
All components access game state via the `useGameStore` Zustand hook. Components subscribe to specific state slices to minimize re-renders:
```typescript
const influence = useGameStore(s => s.influence);
const collect = useGameStore(s => s.collect);
```

### Haptic Feedback
Every interactive element triggers haptic feedback. `GameButton` does this automatically. Custom interactions use the `haptics.ts` utility directly (light for taps, medium for purchases, success for achievements).

### Animation
UI animations use `react-native-reanimated` for native-thread performance. Common patterns: fade-in modals, sliding toasts, floating tap flyouts, breathing glow effects on map countries.

### Sound
Sound effects are triggered alongside haptics on key interactions. The `soundSystem.ts` utility manages 8 effects with lazy loading and graceful error handling.

### Decimal Display
All influence/currency values use `break_eternity.js` Decimal type internally. The `formatInfluence()` utility converts to human-readable strings with 30+ suffixes (K, M, B, T, Qa, Qi, etc.).

### Component Organization
- `ui/` — Design system primitives (reused everywhere)
- `map/` — MapLibre-specific components (used only in GameScreen)
- `leaders/` — Leader management (used only in LeadersScreen)
- Root level — Feature-specific components (modals, toasts, game features, system)
