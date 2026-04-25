# Epic 9: Onboard — Tutorial and Contextual Hints

**Goal:** First-time players get a guided tutorial through the core loop (tap, upgrade, hire Leader, unlock). Steps auto-advance on the triggering action. Progress survives restart. Post-tutorial one-time hints fire on new-system first-exposures.

### Story 9.1: Tutorial State, Persistence, and Overlay UI

As a developer and first-time player,
I want tutorial state managed in `GameWorld`, persisted via Drift, and rendered as a spotlight overlay that guides me through the core loop,
So that the tutorial survives app restarts and I learn the game without trial and error.

**Acceptance Criteria:**

**Given** a fresh install
**When** the app boots
**Then** `state.tutorial.currentStepId == 'tap_to_collect'` (first step), `completed == false`.

**Given** I complete a tutorial step
**When** `AdvanceTutorial(stepId)` dispatches
**Then** `currentStepId` moves to the next step per the tutorial script in content JSON, a `TutorialAdvanced` event fires, and the `tutorial_state` Drift row updates.

**Given** I close and relaunch the app mid-tutorial
**When** the app loads
**Then** `state.tutorial.currentStepId` loads from Drift and the tutorial resumes at the same step.

**Given** `state.tutorial.currentStepId != null` and `completed == false`
**When** the app renders
**Then** a `TutorialOverlay` renders above the current screen with a dim layer, a spotlight cutout at the step's target (screen-space Rect defined in the step data), and a step card with text + optional arrow.

**Given** the tutorial is active
**When** I interact with non-target UI
**Then** that interaction is blocked by the overlay's IgnorePointer layer — only the spotlit target is tappable.

**Given** the tutorial is active
**When** the target is on a different tab (e.g. step 9+ is on Leaders tab)
**Then** the overlay coordinates with the tab system to switch tabs before spotlighting — or the step explicitly instructs me to tap the Leaders tab (which is its own spotlit target).

### Story 9.2: Auto-Advance on Triggering Action

As a player,
I want the tutorial to advance automatically when I perform the action it's teaching (e.g. tap a country → next step),
So that I don't have to tap "Next" after doing exactly what I was told.

**Acceptance Criteria:**

**Given** a tutorial step whose trigger is "`CountryTapped`" (or a specific action condition like "IP reaches 10")
**When** that event fires
**Then** the step auto-advances via an `AdvanceTutorial` command.

**Given** a step with no game-event trigger (pure informational)
**When** displayed
**Then** its step card has a "Next" button that dispatches `AdvanceTutorial`.

**Given** the final tutorial step
**When** advanced
**Then** `state.tutorial.completed = true`, `TutorialCompleted` event fires, and the overlay unmounts permanently.

### Story 9.3: Skip Tutorial Option (Returning Player)

As a returning player or a genre-familiar player,
I want a "Skip Tutorial" button,
So that I can jump straight to playing without being forced through basics I already know.

**Acceptance Criteria:**

**Given** the tutorial overlay is visible
**When** I tap a "Skip" button on the step card
**Then** a confirmation dialog asks "Skip tutorial? You can replay it from Settings." and two buttons (Cancel, Skip).

**Given** I confirm Skip
**When** the command dispatches
**Then** `state.tutorial.completed = true`, `state.tutorial.skipped = true`, `TutorialSkipped` fires, and the overlay unmounts.

**Given** a Settings option "Replay Tutorial"
**When** tapped
**Then** `state.tutorial.completed = false`, `currentStepId = 'tap_to_collect'`, and the overlay re-appears (useful for QA and curious players).

### Story 9.4: Post-Tutorial Contextual Hints (One-Shot)

As a player who finished the tutorial,
I want a one-time contextual hint the first time I encounter a new system (Golden Opportunity, Boost-ready, Leader-eligible, milestone approaching),
So that new mechanics don't surprise me without explanation.

**Acceptance Criteria:**

**Given** `state.tutorial.completed == true` and a Golden spawns for the first time ever
**When** the player's view can see the Golden
**Then** a hint tooltip pops near it saying "Golden Opportunity! Tap for a huge burst" and auto-dismisses after 4 seconds.

**Given** `state.tutorial.hintsShown['golden'] == true`
**When** a subsequent Golden spawns
**Then** no hint shows.

**Given** the same pattern for hints keyed by event/condition: `boost_ready`, `leader_eligible` (first time any country hits IP 10), `milestone_approaching` (first time a continent crosses 20% completion)
**When** each condition first occurs
**Then** the matching hint shows once and is recorded in `hintsShown`.

---
