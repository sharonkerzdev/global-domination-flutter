# Epic 1: Core Stability & Crash Prevention

Fix crash-level bugs and add basic resilience so the app does not white-screen or throw runtime errors during normal gameplay.

## Story 1.1: Add Missing Theme Colors

As a player,
I want the world map to render without errors,
So that I can see country states (golden, unlockable) correctly.

**Acceptance Criteria:**

**Given** `WorldMapSVG.tsx` references `colors.golden` and `colors.unlockableGlow`
**When** rendering any country in golden or unlockable state
**Then** the colors resolve to valid values from `src/styles/theme.ts`
**And** no `TypeError` or undefined color is produced

## Story 1.2: Fix LeaderCard Null Safety

As a developer,
I want LeaderCard to handle missing country data gracefully,
So that invalid `countryId` values do not crash the app.

**Acceptance Criteria:**

**Given** `LeaderCard` receives a `countryId` that does not exist in the store
**When** the component renders
**Then** it returns null or a fallback UI instead of throwing a TypeError
**And** `country.leaderId` and `country.continentId` are only accessed after a null check

## Story 1.3: Add React Error Boundary

As a player,
I want the app to show a recovery screen instead of a blank white screen when something goes wrong,
So that I can restart or get feedback without force-closing the app.

**Acceptance Criteria:**

**Given** any component tree throws an unhandled rendering error
**When** the error propagates upward
**Then** an `ErrorBoundary` component catches it and displays a user-friendly "Something went wrong" screen
**And** the screen offers a "Restart" button that reloads the app

## Story 1.4: Fix App Initialization Error Handling

As a player,
I want to see meaningful feedback if the game fails to load,
So that I know what happened and can take action (retry, reset).

**Acceptance Criteria:**

**Given** `initializeGame()` throws an error during app startup
**When** the splash screen is dismissed
**Then** the app shows an error state with a "Retry" or "Reset Save" option
**And** the app does not render a broken game state

---
