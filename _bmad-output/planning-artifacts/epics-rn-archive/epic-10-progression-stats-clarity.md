# Epic 10: Progression & Stats Clarity

Players can see their conquest progress, continent completion on the world map, and experience celebrations when reaching milestones.

## Story 10.1: Stats and Progress Summary Screen

As a player,
I want to see a summary of my conquest progress,
So that I feel my investment in the game is meaningful.

**Acceptance Criteria:**

**Given** the player taps the stats icon in TopBarHUD
**When** the stats screen renders
**Then** it shows:
- Total Influence earned (all time)
- Total countries unlocked / 79
- Total leaders hired
- Total continents completed / 7
- Global multiplier breakdown (continent bonuses + achievement bonuses)
- Total taps
- Time played
- Current Intel balance
**And** values use `formatInfluence()` for large numbers
**And** the screen uses `GameText` and `GameCard` for consistency

## Story 10.2: Continent Progress Bar on World Map

As a player,
I want to see how close I am to completing a continent when viewing the world map,
So that I have a clear macro-goal.

**Acceptance Criteria:**

**Given** the player is in world view
**When** looking at a continent they have started
**Then** a small progress bar or fraction (e.g., "4/19") appears near the continent
**And** completed continents show a crown/star icon or checkmark
**And** locked continents show a lock icon with the unlock threshold

## Story 10.3: Sequential Modal Queue

As a player,
I want modals to appear one at a time in a logical order,
So that returning to the game feels smooth instead of overwhelming.

**Acceptance Criteria:**

**Given** multiple modals are pending (offline reward + daily reward + achievement)
**When** the player returns to the app
**Then** modals appear sequentially: Offline > Daily > Celebration > Achievement > Bonus Toast
**And** each modal waits for dismissal before the next appears
**And** transitions between modals are smooth (no flicker or stacking)

---
