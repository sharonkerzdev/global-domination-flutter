# Story 2.4: Point-in-Polygon Hit Testing on Tap

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to tap a specific country and have the app register that exact country,
So that I can collect Influence from the country I intended.

## Acceptance Criteria

1. **Given** the map is at any pan/zoom **When** I tap inside a country's polygon **Then** the hit-tester inverse-transforms the tap point, runs bbox reject per country, then point-in-polygon ray-casting, and returns that `CountryId`.

2. **Given** I tap on ocean (outside all polygons) **When** the hit-tester runs **Then** it returns `null` and no command fires.

3. **Given** overlapping or adjacent countries **When** I tap on the boundary **Then** the hit-tester returns the first match in `CountryPath` list order (stable) — unit-tested for consistency.

4. **Given** a tap **When** hit-test succeeds **Then** the gesture handler dispatches `ref.read(gameWorldProvider.notifier).apply(TapCountry(id))`.

## Tasks / Subtasks

- [x] Task 1: Create `PolygonHitTester` class (AC: #1, #2, #3)
  - [x] 1.1 Create `lib/ui/features/map/hit_test/polygon_hit_tester.dart`
  - [x] 1.2 Class takes `List<CountryPath>` in constructor and builds `Map<CountryId, Rect> _bboxCache` from each `CountryPath.bbox`
  - [x] 1.3 Implement `CountryId? hitTest(Offset normalizedPoint)` — iterates `_paths` in order, bbox-rejects via `_bboxCache[path.id]!.contains(normalizedPoint)`, then calls `_pointInPolygon(normalizedPoint, path.rings)` on survivors
  - [x] 1.4 Implement `bool _pointInPolygon(Offset p, List<List<Offset>> rings)` using ray-casting algorithm — for each ring, for each edge, toggle `inside` on crossing. This handles multi-ring polygons (holes via even-odd rule): outer ring sets `inside = true`, hole ring toggles it back to `false`
  - [x] 1.5 First match in list order wins (AC #3) — `CountryPath` list order is stable from the GeoJSON parser (Story 2.1 comment: "stable order matters for hit-testing in Story 2.4")
  - [x] 1.6 Return `null` when no country matches (AC #2)
  - [x] 1.7 Mark class `@immutable` — it holds only final fields

- [x] Task 2: Create `TapCountry` command variant (AC: #4)
  - [x] 2.1 Open `lib/game/game_command.dart` — currently a sealed class with only `Noop`
  - [x] 2.2 Add `TapCountry` variant: `TapCountry({required this.countryId})` with a `final CountryId countryId` field
  - [x] 2.3 Update `GameWorld.applyCommand` switch in `lib/game/game_world.dart` to handle `TapCountry` — for now, return `Result.success(null)` (no-op). Story 2.6 implements the actual collect logic
  - [x] 2.4 Ensure the switch remains exhaustive (compiler enforces via sealed class)

- [x] Task 3: Add inverse-transform tap conversion in `MapScreen` (AC: #1)
  - [x] 3.1 Open `lib/ui/features/map/map_screen.dart` (created by Story 2.2, modified by Story 2.3 to `ConsumerStatefulWidget` with `_viewTransform`)
  - [x] 3.2 Add an `onTapUp` callback to the existing `GestureDetector` (Story 2.3 already has `onScaleStart`/`onScaleUpdate` for pan/zoom)
  - [x] 3.3 In `_onTapUp(TapUpDetails details)`: compute inverse transform: `final inverted = Matrix4.copy(_viewTransform)..invert()`. Then transform the tap point: `final screenPoint = details.localPosition`. Apply the inverse: `final vector = inverted.transform3(Vector3(screenPoint.dx, screenPoint.dy, 0))`. Convert to normalized coords: `final normalized = Offset(vector.x / canvasWidth, vector.y / canvasHeight)` where `canvasWidth`/`canvasHeight` come from the widget's `Size` (available via `LayoutBuilder` or from the `CustomPaint` size)
  - [x] 3.4 **CRITICAL: The painter draws in `[0,1]²` space scaled to canvas size.** The inverse transform must account for both the view transform AND the `[0,1]² → pixel` scaling. The pipeline is: screen tap → invert viewTransform → divide by canvas size → `[0,1]²` normalized point. Verify against spike_canvas_screen.dart's approach
  - [x] 3.5 Pass the normalized `Offset` to `PolygonHitTester.hitTest(normalizedPoint)`

- [x] Task 4: Wire hit-test result to `GameCommand` dispatch (AC: #2, #4)
  - [x] 4.1 Instantiate `PolygonHitTester` — construct it once from the `geoProvider` data, NOT on every tap. Store as a field on the state class or compute lazily: `late final PolygonHitTester _hitTester = PolygonHitTester(geoData)` where `geoData` comes from `ref.read(geoProvider).value!`
  - [x] 4.2 In `_onTapUp`: after computing `normalizedPoint`, call `final countryId = _hitTester.hitTest(normalizedPoint)`
  - [x] 4.3 If `countryId != null`, dispatch: `ref.read(gameWorldProvider.notifier).apply(TapCountry(countryId: countryId))`
  - [x] 4.4 If `countryId == null` (ocean tap), do nothing — no command, no event, no log (hot path)
  - [x] 4.5 `gameWorldProvider` does not exist yet — it will be created as a `StateNotifierProvider` or `NotifierProvider` exposing `GameWorld`. For this story, create a minimal provider at `lib/providers/game_providers.dart` that exposes `GameWorld` so the dispatch compiles. If Story 2.5 hasn't landed yet, this is a stub that will be fleshed out

- [x] Task 5: Write pure-Dart unit tests for `PolygonHitTester` (AC: #1, #2, #3)
  - [x] 5.1 Create `test/ui/features/map/hit_test/polygon_hit_tester_test.dart` using `package:flutter_test/flutter_test.dart` (needs `Offset` and `Rect` from `dart:ui`)
  - [x] 5.2 **Test: hit inside a simple square polygon** — create a `CountryPath` with a single ring forming a square `[(0.1,0.1), (0.3,0.1), (0.3,0.3), (0.1,0.3)]`. Hit-test at `Offset(0.2, 0.2)` → returns that country's ID
  - [x] 5.3 **Test: miss on ocean** — hit-test at `Offset(0.5, 0.5)` with same square polygon → returns `null`
  - [x] 5.4 **Test: bbox rejection** — create a country with bbox far from tap point, verify it's correctly rejected (indirectly — the hit-test returns null quickly)
  - [x] 5.5 **Test: first-match-wins on overlap** — create two `CountryPath` objects whose polygons overlap. Tap in the overlap zone. Verify the FIRST one in list order is returned (AC #3)
  - [x] 5.6 **Test: multi-ring polygon (hole)** — create a country with an outer ring and an inner ring (hole). Tap inside the hole → returns `null`. Tap between outer and inner ring → returns the country's ID
  - [x] 5.7 **Test: point on edge** — tap exactly on a polygon edge. Document the behavior (ray-casting may or may not include edge points — the important thing is it's deterministic)
  - [x] 5.8 Use `test/helpers/` builders if `CountryPath` construction is verbose — create a `makeCountryPath({required String id, required List<List<Offset>> rings})` helper

- [x] Task 6: Write widget tests for tap integration (AC: #1, #2, #4)
  - [x] 6.1 Create `test/ui/features/map/map_screen_tap_test.dart` using `flutter_test`
  - [x] 6.2 **Test: tap on a country dispatches `TapCountry`** — override `geoProvider` with a fixture containing one large polygon covering most of the canvas. Tap in the center. Verify `gameWorldProvider.notifier.apply` was called with `TapCountry` containing the correct `CountryId`. Use a mock/spy `GameWorld` via provider override
  - [x] 6.3 **Test: tap on ocean dispatches nothing** — override `geoProvider` with a small polygon in one corner. Tap in the opposite corner (ocean). Verify no command was dispatched
  - [x] 6.4 **Test: tap works after pan/zoom** — simulate a drag (pan) first, then tap. Verify the inverse transform correctly maps the tap to the right country. This is the critical integration test for AC #1
  - [x] 6.5 Override `geoProvider` with small fixture data (2-3 fake `CountryPath` objects) — never load the real 1.6MB GeoJSON
  - [x] 6.6 Override `gameWorldProvider` with a testable stub/mock to capture dispatched commands
  - [x] 6.7 Override `contentRegistryProvider` if the widget tree requires it

- [x] Task 7: Verify full test suite passes (AC: all)
  - [x] 7.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 7.2 Run `dart format --set-exit-if-changed .` — clean
  - [x] 7.3 Run `flutter test` — all prior tests plus new tests pass
  - [x] 7.4 No `print()` — `Logger` only if needed (but no logging in tap hot path)

## Dev Notes

### Architecture Compliance

**Custom hit-testing pipeline, NOT `Path.contains()`.** Architecture §8 defines the exact pipeline: "tap → inverse-transform to normalized coords → bounding-box reject per country → point-in-polygon (ray-casting); cached bounding boxes per country." Do NOT use Flutter's `Path.contains()` — it operates in pixel space and doesn't give us the normalized-coordinate pipeline the architecture mandates. The architecture's `PolygonHitTester` class operates on `[0,1]²` normalized coordinates AFTER the inverse view-transform. [Source: game-architecture.md#Map Hit-Test Pipeline, line 875]

**`PolygonHitTester` lives in `lib/ui/features/map/hit_test/`.** Architecture file tree shows `hit_test/ { polygon_hit_tester }` under the map feature. [Source: game-architecture.md, line 625]

**`TapCountry` is a `GameCommand`, dispatched via `gameWorldProvider.notifier.apply()`.** UI never mutates `GameState` directly — it dispatches commands. The command is imperative (`TapCountry`), the eventual event will be past tense (`CountryTapped`) — but the event is Story 2.6's scope. [Source: project-context.md#Commands vs Events]

**No Flutter imports in `lib/game/`.** `TapCountry` is added to `game_command.dart` which is in `lib/game/`. It takes a `CountryId` (pure Dart value object), NOT an `Offset` or any Flutter type. The screen-to-normalized conversion happens entirely in `lib/ui/`. [Source: project-context.md#Engine-Specific Rules, rule 1]

**No logging in the tap hot path.** `_onTapUp` and `PolygonHitTester.hitTest` must not call `Logger`. [Source: project-context.md#Performance Rules — "Forbidden in hot paths"]

### Implementation Approach

**Inverse transform pipeline.** The `WorldMapPainter` (Story 2.2) draws by applying `canvas.transform(viewTransform.storage)` then scaling to canvas size. To reverse a screen tap to `[0,1]²` normalized coordinates:
1. Get `localPosition` from `TapUpDetails` (already in widget-local coordinates)
2. Invert the view transform: `Matrix4.copy(_viewTransform)..invert()`
3. Apply inverse to the screen point: `inverted.transform3(Vector3(x, y, 0))`
4. Divide by canvas size to get back to `[0,1]²` space

**Ray-casting algorithm.** Standard even-odd ray-casting: cast a horizontal ray from the test point to +infinity, count polygon edge crossings. Odd = inside, even = outside. Multi-ring polygons (holes) work automatically: the outer ring gives odd crossings (inside), the hole ring adds another crossing (even = outside). This matches the `PathFillType.evenOdd` used by the GeoJSON parser.

**`PolygonHitTester` is constructed once.** It's built from `List<CountryPath>` (from `geoProvider`) and cached as a field. The bbox cache is built in the constructor. No per-tap allocations beyond the `Matrix4.copy()` and `Vector3` for inverse transform.

**`gameWorldProvider` stub.** If this provider doesn't exist yet (Story 2.5 hasn't landed), create a minimal version at `lib/providers/game_providers.dart` that exposes `GameWorld`. The `TapCountry` handler is a no-op in `GameWorld.applyCommand` until Story 2.6 adds collection logic.

### Library/Framework Requirements

- No new packages — `Matrix4`, `Vector3`, `Offset`, `Rect` all come from Flutter/vector_math (transitive dependency)
- `package:flutter_riverpod` — already a dependency, for `ref.read(gameWorldProvider.notifier)`

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/ui/features/map/hit_test/polygon_hit_tester.dart` | `PolygonHitTester` with bbox reject + ray-casting |
| MODIFY | `lib/game/game_command.dart` | Add `TapCountry({required CountryId countryId})` variant |
| MODIFY | `lib/game/game_world.dart` | Handle `TapCountry` in `applyCommand` switch (no-op for now) |
| MODIFY | `lib/ui/features/map/map_screen.dart` | Add `onTapUp` → inverse transform → hit-test → dispatch |
| CREATE | `lib/providers/game_providers.dart` | Stub `gameWorldProvider` if not yet created |
| CREATE | `test/ui/features/map/hit_test/polygon_hit_tester_test.dart` | Unit tests for hit-test logic |
| CREATE | `test/ui/features/map/map_screen_tap_test.dart` | Widget tests for tap integration |

### Testing Standards

- **`PolygonHitTester` tests use `flutter_test`** — needs `Offset` and `Rect` from `dart:ui`
- **Widget tests override `geoProvider`** with small fixture data (2-3 fake `CountryPath` objects) — never load real GeoJSON
- **Widget tests override `gameWorldProvider`** with a spy/mock to verify dispatched commands
- **Test the inverse transform integration** — pan/zoom then tap, verify correct country is identified
- **Test first-match-wins** for overlapping polygons (AC #3)
- **Test multi-ring (hole) polygons** — tap inside hole returns `null`
- **No `print()`** — `Logger` only, never in hot paths

### Anti-Patterns to Avoid

- Do NOT use `Path.contains()` for hit-testing — it operates in pixel space, not `[0,1]²` normalized coordinates, and bypasses the bbox-reject optimization the architecture mandates
- Do NOT create `PolygonHitTester` on every tap — construct once from geo data, cache as field
- Do NOT pass `Offset` or any Flutter type into `lib/game/` — `TapCountry` takes `CountryId` only
- Do NOT add logging inside `_onTapUp` or `hitTest` — these are hot paths
- Do NOT use `InteractiveViewer` — Story 2.3 already uses custom `GestureDetector` specifically so we can access `_viewTransform` for inverse transform here
- Do NOT allocate `Paint`, `Path`, or collections inside the tap handler — only the `Matrix4.copy()` and `Vector3` are acceptable per-tap allocations
- Do NOT fire a command on ocean tap (`null` result) — silently ignore
- Do NOT implement collect logic in `GameWorld.applyCommand` for `TapCountry` — that's Story 2.6's scope. The command handler is a no-op stub
- Do NOT use `DateTime.now()` or `Random()` in any game code touched here
- Do NOT use `print()` anywhere — `Logger('Tag')` only

### Previous Story Intelligence

**From Story 2-3 (Pan and Zoom — ready-for-dev, not yet implemented):**
- `MapScreen` is a `ConsumerStatefulWidget` with `_viewTransform` as local state
- `GestureDetector` has `onScaleStart`/`onScaleUpdate` for pan/zoom — this story adds `onTapUp` to the SAME `GestureDetector`
- `_viewTransform` is directly accessible in the state class — no need for a provider or callback to read it
- Story 2.3 explicitly states: "Story 2.4 will read `_viewTransform` from the same widget to compute inverse transforms for hit-testing"
- Zoom range: 1.0x (identity) to 15.0x — inverse transform must work correctly at all zoom levels

**From Story 2-2 (WorldMapPainter — ready-for-dev, not yet implemented):**
- `WorldMapPainter` applies `canvas.transform(viewTransform.storage)` then draws in `[0,1]²` space scaled to canvas size
- `RepaintBoundary` wraps `CustomPaint` — isolated repainting
- The paint pipeline is: `canvas.save()` → `canvas.transform(viewTransform.storage)` → `canvas.scale(size.width, size.height)` → draw paths in `[0,1]²` → `canvas.restore()`
- This means the inverse pipeline for a tap is: `screenPoint → invert(viewTransform) → divide by (size.width, size.height) → [0,1]²`

**From Story 2-1 (GeoJSON Parser — done, implemented):**
- `CountryPath` has `rings: List<List<Offset>>` with raw projected `[0,1]²` ring vertices — these are what `PolygonHitTester._pointInPolygon` iterates
- `CountryPath.bbox: Rect` — precomputed bounding box, used for bbox rejection
- `geoProvider` at `lib/providers/geo_providers.dart` — `FutureProvider<List<CountryPath>>`
- Parser preserves stable list order (comment: "stable order matters for hit-testing in Story 2.4")
- `PathFillType.evenOdd` used for rendering — ray-casting's even-odd rule is consistent with this

**From Story 1-11 (Canvas Performance Spike — in-progress):**
- Spike at `lib/ui/debug/spike_canvas_screen.dart` has reference implementation of pan/zoom but NO hit-testing code
- Spike confirmed smooth 60fps — the per-tap overhead of inverse transform + linear scan of 79 countries with bbox reject will be negligible

**From Story 1-9 (GameWorld skeleton — done):**
- `GameCommand` is a sealed class at `lib/game/game_command.dart` with only `Noop` variant
- `GameWorld.applyCommand` returns `Result<void, GameError>` — switch must remain exhaustive
- `CountryId` at `lib/game/values/country_id.dart` — immutable value object wrapping a string

### Git Intelligence

Recent commits are infrastructure only (4 commits: init, BMAD setup, MCP config, planning artifacts). All Epic 1 and Story 2.1 implementation is in the working tree (uncommitted). Stories 2.2 and 2.3 are ready-for-dev but not yet implemented — this story depends on both being implemented first.

### Project Structure Notes

- `lib/ui/features/map/hit_test/` is a new directory — matches architecture file tree (`hit_test/ { polygon_hit_tester }`)
- `lib/providers/game_providers.dart` may need to be created if it doesn't exist yet — this is the composition root for game-layer providers
- All hit-test logic stays in `lib/ui/` — `lib/game/` only gains the `TapCountry` command variant (pure Dart, no Flutter types)

### Cross-Story Context

- **Story 2.2** (prerequisite) creates `MapScreen` and `WorldMapPainter` — must exist before this story
- **Story 2.3** (prerequisite) adds pan/zoom with `_viewTransform` — must exist before this story needs the inverse transform
- **Story 2.5** adds `GameWorld.tick()` for influence generation — independent of hit-testing
- **Story 2.6** (depends on this) implements the actual collect logic for `TapCountry` — emits `CountryTapped` event, resets banked influence. This story's no-op handler is the stub
- **Story 2.7** seeds initial unlocked country (Egypt) — independent
- **Epic 8 Story 8.3** adds flying-number animation on tap — will subscribe to `CountryTapped` event from Story 2.6

### References

- [Source: epics.md#Story 2.4] — User story, acceptance criteria, BDD scenarios
- [Source: game-architecture.md#Map Hit-Test Pipeline, line 875] — `PolygonHitTester` class with exact ray-casting algorithm
- [Source: game-architecture.md#Map Rendering Pipeline, line 274] — Custom `GestureDetector` + `Matrix4` inverse transform for hit-tests
- [Source: game-architecture.md, line 625] — File tree: `hit_test/ { polygon_hit_tester }`
- [Source: project-context.md#Engine-Specific Rules] — No Flutter imports in `lib/game/`, UI dispatches commands only
- [Source: project-context.md#Commands vs Events] — `TapCountry` (imperative command), `CountryTapped` (past-tense event, Story 2.6)
- [Source: project-context.md#Performance Rules] — No logging in hot paths, no per-tap allocations
- [Source: 2-3 story] — `_viewTransform` is local widget state, Story 2.4 reads it for inverse transform
- [Source: 2-2 story] — Paint pipeline: `canvas.transform(viewTransform)` then scale to canvas size
- [Source: 2-1 story/CountryPath] — `rings`, `bbox`, stable list order for hit-testing

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `_MapView` was a plain `StatefulWidget` in the working tree (Story 2.3 had already been implemented). Converted to `ConsumerStatefulWidget` to access `ref` for dispatching commands.
- `vector_math` package was a transitive dependency; added as explicit dependency to satisfy `depend_on_referenced_packages` lint rule.
- Widget tests initially used `ContinentId('test')` — `WorldMapPainter` asserts on registered continent IDs; fixed to use `'africa'`.
- Existing `game_command_test.dart` had an exhaustive switch on `GameCommand` that required updating to include `TapCountry()`.

### Completion Notes List

- Created `PolygonHitTester` with bbox-reject + even-odd ray-casting; `@immutable`, constructed once per widget lifecycle via `late final`.
- Added `TapCountry({required CountryId countryId})` to the `GameCommand` sealed hierarchy; `GameWorld.applyCommand` no-op stub (Story 2.6 fills in collect logic).
- Created stub `gameWorldProvider` (`NotifierProvider<GameWorldNotifier, GameState>`) at `lib/providers/game_providers.dart`.
- `MapScreen._MapView` upgraded to `ConsumerStatefulWidget`; `onTapUp` added using `LayoutBuilder` canvas size for inverse transform: `screenPoint → invert(viewTransform) → divide by canvasSize → [0,1]²`.
- 10 new tests (7 unit + 3 widget); total: 341 (was 331). `flutter analyze --fatal-infos` clean, `dart format` clean.

### File List

- `lib/ui/features/map/hit_test/polygon_hit_tester.dart` (CREATED, code-review: `_bboxCache` now `Map.unmodifiable`)
- `lib/game/game_command.dart` (MODIFIED — added TapCountry)
- `lib/game/game_world.dart` (MODIFIED — TapCountry no-op case in switch)
- `lib/ui/features/map/map_screen.dart` (MODIFIED — ConsumerStatefulWidget, onTapUp, LayoutBuilder)
- `lib/providers/game_providers.dart` (CREATED — stub gameWorldProvider)
- `pubspec.yaml` (MODIFIED — added vector_math as explicit dependency)
- `test/ui/features/map/hit_test/polygon_hit_tester_test.dart` (CREATED, code-review: replaced weak edge test with four-sided nudge test)
- `test/ui/features/map/map_screen_tap_test.dart` (CREATED, code-review: added post-zoom tap test for AC #1)
- `test/helpers/country_path_builder.dart` (CREATED)
- `test/game/game_command_test.dart` (MODIFIED — exhaustive switch + code-review: TapCountry equality/hashCode/toString/switch tests)
- `test/game/game_world_test.dart` (MODIFIED — code-review: added `applyCommand(TapCountry)` success + no-event tests)

## Change Log

- 2026-04-22: Story 2.4 implemented — PolygonHitTester (bbox-reject + ray-casting), TapCountry command, inverse-transform onTapUp in MapScreen, gameWorldProvider stub; 10 new tests (341 total)
- 2026-04-22: Code review complete. Fixed 2 MEDIUM + 3 LOW: (1) added `applyCommand(TapCountry)` tests to `game_world_test.dart` covering Task 2.3's switch arm, (2) added post-zoom widget test to cover AC #1 "any pan/zoom", (3) `_bboxCache` now `Map.unmodifiable` to honor `@immutable`, (4) replaced trivially-true edge test with four-sided nudge-inside test, (5) added TapCountry equality/hashCode/toString/switch tests mirroring Noop. 350 tests pass; analyze & format clean.
