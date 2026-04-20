# Epic 2: Dead Code Cleanup & Code Hygiene

Remove unused code, resolve orphan components, and extract inline definitions to improve maintainability.

## Story 2.1: Resolve Orphan Screens

As a developer,
I want every exported screen to be either reachable through navigation or removed,
So that the codebase has no dead screen components.

**Acceptance Criteria:**

**Given** `AchievementsScreen` and `LeaderScreen` exist in `src/screens/`
**When** reviewing `App.tsx` tab navigation
**Then** both screens are either wired into the tab system or removed from the codebase
**And** `LeaderCard` component is removed if `LeaderScreen` is removed

## Story 2.2: Remove Dead Utility Code

As a developer,
I want no unused utility files in the codebase,
So that imports are clean and there is no confusion about which functions to use.

**Acceptance Criteria:**

**Given** `src/utils/format.ts` exports `formatNumber` which is never imported
**When** the cleanup is complete
**Then** `format.ts` is removed (or `formatNumber` is removed from it)
**And** `src/utils/index.ts` barrel export is updated accordingly

## Story 2.3: Clean Up Unused Dependencies and Assets

As a developer,
I want no phantom dependencies or duplicate assets,
So that the bundle is lean and there is no ambiguity about which files are canonical.

**Acceptance Criteria:**

**Given** `expo-secure-store` is declared in `app.json` plugins and `package.json` but never imported
**When** the cleanup is complete
**Then** `expo-secure-store` is either removed from config and dependencies, or documented as planned for future use
**And** `assets/world.svg` is removed if `assets/worldtest.svg` is the canonical source
**And** `isConquered` field is removed from the `Country` type and all references

## Story 2.4: Extract Inline BoostPill Component

As a developer,
I want `BoostPill` to be its own component file,
So that it does not get re-created on every `GameScreen` render.

**Acceptance Criteria:**

**Given** `BoostPill` is currently defined inline in `GameScreen.tsx`
**When** extraction is complete
**Then** `BoostPill` exists as `src/components/BoostPill.tsx`
**And** `GameScreen` imports and renders it as a standalone component

---
