# Epic 18: Map Visual Feedback & Global HUD

Players can read the state of every country at a glance through distinct color coding and animations, see their resources on every screen, and experience locked continents as mysterious unexplored territory — making the map feel alive and the progression more tangible.

## Story 18.1: Country Color State System

As a player,
I want each country on the map to have a distinct color based on its current state,
So that I can instantly tell which countries are locked, generating, ready to collect, or automated without reading any text.

**Acceptance Criteria:**

**Given** a country is locked (not yet unlocked by the player)
**When** the map renders
**Then** the country fills with the existing grey gradient (`#7A8A88` → `#A8B5B2`) unchanged

**Given** a country is unlocked, not automated, and currently generating (not ready to collect)
**When** the map renders
**Then** the country fills with a teal gradient (`#26A69A` → `#4DB6AC`) defined as `url(#grad-generating)` in SVG `<Defs>`

**Given** a country is unlocked, not automated, and ready to collect (`isReadyToCollect === true`)
**When** the map renders
**Then** the country fills with vibrant green (`#4CAF50`) — the breathing glow is handled in Story 18.2

**Given** a country is automated (has an unlocked leader)
**When** the map renders
**Then** the country fills with an electric blue gradient (`#5C7AEA` → `#7C94F4`) defined as `url(#grad-automated)` in SVG `<Defs>`

**Given** a country has an active golden opportunity
**When** the map renders
**Then** the golden color override takes priority over all other states (existing behavior preserved)

**Given** the `getCountryFill` function in `WorldMapSVG.tsx` is updated
**When** reviewing the function
**Then** the previous 3-tier green gradient system (unlocked-t1, t2, t3) is replaced with the new state-based colors
**And** a new helper `getCountryVisualState(country, leader): 'locked' | 'generating' | 'ready' | 'automated' | 'golden'` is extracted as a pure function consumed by fill, label, and animation logic
**And** new `<LinearGradient>` definitions are added to the `<Defs>` block for `grad-generating` and the updated `grad-automated`
**And** non-playable country fills (future-playable, filler) are unchanged

## Story 18.2: Ready-to-Collect Breathing Glow Animation

As a player,
I want countries that are ready to collect to gently pulse with a breathing glow,
So that I can immediately spot which countries need my attention without scanning for text.

**Acceptance Criteria:**

**Given** one or more countries are in the "ready to collect" state (unlocked, not automated, `isReadyToCollect === true`)
**When** the map renders
**Then** those countries display a breathing opacity animation cycling between 0.6 and 1.0 over ~1.5 seconds with ease-in-out timing, repeating infinitely

**Given** the breathing animation is implemented
**When** reviewing the animation architecture
**Then** a single shared `useSharedValue` from `react-native-reanimated` drives the pulse for ALL ready-to-collect countries (not one value per country)
**And** the animation uses `withRepeat(withTiming(...))` running on the UI thread via worklets
**And** the pulse is applied as an animated opacity on the country path, not as a fill color change

**Given** a country transitions from "ready" to "generating" (player collects)
**When** the collection happens
**Then** the breathing animation stops for that country and it smoothly transitions to the teal generating fill
**And** no animation artifacts remain (no stuck opacity values)

**Given** 15+ countries are simultaneously in "ready to collect" state
**When** all are pulsing
**Then** frame rate remains at 60fps on mid-range devices because all share one animated value

## Story 18.3: Remove In-Country Text and Add Floating Rate Labels

As a player,
I want to see how much each country generates per second as a readable label above the country,
So that I can compare country performance and know where to focus my upgrades.

**Acceptance Criteria:**

**Given** the map renders any unlocked country
**When** reviewing the SVG overlay
**Then** ALL in-country text is removed: the "AUTO" label, the level indicator ("L#"), and the inline rate text (`X.X/s`) that was previously rendered inside country SVG paths
**And** continent progress overlays (count/total, checkmark, lock+threshold) are preserved unchanged

**Given** an unlocked automated country is visible on the map
**When** the player is zoomed to continent level or closer
**Then** a floating badge appears above the country center showing the generation rate (e.g., "2.3K/s") with an influence icon
**And** the badge has a semi-transparent dark pill background (`rgba(0,0,0,0.6)`, rounded corners) for contrast against any map color
**And** the text is white, bold, and sized for readability (~fontSize 5-6 in SVG coordinates)

**Given** an unlocked manual country is in "ready to collect" state
**When** the player views it at continent zoom or closer
**Then** instead of a rate label, a bouncing influence coin icon appears above the country center
**And** the bounce animation is a gentle vertical oscillation (translateY ±2px, ~1s loop) using Reanimated

**Given** an unlocked manual country is in "generating" (not ready) state
**When** the player views it at continent zoom
**Then** the rate label shows the generation rate same as automated countries, but with teal-tinted text to match the teal country color

