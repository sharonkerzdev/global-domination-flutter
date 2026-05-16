# Story 8-2: Flying Number Animation on Country Tap

**Epic:** 8 — Juice: Game Feel Layer  
**Story ID:** 8.2  
**Status:** done  
**Created:** 2026-05-16  

---

## Story Overview

When a player taps a country to collect influence, display an animated floating number that flies upward from the tap point and fades out, showing the collected influence amount. This visual feedback makes the economic core feel responsive and satisfying.

---

## User Story

As a player tapping countries for influence,  
I want to see a floating number animation showing how much influence I just collected,  
So that I have immediate visual feedback confirming the collection and understanding the economic impact.

---

## Acceptance Criteria

### AC #1: Flying Number Display
- When CountryTapped is processed and collected influence > 0, a floating number appears at the tap point
- Number displays the collected influence amount (banked → total transfer)
- Text is formatted consistently with existing currency display (no decimal for whole numbers, token-styled)

### AC #2: Animation Arc
- Number animates vertically upward over ~1 second, moving ~100-150 logical pixels
- Opacity smoothly fades from 1.0 → 0.0 over the same duration
- Animation uses easeOut timing (decelerating motion)
- No bounce or overshoot—simple, clean exit

### AC #3: Tap-Point Positioning
- Animation originates from the tapped country's centroid or nearest on-screen position
- If country is partially off-screen, animation still originates from the tap coordinate projected to the screen
- Multiple simultaneous taps can trigger multiple flying numbers (no batching/suppression)

### AC #4: Isolation from Core Game Loop
- Flying number animation does NOT block or delay countryTapped game event processing
- Animation state is UI-only; game state tick/influence collection happens independently
- If country/map is panned/zoomed during animation, number continues from last-known position (no live tracking)

### AC #5: Exclusion Scope
- NO shared Ticker budget with other animations (Story 8-5 owns that consolidation)
- NO haptics/audio coordination (Story 8-1 already handled feedback)
- NO celebration/special animations for unlocks (Story 8-4 owns that)
- Can reuse TweenAnimationBuilder from Story 7-10's pulse precedent if simpler than AnimationController

### AC #6: Edge Cases
- Zero-collected influence (CountryTapped with banked==0 after collection) → NO flying number
- Country unlocked on same tap (UnlockCountry + CountryTapped batch) → show flying number for collected influence only, not unlock state
- Very rapid taps (same country, <100ms apart) → each tap gets its own flying number (no dedup)

### AC #7: Accessibility
- Flying number must be readable at system font scale (no text clipping)
- Animation duration respects platform semantics (use constant, allow animation-off via MediaQuery.boldText or similar platform API)
- If animations globally disabled, number still appears but skips fade/translate (appears 0.5s, static position)

---

## Technical Requirements

### Architecture Compliance
- **One-Ticker Rule:** This story DOES NOT use a Ticker/SingleTickerProviderStateMixin. Use TweenAnimationBuilder per Story 7-10 precedent or pure AnimationController initialized per-animation (ephemeral, disposed immediately when complete).
- **Game/UI Boundary:** Flying number logic is UI-only. NO new GameEvent variants or game state mutations required. The number is purely visual feedback downstream of CountryTapped processing.
- **Provider Isolation:** No new providers required. FlyingNumber widget is local state within MapScreen or custom overlay managed by ConsumerWidget.

### Widget Integration Points
- **MapScreen (lib/ui/features/map/map_screen.dart):** Current TapCountry handler in `_onTapUp(TapUpDetails)` must signal the UI layer with (offset, influenceCollected) after game logic executes.
- **Overlay Layer:** Flying numbers should be rendered in a Stack or Overlay above the map but below modal dialogs. Consider a `_FlyingNumberLayer` StatefulWidget or Consumer reacting to a transient provider that emits (offset, amount, timestamp) tuples.

### Animation Details
- **Duration:** 1.0 second (const `_flyingNumberDuration = Duration(milliseconds: 1000)`)
- **Vertical Distance:** 120 logical pixels (const `_flyingNumberDistance = 120.0`)
- **Timing Curve:** Curves.easeOut
- **Opacity:** Tween<double>(begin: 1.0, end: 0.0)
- **Font Style:** Reuse HudPalette.labelLarge or CurrencyBadge text style for visual consistency

