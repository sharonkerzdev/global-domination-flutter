# Epic 5: Direct Map Interaction

Players interact with countries directly on the map through taps and long-presses. Floating cards replace the bottom sheet for unlock and upgrade actions. Pan and zoom enable map exploration.

## Story 5.1: Tap-to-Collect on Map

As a player,
I want to tap a country on the map and immediately collect Influence,
So that the core loop is fast and satisfying without opening any panel.

**Acceptance Criteria:**

**Given** a country is unlocked and its generation timer is complete (`isReadyToCollect === true`)
**When** the player taps the country on the map
**Then** Influence is collected immediately via `collect(countryId)`
**And** a floating number flyout (+X) animates upward from the country
**And** haptic feedback fires (light impact)
**And** the country's visual state resets to "generating"

**Given** a golden opportunity is active on a country
**When** the player taps the golden-glowing country
**Then** the golden bonus is claimed via `claimGolden(countryId)`
**And** a golden-colored TapFlyout appears with the bonus amount

## Story 5.2: Create FloatingUnlockCard

As a player,
I want to see a compact unlock card when I tap a locked country,
So that I can unlock it directly from the map without navigating away.

**Acceptance Criteria:**

**Given** a locked country in continent view
**When** the player taps it
**Then** a floating card slides up from the bottom (200ms animation) showing:
- Country name (GameText title)
- Cost display with ProgressBar showing affordability percentage
- Unlock button (GameButton green, sm size, affordant when can afford)
**And** the card renders at z-index 80, positioned above the bottom nav
**And** after successful unlock, the card auto-dismisses with 300ms delay

**Given** a floating card is visible
**When** the player taps a different country or an empty area
**Then** the current card dismisses with a slide-down animation (150ms)

## Story 5.3: Create FloatingUpgradeCard

As a player,
I want to see upgrade options when I long-press an unlocked country,
So that I can invest in countries directly from the map.

**Acceptance Criteria:**

**Given** an unlocked non-automated country in continent view
**When** the player long-presses it
**Then** a floating card slides up showing:
- Country name (GameText title) + current IP level (Badge)
- Buy amount toggle pills: x1 / x10 / x25 / Next Milestone
- Cost display + Buy button (GameButton green, sm, shows "+{delta}/tap" subtitle)
**And** the "Next Milestone" option calculates upgrades needed to reach the next leader threshold (IP 10, 50, or 100)
**And** on successful purchase, a flyout animates and the badge flashes

**Given** a floating upgrade card is visible
**When** the player taps Buy
**Then** `purchaseUpgrade(countryId, amount)` is called
**And** the card updates with new cost and level without dismissing

## Story 5.4: Replace Bottom Sheet with Floating Cards in GameScreen

As a developer,
I want GameScreen to use floating cards instead of CountryBottomSheet,
So that all country interactions happen directly on the map.

**Acceptance Criteria:**

**Given** GameScreen currently renders CountryBottomSheet
**When** the replacement is complete
**Then** `selectedCountryId` state and CountryBottomSheet render are removed
**And** a new `floatingCard: { type: 'unlock' | 'upgrade', countryId: string } | null` state manages which card is shown
**And** country tap routes to: collect (if ready), claimGolden (if golden), show FloatingUnlockCard (if locked), dismiss (if non-actionable)
**And** country long-press routes to: show FloatingUpgradeCard (if unlocked)
**And** only one floating card is visible at a time

## Story 5.5: Delete CountryBottomSheet and Audit Dependencies

As a developer,
I want CountryBottomSheet removed from the codebase,
So that there are no remnants of the old interaction pattern.

**Acceptance Criteria:**

**Given** floating cards fully replace the bottom sheet
**When** deletion is complete
**Then** `src/components/map/CountryBottomSheet.tsx` is deleted
**And** all imports of CountryBottomSheet are removed
**And** if no other code imports `@gorhom/bottom-sheet`, the dependency is uninstalled
**And** no references to CountryBottomSheet exist anywhere in the codebase

## Story 5.6: Pan and Zoom Map Navigation

As a player,
I want to drag to pan and pinch to zoom the world map,
So that I can explore all countries and continents.

**Acceptance Criteria:**

**Given** the map is displayed (world or continent view)
**When** the player drags with one finger
**Then** the map pans in the drag direction, bounded so it cannot drift infinitely

**Given** the map is displayed
**When** the player pinches with two fingers
**Then** the map zooms in/out centered on the pinch point
**And** zoom is clamped between MIN_SCALE (1) and MAX_SCALE (6)

**Given** the HUD has zoom buttons
**When** the player taps zoom-in or zoom-out
**Then** the map zooms accordingly
**And** `getScreenPositionRef` accounts for user-driven transforms for TapFlyout positioning

---
