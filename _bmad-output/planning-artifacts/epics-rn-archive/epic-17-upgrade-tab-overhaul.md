# Epic 17: Upgrade Tab Overhaul

The Upgrade tab is streamlined for clarity and progression feel — only relevant content is shown, purchase feedback is instant, and country cards reflect meaningful milestones instead of tap timers.

## Story 17.1: Filter Continent Tabs and Remove Global Tab

As a player,
I want to only see continent tabs for continents I can actually access, and not see a Global tab,
So that the Upgrade screen is focused on what I can act on right now.

**Acceptance Criteria:**

**Given** the Upgrades screen renders the tab bar
**When** the player views the available tabs
**Then** only continents the player has access to (per `canAccessContinent()`) appear as tabs
**And** the "Global" tab is completely removed from the tab list
**And** the `GlobalUpgradeCard` component and all global-upgrade rendering logic in `UpgradesScreen` are removed
**And** global upgrade state in the store is NOT deleted (preserved for future re-homing)
**And** the default active tab is the first accessible continent (e.g. Africa for a new player)

**Given** the player unlocks access to a new continent (e.g. Europe)
**When** returning to the Upgrades screen
**Then** the new continent tab appears in the tab bar in the correct geographic order

## Story 17.2: Show Only Unlocked Countries Plus Next Unlock Teaser

As a player,
I want to see only the countries I've already unlocked plus the next one I can unlock,
So that the country list is short, focused, and motivating rather than overwhelming.

**Acceptance Criteria:**

**Given** a continent tab is active on the Upgrades screen
**When** the country list renders
**Then** all unlocked countries in that continent are shown (with their upgrade/tap cards)
**And** exactly one locked country is shown below them — the next country in unlock order
**And** the locked country shows its name, a lock icon, and the unlock cost with a CurrencyBadge
**And** all remaining locked countries beyond the next one are hidden
**And** if all countries in the continent are unlocked, no locked teaser is shown

## Story 17.3: Progress Bar Shows Milestone Progress Instead of Tap Timer

As a player,
I want the progress bar on each country card to show how close I am to the next meaningful upgrade milestone,
So that I can see my strategic progress at a glance.

**Acceptance Criteria:**

**Given** a country card renders for an unlocked country
**When** the player views the progress bar
**Then** the bar shows progress toward the next milestone level, not the tap/generation timer
**And** milestones are: Level 10 (unlock leader), Level 50 (leader Lv2), Level 100 (leader Lv3), Level 200 (max level)
**And** a small label below or beside the bar indicates what the next milestone is (e.g. "Next: Unlock Leader (Lv 10)")
**And** progress is calculated as `(currentLevel - previousMilestone) / (nextMilestone - previousMilestone)`

**Given** a country is at level 100 or above (all leader milestones achieved)
**When** the progress bar renders
**Then** the bar shows progress toward max level 200
**And** the label reads "Next: Max Level (Lv 200)" or similar

**Given** a country is at max level (200)
**When** the progress bar renders
**Then** the bar is full (100%) and the label reads "MAX"

## Story 17.4: Fix Tap-to-Collect on Country Cards and Border States

As a player,
I want tapping a country card on the Upgrades screen to collect influence when ready, and I want visual borders that tell me each country's state,
So that I can collect from the Upgrades screen and instantly see which countries need attention.

**Acceptance Criteria:**

**Given** a country card is tapped on the Upgrades screen
**When** the country's `isReadyToCollect` is true
**Then** influence is collected and a new generation cycle starts immediately
**And** the card state updates to reflect generation in progress

**Given** a country card is tapped
**When** the country is mid-generation (not ready to collect)
**Then** nothing happens (tap is ignored, cycle continues)

**Given** a country card is tapped
**When** the country is automated (has leader)
**Then** nothing happens (tap is ignored, auto-income continues)

**Given** country cards render on the Upgrades screen
**When** the player views border styling
**Then** countries that are `isReadyToCollect` (and not automated) have a green border (3px, `colors.primary`)
**And** automated countries have a blue border (3px, `colors.accentBlue`)
**And** countries mid-generation have no special border (default card border)

## Story 17.5: Remove "Done" Button Flash After Purchase

As a player,
I want upgrade purchases to apply instantly without the button changing to "Done",
So that rapid-fire upgrading feels smooth and responsive.

**Acceptance Criteria:**

**Given** the player purchases any upgrade (country influence power, continent upgrade, or global upgrade)
**When** the purchase succeeds
**Then** the button remains showing its normal label ("BUY", "BUY x1", "x1", "x10") at all times
**And** the badge scale animation (1.0 -> 1.2 -> 1.0) and green flash effect still play as purchase feedback
**And** no "Done" text is shown on any button anywhere in the app after a purchase

**Given** the code is reviewed
**When** checking all upgrade card components
**Then** `showDone`, `showBuyDone`, `showDone1`, `showDone10` state variables and their associated timeout refs are removed from: `GlobalUpgradeCard`, `ContinentUpgradeCard`, and `CountryCard`

## Story 17.6: Gate Continent Upgrade Behind Country Count

As a player,
I want the continent-wide upgrade (e.g. "Africa Development") to appear only after I've unlocked several countries,
So that I learn individual country upgrades first and the continent upgrade feels like a meaningful mid-game strategic choice.

**Acceptance Criteria:**

**Given** a continent tab is active on the Upgrades screen
**When** the player has fewer than 3 unlocked countries in that continent
**Then** the continent upgrade card (e.g. "Africa Development") is not shown at all (hidden, no teaser)

**Given** the player unlocks a 3rd country in a continent
**When** returning to that continent's tab on the Upgrades screen
**Then** the continent upgrade card appears for the first time
**And** the cost is appropriately scaled (increase baseCostMultiplier by ~5x from current values)

**Given** the continent upgrade is visible and the player can afford it
**When** the player purchases the upgrade
**Then** the upgrade applies its bonus to all countries in that continent as before

---
