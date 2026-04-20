---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
inputDocuments: ['PRD.md', 'docs/project-overview.md', 'docs/index.md']
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 0
workflowType: 'gdd'
lastStep: 2
project_name: 'global-domination-game'
user_name: 'Sharon'
date: '2026-04-05'
game_type: 'idle-incremental'
game_name: 'Global Domination'
rewrite_note: 'v2 — migrated to Flutter stack 2026-04-05'
---

# Global Domination - Game Design Document

**Author:** Sharon
**Game Type:** Idle/Incremental
**Target Platform(s):** Mobile (iOS & Android)

---

## Executive Summary

### Game Name

Global Domination

### Core Concept

Global Domination is a mobile-first idle/incremental strategy game where players accumulate **Influence** to conquer countries, complete continents, and ultimately dominate the world. The game blends the dopamine efficiency of idle games (Cash, Inc.–style) with a clear, finite progression fantasy: world conquest. Instead of endless prestige resets, players advance geographically and narratively, continent by continent.

Players tap countries on an interactive SVG world map to generate Influence, upgrade their power, hire Leaders to automate production, and progressively unlock 79 countries across 7 continents. Active play systems — Golden Opportunities, Boosts, and Missions — layer burst moments on top of the idle foundation.

The core promise: *Short sessions feel powerful. Long-term play feels meaningful.*

### Game Type

**Type:** Idle/Incremental
**Framework:** This GDD uses the idle-incremental template with type-specific sections for core click/interaction, upgrade trees, automation systems, prestige/reset mechanics, number balancing, and meta-progression.

---

## Target Platform(s)

### Primary Platform

**Mobile (iOS & Android)** — Single shared codebase via Flutter (Dart)

### Platform Considerations

- **Offline-first:** Full game playable without internet connection
- **Portrait orientation only** — optimized for one-handed play
- **Battery/thermal:** Idle background processing must be lightweight; offline earnings calculated on resume
- **Storage:** SQLite (via Drift) for structured, transactional persistence with typed migrations
- **Distribution:** App Store (iOS) and Google Play (Android)
- **Future expansion:** Web and desktop ports via Flutter multi-platform under consideration for later phases

### Control Scheme

- **Primary input:** Touch (tap to collect, tap to interact)
- **Map navigation:** Pan (drag) and zoom (pinch + buttons) on interactive canvas-rendered world map
- **UI interaction:** Bottom navigation tabs, modal dialogs, bulk purchase buttons (1x/10x/25x)
- **Haptic feedback:** Tactile response on key interactions (collect, unlock, upgrade)

---

## Target Audience

### Demographics

- **Age range:** 13+ (no mature content, abstract "domination" theme)
- **Gender:** Broad appeal, no gender-specific design
- **Geographic:** Global — game content spans real-world countries

### Gaming Experience

**Casual** — Players who game in short bursts throughout the day. Familiar with mobile gaming conventions (tap, swipe, bottom nav) but not necessarily hardcore gamers.

### Genre Familiarity

Mixed familiarity with idle/incremental games. The game should be immediately intuitive to genre veterans (Cash, Inc., Adventure Capitalist fans) while accessible to newcomers through a step-by-step tutorial overlay.

### Session Length

**1–5 minutes typical** — Quick check-ins to collect offline earnings, tap active countries, claim Golden Opportunities, and progress missions. Longer sessions (15–30 min) during active pushes to unlock new continents.

### Player Motivations

- **Completion drive:** Filling the world map, conquering all 79 countries
- **Numbers going up:** Exponential scaling provides constant dopamine hits
- **Idle progress:** Satisfaction from returning to banked offline earnings
- **No pressure:** Player-friendly design with no forced resets, no aggressive paywalls
- **Geographic narrative:** Continent-by-continent progression gives a clear sense of journey

### Unique Selling Points (USPs)

1. **Finite Geographic Progression** — Unlike most idle games with endless prestige loops, Global Domination has a clear destination: conquer all 79 countries across 7 continents. Every session moves you closer to a real finish line.

2. **Interactive World Map** — Progress is visual and tangible. Instead of abstract number screens, players watch an SVG world map transform as they dominate countries and complete continents.

3. **Multiple Paths to Domination (Future)** — The vision extends beyond simple influence accumulation. Future updates will introduce different strategies and methods to achieve world domination, adding replayability and depth.

4. **Respectful Design** — No forced resets, no aggressive paywalls, no pay-to-win. Offline progression is meaningful. The game respects the player's time and investment.

### Competitive Positioning

| Feature | Cash, Inc. / AdCap | Global Domination |
|---|---|---|
| Progression | Endless prestige resets | Finite world conquest |
| Visual feedback | Abstract UI, number lists | Interactive world map |
| Theme | Business/money | Geopolitical domination |
| End state | None (infinite loop) | Full world domination |
| Reset mechanics | Required for advancement | No resets needed |
| Future depth | More of the same | Multiple domination paths |

---

## Goals and Context

### Project Goals