**Given** the player is at world zoom level (zoomed out to see all continents)
**When** reviewing the map
**Then** floating rate labels are hidden to avoid visual clutter — only shown when zoomed to continent level or closer
**And** the zoom threshold for showing/hiding labels is derived from the current scale value in `WorldMapContainer`

## Story 18.4: Enlarge HUD Currency Display

As a player,
I want the Influence and Intel numbers in the HUD to be large and easy to read,
So that I always know my resource balances at a glance without squinting.

**Acceptance Criteria:**

**Given** the `TopBarHUD` renders on any screen
**When** the player views the currency display
**Then** the Influence amount is displayed at 18-20px font size (up from the current ~14px)
**And** the Intel amount is displayed at 18-20px font size
**And** the passive income rate ("+X.X/s") is displayed at 12px+ font size (up from ~10px)
**And** all text uses the existing `GameText` component and `Fredoka` font family

**Given** the HUD layout is updated
**When** reviewing the visual hierarchy
**Then** currency values remain center-aligned in the HUD
**And** the influence icon and intel icon sizes are proportionally scaled with the larger text
**And** the HUD does not overflow or clip on narrow devices (minimum 320px width)
**And** the animated scale effect on influence change (1.0→1.08→1.0) continues to work correctly with the larger text

## Story 18.5: Global HUD Across All Tabs

As a player,
I want to see my Influence and Intel balances on every screen in the app,
So that I can make informed purchase decisions on the Upgrades and Leaders tabs without switching back to the map.

**Acceptance Criteria:**

**Given** the app renders any tab (Map, Upgrades, Leaders, Achievements, Minigames)
**When** the player views the top of the screen
**Then** the full `TopBarHUD` is visible showing: Influence (icon + amount + rate), Intel (icon + amount), stats icon, and settings gear icon

**Given** the `TopBarHUD` is currently rendered inside `GameScreen.tsx` (lines 562-567)
**When** the refactor is complete
**Then** `TopBarHUD` is rendered in `App.tsx` above the tab content switch block (lines 320-331)
**And** the `hudHeight` state is lifted from `GameScreen` to `App.tsx`
**And** `hudHeight` is passed down to `GameScreen` as a prop (for content offset calculations like bonus toast positioning)
**And** other screens (UpgradesScreen, LeadersScreen, etc.) receive `hudHeight` as a prop or via context to offset their content below the HUD

**Given** the HUD renders on a non-map tab (e.g., Upgrades)
**When** the player taps the settings gear icon
**Then** the settings modal opens correctly regardless of which tab is active

**Given** the HUD renders on a non-map tab
**When** the player taps the stats icon
**Then** the stats screen opens correctly regardless of which tab is active

**Given** the TopBarHUD is moved to App.tsx
**When** reviewing the component
**Then** all existing HUD functionality works: influence animation, rate display, settings modal, stats navigation
**And** no duplicate HUD renders on the map tab (GameScreen no longer renders its own TopBarHUD)

## Story 18.6: Cloud Fog of War on Locked Continents

As a player,
I want locked continents to be covered with drifting clouds that hint at the land beneath,
So that unexplored territory feels mysterious and aspirational, motivating me to unlock new continents.

**Acceptance Criteria:**

**Given** a continent is locked (player has not reached its Influence threshold)
**When** the map renders that continent's region
**Then** a semi-transparent cloud overlay appears above the continent's countries
**And** the clouds are wispy/light enough that the land shapes beneath are partially visible (opacity ~0.4-0.6)
**And** the clouds drift horizontally with a subtle `translateX` animation (slow, ~30-60 seconds per full cycle) creating a living, atmospheric effect

**Given** the cloud overlay is implemented
**When** reviewing the component architecture
**Then** a new `CloudOverlay` component renders cloud PNG textures positioned over continent bounding boxes (from `CONTINENT_BBOXES`)
**And** the cloud images are positioned as `<Image>` elements within the SVG or as absolute-positioned `Animated.View` layers above the SVG
**And** `pointerEvents` is set to `'none'` on all cloud elements so taps pass through to countries underneath
**And** the `translateX` animation uses Reanimated with hardware-accelerated transforms (no layout-triggering properties)

**Given** a continent becomes unlocked (player reaches the Influence threshold)
**When** the unlock happens
**Then** the cloud overlay for that continent fades out with a dissolve animation (~1 second)
**And** the underlying countries are revealed with their correct state colors

**Given** the player pans to a locked continent
**When** interacting with the map
**Then** panning and zooming work normally — the player can freely explore locked continents
**And** tapping on locked countries beneath the clouds still shows the locked state (existing behavior)
**And** no pan restriction is applied to locked continents (FR-54)

**Given** multiple continents are locked
**When** the map renders
**Then** only continents currently within or near the viewport render their cloud overlays (lazy-mount for performance)
**And** cloud overlays for off-screen continents are not rendered
