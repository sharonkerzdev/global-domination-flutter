# Epic 16: Map Screen Overhaul

Players open the game directly to a clean, intuitive map screen with continuous pan/zoom, clear currency visibility, streamlined HUD, and a complete world map — the map feels like the true home of the game.

## Story 16.1: Fix Default Tab on Cold Launch

As a player,
I want the game to always open on the Map screen when I launch it,
So that I immediately see my empire and can start playing.

**Acceptance Criteria:**

**Given** the app is cold-launched (no prior state or after force-close)
**When** the app finishes initialization and displays the main UI
**Then** the active tab is `'game'` (Map screen) regardless of which tab was active when the app was last closed
**And** no AsyncStorage or state hydration overrides the default tab to a different screen

## Story 16.2: Single Continuous Map with Auto-Zoom

As a player,
I want a single continuous pannable/zoomable map without discrete view modes,
So that I can freely explore the world without jarring transitions.

**Acceptance Criteria:**

**Given** the map screen renders
**When** the player interacts with the map
**Then** there is no `viewMode` state — no 'world' vs 'continent' view switching exists
**And** the player can freely pan across the entire world map in any direction (clamped to SVG bounds)
**And** pinch-to-zoom is capped at `MAX_SCALE = 10` (reduced from 15)
**And** `MAX_AUTO_ZOOM` is adjusted proportionally (e.g. 6-7)
**And** the back button ("←") is removed from `TopBarHUD`

**Given** the player opens the app (post-tutorial, regular session)
**When** the map screen loads
**Then** the map auto-zooms with animation to center on the player's latest unlocked country
**And** the zoom level is calculated from the country's bounding box to show it comfortably

**Given** a new player who has not unlocked any country beyond the tutorial start
**When** the map loads
**Then** the map zooms to Somalia (the tutorial starting country)

## Story 16.3: Streamline TopBarHUD

As a player,
I want a clean HUD without unused elements,
So that the map area is maximized and I'm not distracted by non-functional UI.

**Acceptance Criteria:**

**Given** the TopBarHUD renders on the map screen
**When** the player views the HUD
**Then** Row 2 (continent bar with continent name and mission pill) is completely removed
**And** the `viewMode` prop is removed from TopBarHUD (no longer needed)
**And** the `continentName` prop is removed from TopBarHUD
**And** the `onZoomOut` prop is removed from TopBarHUD
**And** the daily reward/event calendar button is hidden (removed from render, not just invisible)
**And** the `onOpenDailyReward` and `showDailyBadge` props are removed from TopBarHUD

## Story 16.4: Currency Icons and Intel in HUD

As a player,
I want to see both my Influence and Intel balances with clear icons in the HUD and everywhere currencies appear,
So that I always know my resources and can distinguish between them at a glance.

**Acceptance Criteria:**

**Given** the TopBarHUD renders
**When** the player views the HUD
**Then** Influence is displayed with a dedicated icon (e.g. globe/crown/star) + formatted amount + passive income rate
**And** Intel is displayed with a dedicated icon (e.g. eye/brain/satellite) + formatted amount
**And** the two currencies are visually distinct in icon shape and color

**Given** a `CurrencyBadge` component exists in `src/components/ui/`
**When** used anywhere in the app
**Then** it renders `[icon] [formatted amount]` for the specified currency type (`'influence'` or `'intel'`)
**And** it accepts optional props for size variant (compact for HUD, normal for cards)
**And** icons are from the vector icon library (Ionicons), not emoji

**Given** the CurrencyBadge component is created
**When** reviewing all screens where currency amounts appear
**Then** CurrencyBadge is used in: TopBarHUD, UpgradesScreen (upgrade costs, global upgrade costs), FloatingUnlockCard (country cost), FloatingUpgradeCard (upgrade cost), reward modals (offline reward, daily reward, mission rewards), achievement toasts, LeadersScreen (hire/upgrade costs)
**And** every currency amount display includes the appropriate icon

## Story 16.5: Fill Missing Countries on Map

As a player,
I want the world map to look complete with no ocean gaps where land should be,
So that the map feels like a real world and hints at future content.

**Acceptance Criteria:**

**Given** the SVG world map renders
**When** the player views any region of the map
**Then** all real-world land masses have SVG paths — no ocean visible where land should exist
**And** countries that may become playable in the future render as medium grey fill with a subtle border stroke
**And** countries that are purely decorative filler (tiny islands, Greenland, etc.) render as a dark muted fill with no border and no interaction
**And** tapping a future-playable grey country does nothing (no floating card, no error)
**And** tapping a filler country does nothing

**Given** the SVG map data is updated
**When** comparing `worldPaths.ts` paths to a complete world map reference
**Then** major missing land masses are filled (Central America, Central Africa, Southeast Asia, Balkans, etc.)
**And** existing playable country paths are not altered

## Story 16.6: Navigation Restructure — Settings to HUD, Achievements Tab

As a player,
I want all gameplay tabs in the bottom nav and Settings accessible from the HUD,
So that bottom navigation is dedicated to gameplay and settings is a quick tap away.

**Acceptance Criteria:**

**Given** the bottom navigation bar renders
**When** the player views the tabs
**Then** the tab order is: Map, Upgrades, Leaders, Achievements, Minigames
**And** the Settings tab is removed from the bottom navigation
**And** the `Tab` type is updated to include `'achievements'` and exclude `'settings'` from bottom nav routing

**Given** the TopBarHUD renders
**When** the player views the rightmost icon area
**Then** a gear icon (settings-outline) appears as the rightmost element
**And** tapping the gear icon opens the existing SettingsScreen as a modal overlay (slides up over current content)
**And** the modal has a close/dismiss button to return to the game

**Given** the Achievements tab is tapped
**When** the screen renders
**Then** a placeholder Achievements screen is shown with title "Achievements" and a message indicating content coming soon (continent progress, missions, milestones)
**And** the screen follows the app's existing design system (colors, fonts, spacing)

**Given** the Minigames tab is tapped
**When** the screen renders
**Then** the existing MinigamesPlaceholderScreen shows with "Coming Soon" messaging
**And** a brief toast notification appears saying "Coming Soon!" on tap

## Story 16.7: Update Tutorial for New Map Flow

As a new player,
I want the tutorial to work correctly with the new single-view map and navigation layout,
So that onboarding is smooth and doesn't reference removed features.

**Acceptance Criteria:**

**Given** the tutorial starts for a new player
**When** the tutorial progresses through map-related steps (steps 0-8)
**Then** no tutorial step references continent view, world view, or the back button
**And** no tutorial step references the continent bar or event button
**And** the tutorial spotlight targets still work correctly with the new TopBarHUD layout (fewer elements, no Row 2)

**Given** the tutorial reaches the tab-switching steps (steps 9-12)
**When** the tutorial navigates to the Leaders tab
**Then** the navigation works with the new tab order (Map, Upgrades, Leaders, Achievements, Minigames)
**And** the tutorial does not attempt to navigate to a Settings tab

**Given** the tutorial completes
**When** the player returns to the map
**Then** the map auto-zooms to Somalia (or their latest unlocked country) as per Story 16.2