1. **Player Engagement:** Achieve strong DAU and long-term retention through rewarding short sessions and meaningful offline progression
2. **Player-Friendly Monetization:** Prove that an idle game can succeed without aggressive paywalls — rewarded ads only, no pay-to-win
3. **Scalable Foundation:** Build a core loop and architecture that supports future expansion — new worlds (Mars Colonies, Corporate Megaworlds, Fantasy/Sci-Fi realms) and multiple domination strategies
4. **Completion Satisfaction:** Create a game where every player can realistically reach full world domination — a clear, finite end goal that feels earned

### Background and Rationale

The idle/incremental genre is saturated with games built around endless prestige resets and abstract number scaling. While mechanically satisfying, these games often lack narrative purpose — players grind without a clear destination. Global Domination fills this gap by anchoring idle mechanics to a geographic conquest fantasy. Real countries and continents give meaning to progression, and the finite goal of world domination provides a satisfying endgame that most idle games lack.

The timing is right: mobile idle games continue to grow, but player expectations have risen. Games that respect players' time, avoid predatory monetization, and offer genuine completion are increasingly valued.

---

## Core Gameplay

### Game Pillars

1. **Satisfying Growth** — Numbers must feel powerful. Every tap, upgrade, and automation should deliver a visible, tangible sense of progress. Exponential scaling, visual map transformation, and milestone celebrations all serve this pillar. If a feature doesn't make the player feel more powerful, it doesn't belong.

2. **Offline Respectful** — Every session matters, whether the player was away for 5 minutes or 8 hours. Offline progression must feel meaningful — returning to banked earnings should be rewarding, not punishing. The game never wastes the player's time or pressures them into constant play.

**Pillar Prioritization:** When pillars conflict, prioritize in this order:
1. Satisfying Growth (the core dopamine driver)
2. Offline Respectful (the trust builder)

### Core Gameplay Loop

**Primary Loop (Minute-to-Minute):**
Tap country → Earn Influence → Upgrade Influence Power → Hire Leader (automate) → Unlock next country → Repeat

**Active Play Layer:**
Golden Opportunity spawns → Tap for burst multiplier → Complete missions → Earn Intel → Activate boosts → Amplify earnings

**Meta Loop (Session-to-Session):**
Return to offline earnings → Collect → Push toward continent completion → Unlock continent bonus → Open new continent → New countries to conquer

**Loop Diagram:**
```
┌─────────────────────────────────────────────┐
│              MINUTE-TO-MINUTE               │
│  Tap → Upgrade → Automate → Unlock → Tap   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│              ACTIVE PLAY BURST              │
│  Golden Opp → Missions → Intel → Boosts    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│              META PROGRESSION               │
│  Complete Continent → Bonus → New Continent │
│  (Future: New upgrade paths, resets, worlds)│
└─────────────────────────────────────────────┘
```

**Loop Timing:** Primary loop cycle: 10–60 seconds. Meta loop cycle: days to weeks per continent.

**Loop Variation:** Each new country costs more and generates more, scaling exponentially. Continents introduce new visual regions and completion bonuses. Future expansion may add new upgrade trees, alternative domination strategies, and optional prestige resets for players seeking deeper long-term engagement.

### Win/Loss Conditions

#### Victory Conditions

- **Primary Win State:** Conquer all 79 countries across 7 continents — full world domination
- **Milestone Victories:** Continent completion milestones at 25%/50%/75%/100% with bonus rewards
- **Achievement Goals:** 27 achievements providing permanent multiplier bonuses
- **Future:** Additional win states through new worlds (Mars, Corporate, Fantasy/Sci-Fi) and alternative domination paths

#### Failure Conditions

- **No traditional failure state** — This is a "no-fail" idle experience. Players cannot lose progress, die, or be set back.
- **Future:** Optional prestige/reset mechanics may introduce voluntary "soft resets" for players who want deeper strategic loops, but these will never be forced.

#### Failure Recovery

Not applicable in current design. The only friction is time — progression slows without active play or upgrades, but never reverses. This directly serves the **Offline Respectful** pillar.

---

## Game Mechanics

### Primary Mechanics

**1. Tap to Collect** (Pillar: Satisfying Growth)
- **When:** Constantly — the most frequent player action
- **What:** Tap owned countries on the world map to collect generated Influence
- **Feel:** Snappy, instant feedback — haptic pulse + number flyout animation + sound effect
- **Progression:** Faster collection as Influence Power increases; eventually automated by Leaders

**2. Upgrade** (Pillar: Satisfying Growth)
- **When:** Frequently — after accumulating Influence
- **What:** Spend Influence to level up a country's Influence Power (up to level 200)
- **Feel:** Satisfying number jumps, bulk purchase options (1x/10x/25x) for momentum
- **Progression:** Exponential cost scaling (1.5x per level); later countries have higher base power
- **Future:** Research trees, diplomatic influence, and additional upgrade paths to be added

**3. Automate** (Pillar: Offline Respectful)
- **When:** Milestone moment — when a country reaches Influence Power level 10
- **What:** Hire a Leader to convert timer-based generation to continuous passive income
- **Feel:** Celebration moment — the country is now "conquered" and works for you while offline
- **Progression:** 4 Leader tiers (1x → 1.5x → 2x → 3x multiplier)

**4. Unlock** (Pillar: Satisfying Growth)
- **When:** Periodically — as Influence accumulates
- **What:** Purchase new countries with Influence; unlock new continents at threshold milestones
- **Feel:** Expansion — the map visually transforms as new territory is claimed
- **Progression:** 79 countries across 7 continents, exponential cost scaling

