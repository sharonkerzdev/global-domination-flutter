# Epic 11: Harden — Accessibility and Performance

**Goal:** Every interactive widget wrapped in `Semantics`. Non-color cues on country states. Touch targets meet platform minimums. 60fps sustained on low-end Android. Cold start < 3s. App size < 50MB.

### Story 11.1: Accessibility Pass — Semantics, Non-Color Cues, and Touch Targets

As a player using a screen reader, having color blindness, or with limited dexterity,
I want every interactive element to be screen-reader labelled, distinguishable without color, and large enough to tap reliably,
So that the game is playable regardless of accessibility needs.

**Acceptance Criteria:**

**Given** any interactive widget (ElevatedButton, InkWell, GestureDetector wrapping a tappable region, etc.)
**When** the widget tree is inspected (widget test)
**Then** it is wrapped in a `Semantics` widget with a `label` and, where applicable, `value`, `hint`, and `button: true` or `enabled: false`.

**Given** map countries (rendered via `CustomPainter`, not widgets)
**When** a screen reader focuses the map region
**Then** a `Semantics` layer or `MergeSemantics` exposes focusable country regions each announced as "{countryName}, {state}, tap to {action}" — exact implementation documented in the story.

**Given** widget tests
**When** run with a11y checks
**Then** no interactive widget is missing a label.

**Given** a country in each state (locked / generating / ready / automated)
**When** rendered
**Then** it has a non-color cue in addition to fill color: locked = no border animation, generating = empty, ready = breathing pulse (Epic 8), automated = subtle dotted or solid outline pattern.

**Given** a high-contrast simulation or color-blind filter applied
**When** the map renders
**Then** all four states are distinguishable (verified by visual review during QA — no automated check).

**Given** any tappable widget in UI code
**When** audited
**Then** its hit-area is at least `Size(44, 44)` logical px (iOS standard) or wraps a larger-padding area around smaller visuals.

**Given** country hit-testing on the map
**When** a country renders small at low zoom
**Then** the hit-test accepts taps within a small radius around tiny-country polygons (documented padding in px), making them reachable without maxing zoom.

### Story 11.2: Cold-Start Performance Profiling and Fix

As a player launching the app
I want cold start to be under 3 seconds on mid-range devices,
So that the game feels responsive and I don't lose interest before it loads.

**Acceptance Criteria:**

**Given** a profile build on a mid-range target device (iPhone 12 / Pixel 5-class)
**When** I cold-launch (app fully killed, device cold)
**Then** time from tap-app-icon to interactive map is ≤ 3.0 seconds measured with `Timeline` events or Flutter DevTools.

**Given** a profile run
**When** the startup trace is analyzed
**Then** GeoJSON parsing, content JSON loading, and Drift boot are identified; any single step > 500ms is optimized (deferred parsing, background isolate, cached Path blob, etc.) until the total fits under 3s.

### Story 11.3: 60fps Map Performance on Low-End Android (API 21)

As a player on a low-end Android device,
I want the world map to pan, zoom, and display animations at 60fps,
So that the core gameplay surface feels smooth regardless of my phone.

**Acceptance Criteria:**

**Given** a low-end Android API 21 device (emulator or physical)
**When** I pan, zoom, tap, and interact with active animations (flying numbers, pulses)
**Then** sustained fps measured via Flutter DevTools stays at 60fps ± occasional drops ≤ 5 frames.

**Given** the canvas performance spike from Story 1.11 identified any hot paths
**When** Epic 11 runs
**Then** those optimizations are implemented (e.g. `Path → Picture` cache invalidated only on country-state version change).

### Story 11.4: App Size Under 50MB

As a player downloading the app
I want the install footprint to be under 50MB,
So that the download is fast and doesn't fill my storage.

**Acceptance Criteria:**

**Given** a release build via `flutter build appbundle` and `flutter build ipa`
**When** the output is measured
**Then** the base APK/AAB is ≤ 50MB and the iOS IPA is ≤ 50MB.

**Given** assets audit
**When** performed
**Then** no redundant GeoJSON variants, no unused SFX files, and unused platform folders (web/windows/macos/linux) are either removed or confirmed to not contribute to mobile build size.

---

