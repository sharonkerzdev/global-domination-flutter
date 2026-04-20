# Epic 15: Map View Visual & Audio Upgrade

Transform the map from a functional prototype to a polished game experience with crisp high-fidelity paths, visual depth through gradients and glow, satisfying unlock animations, and expanded sound effects — all within Expo Go constraints using react-native-svg and Reanimated.

## Story 15.1: Higher-Fidelity SVG Paths and Zoom Upgrade

As a player,
I want the map to look crisp and detailed when I zoom in,
So that exploring countries at close range feels like a quality experience.

**Acceptance Criteria:**

**Given** the current `assets/worldtest.svg` uses low-resolution Natural Earth 1:110m data (~152KB)
**When** the upgrade is complete
**Then** `assets/worldtest.svg` is replaced with a Natural Earth 1:50m pre-projected SVG source
**And** `scripts/extract-svg-paths.js` is updated to:
- Parse the new SVG format (Natural Earth attribute naming)
- Apply a minimum-area filter to drop tiny island fragments (light simplification: keep 3-5 main islands per archipelago country like JP, PH, ID, MY)
- Merge multi-path countries (existing logic preserved)
- Pre-compute per-country bounding boxes and emit them in the generated output
**And** `src/data/worldPaths.ts` is regenerated with higher-resolution path data via `npm run extract-svg`
**And** `src/data/countryBBoxes.ts` is updated to import pre-computed bboxes from the generated file instead of runtime path parsing
**And** all 79 countries in `KEEP_IDS` still render correctly with existing `countryMapping.ts` ISO-2 mappings
**And** `MAX_SCALE` is raised from 10 to 15 in `WorldMapContainer.tsx`
**And** a new `MAX_AUTO_ZOOM = 8` constant is added and used in `computeZoomForBBox` to cap animated zoom (continent/tutorial focus) while allowing manual pinch to 15
**And** country borders appear crisp at 15x zoom with no visible jaggedness
**And** all existing tests pass (zoom, pan, focus-on-country, rate overlay)
**And** `CONTINENT_BBOXES` recompute correctly from the new bbox data

## Story 15.2: Gradient Fills and Ocean Visual Depth

As a player,
I want the map to have visual depth with gradient fills and a rich ocean background,
So that the game looks polished and alive rather than flat.

**Acceptance Criteria:**

**Given** all countries currently use flat solid-color fills
**When** the visual upgrade is complete
**Then** SVG `<Defs>` with `<LinearGradient>` definitions are added for each country state:
- **Locked countries:** dark grey → lighter grey gradient (top-left to bottom-right), subtle depth while reading as "inactive"
- **Unlocked countries:** rich green gradient, darker at edges → brighter at center, feels alive
- **Automated countries:** green-to-gold gradient, visually distinct from just-unlocked, signals "working for you"
- **Upgrade level scaling:** gradient intensity increases with level (L1 soft, L5 vibrant, L10+ subtle inner glow via additional lighter center)
**And** country glow borders are refined with softer outer stroke layers and theme-consistent colors
**And** an ocean background `<Rect>` with `<LinearGradient>` (deep blue top → lighter blue bottom) renders behind all map paths in `WorldMapSVG.tsx`
**And** the bright/playful color direction is consistent with the existing palette (greens, golds, blues)
**And** all existing country state differentiation remains clear (locked, unlockable, generating, ready, automated)
**And** performance is not degraded — gradient definitions are shared via `<Defs>`, not duplicated per path

## Story 15.3: Country Unlock Animation

As a player,
I want to see a satisfying visual animation when I unlock a country,
So that the core unlock moment delivers a dopamine hit.

**Acceptance Criteria:**

**Given** a player unlocks a country (via map tap or Upgrades tab)
**When** the unlock is the **first country in a continent** (continent had zero unlocked countries before)
**Then** a **radial color ripple animation** plays: center starts white, color expands outward filling the country shape over 500ms
**And** the animation uses Reanimated `withSequence` + animated fill properties on the country path

**Given** a player unlocks a country that is **not the first in its continent**
**When** the unlock succeeds
**Then** a **white flash → target color fill** animation plays over 300ms
**And** the animation uses Reanimated `withSequence(withTiming(white, 100ms), withTiming(targetColor, 200ms))`

**Given** any country unlock animation plays
**When** the animation completes
**Then** the country renders with its normal gradient fill (from Story 15.2)
**And** the unlock sound effect plays (existing `unlock` sound in `soundSystem.ts`)
**And** haptic feedback fires (existing Heavy impact)
**And** a "first unlock in continent" boolean is derived from checking `continent.countryIds` unlock status before the action

**Given** the player is in world view (not zoomed into a continent)
**When** a country is unlocked
**Then** the animation still plays but at reduced visual prominence (shorter duration, no ripple — just flash)

## Story 15.4: Expanded Sound Effects

As a player,
I want additional sound effects for map interactions,
So that the game feels immersive and responsive across all actions.

**Acceptance Criteria:**

**Given** the existing `soundSystem.ts` supports 5 effects: `collect`, `golden`, `milestone`, `unlock`, `upgrade`
**When** the expansion is complete
**Then** 3 new sound effects are added to the `SoundEffect` type and `ASSET_MAP`:
- `continent_complete`: triumphant fanfare (1-2 seconds), plays when all countries in a continent are unlocked
- `zoom`: subtle whoosh, plays on animated zoom transitions (continent focus, tutorial focus)
- `auto_tick`: gentle coin clink, plays at low volume when automated countries collect (throttled to max 1 play per 2 seconds to avoid spam)
**And** corresponding `.mp3` files are sourced (CC0/free license from freesound.org or mixkit.co) and placed in `assets/sounds/`
**And** `soundSystem.ts` is updated to include the new effects in `initPlayers()` and the `SoundEffect` type
**And** `continent_complete` sound is triggered in `gameStore.ts` when `checkContinentCompletion` fires
**And** `zoom` sound is triggered in `WorldMapContainer.tsx` during animated zoom transitions (continent zoom, `focusOnCountry`)
**And** `auto_tick` sound is triggered in the game loop tick when automated countries collect, with a 2-second cooldown
**And** all sounds respect the existing `soundEnabled` setting
**And** existing 5 sounds continue to work unchanged

---