**5. Boost & Claim** (Pillar: Satisfying Growth)
- **When:** Situationally — during active play sessions
- **What:** Activate 2x multiplier boosts (Intel or ad), claim Golden Opportunities (10–100x burst)
- **Feel:** Burst moments — explosive earnings that break the normal rhythm
- **Progression:** Missions cycle through objectives (claim goldens, activate boosts, stay active) for Intel rewards

### Mechanic Interactions

- **Tap + Upgrade** synergy: Higher Influence Power makes each tap more valuable, encouraging upgrade investment
- **Automate + Offline** synergy: Leaders generate passive income that banks while away, delivering on the Offline Respectful pillar
- **Boost + Golden Opportunity** stacking: Active players can multiply already-multiplied earnings for massive burst windows
- **Unlock + Complete** chain: Unlocking countries progresses toward continent completion, which grants permanent global multipliers that amplify all other mechanics
- **Future:** Research trees and diplomatic influence will add new mechanic interactions and alternative progression strategies

### Mechanic Progression

| Phase | Focus Mechanics | Player Experience |
|---|---|---|
| **Early** (0–2 hrs) | Tap, Upgrade, first Unlock | High-frequency tapping, fast unlocks, learning the loop |
| **Mid** (Days 2–7) | Automate, Boost, Missions | Shift to idle-focused play, active play systems engage |
| **Late** (Weeks 2+) | Continental completion, Golden Ops | Strategic boost timing, completion-driven motivation |
| **Future** | Research, Diplomacy, Resets | Multiple upgrade paths, strategic choices, replayability |

---

## Controls and Input

### Control Scheme (Mobile — Touch)

| Action | Gesture | Screen Location |
|---|---|---|
| Collect Influence | Tap | Country on world map |
| Pan map | Drag | World map area |
| Zoom | Pinch / buttons | World map area |
| Navigate tabs | Tap | Bottom navigation bar |
| Purchase upgrade | Tap | Upgrade cards |
| Bulk purchase | Tap toggle (1x/10x/25x) | Upgrade screen |
| Claim Golden Opportunity | Tap | Flashing country on map |
| Activate Boost | Tap | Boost button |
| Dismiss modal | Tap button / swipe | Modal overlay |

### Input Feel

- **Tap collection:** Instant — zero perceived delay. Haptic pulse + ascending number flyout + collect sound
- **Upgrades:** Snappy — bulk purchases should feel like rapid-fire power increases
- **Map navigation:** Smooth, inertia-based panning and zooming via gesture handler
- **Modals:** Fluid entrance/exit animations, never blocking urgent gameplay moments

### Accessibility Controls

- Screen-reader labels on all map countries, HUD elements, and modals
- Step-by-step tutorial overlay for first-time players
- Large touch targets for primary actions
- High-contrast visual state differentiation for country states (locked/unlocked/conquered)

---

## Idle/Incremental Specific Design

### Core Click/Interaction

**Primary Mechanic:** Tap owned countries on the interactive canvas-rendered world map to collect accumulated Influence.

- **Click action:** Each tap collects the Influence generated since the last collection (timer-based generation cycle per country)
- **Click value progression:** Scales with Influence Power level (up to 200), Leader multipliers, continent bonuses, achievement bonuses, and active boosts
- **Auto-click mechanics:** Leaders automate collection — countries with Leaders generate Influence passively without tapping
- **Combo/streak systems:** None — each tap is an independent collection event. Simplicity serves the casual audience.
- **Satisfaction and feedback:** Haptic pulse + number flyout animation + collect sound effect. Visual generation timer on map shows when countries are ready for collection.

### Upgrade Trees

**Current Upgrade Systems:**

| Upgrade | Scope | Max Level | Cost Scaling | Effect |
|---|---|---|---|---|
| Influence Power | Per country | 200 | 1.5x per level | Increases Influence generation |
| Leader Hire | Per country | — | Fixed (requires IP lvl 10) | Enables automation |
| Leader Upgrade | Per country | 3 tiers | Scaling | 1.5x → 2x → 3x multiplier |
| Global Upgrades | Global | 3 types | Varies | Influence Amplifier, Efficiency Expert, Intel Bonus |
| Continent Upgrades | Per continent | 7 types | Varies | Continent-specific bonuses |

- **Bulk purchase options:** 1x, 10x, 25x for Influence Power upgrades
- **Unlock conditions:** Leaders require IP level 10; continents require total Influence thresholds
- **Synergies:** Leader multipliers stack with Influence Power, continent bonuses, achievement bonuses, and active boosts for exponential compounding

**Future:** Research trees and diplomatic influence paths will add branching upgrade choices and alternative strategies for progression.

### Automation Systems

**Leader System (Core Automation):**

- Leaders convert timer-based generation to continuous passive income (per second)
- Automated countries generate Influence while the app is open AND while offline
- 4 Leader tiers provide escalating multipliers (1x → 1.5x → 2x → 3x)

**Offline Progression:**

- Offline Influence accumulates from automated countries only
- Calculated on app resume
- Capped at 8 hours of offline earnings
- Presented via Offline Reward modal on return

**Active vs Idle Balance:**

