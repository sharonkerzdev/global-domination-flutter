# Epic 8: Juice — Game Feel Layer

**Goal:** Every `GameEvent` routes through `AudioService` and `HapticsService` (no scattered `playSound()` in UI). Five core SFX wired. Flying numbers on tap. Ready-to-collect breathing pulse. Unlock + continent-complete celebrations.

### Story 8.1: SFX and Haptics Event Bus Wiring

As a developer,
I want `AudioService` and `HapticsService` that both subscribe to `GameWorld.events` and play mapped SFX / haptic patterns,
So that every meaningful action has audio and tactile feedback with no scattered `playSound()` calls in UI code.

**Acceptance Criteria:**

**Given** `AudioService` initialized at app boot
**When** `CountryTapped` fires with nonzero amount
**Then** `assets/audio/collect.mp3` plays.

**Given** other events fire
**When** they match the mapping — `CountryUnlocked → unlock`, `UpgradePurchased → upgrade`, `LeaderHired → upgrade`, `GoldenClaimed → golden`, `ContinentCompleted → milestone`
**Then** the corresponding SFX plays.

**Given** `Settings.soundEnabled == false`
**When** an event fires
**Then** no SFX plays.

**Given** rapid-fire taps
**When** 10 `CountryTapped` events fire in 500ms
**Then** the service rate-limits / polyphones so SFX don't stutter or lag (validated on device).

**Given** `AudioService`
**When** grep'd
**Then** it is the ONLY place `AudioPlayer.play` is called — no UI widget calls `audioplayers` directly.

**Given** `HapticsService` initialized
**When** `CountryTapped` fires
**Then** a light impact haptic fires.

**Given** other events fire
**When** they match — `CountryUnlocked → medium`, `LeaderHired → medium`, `ContinentCompleted → heavy`, `GoldenClaimed → medium + selection`
**Then** the corresponding haptic pattern plays.

**Given** `Settings.hapticsEnabled == false`
**When** events fire
**Then** no haptics play.

### Story 8.2: Flying Number Animation on Country Tap

As a player,
I want a floating "+X" number to rise and fade above a tapped country,
So that the collect action has satisfying visual weight.

**Acceptance Criteria:**

**Given** I tap a country with nonzero banked influence
**When** `CountryTapped(amount)` fires
**Then** a flying-number widget spawns at the country's screen position showing `+{amount.format()}`, tweens up ~40 logical pixels, fades out over ~800ms, then removes itself from the widget tree.

**Given** I rapid-tap 10 times in 500ms
**When** the flying-number layer processes the events
**Then** 10 distinct flying numbers are visible simultaneously (no pooling race) and all clean up without leaks.

**Given** a tap where `amount == 0` (edge case from Story 2.6)
**When** processed
**Then** no flying number spawns.

### Story 8.3: Breathing Pulse Animation on Ready-To-Collect Countries

As a player,
I want ready-to-collect countries to subtly pulse,
So that my eye is drawn to where I can collect right now.

**Acceptance Criteria:**

**Given** a country's state is "ready-to-collect" (banked influence > 0 and no Leader)
**When** the painter renders
**Then** its fill opacity (or a glow overlay) tweens between ~0.6 and ~1.0 on a ~1.5s ease-in-out infinite loop.

**Given** multiple ready countries
**When** rendered
**Then** they share a single `AnimationController` value (one ticker-driven animation drives all pulses) to keep paint cost bounded.

**Given** a country transitions to "automated" (Leader hired)
**When** the state changes
**Then** the pulse stops on that country.

### Story 8.4: Celebration Animations — Country Unlock and Continent Completion

As a player,
I want a visual celebration when I unlock a country and a bigger fanfare when I complete an entire continent,
So that both moments feel earned and proportionally rewarding.

**Acceptance Criteria:**

**Given** `CountryUnlocked` event fires
**When** the map receives it
**Then** the unlocked country plays a celebration animation — first unlock in a continent uses a radial ripple; subsequent unlocks in that continent use a white-flash.

**Given** the animation
**When** it completes (~800ms)
**Then** the country settles into its new state color and no stray paint artifacts remain.

**Given** I am NOT on the Map tab when the unlock fires (unlikely but possible via HUD actions)
**When** I switch to the Map tab
**Then** the animation does not replay — it fired once when the event occurred.

**Given** `ContinentCompleted` event fires
**When** the UI receives it
**Then** a full-screen celebration modal (queued per Epic 7 modal queue) shows the continent name, "+X.XX× Global Multiplier" reward, and a "Continue" CTA — with a continent-complete fanfare SFX if available in `assets/audio/continent_complete.mp3`.

**Given** the modal
**When** dismissed
**Then** the queue advances to the next modal (if any) and the map smoothly animates a highlight over the completed continent region.

### Story 8.5: Number Flyout, HUD Counter, Country Pulse All Share One `Ticker` Budget

As a developer,
I want all decorative animations (HUD counter tweens, flying numbers, breathing pulses, celebration animations) to respect frame budget,
So that the map's 60fps target is never compromised by UI polish.

**Acceptance Criteria:**

**Given** profiling on a low-end Android device
**When** 20 rapid taps spawn 20 flying numbers, the HUD tweens, and 5 countries pulse simultaneously
**Then** sustained fps stays above 45 with stretch goal 60.

**Given** any animation
**When** it completes
**Then** its controller is disposed or reset — no leaked `AnimationController`s (verified by a simple counter assertion in debug mode).

---
