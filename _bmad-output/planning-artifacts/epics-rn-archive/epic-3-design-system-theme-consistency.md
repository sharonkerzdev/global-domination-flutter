# Epic 3: Design System & Theme Consistency

Eliminate hardcoded colors and inconsistent UI patterns to ensure the design system is the single source of truth.

## Story 3.1: Replace Hardcoded Colors with Theme Tokens

As a developer,
I want all color values to come from `src/styles/theme.ts`,
So that theme changes propagate everywhere and dark mode is feasible in the future.

**Acceptance Criteria:**

**Given** 15+ files contain hardcoded hex colors
**When** the migration is complete
**Then** every color literal in `src/` is replaced with a reference to `theme.colors.*`
**And** new theme tokens are added for any colors not yet in the theme
**And** no raw hex strings remain in component files

## Story 3.2: Standardize Text Components

As a developer,
I want all text rendering to use `GameText` from the design system,
So that typography is consistent and font changes apply globally.

**Acceptance Criteria:**

**Given** several screens use raw `<Text>` with hardcoded font styles
**When** the migration is complete
**Then** all `<Text>` usages in `src/` are replaced with `<GameText>` with appropriate `variant` and `weight` props
**And** no raw `Text` imports remain (except inside `GameText` itself)

## Story 3.3: Extract Shared Modal Animation Hook

As a developer,
I want modal backdrop and card animation logic to live in a reusable hook,
So that the four modal components are DRY and animation behavior is consistent.

**Acceptance Criteria:**

**Given** `OfflineModal`, `CelebrationModal`, `BoostModal`, and `DailyRewardModal` duplicate the same backdrop fade + card scale animation
**When** the refactor is complete
**Then** a `useModalAnimation()` hook or shared `ModalWrapper` component encapsulates the common pattern
**And** each modal uses the shared implementation
**And** animation behavior is unchanged

## Story 3.4: Resolve Duplicate Haptic Feedback

As a developer,
I want haptic feedback to fire exactly once per user action,
So that players do not get double-buzzed on collect, unlock, and other interactions.

**Acceptance Criteria:**

**Given** both `CountryBottomSheet` (UI) and `gameStore` (state) trigger haptics for the same actions
**When** ownership is clarified
**Then** haptics fire from exactly one layer (UI or store, not both)
**And** the chosen layer is documented in `project-context.md`

---
