# Epic 12: Accessibility & Performance

Make the app usable by screen reader users and eliminate unnecessary re-renders.

## Story 12.1: Add Accessibility Labels to Map and HUD

As a screen reader user,
I want interactive map elements and HUD buttons to announce their purpose,
So that I can navigate the game without visual cues.

**Acceptance Criteria:**

**Given** `TopBarHUD.tsx` icon buttons have no accessibility attributes
**When** labels are added
**Then** every interactive element has `accessibilityLabel` and `accessibilityRole` props
**And** labels use descriptive text (e.g., "Back to world view", "Open daily rewards", "Open settings")

## Story 12.2: Fix Map Country Accessibility Labels

As a screen reader user,
I want country paths to announce country names and states,
So that I understand which country I am interacting with.

**Acceptance Criteria:**

**Given** `WorldMapSVG.tsx` uses raw SVG `id` (ISO-2 code) as `accessibilityLabel`
**When** labels are fixed
**Then** each country path uses the full country name (e.g., "Nigeria" not "NG")
**And** the label includes state context (e.g., "Nigeria - Locked", "Egypt - Ready to collect")

## Story 12.3: Add Modal Accessibility Attributes

As a screen reader user,
I want modals to be properly announced and dismissible,
So that I can interact with modal content and close it with standard gestures.

**Acceptance Criteria:**

**Given** only `BoostModal` has `onRequestClose`; others lack accessibility props
**When** the fix is applied
**Then** all modals have `accessibilityLabel` on the modal container
**And** all modals have `onRequestClose` handler for Android back button
**And** dismiss behavior is consistent across all modals

## Story 12.4: Optimize Zustand Selector Usage

As a developer,
I want all `useGameStore` calls to use narrow selectors,
So that components only re-render when their specific data changes.

**Acceptance Criteria:**

**Given** some components call `useGameStore()` with no selector (subscribes to entire store)
**When** selectors are scoped
**Then** all components use specific selectors for only the fields they read
**And** no component subscribes to the full store without justification

## Story 12.5: Fix Notification Layering (z-index)

As a player,
I want notifications to always appear above the HUD,
So that I never miss important feedback.

**Acceptance Criteria:**

**Given** any notification appears (AchievementToast, ActiveBonusToast, GoldenSpawnBanner)
**When** the notification is visible
**Then** it renders above the HUD (TopBarHUD) at z-index >= 120
**And** modals still render above notifications at z-index 200+
**And** bottom nav renders at z-index 110

---
