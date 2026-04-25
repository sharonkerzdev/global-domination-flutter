# Epic 2: Playable Map — Tap a Country, Earn Influence

**Goal:** Deliver the minimum playable vertical slice — a custom-rendered world map with unlocked countries that generate Influence on a timer, pan/zoom controls, and tap-to-collect wired end-to-end through `GameCommand` → `GameWorld` → event → UI update.

### Story 2.1: GeoJSON Parser and `CountryPath` Cache

As a developer,
I want `assets/geo/countries.geojson.json` parsed once at boot into a `List<CountryPath>` with precomputed bounding boxes and cached `Path` objects,
So that the map painter and hit-tester operate on ready-to-use data without reparsing on every frame.

**Acceptance Criteria:**

**Given** `assets/geo/countries.geojson.json` exists
**When** the parser loads it at boot
**Then** it produces a `List<CountryPath>` with 79 entries, each containing the `CountryId`, continent, GeoJSON rings projected to `[0,1]²` equirectangular, bbox, and a built `Path`.

**Given** a `geoProvider` as a `FutureProvider<List<CountryPath>>`
**When** multiple widgets watch it
**Then** they share the same parsed result — parsing happens exactly once per app lifetime.

**Given** a `CountryPath`
**When** its bbox is read
**Then** the bbox exactly encloses all ring vertices (unit-tested on a sample country).

### Story 2.2: `WorldMapPainter` Renders Ocean + Country Fills + Borders

As a player,
I want to see a world map with distinct colors for ocean and countries,
So that I can visually orient myself on the globe before interacting.

**Acceptance Criteria:**

**Given** the map screen loads
**When** the `CustomPainter` runs
**Then** it paints, in this order: ocean background → continent background fills → country state-colored fills → country borders.

**Given** a country's state is `locked` / `unlocked` / `ready-to-collect` / `automated`
**When** it is painted
**Then** its fill color comes from the `CountryColors` `ThemeExtension`, not hardcoded literals.

**Given** `shouldRepaint(oldDelegate)` is called
**When** only the view transform has changed (pan/zoom)
**Then** it returns `true` (so pan/zoom re-paints), and country fills are not recomputed from scratch.

**Given** `shouldRepaint` is called
**When** neither the view transform nor any country state has changed
**Then** it returns `false`.

### Story 2.3: Pan and Zoom With `Matrix4` View Transform

As a player,
I want to drag to pan and pinch to zoom the world map,
So that I can explore the globe and focus on the region I care about.

**Acceptance Criteria:**

**Given** the map screen is visible
**When** I drag with one finger
**Then** the map translates in the direction of the drag with no noticeable lag.

**Given** the map screen
**When** I pinch with two fingers
**Then** the map zooms smoothly around the pinch midpoint.

**Given** zoom limits defined in the painter / gesture handler
**When** I try to zoom beyond the maximum scale (initial default 10×, confirm against spike output) or below the minimum (fit-to-screen)
**Then** zoom clamps at the limits.

**Given** a pan or zoom gesture
**When** it completes
**Then** the painter repaints exactly once at the final transform — no redundant frames.

### Story 2.4: Point-in-Polygon Hit Testing on Tap

As a player,
I want to tap a specific country and have the app register that exact country,
So that I can collect Influence from the country I intended.

**Acceptance Criteria:**

**Given** the map is at any pan/zoom
**When** I tap inside a country's polygon
**Then** the hit-tester inverse-transforms the tap point, runs bbox reject per country, then point-in-polygon ray-casting, and returns that `CountryId`.

**Given** I tap on ocean (outside all polygons)
**When** the hit-tester runs
**Then** it returns `null` and no command fires.

**Given** overlapping or adjacent countries
**When** I tap on the boundary
**Then** the hit-tester returns the first match in `CountryPath` list order (stable) — unit-tested for consistency.

**Given** a tap
**When** hit-test succeeds
**Then** the gesture handler dispatches `ref.read(gameWorldProvider.notifier).apply(TapCountry(id))`.

### Story 2.5: `GameWorld` Tick Drives Influence Generation per Country

As a player,
I want each owned country to accumulate Influence over time based on its tier's generation seconds,
So that sitting with the map open produces ready-to-collect countries without tapping.

**Acceptance Criteria:**

**Given** a `GameLoop` widget owns the single `Ticker`
**When** the app is foreground and the loop runs
**Then** each frame calls `gameWorld.tick(elapsed)` with real wall-clock delta, clamped to `Duration(milliseconds: 100)` to avoid tab-switch spikes.

**Given** a country with `generationSeconds = 1`, `baseInfluence = Decimal.parse('1')`, and no upgrades
**When** 1 second of ticks elapses
**Then** the country's banked influence increases by `1.0 ±` floating tolerance — verified via unit test with an injected `FakeClock`.

**Given** the app transitions to `AppLifecycleState.paused` or `inactive`
**When** the lifecycle observer fires
**Then** the ticker stops and no further `tick` calls happen.

**Given** the app returns to `resumed`
**When** the lifecycle observer fires
**Then** the ticker restarts (offline catch-up is handled in Epic 6 — this story only requires the ticker to resume, not apply offline gains).

### Story 2.6: Tap-to-Collect Collects Banked Influence

As a player,
I want tapping an unlocked country to collect its banked Influence and add it to my total,
So that I can see the number go up and feel the core loop.

**Acceptance Criteria:**

**Given** a country has banked influence > 0
**When** the `TapCountry` command is applied
**Then** the country's banked influence resets to 0, the world's `totalInfluence` increases by that amount, and a `CountryTapped` event is emitted with the collected amount.

**Given** a country has banked influence = 0
**When** `TapCountry` is applied
**Then** the reducer returns `Result.success` but emits no `CountryTapped` event (UI treats zero as no-op) — or emits a distinguishable zero-amount event that UI discards. Choice documented in the reducer; either is acceptable so long as UI doesn't animate a "0" flyout.

**Given** a `CountryTapped` event
**When** the HUD is watching `totalInfluenceProvider`
**Then** the HUD updates to the new total in the next frame.

### Story 2.7: Initial Seed — One or More Countries Unlocked by Default

As a first-time player,
I want at least one country (Egypt in Africa) already unlocked when I launch the game,
So that I can immediately tap and start the core loop without first needing unlocks (which don't exist until Epic 4).

**Acceptance Criteria:**

**Given** a fresh install (empty save)
**When** the `GameWorld` initializes from `ContentRegistry`
**Then** the first country (`egypt`) is flagged `unlocked = true` with `ipLevel = 1` and `leaderTier = LeaderTier.none`.

**Given** the initial state
**When** the map renders
**Then** Egypt is painted in the "generating" / "ready" state colors (per its banked influence) and all other countries are painted in the "locked" color.

**Given** the seed state is re-applied on subsequent launches after Epic 6 persistence lands
**When** the player has progressed past the seed
**Then** their actual progression state loads, not the seed.

---
