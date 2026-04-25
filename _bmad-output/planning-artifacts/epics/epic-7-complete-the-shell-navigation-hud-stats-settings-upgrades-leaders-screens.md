# Epic 7: Complete the Shell — Navigation, HUD, Stats, Settings, Upgrades & Leaders Screens

**Goal:** Deliver the productized app shell. 5-tab bottom navigation (Map / Upgrades / Leaders / Achievements / Minigames placeholder), global HUD, Stats screen, Settings as HUD modal, Upgrades and Leaders tab UIs, sequential modal queue.

### Story 7.1: Theme Tokens and Design System Foundation

As a developer,
I want a single `appTheme()` builder composing `ThemeData` + `ThemeExtension`s (`CountryColors`, `HudPalette`, `MilestoneColors`), Fredoka typography via `google_fonts`, and a `Spacing` constants class,
So that every widget reads colors/spacing/typography from one source.

**Acceptance Criteria:**

**Given** `lib/ui/theme/app_theme.dart` and its extensions/constants
**When** any widget references a color, spacing, or font
**Then** it uses `Theme.of(context).extension<CountryColors>()!.locked` (or similar) or `Spacing.md` — never a raw literal.

**Given** `flutter analyze`
**When** a new story introduces a hardcoded color literal in a widget
**Then** a custom_lint rule OR a code-review convention catches it (minimum: documented review criterion; custom_lint rule is a stretch goal).

**Given** `Spacing`
**When** used
**Then** it exposes `xs/sm/md/lg/xl/xxl = 4/8/16/24/32/48` as `static const` doubles.

### Story 7.2: App Scaffold with 5-Tab Bottom Navigation and `IndexedStack`

As a player,
I want five tabs across the bottom (Map / Upgrades / Leaders / Achievements / Minigames) and switching between them should not reparse the world map,
So that the app feels snappy and the map preserves pan/zoom state.

**Acceptance Criteria:**

**Given** the `AppScaffold`
**When** the app is open
**Then** a `BottomNavigationBar` shows 5 tabs with icons + labels; the scaffold uses an `IndexedStack` so each tab's widget tree stays alive across switches.

**Given** I pan/zoom on the Map tab, switch to Upgrades, then switch back
**When** the Map tab re-appears
**Then** it shows at the exact pan/zoom it was left at and the GeoJSON is NOT reparsed.

**Given** the Minigames tab
**When** I tap it
**Then** it shows a "Coming Soon" placeholder screen with a brief message.

### Story 7.3: Global HUD With Influence and Intel Currency Badges

As a player,
I want a top-bar HUD visible on all tabs showing my Influence and Intel totals with icons,
So that I always know my resources without switching screens.

**Acceptance Criteria:**

**Given** any tab is visible
**When** rendered
**Then** a top-bar HUD renders above the tab content showing: Influence badge (icon + abbreviated number), Intel badge (icon + abbreviated number), a stats icon (tap → Stats screen), a settings gear (tap → Settings modal).

**Given** Influence or Intel changes
**When** `totalInfluenceProvider` or `totalIntelProvider` emits
**Then** the HUD badge updates with the new value and an `AnimatedCounter` tweens from the old to the new value over ~400ms.

**Given** the HUD uses a reusable `CurrencyBadge` widget
**When** applied in the HUD AND in upgrade cards, reward modals, mission rows, etc.
**Then** currencies render identically everywhere — icon, color, formatting all from tokens.

### Story 7.4: Sequential Modal Queue With Priority

As a player,
I want modals (Offline Reward, Daily Reward, Continent Complete, Achievement Earned, Purchase Confirm) to appear one after another, never stacked,
So that I'm not overwhelmed by overlapping celebrations.

**Acceptance Criteria:**

**Given** multiple modal-triggering events happen in a short window (e.g. resume fires Offline Reward + Daily Reward, then an Achievement Earned)
**When** the modal queue processes them
**Then** they display in priority order Offline > Daily > Celebration (Continent) > Achievement > Purchase Confirm, each dismissing before the next is shown.

**Given** a modal is showing
**When** a new trigger fires
**Then** the new modal is enqueued and will show after the current dismisses — it never overlays.

**Given** the queue
**When** inspected
**Then** it is exposed via `modalQueueProvider` and testable with a fake dismiss stream.

### Story 7.5: Stats Screen Reachable From HUD

As a player,
I want a Stats screen showing total Influence, Intel, countries owned, continents completed, achievements earned, and active multipliers,
So that I can check my progress at a glance without guessing.

**Acceptance Criteria:**

**Given** I tap the stats icon in the HUD
**When** navigation runs
**Then** a full-screen Stats screen pushes on top of the current tab (Navigator 1.0 push).

**Given** the Stats screen
**When** rendered
**Then** it shows: Total Influence, Total Intel, Countries Owned (X / 79), Continents Completed (X / 7), Achievements Earned (X / 27), and Active Multipliers (IP sum, Leader sum, continent bonus, achievement bonus, global upgrade) broken out.

