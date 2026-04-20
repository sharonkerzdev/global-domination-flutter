# Epic 6: Leaders Strategy Tab

Players manage their empire through a dedicated Leaders tab where they can browse continents, see available leaders, hire leaders to automate countries, and upgrade leaders for higher multipliers.

## Story 6.1: Create ContinentCard Component

As a player,
I want to see my continents organized as expandable cards,
So that I can browse my empire's leader status by region.

**Acceptance Criteria:**

**Given** the Leaders tab is active
**When** continents have at least one unlocked country
**Then** a ContinentCard renders for each qualifying continent, sorted by unlock order
**And** each card shows: continent name, chevron icon (rotates on expand), and leader count badge "{hired}/{total unlockable}"
**And** tapping a card expands it (accordion — only one expanded at a time, previous collapses)
**And** a continent card shows a gold highlight glow when any leader hire is affordable
**And** continents with zero unlocked countries are hidden

## Story 6.2: Create CountryLeaderRow Component

As a player,
I want to see each country's leader status with clear actions,
So that I know exactly what I can do to automate my empire.

**Acceptance Criteria:**

**Given** a ContinentCard is expanded
**When** it shows country leader rows
**Then** each row displays: country name, leader name (if hired, dimmed), leader level badge (Lv 1/2/3 if hired)
**And** the action button shows contextually:
- IP < 10, leader not hired: GameButton gray disabled, "IP Lv 10 required"
- IP >= 10, leader not hired, affordable: GameButton green sm, cost display, glow border
- IP >= 10, leader not hired, not affordable: GameButton green sm, cost display, no glow
- Leader hired, upgrade available (IP >= 50 or 100): GameButton blue sm, "Upgrade Lv{next}", cost
- Leader hired, max level (3): Badge "MAX" with automated indicator
**And** hired leaders show multiplier text (e.g., "x1.5 automation")
**And** all costs use `formatInfluence()`

## Story 6.3: Create LeadersScreen

As a player,
I want a dedicated Leaders screen to manage all my leaders in one place,
So that the strategy layer of the game is easy to discover and use.

**Acceptance Criteria:**

**Given** the player switches to the Leaders tab
**When** the screen renders
**Then** a ScrollView shows ContinentCard components for all qualifying continents
**And** the screen has a GameText header "Leaders" at the top
**And** tapping Hire calls `purchaseLeader(countryId)` and triggers LeaderHireCelebration
**And** tapping Upgrade calls `upgradeLeader(countryId)` and updates the row
**And** if no continents have unlocked countries, an empty state message shows: "Unlock your first country to see leaders here"

## Story 6.4: Remove Leader UI from UpgradesScreen

As a developer,
I want leader hire/upgrade actions removed from UpgradesScreen,
So that leader management lives exclusively in the Leaders tab.

**Acceptance Criteria:**

**Given** UpgradesScreen currently shows leader hire/upgrade within CountryCard rendering
**When** the removal is complete
**Then** the "Manager" card section showing hire/upgrade leader buttons is removed from UpgradesScreen
**And** all country upgrade (influence power) functionality remains intact
**And** global upgrades and continent upgrades tabs remain intact

---
