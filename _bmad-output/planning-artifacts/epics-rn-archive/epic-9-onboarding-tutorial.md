# Epic 9: Onboarding & Tutorial

New players learn the game through a 12-step interactive tutorial that spans the Map and Leaders tabs. Post-tutorial contextual hints guide players through first encounters with key features.

## Story 9.1: Update Tutorial State and Store

As a developer,
I want the store to support a 12-step tutorial with contextual hints,
So that the new FTUE flow has proper state management.

**Acceptance Criteria:**

**Given** the current tutorial has 5 steps (0-4)
**When** the update is complete
**Then** `tutorialStep` range is 0-12
**And** a new `tutorialHints: Record<string, boolean>` state field tracks one-time hints (keys: 'golden', 'boost', 'milestone', 'leader_nudge')
**And** a `markHintShown(hintId: string)` action exists
**And** auto-advance triggers are updated:
- Step 1 > 2: on first `unlockCountry`
- Step 3 > 4: on first `collect`
- Step 7 > 8: on first `purchaseUpgrade`
- Step 11 > 12: on first `purchaseLeader`
- Step 12: sets `tutorialCompleted = true`
**And** existing saves with `tutorialCompleted === false` and `tutorialStep > 0` reset to step 0
**And** `SAVE_VERSION` is bumped in `saveSystem.ts`

## Story 9.2: Rewrite Tutorial Overlay

As a new player,
I want a guided 12-step tutorial that teaches me tapping, upgrading, and hiring leaders,
So that I understand the game within my first session.

**Acceptance Criteria:**

**Given** a fresh game (`tutorialCompleted === false`, `tutorialStep === 0`)
**When** the game starts
**Then** the 12-step tutorial begins:
- Steps 0-8: render over GameScreen (map tab) — welcome, unlock first country, collect, spotlight milestone, long-press to upgrade
- Steps 9-12: render over LeadersScreen — spotlight Leaders tab, continent card, hire first leader, celebration
**And** the tutorial uses SVG mask spotlight with circle cutout
**And** each step has a "Next" button and "Skip Tutorial" option
**And** auto-advance steps wait for the corresponding game action
**And** step 9 programmatically switches to the Leaders tab
**And** step 0 uses `focusOnCountry` to auto-zoom to the first country
**And** the TutorialOverlay renders in App.tsx (above screens, below modals, z-index 200)
**And** gestures are disabled during spotlight steps

## Story 9.3: Add Contextual One-Time Hints

As a player,
I want brief tips the first time I encounter golden opportunities, boosts, milestones, and leader availability,
So that I learn the game naturally after the tutorial.

**Acceptance Criteria:**

**Given** the tutorial is completed
**When** the player encounters a feature for the first time:
- First golden opportunity spawn: "A Golden Opportunity! Tap the glowing country for bonus Influence!"
- First BoostPill appearance: "Tap to activate a temporary boost!"
- First milestone glow: "Long-press to upgrade — a Leader is almost available!"
- First affordable leader: "You can hire your first Leader!" (near Leaders tab)
**Then** a small floating hint card appears at z-index 120
**And** each hint auto-dismisses after 4 seconds or on tap
**And** each hint shows exactly once, tracked via `tutorialHints` in store

---
