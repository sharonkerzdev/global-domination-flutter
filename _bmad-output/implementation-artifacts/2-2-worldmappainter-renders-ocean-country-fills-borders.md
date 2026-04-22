# Story 2.2: `WorldMapPainter` Renders Ocean + Country Fills + Borders

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to see a world map with distinct colors for ocean and countries,
So that I can visually orient myself on the globe before interacting.

## Acceptance Criteria

1. **Given** the map screen loads **When** the `CustomPainter` runs **Then** it paints, in this order: ocean background → continent background fills → country state-colored fills → country borders.

2. **Given** a country's state is `locked` / `unlocked` / `ready-to-collect` / `automated` **When** it is painted **Then** its fill color comes from the `CountryColors` `ThemeExtension`, not hardcoded literals.

3. **Given** `shouldRepaint(oldDelegate)` is called **When** only the view transform has changed (pan/zoom) **Then** it returns `true` (so pan/zoom re-paints), and country fills are not recomputed from scratch.

4. **Given** `shouldRepaint` is called **When** neither the view transform nor any country state has changed **Then** it returns `false`.

## Tasks / Subtasks

- [x] Task 1: Create `CountryVisualState` enum in UI layer (AC: #2)
  - [x] 1.1 Create `lib/ui/features/map/country_visual_state.dart` — `enum CountryVisualState { locked, unlocked, readyToCollect, automated }`
  - [x] 1.2 This enum lives in `lib/ui/` because it is a UI/rendering concern — the game layer's `CountryState` (future Story 2.5+) will be mapped to this enum by the provider layer. For now, the painter accepts a `Map<CountryId, CountryVisualState>` parameter
  - [x] 1.3 The enum values match the architecture's country states: locked (muted), unlocked (active), ready-to-collect (generating complete), automated (leader-managed)

- [x] Task 2: Create `CountryColors` ThemeExtension (AC: #2)
  - [x] 2.1 Create `lib/ui/theme/country_colors.dart` — `class CountryColors extends ThemeExtension<CountryColors>`
  - [x] 2.2 Fields: `Color ocean`, `Color border`, `Color locked`, `Color unlocked`, `Color readyToCollect`, `Color automated`, `Map<String, Color> continentFills` (keyed by `ContinentId.value` string for the 7 continents: africa, europe, middle_east, asia, south_america, north_america, oceania)
  - [x] 2.3 Implement `copyWith()` and `lerp()` as required by `ThemeExtension`
  - [x] 2.4 Provide a `static CountryColors defaults` factory with the initial color palette — bright/vibrant per GDD art direction: ocean deep blue, locked muted grey, unlocked bright green, readyToCollect bright gold/amber, automated saturated teal/cyan. Continent fills use distinct muted color families per continent for visual differentiation behind country fills
  - [x] 2.5 Colors must be chosen so country state fills are visually distinct FROM continent background fills (continent fills are subtle/muted; state fills are bolder)
  - [x] 2.6 Border color should be a dark semi-transparent value that works over both continent fills and country state fills

- [x] Task 3: Register `CountryColors` in app theme (AC: #2)
  - [x] 3.1 Create `lib/ui/theme/app_theme.dart` — `ThemeData appTheme()` builder that creates `ThemeData` with `extensions: [CountryColors.defaults]`
  - [x] 3.2 If `app_theme.dart` already exists, modify it to add the `CountryColors` extension. If not, create the minimal theme builder following architecture: `GoogleFonts.fredokaTextTheme(base)`, single theme (no dark mode), and the `CountryColors` extension
  - [x] 3.3 Wire `appTheme()` into `MaterialApp` in `lib/app.dart` via `theme: appTheme()` — verify this doesn't break existing code
  - [x] 3.4 Access pattern in widgets: `Theme.of(context).extension<CountryColors>()!`

- [x] Task 4: Create `WorldMapPainter` (AC: #1, #2, #3, #4)
  - [x] 4.1 Create `lib/ui/features/map/world_map_painter.dart` — `class WorldMapPainter extends CustomPainter`
  - [x] 4.2 Constructor parameters: `List<CountryPath> countries`, `Matrix4 viewTransform`, `Map<CountryId, CountryVisualState> countryStates`, `CountryColors colors`
  - [x] 4.3 Pre-allocate all `Paint` objects as fields in the constructor body (or lazy finals) from the `CountryColors` — do NOT create `Paint()` inside `paint()`. Create: `_oceanPaint`, `_borderPaint`, `_lockedPaint`, `_unlockedPaint`, `_readyToCollectPaint`, `_automatedPaint`, and a `Map<String, Paint>` for continent fills
  - [x] 4.4 `paint()` method layer order (MUST match architecture): (1) ocean background `canvas.drawRect(Offset.zero & size, _oceanPaint)`, (2) apply view transform via `canvas.save()` + `canvas.transform(viewTransform.storage)` + `canvas.scale(size.width, size.height)`, (3) continent background fills — for each country, `canvas.drawPath(country.path, continentFillPaint[country.continent])`, (4) country state fills — for each country, look up `countryStates[country.id]` and draw with the corresponding state paint (default to `_lockedPaint` if not in map), (5) country borders — for each country, `canvas.drawPath(country.path, _borderPaint)`, (6) `canvas.restore()`
  - [x] 4.5 The border `Paint` must use `PaintingStyle.stroke` with a thin `strokeWidth` (suggest `0.001` in normalized space, same as spike). State/continent fills use `PaintingStyle.fill`
  - [x] 4.6 Continent fills serve as a subtle background tint — they should have low opacity (e.g. 0.15–0.25 alpha) so country state fills are visually dominant

- [x] Task 5: Implement `shouldRepaint` correctly (AC: #3, #4)
  - [x] 5.1 `shouldRepaint(WorldMapPainter oldDelegate)` returns `true` if: `viewTransform != oldDelegate.viewTransform` OR `countryStates != oldDelegate.countryStates` OR `countries != oldDelegate.countries` OR `colors != oldDelegate.colors`
  - [x] 5.2 For efficient country state comparison, compare by identity first (`identical(countryStates, oldDelegate.countryStates)`), then fall back to map equality. This avoids deep comparison on every frame during pan/zoom where states haven't changed
  - [x] 5.3 Do NOT compare `List<CountryPath>` deeply — use `identical()` since the list is cached by `geoProvider` and never rebuilt

- [x] Task 6: Create a minimal map screen to host the painter (AC: #1)
  - [x] 6.1 Create `lib/ui/features/map/map_screen.dart` — `class MapScreen extends ConsumerWidget`
  - [x] 6.2 Watch `geoProvider` — handle loading (show `CircularProgressIndicator`) and error states
  - [x] 6.3 When data is loaded, render a `CustomPaint` with `WorldMapPainter`, passing: countries from `geoProvider`, a default `Matrix4.identity()` view transform (pan/zoom is Story 2.3), an empty `countryStates` map `{}` (all countries render as locked — real states come from Story 2.5+/2.7), and `CountryColors` from `Theme.of(context).extension<CountryColors>()!`
  - [x] 6.4 Wrap the `CustomPaint` in a `RepaintBoundary` to isolate repaints
  - [x] 6.5 Set `CustomPaint.size` to `Size.infinite` (or use `LayoutBuilder` to fill available space) — the painter scales internally via `canvas.scale(size.width, size.height)` from the `[0,1]²` coordinate space
  - [x] 6.6 Do NOT implement pan/zoom gestures here — that is Story 2.3. The map renders at the default identity transform (fit-to-screen)

- [x] Task 7: Write tests (AC: #1, #2, #3, #4)
  - [x] 7.1 Create `test/ui/features/map/world_map_painter_test.dart` using `flutter_test`
  - [x] 7.2 Test `shouldRepaint` returns `false` when all parameters are identical
  - [x] 7.3 Test `shouldRepaint` returns `true` when `viewTransform` differs
  - [x] 7.4 Test `shouldRepaint` returns `true` when `countryStates` map differs
  - [x] 7.5 Test `shouldRepaint` returns `false` when same `countryStates` map is passed (identity check)
  - [x] 7.6 Create `test/ui/theme/country_colors_test.dart` — test `copyWith` returns modified instance, test `lerp` interpolates between two `CountryColors` instances, test that `defaults` has non-null values for all fields and all 7 continents
  - [x] 7.7 Widget test: `MapScreen` shows a `CircularProgressIndicator` when `geoProvider` is loading
  - [x] 7.8 Widget test: `MapScreen` renders a `CustomPaint` with `WorldMapPainter` when `geoProvider` resolves — override `geoProvider` with a small test fixture (2-3 fake `CountryPath` objects)
  - [x] 7.9 Do NOT test exact pixel colors — `CustomPainter.paint()` is hard to assert on. Focus on `shouldRepaint` logic and widget composition

- [x] Task 8: Verify full test suite passes (AC: all)
  - [x] 8.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 8.2 Run `dart format --set-exit-if-changed .` — clean
  - [x] 8.3 Run `flutter test` — all prior tests (304+) plus new tests pass (323 total)
  - [x] 8.4 No `print()` — use `Logger` if any logging needed (but avoid logging in paint hot path)

## Dev Notes

### Architecture Compliance

**Layer order is non-negotiable.** Architecture §8 specifies: ocean → continent fills → country fills (state color) → borders → labels → effects. This story implements the first four layers. Labels and effects are future stories. [Source: game-architecture.md#Map Rendering Pipeline, line 277]

**`CountryColors` ThemeExtension.** Architecture §11 specifies game-specific tokens via `ThemeExtension`s including `CountryColors` (locked/unlocked/conquered/golden). This story creates the first `ThemeExtension` in the project. The state names in the extension map to: locked, unlocked, readyToCollect (renamed from "conquered" for clarity — represents "generating complete"), automated (represents leader-managed auto-collection). [Source: game-architecture.md#Theme & Design Tokens, line 297]

**No allocations in `paint()`.** All `Paint` objects are pre-built from `CountryColors` in the constructor. The `Path` objects are pre-built in Story 2.1's parser. Zero per-frame allocations in the paint method. [Source: project-context.md#Performance Rules]

**`shouldRepaint` must be correct.** Architecture says `shouldRepaint` is based on "view-transform change OR country-state version". The implementation checks viewTransform, countryStates map, countries list, and colors — all by identity first for efficiency. [Source: game-architecture.md#Map Rendering Pipeline, line 276]

**No `InteractiveViewer`.** Pan/zoom is Story 2.3 with custom `GestureDetector` + `Matrix4`. This story uses `Matrix4.identity()` only. [Source: game-architecture.md, line 274]

### Implementation Approach

**Painter receives all data as constructor parameters.** `WorldMapPainter` is a pure rendering function — it receives `List<CountryPath>`, `Matrix4`, `Map<CountryId, CountryVisualState>`, and `CountryColors`, then paints. No providers, no context access inside the painter.

**Continent fills as subtle background.** The painting order draws continent fills FIRST (muted, low-opacity per-continent color), then country state fills ON TOP (bold state-based colors). This means continent fills are only visible as a subtle border halo around countries and in any gaps between country paths. They provide geographic context without interfering with state visibility.

**Default state is locked.** Until Story 2.7 seeds Egypt as unlocked and Story 2.5 adds real country states, all countries render as `locked`. The painter defaults missing entries in `countryStates` to `CountryVisualState.locked`.

**`CountryVisualState` vs game-layer state.** The game layer will eventually have `CountryState` (Story 2.5+) in `lib/game/features/countries/`. The UI-layer `CountryVisualState` enum is a rendering concern that providers will map game state to. This keeps the painter decoupled from game internals.

### Library/Framework Requirements

- No new packages — all rendering uses `dart:ui` (Flutter core) and `package:flutter/rendering.dart`
- `package:google_fonts` — already a dependency, used in `appTheme()` for Fredoka font
- `package:flutter_riverpod` — already a dependency, `ConsumerWidget` for `MapScreen`
- `package:vector_math` — already a dependency (transitive via Flutter), used for `Matrix4`

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/ui/features/map/country_visual_state.dart` | `CountryVisualState` enum (locked/unlocked/readyToCollect/automated) |
| CREATE | `lib/ui/theme/country_colors.dart` | `CountryColors extends ThemeExtension` with ocean, border, state, continent colors |
| CREATE | `lib/ui/theme/app_theme.dart` | `appTheme()` builder with `CountryColors.defaults` extension |
| CREATE | `lib/ui/features/map/world_map_painter.dart` | `WorldMapPainter extends CustomPainter` — ocean + continent fills + state fills + borders |
| CREATE | `lib/ui/features/map/map_screen.dart` | `MapScreen` ConsumerWidget hosting the painter |
| MODIFY | `lib/app.dart` | Wire `theme: appTheme()` into `MaterialApp` |
| CREATE | `test/ui/features/map/world_map_painter_test.dart` | `shouldRepaint` logic tests + widget tests |
| CREATE | `test/ui/theme/country_colors_test.dart` | ThemeExtension copyWith/lerp/defaults tests |

### Testing Standards

- **Use `flutter_test`** — painter uses `dart:ui` types, widgets use Flutter framework
- **Override `geoProvider` in widget tests** with a small fixture (2-3 fake `CountryPath` objects) — never load the real 1.6MB GeoJSON in widget tests
- **Focus `shouldRepaint` tests on correctness** — this is the most important behavioral contract
- **Do NOT test pixel colors** — `CustomPainter` visual output is best verified by human review or golden tests (not in scope)
- **No `print()`** — `Logger` only, and never inside `paint()`

### Anti-Patterns to Avoid

- Do NOT create `Paint` objects inside `paint()` — pre-allocate from `CountryColors` in constructor
- Do NOT hardcode color literals in the painter — all colors flow through `CountryColors` ThemeExtension
- Do NOT use `InteractiveViewer` — custom gesture handling is Story 2.3
- Do NOT import `package:flutter/*` in `lib/game/` — `CountryVisualState` lives in `lib/ui/`
- Do NOT log inside `paint()` — hot path, no logging allowed [Source: project-context.md#Performance Rules]
- Do NOT deep-compare `List<CountryPath>` in `shouldRepaint` — use `identical()` since the list is cached
- Do NOT add pan/zoom gesture handling — that is Story 2.3's scope
- Do NOT create country game state (`CountryState` in `lib/game/`) — that is Story 2.5+
- Do NOT use `print()` — `Logger('WorldMapPainter')` only if needed outside paint
- Do NOT add any map library packages — custom `CustomPainter` is mandatory [Source: project-context.md#Forbidden packages]
- Do NOT forget `PathFillType.evenOdd` — Story 2.1 code review established that `Path` objects use `evenOdd` fill type for correct hole rendering (Italy, South Africa, UAE). The painter MUST NOT override the fill type when drawing

### Previous Story Intelligence

**From Story 2-1 (GeoJSON Parser — done):**
- `CountryPath` at `lib/ui/features/map/country_path.dart` — `@immutable` data class with `id` (CountryId), `continent` (ContinentId), `rings` (List<List<Offset>>), `bbox` (Rect), `path` (Path with `PathFillType.evenOdd`)
- `geoProvider` at `lib/providers/geo_providers.dart` — `FutureProvider<List<CountryPath>>` that caches the parsed result
- Parser returns exactly 79 `CountryPath` entries, all projected to `[0,1]²` normalized space
- `Path` objects have `PathFillType.evenOdd` set for correct GeoJSON hole rendering — do NOT change this in the painter
- 304 tests passing, all clean

**From Story 1-11 (Canvas Performance Spike — in-progress):**
- Spike painter at `lib/ui/debug/spike_map_painter.dart` validates the approach: `canvas.transform(viewTransform.storage)` + `canvas.scale(size.width, size.height)` + iterate countries drawing fill then stroke
- Spike uses pre-allocated static `Paint` objects — production painter should do the same but from `CountryColors` instead of hardcoded colors
- Spike confirmed: `canvas.drawRect(Offset.zero & size, oceanPaint)` paints ocean BEFORE transform (so it covers full screen), then transform is applied for country paths
- Spike uses `strokeWidth: 0.001` in normalized space — same approach for production borders
- FPS measurement pending device profiling (Task 7 incomplete) but the approach is validated

**Key patterns from Epic 1:**
- `@immutable` on all value/data classes
- Manual `==` / `hashCode` (no freezed)
- `const` constructors where possible
- `Logger('Tag')` for runtime logging (not in hot paths)
- `avoid_print: error` enforced

### Git Intelligence

All code from Epic 1 (Stories 1.1–1.11) and Story 2.1 is in the working tree (uncommitted). No new dependencies needed.

### Project Structure Notes

- `lib/ui/features/map/` exists with 3 files from Story 2.1 — add `country_visual_state.dart`, `world_map_painter.dart`, `map_screen.dart`
- `lib/ui/theme/` does NOT exist yet — create it for `country_colors.dart` and `app_theme.dart`
- `test/ui/theme/` does NOT exist yet — create it for `country_colors_test.dart`
- `test/ui/features/map/` exists with 2 test files from Story 2.1 — add `world_map_painter_test.dart`
- Spike file `lib/ui/debug/spike_map_painter.dart` shows the pattern to follow but uses hardcoded colors — production replaces this

### Cross-Story Context

- **Story 2.1** (done) provides `CountryPath` data class and `geoProvider` — this story consumes both
- **Story 2.3** (next) adds pan/zoom gesture handling — will update the `viewTransform` passed to this painter
- **Story 2.4** uses `CountryPath.rings` and `CountryPath.bbox` for hit-testing — orthogonal to painting
- **Story 2.5** adds `GameWorld.tick()` driving influence generation — will create `CountryState` in game layer, provider maps it to `CountryVisualState` for the painter
- **Story 2.7** seeds Egypt as unlocked — will pass `{egypt: CountryVisualState.unlocked}` in the state map
- **Epic 7 Story 7-1** will expand the theme with `HudPalette`, `RarityColors`, `MilestoneColors` ThemeExtensions — `CountryColors` is the first. Follow the same `ThemeExtension` pattern
- **Epic 7 Story 7-2** creates the `AppScaffold` with `IndexedStack` — `MapScreen` from this story will become one of the tabs

### References

- [Source: epics.md#Story 2.2] — User story, acceptance criteria, BDD scenarios
- [Source: game-architecture.md#Map Rendering Pipeline, line 277] — Layer order: ocean → continent fills → country fills → borders → labels → effects
- [Source: game-architecture.md#Theme & Design Tokens, line 297] — `CountryColors` ThemeExtension (locked/unlocked/conquered/golden)
- [Source: project-context.md#Performance Rules] — No per-frame allocations, `shouldRepaint` must return false when only non-map state changed
- [Source: project-context.md#Forbidden packages] — No external map libraries
- [Source: 2-1 story#Code Review] — `PathFillType.evenOdd` set on all `Path` objects for correct hole rendering
- [Source: spike_map_painter.dart] — Validated painting approach: transform, scale, iterate, fill+stroke

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Matrix4 identity equality works via value comparison (element-by-element); `shouldRepaint` uses this correctly
- `List<CountryPath>` uses identity-only comparison in `shouldRepaint` (per spec — `geoProvider` caches the same list instance)
- Two `[]` default args in test helper created different instances, breaking identity check — fixed by requiring explicit same-instance in tests
- `dart:ui` and `vector_math_64` imports were unnecessary (re-exported via `flutter/material.dart` and `flutter/rendering.dart`); removed

### Completion Notes List

- Created `CountryVisualState` enum (4 values: locked, unlocked, readyToCollect, automated) in UI layer
- Created `CountryColors extends ThemeExtension` with ocean, border, 4 state colors, 7 continent fills; `const` defaults; `copyWith`/`lerp`/`==`/`hashCode` implemented
- Created `app_theme.dart` with `appTheme()` using Fredoka font + `CountryColors.defaults` extension; wired into `lib/app.dart`
- Created `WorldMapPainter` with 4-layer paint order (ocean → continent fills → state fills → borders), all Paint objects pre-allocated in constructor, no per-frame allocations
- `shouldRepaint` uses identity-first for both `countries` (identity-only per spec) and `countryStates` (identity then deep map equality); value equality for `viewTransform` (Matrix4) and `colors`
- Created `MapScreen` ConsumerWidget watching `geoProvider`, loading/error/data states, `RepaintBoundary`, `Size.infinite` CustomPaint
- 19 new tests: 7 `shouldRepaint` unit tests, 9 `CountryColors` tests (defaults/copyWith/lerp/equality), 2 widget tests (MapScreen loading + data)
- Full suite: 323 tests pass (304 prior + 19 new), `flutter analyze` clean, `dart format` clean

### File List

- lib/ui/features/map/country_visual_state.dart (CREATE)
- lib/ui/theme/country_colors.dart (CREATE)
- lib/ui/theme/app_theme.dart (CREATE)
- lib/ui/features/map/world_map_painter.dart (CREATE)
- lib/ui/features/map/map_screen.dart (CREATE)
- lib/app.dart (MODIFY — add appTheme() import + wire theme: appTheme())
- test/ui/features/map/world_map_painter_test.dart (CREATE)
- test/ui/theme/country_colors_test.dart (CREATE)

### Change Log

- 2026-04-22: Story 2-2 implemented — WorldMapPainter with ocean+continent fills+country state fills+borders, CountryColors ThemeExtension, MapScreen, 19 new tests (323 total)
- 2026-04-22: Code review fixes — (1) MapScreen now hosts `_MapView` StatefulWidget that caches `WorldMapPainter` across rebuilds so pre-allocated `Paint` objects survive Story 2.3's gesture-driven rebuilds, (2) painter `assert`s known continent to catch GeoJSON drift, (3) cached `appTheme()` as static `_theme` in `GlobalDominationApp`, (4) added widget tests for painter reuse + `geoProvider` error branch — 325 tests pass, analyze + format clean