- **Active play:** Tapping, claiming Golden Opportunities, activating boosts, completing missions — higher earnings per minute
- **Idle play:** Leaders generate passively — lower rate but zero effort
- **Design intent:** Active play should feel 3–5x more rewarding than idle, but idle should never feel like wasted time

### Prestige and Reset Mechanics

**Current:** No prestige or reset mechanics. Players progress linearly from first country to full world domination without any resets.

**Future Considerations:**
- Optional prestige/reset system under consideration for post-launch
- Design constraint: Resets must never be forced — they must be a voluntary strategic choice
- Must align with the **Offline Respectful** pillar — resetting should feel like gaining power, not losing progress
- Potential direction: Reset countries but retain continent bonuses, gaining a permanent prestige multiplier

### Number Balancing

**Economy Design:**

- **Exponential growth curves:** Base influence per country = previous × 5; costs scale similarly
- **Big number library:** Dart `decimal` or `big_decimal` package handles numbers beyond native double limits
- **Notation system:** Abbreviated format (K, M, B, T, Qa, Qi...) for readability
- **Generation times:** Tier-based, 1–79 seconds per country
- **Continent unlock thresholds:** Range from 0 (Africa) to 1e38 (Oceania)

**Pacing Design:**

| Phase | Number Range | Pacing Feel |
|---|---|---|
| Early game | 0 – 1B | Fast, frequent milestones |
| Mid game | 1B – 1e20 | Steady, automation-driven |
| Late game | 1e20 – 1e38+ | Boost-dependent, completion-driven |

> **Note (v2):** Number ranges and pacing walls were tuned for the React Native build. With a proper game loop (Flutter game loop, not a 1-second JS setInterval), generation timers and income ticks can be smoother and more granular — pacing curves should be revisited during balance testing on the new engine.

- **Soft caps and plateaus:** Natural slowdowns between continents create pacing walls
- **Wall-breaking mechanics:** Golden Opportunities (10–100x burst), Boosts (2x for 30s), and continent completion bonuses break through plateaus
- **Late game balance:** Not yet fully tuned — will require playtesting data to adjust curves

### Meta-Progression

**Achievement System:** 27 achievements with permanent multiplier and Intel rewards

| Category | Examples | Reward Type |
|---|---|---|
| Milestone | First Country, First Leader, Million Total | Multiplier bonus |
| Activity | Thousand Taps | Multiplier bonus |
| Completion | Continent Complete | Multiplier bonus |

**Continent Completion Bonuses:** Permanent global multipliers (+0.25x to +1.75x) for completing all countries in a continent

**Daily Rewards:** 7-day streak system with Influence and Intel rewards — encourages daily return without punishing absence

**Future Meta-Progression:**
- New worlds (Mars Colonies, Corporate Megaworlds, Fantasy/Sci-Fi realms) reusing core mechanics with new themes
- Seasonal challenges
- Asynchronous leaderboards and ghost progress comparisons
- Alternative domination strategies adding replayability

---

## Progression and Balance

### Player Progression

#### Progression Types

| Type | Implementation | Example |
|---|---|---|
| **Power** | Influence Power upgrades, Leader tiers, Global/Continent upgrades | Leveling a country from IP 1 → 200 |
| **Content** | New countries and continents unlock as Influence grows | Opening Europe after completing Africa |
| **Collection** | Achievements, continent completion milestones | Earning "First Leader" achievement (+0.05x) |

#### Progression Pacing

| Phase | Timeframe | Experience |
|---|---|---|
| **Early Game** | 0–2 hours | Fast unlocks across Africa. Heavy tapping with quick generation cycles. First Leaders unlock around IP level 10. High reward frequency. |
| **Mid Game** | Days 2–7 | More idle-focused as Leaders automate countries. Active play systems (Golden Opportunities, Missions) keep sessions engaging. Continent completion becomes the driving goal. |
| **Late Game** | Weeks 2+ | Large Influence numbers (break_eternity.js scaling). Boosts and Golden Opportunities critical for progression. Completion-driven motivation across later continents. |

### Difficulty Curve

**Pattern:** Exponential — gentle start with steep late-game scaling.

#### Challenge Scaling

- **Between countries:** Each successive country costs ~5x more and generates ~5x more, creating a steady power ramp
- **Between continents:** Major difficulty jumps at continent thresholds (0 → 1B → 100T → 100Qi → 1e26 → 1e32 → 1e38) create natural pacing walls
- **Wall-breakers:** Golden Opportunities (10–100x burst), Boosts (2x for 30s), and continent completion bonuses (+0.25x to +1.75x) help players push through plateaus
- **Future:** Additional catch-up mechanics planned to smooth late-game walls

#### Difficulty Options

- No explicit difficulty selection — the game self-paces based on player activity level
- Active players progress faster; idle players progress steadily but slower
- No punishment for slow progress — the game waits for you (Offline Respectful pillar)

### Economy and Resources

#### Resources

| Resource | Role | Earn | Spend |
|---|---|---|---|
| **Influence** | Primary currency | Tapping, idle generation, offline accumulation | Unlock countries, Influence Power upgrades, hire/upgrade Leaders |
| **Intel** | Secondary currency | Mission completion, achievements | Activate boosts (2x for 30s) |

#### Economy Flow