### Implementation Patterns
- **TweenAnimationBuilder Approach (Preferred):** Create a `FlyingNumberWidget(offset, amount, key: UniqueKey())` that internally uses TweenAnimationBuilder for position + opacity, auto-disposes when animation completes via `onEnd` callback removing it from parent Stack/Overlay.
- **AnimationController Approach (Alternative):** Create `FlyingNumber` ConsumerWidget managing ephemeral AnimationController, firing onEnd → callback to parent to remove it.

### Data Flow
1. **CountryTapped Event:** Game processes, emits `CountryTapped(countryId, collectedInfluence, ...)` with `collectedInfluence > 0`
2. **MapScreen._onTapUp:** After game.applyCommand(TapCountry), read gameWorldProvider to check latest state, extract collectedInfluence delta from event
3. **UI Emission:** Add flying-number entry to a transient `Stack` or `Overlay.of(context).insert()` with UniqueKey so multiple can coexist
4. **Auto-Cleanup:** After animation completes (1s), TweenAnimationBuilder's `onEnd` callback removes the widget

---

## Previous Story Intelligence

### Story 8-1 Learnings (Completed ✓)
- **Audio/Haptics Services Architecture:** Services inject AudioBackend/HapticsBackend interfaces, attach() on bootstrap, subscribe to gameWorldEventsProvider
- **Event Exhaustive Switch:** CountryTapped must NOT change how feedback services operate; flying number is independent visual feedback
- **No New Events:** Reuse existing CountryTapped event; flying number is NOT a new game event variant
- **Rate Limiting:** Story 8-1's 70ms tap rate limit on audio does NOT apply to flying numbers—show all taps
- **Test Pattern:** Use FakeAudioBackend/FakeHapticsBackend helpers; flying number tests can use fake event streams via WidgetTester.pumpAndSettle

### Story 7-10 Animation Precedent (Completed ✓)
- **TweenAnimationBuilder:** ContinentProgressBar uses TweenAnimationBuilder for milestone-reach pulse; *this* story should reuse that pattern for simplicity
- **didUpdateWidget Reactivity:** Flying number does NOT need didUpdateWidget since it's ephemeral (no state update expected mid-animation)
- **StatefulWidget Tracking:** No need for `_previousTiers` equivalent; just create widget, animate, dispose
- **Color/Styling:** Access HudPalette theme extension for label colors; ensure text is readable at large font scales

### Story 7-9/7-10 Map Context (Completed ✓)
- **MapScreen State:** _MapViewState manages pan/zoom matrix via GestureDetector; flying numbers originate from tap offset (Offset) in screen coordinates
- **post-frame callback:** _MapViewState uses addPostFrameCallback for one-shot effects; consider similar pattern for flying-number cleanup if using Overlay
- **No Breaking Changes:** MapScreen._onTapUp must remain idempotent; flying number is pure addition to tap feedback pipeline

---

## Architecture Guardrails

### File Structure
```
lib/ui/features/map/
├── flying_number.dart          [NEW] FlyingNumber widget + constants
└── map_screen.dart             [MODIFIED] integrate flying number on tap

test/ui/features/map/
└── flying_number_test.dart     [NEW] animation rendering + edge cases
```

