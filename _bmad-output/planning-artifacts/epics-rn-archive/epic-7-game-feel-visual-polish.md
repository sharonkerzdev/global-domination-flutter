# Epic 7: Game Feel & Visual Polish

Every player action feels satisfying through visual feedback, animation, haptics, and sound. This is the single highest-impact change for player engagement.

## Story 7.1: Tap-to-Collect on Map

As a player,
I want to tap a country on the map and immediately collect Influence without opening the bottom sheet,
So that the core loop is fast and satisfying.

**Acceptance Criteria:**

**Given** a country is unlocked and its generation timer is complete
**When** the player taps the country on the map
**Then** Influence is collected immediately (no bottom sheet required)
**And** a floating number flyout (+X) animates upward from the country
**And** haptic feedback fires (light impact)
**And** the country's visual state resets to "generating"
**And** long-press on a country opens the upgrade floating card for management

## Story 7.2: Number Flyout Animation

As a player,
I want to see the amount of Influence I earned floating up from the country I tapped,
So that every collection feels rewarding.

**Acceptance Criteria:**

**Given** Influence is collected from any source (tap, golden, offline)
**When** the collection occurs
**Then** a `GameText` element animates: fade in, translate upward 60px, fade out over 800ms
**And** the number is formatted using `formatInfluence()` with a "+" prefix
**And** golden collections show a larger, golden-colored flyout
**And** multiple concurrent flyouts are supported

## Story 7.3: Haptics on All Interactions

As a player,
I want to feel a subtle vibration on every meaningful action,
So that the game feels responsive and tactile.

**Acceptance Criteria:**

**Given** the player performs any of: collect, unlock, upgrade, hire leader, claim golden, activate boost, claim daily reward, switch tab, dismiss modal
**When** the action fires
**Then** appropriate haptic feedback fires:
- Collect: `impactAsync(Light)`
- Unlock/Leader hire: `impactAsync(Heavy)`
- Upgrade purchase: `impactAsync(Medium)`
- Golden claim: `notificationAsync(Success)`
- Button press: `impactAsync(Light)`
**And** haptics respect the `hapticsEnabled` setting
**And** haptics fire from exactly one layer (UI component, not duplicated in store)

## Story 7.4: Visual Generation Timer on Map

As a player,
I want to see a visual indicator of how close each country is to producing Influence,
So that I know when to tap without opening any panel.

**Acceptance Criteria:**

**Given** a country is unlocked and generating (not automated)
**When** the generation timer is progressing
**Then** the country's fill color gradually transitions from dim to bright based on generation progress
**And** when 100% ready, the country pulses with a bright glow
**And** automated (leader) countries show a steady "AUTO" indicator or distinct fill
**And** only visible countries (in current view) animate for performance

## Story 7.5: Next Country Highlight and Affordability

As a player,
I want to clearly see which country I should unlock next and whether I can afford it,
So that I always know my immediate goal.

**Acceptance Criteria:**

**Given** there are locked countries in the current continent
**When** the map renders in continent view
**Then** the cheapest locked country has a distinct glowing border
**And** if the player can afford it, the glow is green; if not, it is a dimmer white/grey
**And** when the player gains enough Influence to afford it, the glow brightens with a transition

## Story 7.6: Upgrade Purchase Feedback

As a player,
I want to see and feel feedback when I buy an upgrade,
So that spending Influence feels rewarding.

**Acceptance Criteria:**

**Given** the player purchases an Influence Power upgrade (x1, x10, or x25)
**When** the purchase succeeds
**Then** the level badge animates (scale pop 1.0 > 1.2 > 1.0 over 200ms)
**And** the income rate text animates (brief green flash or color pulse)
**And** haptic feedback fires (Medium)
**And** the buy button briefly shows a checkmark or "Done" state before resetting

## Story 7.7: Replace Emoji Icons with Vector Icons

As a player,
I want consistent, professional-looking icons throughout the game,
So that the UI feels polished across all devices.

**Acceptance Criteria:**

**Given** `TopBarHUD` and other components use emoji characters for icons
**When** the migration is complete
**Then** all emoji icons are replaced with `@expo/vector-icons` (Ionicons or MaterialCommunityIcons)
**And** icons have consistent size (24px) and color (from theme)
**And** the daily reward notification dot still appears over the calendar icon

## Story 7.8: Strengthen Country Visual State Differentiation

As a player,
I want each country's state to be visually distinct at a glance,
So that I can quickly tell what is locked, unlockable, generating, ready, and automated.

**Acceptance Criteria:**

**Given** the map is rendered
**When** looking at countries
**Then** each state is visually distinct:
- Locked: clearly dimmed/greyed, no glow
- Next-available (unlockable): stronger glow or outline; green if affordable, grey if not
- Manual-collect (generating): subtle pulse or fill change
- Manual-collect (ready): strong "ready to tap" bright pulse
- Automated (with leader): distinct fill or "AUTO" badge
**And** all states remain distinguishable in both world and continent view

## Story 7.9: Milestone Glow and Boost Shimmer

As a player,
I want visual cues on the map for milestone upgrades and active boosts,
So that I notice important opportunities and effects.

**Acceptance Criteria:**

**Given** a country is approaching a leader threshold (IP >= 8 with no leader, IP >= 48 for Lv2, IP >= 98 for Lv3)
**When** the map renders
**Then** the country shows an amber pulsing glow stroke (2.5px, 1500ms cycle)

**Given** a boost is active
**When** the map renders
**Then** a subtle shimmer overlay cycles opacity (0.03 to 0.08, `colors.secondary`, 2000ms loop) behind country paths

---