```
        ┌──── Tap ────┐
        │             ▼
   [Countries] ──► INFLUENCE ──► Upgrades / Unlocks / Leaders
        ▲             │
        └── Leaders ──┘ (automation loop)

   [Missions] ──► INTEL ──► Boosts ──► Amplified Influence
```

- **Influence sinks:** Country unlocks, IP upgrades, Leader hires/upgrades, Global upgrades, Continent upgrades
- **Intel sinks:** Boost activation (current); additional uses planned for future
- **Inflation design:** Exponential scaling means earlier content becomes trivially cheap — this is intentional and satisfying (Satisfying Growth pillar)
- **Balance status:** Intel economy to be rebalanced as new uses are added in future updates

---

## Level Design Framework

### Structure Type

**Gated World Map** — A finite, geographically-structured progression system. The interactive canvas-rendered world map serves as both the primary gameplay surface and the content navigation system. Countries are individual progression units gated by Influence cost; continents are major content tiers gated by total Influence thresholds.

### Level Types

| Level Type | Count | Role |
|---|---|---|
| **Countries** | 79 | Individual progression units — each has its own unlock cost, generation rate, IP upgrades, and Leader slot |
| **Continents** | 7 | Major content tiers grouping countries — each has milestone rewards at 25%/50%/75%/100% and a completion bonus |
| **Future Worlds** | TBD | Separate maps (Mars Colonies, Corporate Megaworlds, Fantasy/Sci-Fi realms) reusing core mechanics with new themes |

#### Content Breakdown

| # | Continent | Countries | Unlock Threshold | Completion Bonus |
|---|---|---|---|---|
| 1 | Africa | 19 | 0 (starting) | +0.25x |
| 2 | Europe | 19 | 1 Billion | +0.50x |
| 3 | Middle East | 10 | 100 Trillion | +0.75x |
| 4 | Asia | 16 | 100 Quintillion | +1.00x |
| 5 | South America | 8 | 1e26 | +1.25x |
| 6 | North America | 4 | 1e32 | +1.50x |
| 7 | Oceania | 3 | 1e38 | +1.75x |

#### Tutorial Integration

Step-by-step onboarding overlay guides first-time players through the core loop: tap to collect → upgrade → hire Leader → unlock next country. No plans to change this approach currently.

#### Special Content

- **Golden Opportunities:** Random time-limited bonus spawns on map countries (10–100x multiplier burst)
- **Continent Milestones:** 25%/50%/75%/100% completion rewards per continent
- **Future Worlds:** Entirely separate maps with new themes — not extensions of the current world map

### Level Progression

**Model:** Gated Progress — Influence thresholds gate both individual country unlocks and continent access.

#### Unlock System

- **Countries:** Unlocked sequentially within a continent by spending Influence (cost = previous × 5)
- **Continents:** Unlocked when total Influence reaches the continent's threshold
- **Leaders:** Available per country when Influence Power reaches level 10

#### Replayability

- All countries remain active after unlocking — players continuously collect from and upgrade owned countries
- Continent completion bonuses incentivize fully finishing each continent before moving on
- **Future:** New worlds (separate maps) add fresh content layers; potential prestige/reset mechanics add replay value to existing content

---

## Art and Audio Direction

### Art Style

**Current: Vector/Flat** — Clean GeoJSON-polygon world map with color-coded country states and minimal UI chrome. Lightweight and performant on mobile.

- **Rendering:** Flutter `CustomPainter` on a `Canvas` for the interactive world map; GeoJSON country polygons projected to screen space, no external map library
- **Typography:** Fredoka (rounded, friendly) via `google_fonts` Flutter package
- **Design system:** Centralized theme tokens (colors, spacing, typography) in Dart theme classes
- **Visual effects:** Country glow, takeover animations, and state transitions implemented as Flutter `AnimationController`-driven painter operations — no third-party animation library required

**Future Direction:** The custom canvas renderer is designed to support richer effects — animated conquest spreads, fog-of-war overlays, country pulse animations — without architectural changes. Evolve toward more visually dynamic map states as the game matures.

#### Color Palette

**Bright and vibrant** — Board game energy with clear visual hierarchy.

- Country states use distinct color coding: locked (muted), unlocked (active/bright), conquered (saturated/bold)
- Continent regions visually differentiated by color family
- UI elements use high-contrast bright accents against clean backgrounds
- Golden Opportunities use attention-grabbing highlight colors
- Overall mood: optimistic, empowering, playful — aligned with **Satisfying Growth** pillar

#### Camera and Perspective

**Top-down world map** — Fixed perspective looking down at the globe, with pan and zoom for navigation. No camera rotation or 3D perspective shifts.

### Audio and Music

#### Music Style

**No background music currently planned.** The game is designed for short mobile sessions often played in public or while multitasking — silence-friendly by default. Background music may be considered in future updates as the art direction evolves.

#### Sound Design

**5 core sound effects providing feedback on key actions:**

| Sound | Trigger | Purpose |
|---|---|---|
| Collect | Tapping a country to gather Influence | Moment-to-moment satisfaction |
| Unlock | Purchasing a new country | Achievement moment |
| Milestone | Hitting continent completion thresholds | Major progress celebration |
| Upgrade | Purchasing Influence Power or Leader tier | Power growth feedback |
| Golden | Claiming a Golden Opportunity | Burst excitement |

