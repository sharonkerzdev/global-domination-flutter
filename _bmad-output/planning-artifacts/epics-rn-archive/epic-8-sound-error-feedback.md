# Epic 8: Sound & Error Feedback

Make error states visible to users and provide audio feedback for meaningful game actions.

## Story 8.1: Implement Sound System

As a player,
I want sound effects to play when I collect, unlock, or achieve something,
So that the game feels alive and responsive.

**Acceptance Criteria:**

**Given** `soundSystem.ts` is a stub and 5 `.mp3` files exist in `assets/sounds/`
**When** implementation is complete
**Then** sounds load and play for `collect`, `golden`, `milestone`, `unlock`, and `upgrade` effects
**And** the `soundEnabled` setting controls playback
**And** the Settings screen sound toggle works correctly

## Story 8.2: Add User-Facing Save/Load Error Handling

As a player,
I want to know if my game failed to save or load,
So that I can retry instead of silently losing progress.

**Acceptance Criteria:**

**Given** `saveSystem.ts` catches all errors with `console.warn` only
**When** a save or load fails
**Then** a toast or alert informs the player of the failure
**And** a retry mechanism is available
**And** the dead save-version check code path is removed or made functional

## Story 8.3: Add Empty and Error State UI

As a player,
I want to see a helpful screen if my game data is missing or corrupted,
So that I can start fresh instead of seeing a broken layout.

**Acceptance Criteria:**

**Given** no empty-state or error-state UI exists
**When** game data fails to initialize or loads as empty
**Then** the app displays a clear message with options ("Start New Game", "Retry")
**And** no broken or half-rendered game screen is shown

---
