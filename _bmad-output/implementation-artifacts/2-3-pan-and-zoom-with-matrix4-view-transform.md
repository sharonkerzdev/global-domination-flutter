# Story 2.3: Pan and Zoom With `Matrix4` View Transform

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to drag to pan and pinch to zoom the world map,
So that I can explore the globe and focus on the region I care about.

## Acceptance Criteria

1. **Given** the map screen is visible **When** I drag with one finger **Then** the map translates in the direction of the drag with no noticeable lag.

2. **Given** the map screen **When** I pinch with two fingers **Then** the map zooms smoothly around the pinch midpoint.

3. **Given** zoom limits defined in the gesture handler **When** I try to zoom beyond the maximum scale (15x, matching spike output) or below the minimum (1.0x = fit-to-screen) **Then** zoom clamps at the limits.

4. **Given** a pan or zoom gesture **When** it completes **Then** the painter repaints exactly once at the final transform — no redundant frames.

## Tasks / Subtasks

- [x] Task 1: Ensure `MapScreen`/`_MapView` hosts gesture state as `StatefulWidget` (AC: #1, #2)
  - [x] 1.1 Open `lib/ui/features/map/map_screen.dart` (created by Story 2.2)
  - [x] 1.2 `_MapView` was already converted to `StatefulWidget` by Story 2.2's code-review fix for painter caching — this story extends the state class rather than converting a fresh `ConsumerWidget`
  - [x] 1.3 Add state fields: `Matrix4 _viewTransform = Matrix4.identity()`, `double _gestureScale = 1.0`, `Offset? _lastFocalPoint`
  - [x] 1.4 These fields are LOCAL widget state, not Riverpod providers — viewTransform is a render-only concern at this point. Story 2.4 will read `_viewTransform` from the same widget to compute inverse transforms for hit-testing

- [x] Task 2: Add zoom limit constants (AC: #3)
  - [x] 2.1 Add `static const double _minZoom = 1.0;` and `static const double _maxZoom = 15.0;` at the top of the state class
  - [x] 2.2 `_minZoom = 1.0` means fit-to-screen (identity transform scale). `_maxZoom = 15.0` matches the spike's validated value (architecture AC says "initial default 10x, confirm against spike output" — spike used 15.0x and felt correct)
  - [x] 2.3 These are UI constants, NOT game config — they live in the widget, not in `GameConstants` or `BalanceConfig`

- [x] Task 3: Implement pan gesture handling (AC: #1, #4)
  - [x] 3.1 Add `_onScaleStart(ScaleStartDetails details)` callback: store `details.localFocalPoint` in `_lastFocalPoint`, reset `_gestureScale = 1.0`
  - [x] 3.2 In `_onScaleUpdate(ScaleUpdateDetails details)`: compute `delta = details.localFocalPoint - _lastFocalPoint!`, apply pan as `_viewTransform = Matrix4.translationValues(delta.dx, delta.dy, 0) * _viewTransform`, update `_lastFocalPoint = details.localFocalPoint`
  - [x] 3.3 The pan translation is in SCREEN pixels (pre-transform space), applied by left-multiplying the current transform — same approach validated in spike

- [x] Task 4: Implement zoom gesture handling (AC: #2, #3, #4)
  - [x] 4.1 In the same `_onScaleUpdate`: when `details.scale != 1.0`, compute incremental scale as `details.scale / _gestureScale`
  - [x] 4.2 Compute current zoom level: `_viewTransform.getMaxScaleOnAxis()`. If `currentZoom * incrementalScale` would exceed `_maxZoom` or go below `_minZoom`, return early (skip this frame's zoom — clamp by rejecting, not by clamping the value, to prevent drift)
  - [x] 4.3 Apply zoom around the pinch focal point: `_viewTransform = Matrix4.translationValues(focal.dx, focal.dy, 0) * Matrix4.diagonal3Values(scale, scale, 1) * Matrix4.translationValues(-focal.dx, -focal.dy, 0) * _viewTransform` where `focal = details.localFocalPoint`
  - [x] 4.4 Update `_gestureScale = details.scale` to track cumulative gesture scale for incremental calculation
  - [x] 4.5 The focal-point zoom formula is: translate origin to focal → scale → translate back → apply to existing transform. This ensures the point under the user's fingers stays fixed during zoom

- [x] Task 5: Wire `GestureDetector` to `CustomPaint` in `build()` (AC: #1, #2, #4)
  - [x] 5.1 Wrap the existing `RepaintBoundary` + `CustomPaint` in a `GestureDetector` with `onScaleStart: _onScaleStart` and `onScaleUpdate: _onScaleUpdate`
  - [x] 5.2 Use `GestureDetector` (NOT `InteractiveViewer`) — architecture mandates this because we need the inverse transform for hit-testing in Story 2.4
  - [x] 5.3 `onScaleStart`/`onScaleUpdate` handles both one-finger pan AND two-finger pinch-zoom in a single gesture recognizer — Flutter unifies these as "scale" gestures
  - [x] 5.4 Pass `_viewTransform` to the `WorldMapPainter` constructor (replacing the previous `Matrix4.identity()`)
  - [x] 5.5 Call `setState(() { ... })` inside `_onScaleUpdate` to trigger repaint. `WorldMapPainter.shouldRepaint` (from Story 2.2) returns `true` when `viewTransform` differs, so only the painter repaints — widget tree does not rebuild beyond the `RepaintBoundary`
  - [x] 5.6 Do NOT add `onScaleEnd` — no inertia/fling animation in this story. The gesture simply stops, and the last `setState` call is the final repaint (AC #4: "repaints exactly once at the final transform")

- [x] Task 6: Write tests (AC: #1, #2, #3, #4)
  - [x] 6.1 Create `test/ui/features/map/map_screen_gesture_test.dart` using `flutter_test`
  - [x] 6.2 **Zoom clamp tests:** Implemented as widget tests using multi-touch `TestGesture` instances rather than a pure-logic helper — clamp behavior is only meaningful with real `ScaleUpdateDetails`, so extracting a helper was unnecessary
  - [x] 6.3 **Widget test — pan gesture:** `tester.drag` + assert painter viewTransform != identity
  - [x] 6.4 **Widget test — initial state:** Verified identity transform before any gesture
  - [x] 6.5 **Widget test — zoom clamp at min:** Pinch-in test; scale stays >= 1.0
  - [x] 6.6 **Widget test — zoom clamp at max:** 25 aggressive pinch-out gestures; scale stays <= 15.0
  - [x] 6.7 Override `geoProvider` with 3 fake `CountryPath` objects
  - [x] 6.8 No `contentRegistryProvider` override needed (not in widget tree)
  - [x] 6.9 Used two `TestGesture` objects via `tester.startGesture` for pinch simulation

- [x] Task 7: Verify full test suite passes (AC: all)
  - [x] 7.1 `flutter analyze` — zero issues
  - [x] 7.2 `dart format --set-exit-if-changed .` — clean
  - [x] 7.3 `flutter test` — 331 tests pass (325 prior + 6 gesture tests, incl. 2 added during code review)
  - [x] 7.4 No `print()` — no logging in gesture hot path

## Dev Notes

### Architecture Compliance

**Custom `GestureDetector`, NOT `InteractiveViewer`.** Architecture §8 explicitly states: "Pan/zoom: custom `GestureDetector` that maintains a `Matrix4 viewTransform`; **no `InteractiveViewer`** (we need inverse transform for hit-tests)". The inverse transform is needed in Story 2.4 for `PolygonHitTester` to convert screen-space tap coordinates back to `[0,1]²` normalized space. [Source: game-architecture.md#Map Rendering Pipeline, line 274]

**`Matrix4` viewTransform is the contract.** `WorldMapPainter` (Story 2.2) already accepts `Matrix4 viewTransform` as a constructor parameter. This story changes MapScreen to pass a mutable transform instead of the hardcoded `Matrix4.identity()`. [Source: 2-2 story#Task 6]

**No allocations in gesture hot path.** `_onScaleUpdate` fires on every pointer move frame. It only performs `Matrix4` multiplications (pre-allocated return values) and a `setState` call. No `Paint`, `Path`, or collection allocations. [Source: project-context.md#Performance Rules]

**`shouldRepaint` already handles transform changes.** Story 2.2's `WorldMapPainter.shouldRepaint` returns `true` when `viewTransform != oldDelegate.viewTransform`. Pan/zoom changes the transform every frame → painter repaints → `RepaintBoundary` isolates the repaint from the rest of the widget tree. [Source: 2-2 story#Task 5]

### Implementation Approach

**Unified gesture recognizer.** Flutter's `GestureDetector.onScaleStart`/`onScaleUpdate` unifies one-finger pan and two-finger pinch-zoom into a single `ScaleGestureRecognizer`. When one finger is down, `details.scale == 1.0` and only `localFocalPoint` moves (pan). When two fingers pinch, `details.scale` changes (zoom) and `localFocalPoint` moves to the midpoint (pan + zoom). No need for separate `onPan*` and `onScaleStart`/`onScaleEnd` callbacks.

**Incremental scale tracking.** `ScaleUpdateDetails.scale` is cumulative since `onScaleStart`. To get the per-frame delta, track `_gestureScale` and compute `incrementalScale = details.scale / _gestureScale`. This is the same approach used in the spike. [Source: spike_canvas_screen.dart, lines 117-133]

**Zoom clamping by rejection.** When the computed new zoom would exceed bounds, the frame's zoom is skipped entirely rather than clamping to the boundary. This prevents scale drift artifacts where accumulated small clamping errors cause the map to slowly shift. The spike validated this approach. [Source: spike_canvas_screen.dart, lines 121-125]

**Focal-point zoom math.** The zoom formula `translate(focal) * scale * translate(-focal) * current` ensures the screen point under the user's fingers stays fixed during zoom. This is standard 2D affine zoom-to-point transformation.

**Local state, not Riverpod.** The `Matrix4 _viewTransform` is purely a rendering concern — it doesn't participate in game state, persistence, or cross-widget communication (yet). It lives as widget-local state in `ConsumerStatefulWidget`. Story 2.4 adds tap handling in the same widget and reads `_viewTransform` directly to compute the inverse transform for hit-testing.

**No inertia/fling.** This story implements direct-manipulation pan/zoom only. No momentum scrolling or fling animation. The map stops exactly where the finger lifts. Fling could be added as a polish item in Epic 8 if desired.

### Library/Framework Requirements

- No new packages — all gesture handling uses Flutter core (`package:flutter/gestures.dart` via `GestureDetector`)
- `package:vector_math` — already a transitive dependency via Flutter, used for `Matrix4` operations
- `package:flutter_riverpod` — already a dependency, `ConsumerStatefulWidget` for `MapScreen`

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| MODIFY | `lib/ui/features/map/map_screen.dart` | Convert to `ConsumerStatefulWidget`, add `GestureDetector` + `_viewTransform` state + pan/zoom callbacks |
| CREATE | `test/ui/features/map/map_screen_gesture_test.dart` | Widget tests for pan, zoom, zoom clamping |

### Testing Standards

- **Use `flutter_test`** — widget tests with gesture simulation
- **Override `geoProvider`** with a small fixture (2-3 fake `CountryPath` objects) — never load the real 1.6MB GeoJSON in widget tests
- **Test zoom bounds** — verify clamping at both min (1.0x) and max (15.0x)
- **Test pan** — verify transform changes after drag gesture
- **Test initial state** — verify identity transform before any gestures
- **Two-finger pinch simulation** requires two `TestGesture` instances or a scale gesture simulation helper. Flutter's `WidgetTester` supports this via `startGesture` for multi-touch
- **No `print()`** — `Logger` only, and never in gesture callbacks
- **Do NOT test exact Matrix4 values** for pan — test that the transform is NOT identity (non-trivial assertion). Exact pixel-to-transform math is fragile. For zoom clamping, assert `painter.viewTransform.getMaxScaleOnAxis()` is within `[1.0, 15.0]`

### Anti-Patterns to Avoid

- Do NOT use `InteractiveViewer` — architecture forbids it; it doesn't expose the inverse transform needed for hit-testing [Source: game-architecture.md, line 274]
- Do NOT use separate `onPanStart`/`onPanUpdate` alongside `onScaleStart`/`onScaleUpdate` — Flutter does not allow both on the same `GestureDetector` (they conflict). `onScale*` handles both pan and zoom
- Do NOT clamp the zoom by modifying the scale factor — reject the frame entirely if zoom would exceed bounds (prevents drift)
- Do NOT add `onScaleEnd` with fling/inertia animation — out of scope for this story
- Do NOT store `_viewTransform` in a Riverpod provider — it's local UI state. Converting to a provider is premature until cross-widget access is actually needed
- Do NOT allocate objects inside `_onScaleUpdate` — `Matrix4.translationValues` and `Matrix4.diagonal3Values` return new Matrix4 instances (unavoidable), but do not create `Paint`, `Path`, `List`, or other heavy objects
- Do NOT log inside `_onScaleUpdate` — it fires every pointer-move frame, logging would destroy performance [Source: project-context.md#Performance Rules — "Forbidden in hot paths"]
- Do NOT remove the `RepaintBoundary` around `CustomPaint` — it isolates map repaints from the rest of the widget tree during pan/zoom
- Do NOT use `print()` — `Logger('MapScreen')` only
- Do NOT import `package:flutter/*` in `lib/game/` — all gesture code stays in `lib/ui/`
- Do NOT create a second `Ticker` for animation — if fling were added (it's not), it would need careful coordination with `GameLoop`'s single ticker [Source: project-context.md#Engine-Specific Rules]

### Previous Story Intelligence

**From Story 2-2 (WorldMapPainter — ready-for-dev, not yet implemented):**
- `MapScreen` at `lib/ui/features/map/map_screen.dart` — `ConsumerWidget` that watches `geoProvider`, renders `CustomPaint` with `WorldMapPainter`, passes `Matrix4.identity()` as viewTransform. This story converts it to `ConsumerStatefulWidget` and replaces the identity transform with mutable state
- `WorldMapPainter` accepts `Matrix4 viewTransform` as constructor parameter — applies it via `canvas.transform(viewTransform.storage)` inside `paint()`
- `shouldRepaint` returns `true` when `viewTransform != oldDelegate.viewTransform` — pan/zoom triggers repaint automatically
- `RepaintBoundary` wraps the `CustomPaint` — repaints are isolated
- `CountryColors` ThemeExtension provides all colors — this story doesn't change colors
- `CountryVisualState` enum — irrelevant to this story

**From Story 2-1 (GeoJSON Parser — done):**
- `geoProvider` at `lib/providers/geo_providers.dart` — `FutureProvider<List<CountryPath>>` caches parsed result
- `CountryPath` at `lib/ui/features/map/country_path.dart` — `@immutable` data class with `id`, `continent`, `rings`, `bbox`, `path`
- 304 tests passing after Story 2-1

**From Story 1-11 (Canvas Performance Spike — in-progress):**
- Spike screen at `lib/ui/debug/spike_canvas_screen.dart` has the EXACT pan/zoom pattern this story productionizes:
  - `_viewTransform: Matrix4 = Matrix4.identity()`
  - `_currentScale: double = 1.0` (tracks cumulative gesture scale)
  - `_lastFocalPoint: Offset?` (tracks focal point for delta computation)
  - `_minZoom = 1.0`, `_maxZoom = 15.0`
  - `_onScaleStart`: stores focal, resets cumulative scale
  - `_onScaleUpdate`: pan via `Matrix4.translationValues(delta) * _viewTransform`, zoom via focal-point formula with clamp-by-rejection
  - Uses `GestureDetector` with `onScaleStart`/`onScaleUpdate`
- Spike painter applies transform via `canvas.save()` → `canvas.transform(viewTransform.storage)` → `canvas.scale(size.width, size.height)` → draw → `canvas.restore()` — Story 2.2's `WorldMapPainter` follows this same pattern
- Spike confirmed smooth 60fps pan/zoom on desktop (device profiling pending)

**Key patterns from Epic 1:**
- `@immutable` on all value/data classes
- Manual `==` / `hashCode` (no freezed)
- `Logger('Tag')` for runtime logging (not in hot paths)
- `avoid_print: error` enforced

### Git Intelligence

All code from Epic 1 (Stories 1.1–1.11) and Story 2.1 is in the working tree (uncommitted). Story 2.2 has not been implemented yet (ready-for-dev). This story depends on Story 2.2 being implemented first — `MapScreen` and `WorldMapPainter` must exist before adding gesture handling.

### Project Structure Notes

- `lib/ui/features/map/` will contain `map_screen.dart` (from Story 2.2, modified here), `world_map_painter.dart`, `country_path.dart`, `country_visual_state.dart`, `geojson_parser.dart`, `geo_country_id_mapping.dart`
- `test/ui/features/map/` will contain gesture tests alongside existing parser tests
- No new directories needed — all changes are in existing files/folders
- Spike file `lib/ui/debug/spike_canvas_screen.dart` is the reference implementation — do not import it, write fresh production code informed by its patterns

### Cross-Story Context

- **Story 2.2** (prerequisite, ready-for-dev) creates `MapScreen` and `WorldMapPainter` — this story modifies `MapScreen` to add gesture handling
- **Story 2.4** (next) adds tap handling + hit-testing — will add `onTapUp` to the same `GestureDetector` and use `_viewTransform` to compute the inverse transform for converting screen-space taps to normalized `[0,1]²` coordinates. This is WHY `_viewTransform` is local state in the widget — Story 2.4 accesses it directly
- **Story 2.5** adds `GameWorld.tick()` — unrelated to gestures
- **Story 2.6** adds tap-to-collect — depends on 2.4's hit-testing
- **Epic 7 Story 7-2** creates `AppScaffold` with `IndexedStack` — `MapScreen` from this story becomes one of the 5 tabs. The `IndexedStack` keeps MapScreen alive, preserving the viewTransform state across tab switches
- **Epic 8** (Game Feel) may add fling/momentum animation to pan — would require an `AnimationController` coordinated with the single `Ticker` budget. Out of scope here

### References

- [Source: epics.md#Story 2.3] — User story, acceptance criteria
- [Source: game-architecture.md#Map Rendering Pipeline, line 274] — Custom `GestureDetector` + `Matrix4` viewTransform, no `InteractiveViewer`
- [Source: game-architecture.md, line 144] — Input: `GestureDetector` + custom hit-testing, pan/zoom via transform matrices
- [Source: game-architecture.md, line 196] — Decision #8: Equirectangular projection, `Matrix4` pan/zoom, point-in-polygon hit-test
- [Source: project-context.md#Performance Rules] — No per-frame allocations, no logging in hot paths
- [Source: project-context.md#Engine-Specific Rules] — Single Ticker, no `InteractiveViewer`
- [Source: spike_canvas_screen.dart] — Validated pan/zoom pattern: GestureDetector + Matrix4 + focal-point zoom + clamp-by-rejection
- [Source: 2-2 story] — MapScreen as ConsumerWidget, WorldMapPainter accepts Matrix4 viewTransform, shouldRepaint checks transform

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Converted `_MapView` (already `StatefulWidget` from Story 2.2) to add `_gestureScale`, `_lastFocalPoint` state fields alongside existing `_viewTransform`
- Implemented `_onScaleStart` / `_onScaleUpdate` using unified `ScaleGestureRecognizer` — handles both pan (1-finger) and zoom (2-finger) in one recognizer
- Zoom clamping uses rejection (skip frame) not value-clamping to prevent drift — matches spike pattern
- Focal-point zoom formula: `translate(focal) * scale * translate(-focal) * current`
- Painter caching preserved: new `WorldMapPainter` only allocated when `_viewTransform`, `colors`, or `countries` changes — existing `'reuses the same WorldMapPainter'` test continues to pass
- 329 tests pass (325 prior + 4 new gesture tests); analyze clean; format clean

### File List

- lib/ui/features/map/map_screen.dart
- lib/ui/features/map/country_paints.dart
- lib/ui/features/map/world_map_painter.dart
- test/ui/features/map/map_screen_gesture_test.dart
- test/ui/features/map/world_map_painter_test.dart

## Change Log

- 2026-04-22: Story 2.3 implemented — pan/zoom via GestureDetector + Matrix4 viewTransform; zoom clamped 1x–15x; 4 new gesture widget tests; 329 total tests passing
- 2026-04-22: Code review fixes — (1) extracted `CountryPaints` palette (`lib/ui/features/map/country_paints.dart`) and moved `Paint` allocation out of `WorldMapPainter` constructor so gesture-driven painter rebuilds no longer re-allocate `Paint` objects every frame (addresses "no allocations in gesture hot path" anti-pattern); (2) added `CountryPaints` cache in `_MapViewState` keyed on `CountryColors` identity; (3) added 2 gesture tests — paint-palette identity across gesture frames and post-gesture transform stability (direct AC #4 coverage); (4) corrected Task 1/6.2 descriptions to match implementation; 331 total tests passing