- All sounds are short, punchy MP3s optimized for mobile (`audioplayers` Flutter package)
- Audio triggered via event bus — game events (`country_unlocked`, `golden_claimed`, etc.) drive sound automatically; no scattered `playSound()` calls in UI code
- Haptic feedback (`flutter_haptic_feedback` or `HapticFeedback` from Flutter SDK) complements audio on every key interaction
- Sound is optional — game is fully playable on mute

#### Voice/Dialogue

None — no voice acting or dialogue. All communication is through UI text, numbers, and visual/audio feedback.

### Aesthetic Goals

- **Satisfying Growth:** Every visual and audio cue reinforces the feeling of growing power — numbers fly up, sounds ping, the map transforms with color
- **Offline Respectful:** The Offline Reward modal on return delivers a visually satisfying "here's what you earned" moment
- **Clarity over complexity:** The bright, vector style ensures country states and interactive elements are immediately readable at a glance — critical for short mobile sessions

---

## Technical Specifications

### Performance Requirements

#### Frame Rate Target

**60fps target** — Flutter with Impeller rendering engine (iOS default, Android opt-in). Map interactions (pan, zoom, tap) must feel fluid and responsive. Flutter's single-threaded Dart isolate + Impeller GPU pipeline eliminates the JS-bridge bottleneck that constrained the v1 build.

#### Resolution Support

- Adaptive to device resolution — Flutter handles logical pixels with device pixel ratio scaling
- Portrait orientation only
- SVG map scales to any screen size without quality loss

#### Load Times

- **Cold start:** Under 3 seconds to interactive map
- **Save/load:** Near-instant (SQLite/Drift, local only; partial state writes avoid full serialization overhead)
- **Offline resume:** Offline earnings calculated and displayed immediately on app open

### Platform-Specific Details

#### iOS Requirements

- **Minimum version:** iOS 16.0+ (Flutter 3.x stable support baseline)
- **Orientation:** Portrait locked
- **Offline play:** Full functionality without internet
- **Future:** Rewarded ads + in-app purchases planned (via `in_app_purchase` and ad SDK Flutter plugins)
- **App Store:** Standard submission via `flutter build ipa`; no special entitlements required currently

#### Android Requirements

- **Minimum API level:** API 21 (Android 5.0+) — Flutter stable minimum
- **Orientation:** Portrait locked
- **Offline play:** Full functionality without internet
- **Future:** Rewarded ads + in-app purchases planned
- **Play Store:** Standard submission via `flutter build appbundle`

#### Cross-Platform

- Single shared codebase via Flutter (Dart)
- No OTA update capability (unlike Expo) — all updates via store release; plan release cadence accordingly
- Plugin-based native integrations (audio, haptics, SQLite) — all stable Flutter pub.dev packages, no custom native modules required for v1.0

### Asset Requirements

#### Art Assets

| Asset Type | Count | Format | Notes |
|---|---|---|---|
| World map GeoJSON | 1 | GeoJSON | 79 country polygon features — ported directly from v1 |
| Country mapping data | 1 | Dart | Maps GeoJSON ISO codes to game country IDs |
| Vector icons | ~20 | Material Icons / flutter_svg | UI icons throughout |
| Theme tokens | 1 | Dart | Colors, spacing, typography as `ThemeData` + constants |

#### Audio Assets

| Asset Type | Count | Format | Notes |
|---|---|---|---|
| Sound effects | 5 | MP3 | Collect, unlock, milestone, upgrade, golden — ported from v1 |
| Haptic patterns | ~5 | Flutter `HapticFeedback` API | Complement audio on key actions |

#### Font Assets

| Asset | Source | Notes |
|---|---|---|
| Fredoka | `google_fonts` Flutter package | Primary typeface, rounded/friendly |

#### External Assets

- No licensed third-party assets
- GeoJSON world map data is project-owned (ported from v1)
- Future art evolution may require external illustration assets

### Technical Constraints

- **Big numbers:** Dart big number package (e.g., `big_decimal`) required for exponential scaling — no custom JSON serialization needed; SQLite stores values as TEXT with typed accessors
- **Offline cap:** 8 hours maximum offline earnings accumulation
- **Save system:** SQLite via Drift — versioned schema migrations replace manual save-format hacks; no full-state serialization on every save
- **Simulation isolation:** Core game simulation (`GameWorld`) runs as a pure Dart class with no Flutter/UI dependencies — headlessly testable, renderable by any UI layer
- **Battery/thermal:** Game loop runs via Flutter's `Ticker` (tied to display refresh) when foregrounded; no background processing — all offline earnings calculated on resume
- **No OTA updates:** Unlike Expo, Flutter requires full store release for any code changes — factor into release planning
- **Future:** IAP and ad SDK integration available as standard Flutter pub.dev plugins; no special build tooling changes required

---

## Development Epics

### Epic Overview

> **v2 Rewrite Note:** Epics 1–13 were written for the React Native codebase and are now archived as reference. The Flutter rewrite starts with a clean epic set. The *design goals* from those epics (game feel, map interaction, leader UX, onboarding, balance) remain fully valid and should inform the new stories — only the implementation specifics change.

#### Flutter Rewrite Epics

