# Epic List

### Epic 1: Foundation — Architecture Boundaries, Persistence Scaffold, and Safety Net
Deliver a stable Flutter app scaffold that enforces the headless-simulation boundary, loads game content, persists player settings, handles errors without crashing to white, and passes the two Epic-1 risk spikes (big-number precision and canvas performance). After this epic the app boots to a placeholder screen with guaranteed-safe foundations — not yet playable, but every subsequent epic can build on proven primitives without re-litigating architecture.
**FRs covered:** FR45, FR46
**NFRs covered:** NFR5, NFR6, NFR8, NFR9, NFR10, NFR15, NFR16, NFR17, NFR25, NFR26

### Epic 2: Playable Map — Tap a Country, Earn Influence
Deliver the minimum playable vertical slice: a custom-rendered world map with a handful of unlocked countries the player can pan, zoom, and tap to collect Influence. The `GameWorld` tick system drives generation; `CustomPainter` renders state-colored country polygons; hit-testing routes taps into `GameCommand`s. After this epic a player can tap the map and watch Influence go up — the core dopamine loop is proven end-to-end on the Flutter stack.
**FRs covered:** FR1, FR2, FR21, FR22, FR23, FR24
**NFRs covered:** (none exclusive — NFR1/NFR2/NFR3/NFR11 validated incrementally across Epics 2, 8, 11)

### Epic 3: Power Up — Upgrades, Leaders, and Automation
Deliver the "feel more powerful" layer: players spend Influence to raise Influence Power (1×/10×/25× bulk), hire Leaders at IP 10 to automate income, and upgrade Leader tiers. The multiplier stack lives in a single `IncomeCalculator` — the authoritative source for all rate math. After this epic, manual tapping transitions naturally to idle generation.
**FRs covered:** FR3, FR4, FR5, FR6
**NFRs covered:** NFR7, NFR12

### Epic 4: Expand — Unlocks, Continents, and Completion Bonuses
Deliver the geographic-progression promise: players unlock new countries with exponential cost scaling, unlock new continents at Influence thresholds, hit 25/50/75/100% continent milestones for bonus rewards, and receive a permanent global multiplier on continent completion. After this epic, the map fills up over time and the "conquer the world" arc is real, not a promise.
**FRs covered:** FR7, FR8, FR9, FR10

### Epic 5: Active Play — Goldens, Boosts, Missions, Dailies, Achievements
Deliver the burst / retention layer: Golden Opportunities spawn on the map for 10–100× tap-to-claim bursts, Boosts give 2× for 30s in exchange for Intel, rotating Missions reward Intel for active play, the 7-day Daily Reward streak encourages return visits, and 27 Achievements grant permanent multiplier rewards. After this epic there are reasons to open the app beyond just collecting.
**FRs covered:** FR11, FR12, FR13, FR14, FR15

### Epic 6: Never Lose Progress — Persistence and Offline Earnings
Deliver the Offline Respectful pillar: all state persists to Drift/SQLite via a normalized schema with typed migrations; on resume, offline earnings are computed from Leader-automated countries only (capped at 8h) with stable multipliers, presented via an Offline Reward Modal before any other UI interaction; save corruption has a defined recovery path. After this epic, players can close the app for days without anxiety.
**FRs covered:** FR16, FR17, FR18, FR19, FR20
**NFRs covered:** NFR13, NFR14

### Epic 7: Complete the Shell — Navigation, HUD, Stats, Settings, Upgrades & Leaders Screens
Deliver the productized app shell around the map: 5-tab bottom navigation (Map / Upgrades / Leaders / Achievements / Minigames placeholder), global HUD with Influence + Intel currency badges across all tabs, Stats screen reachable from a HUD icon, Settings as a HUD-gear modal, Upgrades tab showing unlocked countries + next-unlock teaser per continent, Leaders tab with grouped-by-continent accordion, sequential modal queue with priority. After this epic the app feels like a shipped product, not a prototype.
**FRs covered:** FR26, FR27, FR28, FR29, FR30, FR31, FR32, FR33, FR34, FR43, FR44
**NFRs covered:** NFR21, NFR22, NFR23

### Epic 8: Juice — Game Feel Layer
Deliver the sensory polish layer: every typed `GameEvent` routes through `AudioService` and `HapticsService` (no scattered `playSound()` calls in UI); five core SFX (collect / unlock / upgrade / milestone / golden) are wired; flying numbers spawn on tap; ready-to-collect countries breathe; unlocks and continent-completes get dedicated celebration animations. After this epic every interaction has weight.
**FRs covered:** FR25, FR35, FR36, FR37, FR38
**NFRs covered:** NFR11

