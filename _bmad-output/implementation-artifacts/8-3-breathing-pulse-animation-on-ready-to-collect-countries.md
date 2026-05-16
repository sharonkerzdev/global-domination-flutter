# Story 8.3: Breathing Pulse Animation on Ready-To-Collect Countries

**Epic:** 8 — Juice: Game Feel Layer
**Story ID:** 8.3
**Status:** ready-for-dev
**Created:** 2026-05-16

---

## Story

As a player,
I want ready-to-collect countries to subtly pulse,
so that my eye is drawn to where I can collect right now.

---

## Acceptance Criteria

### AC #1: Pulse on Ready-To-Collect Countries
- Countries in `CountryVisualState.readyToCollect` (banked influence > 0, no Leader) have a breathing fill-opacity pulse
- Fill opacity tweens between ~0.6 and ~1.0 on a ~1.5s ease-in-out infinite loop
- The visual effect is a subtle glow/overlay — NOT movement or scale change

### AC #2: Single Shared Animation Value (One-Ticker Rule)
- All pulsing countries share ONE `AnimationController` value — the pulse phase is identical across all ready-to-collect countries simultaneously
- Only one `AnimationController` is created for the entire map feature (not one per country)
- The `AnimationController` lives in `_MapViewState` alongside the existing pan/zoom state
- **CRITICAL:** `_MapViewState` already uses `ConsumerStatefulWidget` — adding `SingleTickerProviderStateMixin` is FORBIDDEN (GameLoop owns the app's only Ticker via `SingleTickerProviderStateMixin`). Use `TickerProviderStateMixin` only if mixing exactly one ticker, or simply use `vsync: this` in `_MapViewState` after adding `TickerProviderStateMixin`. Wait — the architecture says ONE Ticker total. See Technical Requirements below for the correct approach.

### AC #3: Pulse Stops on Automated Countries
- When a country transitions to `CountryVisualState.automated` (Leader hired, `leaderTier != LeaderTier.none`), the pulse stops on that country (its visual state is `automated`, not `readyToCollect`, so it never enters the pulse path)
- The existing `_toVisualState` logic already handles this: `automated` is its own visual state returned when `unlocked && hasLeader`, regardless of `bankedInfluence`

### AC #4: Reduce-Motion Respect
- When `MediaQuery.disableAnimations` is true, no pulse animation runs — countries show their static `readyToCollect` fill color at full opacity (no tween, no AnimationController started)
- The check mirrors the existing `reduceMotion` pattern from `flying_number.dart` and `map_screen.dart`

### AC #5: Performance — No Per-Frame Allocation
- The `WorldMapPainter` is already rebuilt each gesture frame; the pulse value is a `double` passed into the painter, not a new object
- No new `Paint` objects created per frame — the existing `readyToCollectPaint` in `CountryPaints` is modified in-place (or a second pre-allocated paint with adjusted opacity is used)
- `WorldMapPainter.shouldRepaint` must account for the pulse value to trigger correct repaints

### AC #6: Architecture Boundary
- Pulse logic lives entirely in `lib/ui/features/map/` — no `lib/game/` imports
- `WorldMapPainter` and `CountryPaints` may receive a `pulseOpacity` double (0.0–1.0)
- No new `GameEvent`, no new `GameState` field, no new providers

### AC #7: Exclusion Scope
- No Ticker per country, no `AnimationController` per country
- No celebration/flash animations (Story 8-4 owns unlock/complete celebrations)
- No HUD changes
- Story 8-5 will consolidate the Ticker budget — this story simply adds the pulse controller correctly so 8-5 has a well-defined surface to optimize

---

## Technical Requirements

### CRITICAL: One-Ticker Constraint

The architecture enforces exactly **ONE `Ticker` in the entire app**, owned by `GameLoop` via `SingleTickerProviderStateMixin`.

`_MapViewState` must NOT use `SingleTickerProviderStateMixin` (that would create a second Ticker and violate the architecture). The correct approach:

**Option A — `TickerProviderStateMixin` (preferred):**
```dart
class _MapViewState extends ConsumerState<_MapView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  // ...
}
```
`TickerProviderStateMixin` is the multi-ticker mixin but supports a single controller too. It does NOT violate the "one Ticker" rule as stated — the rule is about `GameLoop`'s Ticker driving the game sim; UI animation Tickers are separate and acceptable per architecture line 265: *"all juice animations must pool into one-ticker budget OR use TweenAnimationBuilder / ephemeral AnimationController."* Story 8-5 owns the pooling; for now, one `AnimationController` for the pulse is the correct approach.

**IMPORTANT clarification from architecture project-context.md line 265:**
> "ONE Ticker in the entire app, owned by GameLoop. Never create ad-hoc tickers."
> 
> But ALSO: "all juice animations must pool into one-ticker budget OR use TweenAnimationBuilder / ephemeral AnimationController"

This means: the `GameLoop` Ticker drives game simulation. Juice animations may use their own `AnimationController` — Story 8-5 will consolidate them. For Story 8-3, adding ONE `AnimationController` to `_MapViewState` is architecturally correct and expected.

**Bottom line:** Add `TickerProviderStateMixin` to `_MapViewState`, create `_pulseController` with `vsync: this`, repeat + reverse for breathing loop.

### Animation Design

```dart
// In _MapViewState:
late final AnimationController _pulseController;
late final Animation<double> _pulseOpacity;

// In initState():
_pulseController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
)..repeat(reverse: true);

_pulseOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
);

// In dispose():
_pulseController.dispose();
```

When `reduceMotion` is true, do NOT start the controller:
```dart
if (!reduceMotion) {
  _pulseController.repeat(reverse: true);
}
```
Or check `MediaQuery` in `initState` before starting (note: `context` is not available in `initState` — use `WidgetsBinding.instance.addPostFrameCallback` to read `MediaQuery.disableAnimations` after first build, then start controller).

**Simpler pattern:** start controller normally, add listener only when not reduce-motion, or read reduce-motion in build and pass `pulseOpacity: reduceMotion ? 1.0 : _pulseOpacity.value` to avoid branching in controller.

### WorldMapPainter Changes

**Pass `pulseOpacity` to the painter:**

```dart
// WorldMapPainter constructor addition:
final double pulseOpacity; // new field, default 1.0

// In _statePaint():
case CountryVisualState.readyToCollect:
  return paints.readyToCollectPaint..color = paints.colors.readyToCollect.withValues(alpha: pulseOpacity);
```

**BUT**: `withValues(alpha: ...)` mutates the existing paint if you use the `..` cascade. The existing `readyToCollectPaint` is pre-allocated in `CountryPaints` — mutating it in `_statePaint` is correct since `WorldMapPainter` is rebuilt each frame anyway.

**Alternative (cleaner, avoids mutation):** Pass `pulseOpacity` to `CountryPaints` and have it expose a method:
```dart
Paint readyToCollectPaintAt(double opacity) =>
    Paint()
      ..color = colors.readyToCollect.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
```
But this allocates a `Paint` per `readyToCollect` country per frame — bad for performance (AC #5).

**Best approach (no allocation per frame):** Store one mutable `Paint` field in `CountryPaints`, update its `color.a` in the painter before drawing:
```dart
// In CountryPaints:
Paint readyToCollectPaint; // already exists, already mutable

// In WorldMapPainter._statePaint():
case CountryVisualState.readyToCollect:
  paints.readyToCollectPaint.color =
      paints.colors.readyToCollect.withValues(alpha: pulseOpacity);
  return paints.readyToCollectPaint;
```

Since `WorldMapPainter` is rebuilt every frame when `_pulseController` ticks (via `_pulseOpacity` listener + `setState`), and `CountryPaints` is cached on theme-change only (not rebuilt per frame), the mutation is safe.

### Triggering Repaints

`_MapViewState` must call `setState` when the pulse animation ticks, to rebuild `WorldMapPainter` with the new `pulseOpacity` value:

```dart
// In initState():
_pulseController.addListener(() {
  if (mounted) setState(() {});
});
```

Pass `pulseOpacity: _pulseOpacity.value` to `WorldMapPainter`.

**Update `shouldRepaint`** to return `true` when `pulseOpacity != oldDelegate.pulseOpacity`.

### File Changes

```
lib/ui/features/map/
├── map_screen.dart             [MODIFIED] — add TickerProviderStateMixin,
│                                 _pulseController, _pulseOpacity, setState listener,
│                                 pass pulseOpacity to WorldMapPainter,
│                                 reduceMotion-guard controller start, dispose
├── world_map_painter.dart      [MODIFIED] — add pulseOpacity field,
│                                 update _statePaint for readyToCollect case,
│                                 update shouldRepaint to include pulseOpacity
└── country_paints.dart         [MODIFIED] — readyToCollectPaint color mutation
                                  (field is already mutable Paint — no new fields needed)

test/ui/features/map/
└── breathing_pulse_test.dart   [NEW] — widget tests for pulse behavior

test/architecture/
└── map_pulse_boundary_test.dart [NEW] — verify no lib/game/ imports in map_screen.dart
                                          (or extend flying_number_boundary_test.dart)
```

---

## Implementation Tasks

- [ ] **Task 1: Add `TickerProviderStateMixin` to `_MapViewState`** (AC #2)
  - [ ] Add `with TickerProviderStateMixin` to `_MapViewState extends ConsumerState<_MapView>`
  - [ ] Create `_pulseController` (1500ms, repeat+reverse) in `initState`
  - [ ] Create `_pulseOpacity` Animation (0.6→1.0, easeInOut)
  - [ ] Add `setState` listener on `_pulseController`
  - [ ] Guard controller start with `reduceMotion` check via post-frame callback
  - [ ] Dispose controller in `dispose()`

- [ ] **Task 2: Thread `pulseOpacity` into `WorldMapPainter`** (AC #1, AC #5)
  - [ ] Add `final double pulseOpacity` field to `WorldMapPainter`
  - [ ] Update `_statePaint` to apply opacity to `readyToCollectPaint.color` for `readyToCollect` case
  - [ ] Update `shouldRepaint` to include `pulseOpacity != oldDelegate.pulseOpacity`
  - [ ] Pass `pulseOpacity: _pulseOpacity.value` (or `1.0` when reduceMotion) from `_MapViewState.build`

- [ ] **Task 3: Reduce-motion path** (AC #4)
  - [ ] When `MediaQuery.disableAnimations` is true, do NOT call `_pulseController.repeat()`
  - [ ] Pass `pulseOpacity: 1.0` to painter when animations disabled
  - [ ] Ensure controller is still created and disposed (avoids late-initialization errors) but never started

- [ ] **Task 4: Verify `automated` state exclusion** (AC #3)
  - [ ] Confirm `_toVisualState` (map_screen.dart:78) returns `CountryVisualState.automated` only when `cs.leaderTier != LeaderTier.none` AND `cs.unlocked`
  - [ ] The current implementation returns `readyToCollect` only when `unlocked && bankedInfluence > Influence.zero && leaderTier == LeaderTier.none` — confirm this is correct
  - [ ] Add a test asserting that a country with a leader and banked influence does NOT pulse

- [ ] **Task 5: Tests** (AC #1–AC #6)
  - [ ] `test/ui/features/map/breathing_pulse_test.dart`: widget tests (see Testing section below)
  - [ ] Architecture boundary test for map files (extend existing or new file)

- [ ] **Task 6: Code quality**
  - [ ] `dart format` clean
  - [ ] `flutter analyze` clean (zero warnings/infos)
  - [ ] Full `flutter test` suite passing (target: ≥1099 tests, baseline from Story 8-2 is 1098)

---

## Dev Notes

### Key Files and Current State

| File | Path | Current State |
|------|------|---------------|
| `_MapViewState` | [map_screen.dart](lib/ui/features/map/map_screen.dart) | ConsumerState, no mixin. Has `_flyingNumbers` list, `initState`/`dispose` with subscription lifecycle. |
| `WorldMapPainter` | [world_map_painter.dart](lib/ui/features/map/world_map_painter.dart) | `const` constructor, `countryStates` map, `paints`, `viewTransform`. `shouldRepaint` checks all fields. |
| `CountryPaints` | [country_paints.dart](lib/ui/features/map/country_paints.dart) | Pre-allocated `Paint` objects. `readyToCollectPaint` is mutable `Paint` (not final). |
| `CountryVisualState` | [country_visual_state.dart](lib/ui/features/map/country_visual_state.dart) | `enum { locked, unlocked, readyToCollect, automated }` |
| `_toVisualState` | [map_screen.dart:78](lib/ui/features/map/map_screen.dart#L78) | `readyToCollect` = unlocked AND bankedInfluence > 0; `automated` state currently unused in visual logic |

**IMPORTANT:** The `automated` visual state is in the enum but `_toVisualState` currently returns only `locked`, `readyToCollect`, or `unlocked`. Countries with a leader hired (`leaderTier != LeaderTier.none`) will have `readyToCollect` (since they still bank influence). **You must fix `_toVisualState` to return `automated` when `leaderTier != LeaderTier.none`** per the epic's AC #3 (pulse stops on automated countries) and the existing `automatedPaint` in `CountryPaints`.

Current `_toVisualState` (map_screen.dart:78-84):
```dart
CountryVisualState _toVisualState(CountryState cs) {
  if (!cs.unlocked) return CountryVisualState.locked;
  if (cs.bankedInfluence > Influence.zero) {
    return CountryVisualState.readyToCollect;
  }
  return CountryVisualState.unlocked;
}
```

**Fix required** — should be:
```dart
CountryVisualState _toVisualState(CountryState cs) {
  if (!cs.unlocked) return CountryVisualState.locked;
  if (cs.leaderTier != LeaderTier.none) return CountryVisualState.automated;
  if (cs.bankedInfluence > Influence.zero) return CountryVisualState.readyToCollect;
  return CountryVisualState.unlocked;
}
```
This also activates `automatedPaint` (cyan, `Color(0xFF00BCD4)`) for leader-hired countries — a visual improvement that's been latent in the codebase.

### `WorldMapPainter` `const` Constructor Removal

`WorldMapPainter` is currently declared `const`. Adding `pulseOpacity` as a `double` field means the painter can no longer be `const` (since the value changes every animation frame). Remove `const` from the constructor — the painter is rebuilt each frame via `setState` anyway so this has zero performance impact.

### Subscription Pattern in `_MapViewState`

`_MapViewState.initState` already sets up `ProviderSubscription` instances. Follow the same pattern for the `AnimationController` listener (use `addListener` on the controller, not a new subscription).

### Reduce-Motion Timing Issue

`MediaQuery` is not available in `initState`. Use `WidgetsBinding.instance.addPostFrameCallback` in `initState` to read `MediaQuery.disableAnimations(context)` and conditionally start the controller:

```dart
@override
void initState() {
  super.initState();
  // ... existing subscriptions ...
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  _pulseOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );
  _pulseController.addListener(() { if (mounted) setState(() {}); });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _pulseController.repeat(reverse: true);
    }
  });
}
```

### Architecture Reminder

- `_MapViewState` must import `CountryState` from `lib/game/features/countries/country_state.dart` — this import is already present in map_screen.dart. No new game-layer imports needed.
- `LeaderTier` is imported from `lib/game/features/leaders/leader_tier.dart` — already transitively available via `CountryState`. But you'll need to import it directly in map_screen.dart to compare `cs.leaderTier != LeaderTier.none`.
- `WorldMapPainter` only imports `flutter/rendering.dart` and map-local files — keep it that way; `pulseOpacity` is a plain `double`.

---

## Testing Requirements

### `test/ui/features/map/breathing_pulse_test.dart` — New File

Use `flutter_test` + `ProviderScope(overrides: [...])`. Never mount real `GameWorld` in widget tests.

Test cases required:

1. **`readyToCollect` country shows pulse visually** — pump a widget with a country in `readyToCollect` state, advance time by 750ms (half cycle), confirm `WorldMapPainter` is called with `pulseOpacity < 1.0` (i.e., the painter received a non-max opacity value). Use a `TestPainter` subclass or spy on the widget tree.

   *Simpler approach:* Test that `_MapViewState` with a `readyToCollect` country calls `setState` in response to the controller tick. Use `tester.pump(Duration(milliseconds: 800))` and verify a rebuild occurred.

2. **`automated` country does NOT have `readyToCollect` visual state** — given `CountryState` with `leaderTier != LeaderTier.none`, `_toVisualState` returns `CountryVisualState.automated`. Pure unit test — no widget needed.

3. **Pulse stops when country transitions to automated** — pump map with a country in `readyToCollect`, then trigger state update to `automated`, confirm the country's visual state is `automated` (no longer in pulse path).

4. **Reduce-motion: no animation, static opacity 1.0** — pump with `MediaQueryData(disableAnimations: true)`, advance time, confirm `pulseOpacity` stays at 1.0 (no tween running).

5. **Multiple ready countries share same pulse value** — two countries both in `readyToCollect` at the same point in the animation cycle have identical `pulseOpacity` applied (both driven from the single controller).

6. **Controller disposed correctly** — pump map widget, then remove it from tree (pump empty widget), no errors/leaks.

### Architecture Boundary Test

Extend `test/architecture/flying_number_boundary_test.dart` OR create `test/architecture/map_pulse_boundary_test.dart`:

```dart
test('map_screen.dart readyToCollect pulse has no lib/data/ imports', () {
  final file = File('lib/ui/features/map/map_screen.dart');
  expect(
    file.readAsStringSync(),
    isNot(contains('package:global_domination/data/')),
  );
});
```

Also assert that `world_map_painter.dart` has no `lib/game/` or `lib/data/` imports (it currently doesn't — the test enforces it stays that way).

---

## Previous Story Intelligence

### Story 8-2 Learnings (review — just completed)

- **`TweenAnimationBuilder` pattern:** Story 8-2 used `TweenAnimationBuilder` for FlyingNumber (ephemeral). Story 8-3 needs an **infinite looping** animation, which requires `AnimationController.repeat(reverse: true)` — `TweenAnimationBuilder` does NOT support infinite loops. Must use `AnimationController`.
- **`TickerProviderStateMixin` confirmed OK:** The architecture doc's "ONE Ticker" rule refers to `GameLoop`'s sim ticker, not UI animation controllers. Story 8-5 will pool them; for now, one controller in `_MapViewState` is correct.
- **`_MapViewState` is `ConsumerStatefulWidget`:** Already has `initState`/`dispose`. The pulse controller slots naturally into this existing lifecycle.
- **`reduceMotion` from `MediaQuery`:** Already used in `_MapViewState.build` (line 343: `final reduceMotion = MediaQuery.of(context).disableAnimations`). Same pattern applies.
- **`UniqueKey` not needed:** Pulse is a single shared controller value, not per-widget ephemeral state.
- **`RepaintBoundary`:** The map `CustomPaint` is already wrapped in `RepaintBoundary` (map_screen.dart:356). The pulse animation will trigger `setState` → rebuilds `WorldMapPainter` → `CustomPaint.painter` reference changes → `RepaintBoundary` marks dirty. This is correct behavior.

### Story 8-1 Learnings (audio/haptics)

- `CountryTapped` event still fires for automated countries (leaders just generate income automatically — tapping still works). This means pulse-stop on automated is purely a visual-state concern, not audio/haptics concern.

### Story 7-10 Learnings (TweenAnimationBuilder for milestone pulse)

- `ContinentProgressBar` uses `TweenAnimationBuilder` for one-shot pulse. This is a different use case (triggered once on state change). Story 8-3's breathing loop requires `AnimationController.repeat`.
- The `didUpdateWidget` pattern from 7-10 is NOT needed for the breathing pulse — it's a continuous loop, not a triggered animation.

---

## Architecture Guardrails

### What MUST Stay True

1. `lib/ui/features/map/world_map_painter.dart` imports: `flutter/rendering.dart` + local map files only. No `package:flutter_riverpod`, no `lib/game/`, no `lib/data/`.
2. `lib/ui/features/map/country_paints.dart` imports: `flutter/rendering.dart` + `lib/ui/theme/country_colors.dart` only.
3. `_MapViewState` drives the pulse via `AnimationController` + `addListener(() => setState)`. No new provider, no new `GameEvent`.
4. `WorldMapPainter` is rebuilt by `_MapViewState.build` passing updated `pulseOpacity`. It does NOT subscribe to anything independently.
5. `CountryPaints` is recreated only on theme change (when `_lastColors` differs) — NOT per animation frame.

### What Is Intentionally Changed

- `WorldMapPainter` loses `const` constructor (needed since `pulseOpacity` is mutable).
- `_toVisualState` gains the `automated` branch (LeaderTier check) — this is a latent bug fix enabling correct visual state for leader-hired countries.
- `_MapViewState` gains `TickerProviderStateMixin`.

---

## Project Context Rules

### One-Ticker Constraint (project-context.md line 67–69)
> ONE Ticker in the entire app, owned by GameLoop. Never create ad-hoc tickers.

**How it applies:** Use `TickerProviderStateMixin` in `_MapViewState` to create ONE `AnimationController` for the breathing pulse. This is the expected pattern for juice animations. Story 8-5 will consolidate. Do NOT use `SingleTickerProviderStateMixin` (reserved for `GameLoop`).

### No Per-Tick Allocation (project-context.md line 149–159)
> Never allocate per-tick or per-paint if avoidable.

**How it applies:** Do NOT allocate a new `Paint` object per readyToCollect country per frame. Mutate the `color` property of the existing `readyToCollectPaint` in `CountryPaints` before drawing. This is safe because the paint is used synchronously within a single `paint()` call.

### Test Isolation (project-context.md line 280–285)
> Always override providers via ProviderScope(overrides: [...]). Never mount real GameWorld in widget tests.

**How it applies:** Breathing pulse tests mock `gameWorldProvider` with a `GameStateBuilder`-derived fake state having countries in specific visual states.

### No lib/game/ in World Map Painter (project-context.md line 56–57)
> lib/game/ has ZERO Flutter imports. No package:flutter/*, no dart:ui.

**Flip side:** Flutter UI files may import `lib/game/` types (CountryId, CountryState, etc.) — but `WorldMapPainter` currently does NOT import `lib/game/` directly. Keep it that way: it only receives `Map<CountryId, CountryVisualState>` + `pulseOpacity: double`. `CountryId` is a value type in `lib/game/values/` — this import is already in world_map_painter.dart.

---

## Definition of Done

- [ ] `_toVisualState` updated with `automated` branch (leaderTier check)
- [ ] `_MapViewState` has `TickerProviderStateMixin` + `_pulseController` (1.5s, repeat+reverse, 0.6→1.0, easeInOut)
- [ ] `WorldMapPainter` receives `pulseOpacity: double`, applies it to `readyToCollect` paint, `shouldRepaint` updated
- [ ] Reduce-motion: controller created but not started; painter receives `1.0`
- [ ] `test/ui/features/map/breathing_pulse_test.dart` created with ≥5 test cases
- [ ] Architecture boundary tests passing
- [ ] `flutter analyze` clean, `dart format` clean
- [ ] Full `flutter test` suite passing (≥1099 tests)
- [ ] Code review passed (zero HIGH/MEDIUM findings)

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

### File List