| # | Epic Name | Scope | Status |
|---|---|---|---|
| 1 | Foundation & Project Setup | Flutter project scaffold, Drift/SQLite, game simulation core, CI | Backlog |
| 2 | World Map Renderer | CustomPainter canvas, GeoJSON loader, country polygon rendering, pan/zoom | Backlog |
| 3 | Core Game Loop | GameWorld simulation, tick system, income, tap-to-collect, country states | Backlog |
| 4 | Upgrade & Leader Systems | IP upgrades, leader hire/upgrade, automation, passive income | Backlog |
| 5 | Continent & Unlock Progression | Continent gating, unlock flow, milestone rewards, completion bonuses | Backlog |
| 6 | Active Play Systems | Golden Opportunities, Boosts, Missions, Intel economy | Backlog |
| 7 | Persistence & Offline | SQLite save/load, offline earnings calculation, save migrations | Backlog |
| 8 | UI Shell & Navigation | App shell, contextual HUD, screen navigation, design system tokens | Backlog |
| 9 | Game Feel & Juice | Canvas animations, haptics, sound event bus, visual feedback | Backlog |
| 10 | Onboarding & Tutorial | FTUE flow, contextual hints, tutorial state | Backlog |
| 11 | Balance & Economy Tuning | Pacing review, progression curves, playtesting iterations | Backlog |
| 12 | Accessibility & Performance | A11y semantics, profiling, low-end device testing | Backlog |
| 13 | In-App Purchases & Monetization | Rewarded ads, IAP integration | Future |
| 14 | Research Trees & Diplomatic Influence | New upgrade paths and strategies | Future |
| 15 | Prestige/Reset System | Optional voluntary reset mechanics | Future |
| 16 | Social Features | Leaderboards, ghost progress, seasonal challenges | Future |
| 17 | Art Evolution | Richer visuals, illustrated countries, animated effects | Future |

### Recommended Sequence

**Phase 1 — Engine (Epics 1–3):** Build the headless simulation and canvas renderer before any UI. Ensures the game loop and map are solid foundations.

**Phase 2 — Content (Epics 4–7):** Layer all game mechanics on top of the proven engine. Persistence comes after mechanics are stable.

**Phase 3 — Experience (Epics 8–12):** UI shell, game feel, onboarding, accessibility, and balance. This is the polish phase.

**Future (Epics 13–17):** Sequence TBD based on player feedback and business priorities.

### Vertical Slice

**Already achieved** — The core gameplay loop (tap, upgrade, automate, unlock, continent completion) is fully playable. Current epics focus on polish, UX redesign, and stability rather than proving core gameplay.

### Future Epic Details

#### Epic 13: In-App Purchases & Monetization

- **Goal:** Enable revenue generation through player-friendly monetization
- **Includes:** Rewarded ad integration, IAP store, premium currency or packs
- **Excludes:** Pay-to-win mechanics, forced ads
- **Dependencies:** Core game stable (Epics 1–12)
- **Deliverable:** Players can optionally watch ads for boosts and purchase value packs

#### Epic 14: Research Trees & Diplomatic Influence

- **Goal:** Add strategic depth through branching upgrade paths
- **Includes:** Research tree UI, diplomatic influence mechanic, new upgrade types
- **Excludes:** Prestige system (separate epic)
- **Dependencies:** Economy tuning (Epic 11), UI Shell (Epic 8)
- **Deliverable:** Players choose between multiple upgrade strategies for progression

#### Epic 15: Prestige/Reset System

- **Goal:** Add voluntary reset mechanic for long-term replayability
- **Includes:** Prestige currency, reset flow, persistent bonuses, prestige UI
- **Excludes:** Forced resets — must always be voluntary
- **Dependencies:** Balance (Epic 11), Research Trees (Epic 14)
- **Deliverable:** Players can optionally reset for permanent multiplier bonuses

#### Epic 16: Social Features

- **Goal:** Add community and competitive elements for retention
- **Includes:** Asynchronous leaderboards, ghost progress comparisons, seasonal challenges
- **Excludes:** Real-time multiplayer
- **Dependencies:** IAP (Epic 13) for seasonal reward structure
- **Deliverable:** Players can compare progress and compete in time-limited events

#### Epic 17: Art Evolution

- **Goal:** Elevate visual quality from vector/flat to richer illustrated style
- **Includes:** Illustrated country assets, animated map elements, visual effects
- **Excludes:** 3D rendering, camera changes
- **Dependencies:** UI shell complete (Epic 8), game feel complete (Epic 9)
- **Deliverable:** Visually richer game that stands out in app store screenshots

> **Note:** Epics 1–12 for the Flutter rewrite are new and stories will be created during architecture + sprint planning. The archived RN epics (1–13) are in `_bmad-output/planning-artifacts/epics.md` — reference them for design intent but not implementation. Future epics (13–17) will be broken into stories during sprint planning when they enter active development.

---

## Success Metrics

### Technical Metrics

| Metric | Target | Measurement Method |
|---|---|---|
| Frame rate | 60fps sustained | On-device profiling, Flutter DevTools performance overlay |
| Cold start load time | Under 3 seconds | Manual testing across device tiers |
| Crash rate | < 1% of sessions | App store crash reports, future analytics SDK |
| Save integrity | 0% corruption | Versioned save format with migration testing |
| App size | Under 50MB | Build output monitoring |