### Imports & Boundaries
- `flying_number.dart`: imports lib/theme/*, Flutter material (Offset, Curves, Animation, etc.), NO lib/game/ or lib/providers/
- `map_screen.dart`: imports flying_number.dart; tap handler remains pure game-logic pass-through
- Tests: mock MapScreen context, WidgetTester.pumpAndSettle to await animation completion

### Design System Reuse
- **Typography:** `HudPalette.labelLarge` or `CurrencyBadge` text style for number formatting
- **Colors:** Use `HudPalette.onSurface` for text; consider ForegroundColor or `ColorScheme.primary` for emphasis
- **Spacing:** Tap offset is already in screen coordinates (Offset from GestureDetector.onTapUp); no extra conversion needed

### Testing Standards
- **Widget Test:** Create flying-number-test.dart covering:
  - Animation renders with correct number and position
  - Opacity fades from 1.0 → 0.0
  - Y-position translates upward ~120px
  - onEnd callback fires after ~1s
  - Zero-amount case: no widget created
  - Rapid taps: multiple flying numbers coexist without interference
- **No Integration Test Required:** Pure animation—no async I/O or device interaction
- **Architecture Boundary Test:** flying_number.dart imports allowlist (no lib/game/, no lib/data/) via grep in architecture_tests.dart

---

## Project Context Rules

### Relevant Excerpts from project-context.md
- **One-Ticker Constraint (line 265):** "Game loop owns singleton Ticker; all juice animations must pool into one-ticker budget OR use TweenAnimationBuilder / ephemeral AnimationController." → This story uses TweenAnimationBuilder per precedent.
- **Game/UI Boundary (line ~100):** "lib/game/ is import-clean from Flutter widgets; UI receives events, never queries game state mid-frame." → Flying number widget receives CollectedInfluence amount from MapScreen callback, does NOT read gameWorldProvider.

### Drift/Persistence
- Flying numbers are ephemeral animations; NO persistence required. Game state (collected influence) is already persisted by Story 6-2's SaveRepository.

### Content Registry
- No new content files needed. Tap feedback is hardcoded animation, not data-driven.

---

## Latest Technical Specifics

### Flutter Animation APIs (Current)
- **TweenAnimationBuilder:** Available in Flutter 2.0+, well-tested for one-shot animations; preferred over AnimationController for simple tweens.
- **Offset + Transform:** Use Transform.translate(offset: Offset(0, dy), child: Opacity(...)) or Positioned for precise positioning in Stack.
- **Curves.easeOut:** Built-in timing function, matches material-design deceleration guidelines.

---

## Git Intelligence

### Recent Commits (Last 5)
1. `f8eed5d` feat: continent progression, audio/haptics services, and continent features UI
2. `dc5c571` feat: continent progression, leaders grouping, map auto-focus, and upgrades UI
3. `a6bbe42` feat(ui): priority modal queue, stats screen, and settings overlay
4. `8a74e35` feat(ui): global HUD, currency badges, stats and settings
5. `0db66e0` feat(ui): extract AppScaffold with IndexedStack and Minigames tab

### Patterns Observed
- **Widget Composition:** Recent PRs reuse existing providers (statsProgressSummaryProvider pattern) and theme extensions (MilestoneColors, HudPalette)
- **Animation Precedent:** Story 7-10's ContinentProgressBar shows TweenAnimationBuilder for simple animations is preferred; no new Ticker complexity
- **Test Structure:** Provider + widget tests coexist; map tests override gameWorldProvider for isolation
- **Code Organization:** New UI features create focused files (e.g., continent_progress_bar.dart) rather than monolithic screens

---

## Implementation Checklist

### Pre-Implementation
- [x] Review Story 8-1 audio/haptics testing patterns for event-stream mocking
- [x] Review Story 7-10 ContinentProgressBar TweenAnimationBuilder implementation
- [x] Check MapScreen._onTapUp current structure and data flow post-Story 7-9

### Core Implementation
- [x] Create lib/ui/features/map/flying_number.dart with FlyingNumber widget
- [x] Define animation constants: duration=1s, distance=120px, curve=easeOut
- [x] Implement tap-point capture in MapScreen._onTapUp after game.applyCommand
- [x] Wire FlyingNumber into MapScreen via Stack or Overlay layer
- [x] Ensure multiple simultaneous taps each get their own flying number (no dedup)

### Testing
- [x] Create test/ui/features/map/flying_number_test.dart
- [x] Test animation rendering, fade, position delta
- [x] Test onEnd cleanup callback
- [x] Test zero-amount edge case
- [x] Add architecture boundary test for import allowlist

### Code Quality
- [x] dart format clean
- [x] flutter analyze clean (no warnings/infos)
- [x] Full flutter test suite passing (target: >1100 tests)

### Regression Check
- [x] Map pan/zoom functionality unaffected by tap changes
- [x] Game loop tick/influence collection unaffected
- [x] Story 8-1 audio/haptics still fire on CountryTapped
- [x] Confirm visual styling matches existing HUD (font, colors, spacing)

---

## Success Criteria Summary

**Developer Completion:** Flying number animation renders on every country tap with collected influence > 0, animates upward and fades out over 1 second, is purely UI-isolated, and passes all edge-case tests.

**Player Perception:** Collecting influence feels responsive and satisfying; floating number confirms economic impact immediately.

**Code Quality:** Zero architecture violations, full test coverage, zero regressions in game loop or existing UI.

---

## Notes for Developer

1. **CountryTapped Event Timing:** The game loop processes CountryTapped synchronously in applyCommand → applies reducer → emits event. MapScreen can read the result immediately after await or subscribe to gameWorldEventsProvider; flying number callback must execute after game state is finalized to avoid showing stale influence amounts.

2. **Tap Coordinate System:** GestureDetector.onTapUp provides Offset in local RenderBox coordinates. Ensure offset is translated to screen/overlay coordinates if flying number lives in a different layer (e.g., Overlay vs. within map Canvas).

3. **Animation Cleanup:** TweenAnimationBuilder's onEnd callback is the cleanest way to auto-remove the widget. If using AnimationController directly, ensure dispose() is called immediately after animation completes; no lingering listeners or memory leaks.

4. **Platform Semantics:** Check MediaQuery.boldTextOf or Theme.of(context).disableAnimations to respect system animation settings. Adjust duration or skip animation if disabled, but always show the number.

5. **No Game State Coupling:** Flying number amount comes from the tap handler's post-game-update read, NOT a provider watch. This keeps the animation truly ephemeral and avoids unexpected rebuilds if game state changes later.

---

## Definition of Done

- [x] Story file created with comprehensive context
- [x] Implementation complete: flying-number widget, map integration, edge cases
- [x] All acceptance criteria verified via manual/automated testing
- [x] Test suite passing: 1098 tests (Story 8-1 baseline was 1085)
- [x] Code review passed (zero HIGH/MEDIUM findings)
- [x] Regression-tested against Epic 7 UI + Story 8-1 audio

### Review Findings

- [x] [Review][Patch] Clamp flying-number bounds so edge taps and large text scales cannot clip [lib/ui/features/map/flying_number.dart:60]
- [x] [Review][Patch] Add MapScreen integration tests for positive/zero tap flyout behavior [test/ui/features/map/map_screen_tap_test.dart:123]

---

**Last Updated:** 2026-05-16  
**Ready for Development:** YES

---

## Dev Agent Record

### Implementation Plan
- Used `TweenAnimationBuilder<double>` (t: 0→1, easeOut, 1s) per Story 7-10 precedent — no AnimationController/Ticker
- `_onTapUp` reads `bankedInfluence` before `apply(TapCountry(...))`, then adds a `_FlyingEntry` with the formatted amount and screen offset if banked > 0 (zero-amount suppression built in)
- `_FlyingEntry` holds `amount`, `offset`, and a `UniqueKey` so multiple simultaneous taps each get independent animations
- `FlyingNumber` widget: `Positioned` inside parent `Stack`, `Opacity` driven by `1.0 - t`, Y-translation by `-120 * t` px; `onEnd` callback removes the entry from `_flyingNumbers`
- `reduce-motion` path: `_StaticFlyingNumber` StatefulWidget uses `Future.delayed(500ms)` to call `onEnd`, no translate/fade
- Architecture boundary: `flying_number.dart` imports only `flutter/material.dart` and `lib/ui/theme/hud_palette.dart`

### Completion Notes
- All 7 ACs satisfied: animation displays, arc + opacity correct, positioned at tap point, UI-isolated from game loop, exclusion scope respected, edge cases (zero, rapid taps, unlock batch) handled, reduce-motion respected
- 16 story tests/guards added: rendering, animation lifecycle (opacity/position/onEnd), bounds clamping, multi-number coexistence, reduce-motion static display, MapScreen positive/zero flyout behavior, and import boundaries
- 4 architecture boundary tests added in `test/architecture/flying_number_boundary_test.dart`
- Full test suite: 1101 passing, flutter analyze clean, dart format clean
- Code review patch pass: `FlyingNumber` now clamps measured text inside the overlay for edge taps and large text scale; `MapScreen` tap tests cover positive flyout creation, cleanup, and zero-amount suppression.

---

## File List

**New files:**
- `lib/ui/features/map/flying_number.dart`
- `test/ui/features/map/flying_number_test.dart`
- `test/architecture/flying_number_boundary_test.dart`

**Modified files:**
- `lib/ui/features/map/map_screen.dart`
- `_bmad-output/implementation-artifacts/8-2-flying-number-animation-on-country-tap.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

---

## Change Log

- 2026-05-16: Story 8-2 code review patches applied - bounds clamping + MapScreen integration regressions; story marked done

- 2026-05-16: Story 8-2 implemented — FlyingNumber widget + MapScreen integration + tests (1098 passing)
