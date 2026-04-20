# Epic 4: Navigation & Screen Architecture

Players navigate the game through a persistent 5-tab bottom navigation bar. The app structure is reorganized to support Map, Leaders, Minigames, Upgrades, and Settings tabs with Stats accessible from the HUD.

## Story 4.1: Create Bottom Navigation Bar

As a player,
I want a persistent navigation bar at the bottom of the screen,
So that I can easily switch between game sections without hunting for hidden buttons.

**Acceptance Criteria:**

**Given** the app is loaded and any screen is visible
**When** the player looks at the bottom of the screen
**Then** a navigation bar with 5 tabs (Map, Leaders, Minigames, Upgrades, Settings) is always visible
**And** each tab has an Ionicons icon and a label using GameText small variant
**And** the active tab shows `colors.primary` icon and label; inactive tabs show `colors.textDim`
**And** tapping a tab switches the screen and fires light haptic feedback
**And** the nav bar height is 56px plus SafeArea bottom inset
**And** the nav bar renders at z-index 110 (above HUD, below notifications/modals)

## Story 4.2: Update Tab Type and App.tsx Routing

As a player,
I want the app to support the new tab structure,
So that all five screens are accessible and render correctly.

**Acceptance Criteria:**

**Given** the Tab type currently includes `'game' | 'upgrades' | 'settings' | 'stats'`
**When** the update is complete
**Then** the Tab type is `'game' | 'leaders' | 'minigames' | 'upgrades' | 'settings'`
**And** `App.tsx` renders the BottomNavBar below all screens (always visible)
**And** `App.tsx` conditionally renders the correct screen for each tab
**And** `LeadersScreen` and `MinigamesPlaceholderScreen` are wired into the routing

## Story 4.3: Create Minigames Placeholder Screen

As a player,
I want to see a "Coming Soon" screen when I tap the Minigames tab,
So that I know this feature is planned but not yet available.

**Acceptance Criteria:**

**Given** the player is on any tab
**When** they tap the Minigames tab in the bottom nav
**Then** a screen renders with GameText header "Minigames" and body "Coming Soon" centered
**And** the background uses `colors.background`

## Story 4.4: Clean Up Screen Headers and Navigation Callbacks

As a developer,
I want obsolete navigation props and header close buttons removed from screens,
So that navigation is handled exclusively by the bottom nav bar.

**Acceptance Criteria:**

**Given** UpgradesScreen and SettingsScreen have `onClose` back-arrow headers
**When** cleanup is complete
**Then** `onClose` back-arrow headers are removed from UpgradesScreen and SettingsScreen
**And** `onOpenSettings`, `onOpenUpgrades`, `onOpenStats` callbacks are removed from GameScreen props
**And** TopBarHUD removes settings and upgrades icon buttons (moved to bottom nav)
**And** TopBarHUD keeps: back arrow, influence display, zoom buttons, daily reward button, stats button

## Story 4.5: Wire Stats Screen as TopBarHUD Overlay

As a player,
I want to access my stats from the HUD stats icon,
So that I can check my progress without it taking a permanent tab slot.

**Acceptance Criteria:**

**Given** the player is on the Map tab
**When** they tap the stats icon in TopBarHUD
**Then** the StatsScreen renders as a full-screen overlay above the current tab (z-index 150)
**And** the StatsScreen has a close button that dismisses the overlay
**And** the Stats tab is not present in the bottom navigation bar

---