### Gameplay Metrics

| Metric | Target | Measurement Method |
|---|---|---|
| Day 1 retention | 40%+ | Analytics SDK (post-launch) |
| Day 7 retention | 15%+ | Analytics SDK (post-launch) |
| DAU/MAU ratio | 20%+ | Analytics SDK (post-launch) |
| Average session length | 3+ minutes | Analytics SDK (post-launch) |
| Tutorial completion rate | 80%+ | In-app event tracking |
| Continent 1 (Africa) completion | 60%+ of retained players | In-app event tracking |
| Ad opt-in rate | Track (no target yet) | Ad SDK metrics (future) |

### Qualitative Success Criteria

- Positive app store reviews — players mention the world map, satisfying progression, and respect for their time
- Players share progress screenshots on social media (map filling up with conquered countries)
- Reviews reference the USPs: "not like other idle games," "actually has an ending," "fair monetization"
- Players return after breaks without feeling punished (validates Offline Respectful pillar)

### Metric Review Cadence

- **Pre-launch:** Manual playtesting for technical metrics (load time, frame rate, crash rate)
- **Post-launch week 1:** Daily review of retention and session metrics
- **Post-launch month 1:** Weekly review of gameplay metrics, identify churn points
- **Ongoing:** Monthly review of store ratings, qualitative feedback, and feature usage

---

## Out of Scope

The following features are explicitly **not in scope** for v1.0:

- **In-app purchases and rewarded ads** — Monetization deferred to post-launch (Epic 13)
- **Research trees and diplomatic influence** — New upgrade paths deferred (Epic 14)
- **Prestige/reset mechanics** — Optional reset system deferred (Epic 15)
- **Social features** — Leaderboards, ghost progress, seasonal challenges deferred (Epic 16)
- **Rich art/illustrations** — Art evolution beyond current vector style deferred (Epic 17)
- **Background music** — No music planned for v1.0
- **Web/PC ports** — Under consideration for future, not v1.0
- **New worlds** — Mars, Corporate, Fantasy/Sci-Fi separate maps are post-v1.0 expansion content
- **Real-time multiplayer** — No multiplayer planned at any stage
- **Localization** — English only for v1.0

### Deferred to Post-Launch

| Feature | Priority | Dependency |
|---|---|---|
| IAP & Monetization | High — enables revenue | Core game stable (Epic 12) |
| Research Trees | Medium — adds depth | Economy balanced (Epic 11) |
| Prestige System | Medium — adds replayability | Research trees (Epic 14) |
| Social Features | Low — retention boost | IAP for seasonal rewards (Epic 13) |
| Art Evolution | Low — visual upgrade | UI shell + game feel (Epics 8–9) |

---

## Assumptions and Dependencies

### Key Assumptions

- **Solo developer:** Sharon is the sole developer; scope and timeline must reflect individual capacity
- **Flutter stable toolchain:** Flutter stable channel used for all builds; no beta/master channel dependencies
- **Offline-only:** No backend infrastructure required for v1.0
- **SQLite sufficient:** Drift/SQLite handles all save data needs; no cloud sync for v1.0
- **Dart big number package sufficient:** A Dart big number library handles exponential scaling without precision loss
- **Canvas performance:** Flutter `CustomPainter` can render 79 GeoJSON country polygons at 60fps on target devices (mid-range 2021+ phones)
- **No OTA updates required:** All changes ship via store releases; no critical patch mechanism beyond store review

### External Dependencies

| Dependency | Version | Risk Level | Notes |
|---|---|---|---|
| Flutter SDK | Stable (3.x+) | Low | Primary framework, stable channel |
| Dart | Bundled with Flutter | Low | Language runtime |
| drift | Latest stable | Low | SQLite ORM with type-safe migrations |
| sqlite3_flutter_libs | Latest stable | Low | SQLite native bindings for Flutter |
| google_fonts | Latest stable | Low | Fredoka font loading |
| audioplayers | Latest stable | Low | MP3 sound effects |
| big_decimal / decimal | Latest stable | Medium | Validate precision at game's maximum number scale (1e38+) |
| flutter_svg | Latest stable | Low | Icon assets if needed (optional) |

### Risk Factors

- **Late-game balance:** Progression curves were tuned for a 1-second JS tick loop — re-validate on Flutter's smoother game loop tick
- **Canvas performance on low-end devices:** GeoJSON polygon rendering at 60fps needs profiling on Android API 21 devices
- **Big number library selection:** Validate chosen Dart library handles 1e38+ precision before committing; may need custom implementation
- **No OTA patch channel:** Unlike Expo, hotfixes require full store submission and review (~1–3 days); plan accordingly
- **Solo developer bottleneck:** All design, code, art, and testing on one person

---

## Document Information

**Document:** Global Domination - Game Design Document
**Version:** 2.0
**Created:** 2026-03-21
**Revised:** 2026-04-05 — Migrated to Flutter stack; epics rewritten for Flutter rewrite; all RN/Expo/AsyncStorage/SVG references updated
**Author:** Sharon
**Status:** Active — Flutter rewrite in planning

### Change Log

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-03-21 | Initial GDD complete |