**Given** the Stats screen is open
**When** state changes (e.g. a country is collected in the background? — actually the Stats screen pauses ticker? — no, ticker continues; Stats reads reactive providers)
**Then** the stats values update reactively.

### Story 7.6: Settings Modal Overlay From HUD Gear Icon

As a player,
I want a Settings screen that opens as a modal overlay from the HUD gear,
So that I can adjust sound/haptics/notifications without leaving my current tab.

**Acceptance Criteria:**

**Given** I tap the gear icon in the HUD
**When** the tap completes
**Then** a modal bottom sheet (or full-screen modal) opens over the current tab — the bottom nav is still visible but dimmed.

**Given** the Settings modal
**When** rendered
**Then** it contains at minimum: Sound on/off, Haptics on/off, Credits link, a 5-second long-press activator for the Support (crash logs) screen from Story 1.10.

**Given** I toggle a setting
**When** I dismiss the modal
**Then** the setting persists via the Drift `settings` table and takes effect immediately.

### Story 7.7: Upgrades Tab — Unlocked Countries + Next-Unlock Teaser per Continent

As a player,
I want an Upgrades tab that lists my unlocked countries grouped by continent, plus a "Next unlock" teaser for the next locked country,
So that I can efficiently spend Influence without navigating the map.

**Acceptance Criteria:**

**Given** the Upgrades tab
**When** rendered
**Then** it shows one section per UNLOCKED continent (locked continents are not shown as sections).

**Given** each continent section
**When** rendered
**Then** it lists unlocked countries as cards with current IP level, current rate, bulk toggle (1×/10×/25×), cost for next upgrade, and a Buy button
**And** it ends with a single "Next unlock" teaser card showing the next locked country's name, cost, and an Unlock button (or an "Unlock in current continent" placeholder if next locked is in a future continent).

**Given** I use the bulk toggle
**When** I tap Buy
**Then** `PurchaseUpgrade(countryId, bulk)` dispatches and the card updates.

**Given** I tap Unlock on the teaser
**When** I have enough Influence
**Then** `UnlockCountry(countryId)` dispatches and the card transitions into a regular upgrade card.

### Story 7.8: Leaders Tab — Grouped-by-Continent Accordion

As a player,
I want a Leaders tab that groups countries by continent in expandable cards, showing leader status per country (not-eligible / hire available / hired / upgrade available / max tier),
So that I can manage automation across the whole game from one screen.

**Acceptance Criteria:**

**Given** the Leaders tab
**When** rendered
**Then** one accordion continent card appears per unlocked continent, each showing "X / Y Leaders hired" and a gold highlight if ANY hire-eligible leader is affordable.

**Given** I expand a continent card
**When** the rows render
**Then** each shows a `CountryLeaderRow` with country name, IP level, leader tier/status, and a contextual action button whose label depends on state: "Hire (cost)" / "Upgrade to tier N (cost)" / "Max tier reached" / "Reach IP 10 first" (disabled).

**Given** I tap the action button
**When** it dispatches
**Then** the appropriate command (`HireLeader` or `UpgradeLeader`) fires and the row updates on event.

**Given** a country approaches a leader threshold (IP ≥ 8 for hire, ≥ 48 for tier 2, ≥ 98 for tier 3)
**When** the row renders
**Then** it shows a subtle "approaching threshold" visual hint (gold border or similar, tokens only — full milestone glow polish is Epic 8).

### Story 7.9: Map as Default Cold-Launch Screen, Auto-Focus Post-Tutorial

As a player,
I want the app to open directly on the Map tab every cold launch, and (after tutorial is complete) zoom focused on my latest unlocked country,
So that I land on the gameplay surface, oriented on my current frontier.

**Acceptance Criteria:**

**Given** the app cold-launches
**When** `AppScaffold` initializes
**Then** the selected tab index is 0 (Map) regardless of the last tab used in the previous session.

**Given** the tutorial is completed (`state.tutorialCompleted == true`)
**When** the Map tab first renders
**Then** the view transform auto-focuses on the most-recently-unlocked country (or the first unlocked country if no unlocks yet) with zoom level approximately equal to "continent fit."

**Given** the tutorial is NOT yet completed
**When** the Map tab renders
**Then** auto-focus is suppressed and the map shows whatever pan/zoom the tutorial expects at its current step.

### Story 7.10: Continent Progression Visual Indicators

As a player,
I want each continent to visually communicate how many of its countries I own,
So that I can eyeball progress without counting.

**Acceptance Criteria:**

**Given** I'm on the Upgrades tab or Stats screen
**When** a continent is displayed
**Then** it shows "X / Y owned" and a horizontal progress bar with 25% / 50% / 75% milestone tick marks.

**Given** I hit 25/50/75% milestones
**When** the progress bar is visible in real time
**Then** the corresponding tick mark fills in with a subtle pulse animation (token-based; polish in Epic 8).

---