### Epic 9: Onboard — Tutorial and Contextual Hints
Deliver a first-time player journey: a step-by-step tutorial overlay covers tap-to-collect → first upgrade → first Leader → first unlock; steps auto-advance on the triggering action; progress survives app restart; post-tutorial one-time contextual hints fire on first exposure to Golden / Boost / Leader-ready moments and auto-dismiss. After this epic a cold first-time player understands the loop without external explanation.
**FRs covered:** FR39, FR40, FR41, FR42

### Epic 10: Tune — Economy and Balance
Deliver tuned progression curves on the Flutter engine: content JSON (`countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, `global_upgrades.json`) is populated and validated; balance constants (`BalanceConfig`) tuned against playtest data; pacing walls revisited against the new smoother game loop; late-game balance refined via instrumented runs. After this epic the numbers feel right — not too fast, not grindy.
**FRs covered:** _(no new FR coverage — tunes data underlying FR3, FR7, FR8, FR9, FR11, FR12, FR13, FR15 across prior epics)_
**NFRs covered:** NFR27

### Epic 11: Harden — Accessibility and Performance
Deliver shippable quality: every interactive widget wraps in `Semantics` with proper labels; country states have non-color cues; touch targets meet platform minimums; app sustains 60fps on low-end Android (API 21); cold start stays under 3s; `Path` rebuilds are cached where profiling flags them; app size stays under 50MB. After this epic the game is store-submission ready.
**FRs covered:** _(covers NFRs only — polish applies across all epics)_
**NFRs covered:** NFR1, NFR2, NFR3, NFR4, NFR18, NFR19, NFR20, NFR24

### Future Epics (Out of Scope for v1.0)

- **Epic 12 (future): In-App Purchases & Monetization** — rewarded ads, IAP store, premium value packs. Dependencies: Epics 1–11 stable.
- **Epic 13 (future): Research Trees & Diplomatic Influence** — branching upgrade paths and alternative strategies. Dependencies: Epic 10 (balance) + Epic 7 (UI shell).
- **Epic 14 (future): Prestige/Reset System** — optional voluntary reset for permanent multipliers. Dependencies: Epic 10 (balance) + Epic 13 (research trees).
- **Epic 15 (future): Social Features** — asynchronous leaderboards, ghost progress, seasonal challenges. Dependencies: Epic 12 (IAP for seasonal rewards).
- **Epic 16 (future): Art Evolution** — illustrated countries, animated map elements, richer visual effects. Dependencies: Epic 7 (UI shell) + Epic 8 (game feel).

These are intentionally NOT broken into stories in this document — they will be elaborated during the sprint cycle where they enter active development.

### Epic Sequencing and Dependencies

**Phase 1 — Engine (Epic 1 → Epic 2):** Foundation unblocks Playable Map. Epic 2 depends on Epic 1's `GameWorld` + `ContentRegistry` + persistence scaffold existing.

**Phase 2 — Mechanics (Epic 3 → Epic 4 → Epic 5):** Each builds on the prior. Upgrades/Leaders (3) must exist before Continent completion bonuses (4) matter; Continents (4) must exist before Missions referencing continent progress (5) can author conditions. Daily Rewards and Achievements within Epic 5 are largely independent.

**Phase 3 — Durability (Epic 6):** Persistence can start in parallel with Epic 2 (event-driven write points need to exist as mechanics land) but event-driven writes for Epic 5 features must be wired before Epic 6 closes. Offline earnings flow depends on Leader system (Epic 3).

**Phase 4 — Experience (Epic 7 → Epic 8 → Epic 9):** Shell first, then juice, then onboarding. Shell provides the surfaces (tabs, HUD, modals) where juice (Epic 8) fires and tutorial (Epic 9) spotlights.

**Phase 5 — Polish (Epic 10 → Epic 11):** Balance tuning needs real runs of the full game (Epics 1–9 landed); accessibility + performance hardening benefits from frozen surfaces.

Epics are **standalone in the user-value sense** — each delivers a distinguishable player-visible outcome — but Flutter-rewrite scope means they are **implementation-sequenced**: Epic 2 cannot ship before Epic 1, Epic 4 needs Epic 3's Leader system, etc. This is expected for a ground-up rewrite and is documented here so story ordering respects it.

---
