# Epic 14: Simplify Map Interaction & Upgrade Consolidation

Remove long-press gesture from the map and consolidate all upgrade/unlock actions into the Upgrades tab. The map becomes a tap-only surface (collect, unlock affordable countries, claim golden bonuses). Upgrades and country unlocking are accessible from the Upgrades tab. This simplifies discoverability and prepares the map for future events and power-ups.

## Story 14.1: Remove Long-Press and Add Tap-to-Unlock on Map + Upgrades Tab Unlock Flow

As a player,
I want to upgrade countries from the Upgrades tab and unlock countries by tapping them on the map,
So that all interactions are intuitive and I don't need to discover hidden gestures.

**Acceptance Criteria:**

**Given** a country on the map is locked and the next unlockable in its continent
**When** the player taps it and has enough Influence
**Then** the country is instantly unlocked via `unlockCountry(countryId)`
**And** a celebration animation plays (flyout + haptic + sound)
**And** the country visual state updates to "unlocked"

**Given** a country on the map is locked and the next unlockable in its continent
**When** the player taps it and does NOT have enough Influence
**Then** a brief toast message appears: "Need X more Influence"
**And** no state change occurs

**Given** the Upgrades tab is open and showing a continent's countries
**When** there are locked countries that are next in the unlock order
**Then** each shows an unlock button with the cost, affordability indicator, and unlock action
**And** tapping the unlock button calls `unlockCountry(countryId)` with celebration feedback

**Given** the long-press gesture exists in WorldMapSVG and WorldMapContainer
**When** this story is complete
**Then** all long-press detection logic is removed (LONG_PRESS_MS, handleContinentPressIn duration check, onCountryLongPress callback)
**And** `FloatingUpgradeCard` and `FloatingUnlockCard` components are removed from GameScreen
**And** the `floatingCard` state in GameScreen is removed
**And** all dead imports and props related to long-press and floating cards are cleaned up

## Story 14.2: Update Tutorial for New Upgrade/Unlock Flow

As a new player,
I want the tutorial to guide me to the Upgrades tab for upgrading countries,
So that I learn the correct interaction pattern from the start.

**Acceptance Criteria:**

**Given** the tutorial currently references long-press for upgrading (step 5-7 area)
**When** the tutorial update is complete
**Then** the tutorial guides players to the Upgrades tab to purchase their first upgrade
**And** the step that referenced long-press is replaced with a step pointing to the Upgrades tab
**And** auto-advance on `purchaseUpgrade` still triggers regardless of where the purchase happens
**And** the contextual hint for milestones no longer references "Long-press to upgrade"
**And** the tutorial flow remains coherent end-to-end (12 steps, Map then Leaders)

## Story 14.3: Milestone Badge on Upgrades Tab

As a player,
I want to see a visual indicator on the Upgrades tab when a significant milestone upgrade is available,
So that I'm drawn back to upgrade my countries at the right moments.

**Acceptance Criteria:**

**Given** a country has reached a milestone threshold (e.g., IP level approaching leader hire at 10, upgrade at 50 or 100)
**When** the player can afford the upgrade to reach that milestone
**Then** a small badge or fire icon appears on the Upgrades tab in the bottom navigation bar
**And** the badge clears once the milestone upgrade is purchased or no longer applicable

**Given** no milestone upgrades are affordable
**When** the player views the bottom navigation
**Then** no badge appears on the Upgrades tab

---
