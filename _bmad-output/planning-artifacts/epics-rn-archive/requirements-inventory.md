# Requirements Inventory

## Functional Requirements

FR-1: All theme colors referenced in components must exist in the theme definition
FR-2: Components must handle undefined/null data without crashing
FR-3: Sound system must function (implementation mandatory per sprint change 2026-03-15)
FR-4: All screens must be reachable through navigation or removed
FR-5: Save/load errors must surface user-facing feedback
FR-6: App must display meaningful state on initialization failure
FR-7: Every player action must produce visual + haptic feedback
FR-8: Map must support tap-to-collect without requiring bottom sheet
FR-9: New players must receive guided onboarding tutorial (12-step FTUE per tech spec)
FR-10: Players must have visibility into progression stats
FR-11: Continent progression must show visual progress indicators
FR-12: Game economy must be balanced for smooth progression pacing
FR-13: Offline Influence accumulates from automated countries, capped at 8 hours
FR-14: Achievements grant permanent global multiplier rewards
FR-15: Players can bulk-purchase upgrades (1x, 10x, 25x)
FR-16: Golden opportunities spawn randomly on the map with 10-100x multiplier burst
FR-17: Missions provide rotating active-play objectives rewarding Intel
FR-18: Daily rewards system with 7-day streak
FR-19: Bottom navigation bar with 5 tabs: Map, Leaders, Minigames, Upgrades, Settings
FR-20: Leaders tab showing continent-country-leader hierarchy for hire/upgrade management
FR-21: Higher-fidelity SVG map paths (Natural Earth 1:50m) for crisp rendering at high zoom
FR-22: Gradient fills for country states (locked, unlocked, automated) with visual depth
FR-23: Country unlock animation with radial ripple (first in continent) or white flash (subsequent)
FR-24: Ocean gradient background behind map paths
FR-25: Extended sound effects: continent complete fanfare, zoom whoosh, auto-collect tick
FR-26: Map tab must be the default screen on every cold launch
FR-27: Max zoom capped at 10x (reduce MAX_SCALE from 15 to 10)
FR-28: Single continuous map view — remove world/continent view modes and all branching logic
FR-29: Auto-zoom to latest unlocked country on app launch (post-tutorial and regular sessions)
FR-30: Remove back button from HUD (no longer needed without view mode switching)
FR-31: Remove continent bar (Row 2) from TopBarHUD
FR-32: Hide event/daily-reward button until events feature is implemented
FR-33: Display Intel currency in TopBarHUD with icon
FR-34: Create reusable CurrencyBadge component for Influence and Intel with dedicated icons
FR-35: Apply CurrencyBadge everywhere currencies are displayed (HUD, upgrades, rewards, missions, achievements, leaders)
FR-36: Fill missing countries on SVG map — future-playable as grey with border, pure filler as dark muted
FR-37: Move Settings from bottom tab to gear icon in TopBarHUD (rightmost element), opens as modal overlay
FR-38: Add Achievements tab to bottom navigation replacing Settings slot
FR-39: Minigames tab shows "Coming Soon" state with toast on tap
FR-40: Upgrade tab shows only accessible continent tabs (no locked continents)
FR-41: Remove Global tab from Upgrades screen — global upgrades to be re-homed to a dedicated screen (future epic)
FR-42: Upgrade tab shows only unlocked countries + next unlock teaser per continent
FR-43: Country card progress bar shows milestone progress (Lv 10/50/100/200) instead of tap timer
FR-44: Tap-to-collect on country cards in Upgrades screen with green/blue/default border states
FR-45: Remove "Done" button flash after purchase across all upgrade components
FR-46: Gate continent upgrades behind minimum 3 unlocked countries with increased cost
FR-47: Country map fill must use distinct color states: locked (grey), generating/not-ready (teal), ready-to-collect (green with breathing glow), automated (electric blue)
FR-48: Ready-to-collect countries must display a breathing pulse animation (opacity 0.6→1.0, ~1.5s ease-in-out, infinite) using a single shared Reanimated value
FR-49: All in-country text (AUTO label, level indicator, rate text) must be removed from SVG country paths
FR-50: Floating rate labels showing /s generation rate above unlocked countries, visible at continent zoom level; manual ready-to-collect countries show bouncing influence icon instead
FR-51: TopBarHUD currency values enlarged to 18-20px font with rate display at 12px+ for readability
FR-52: TopBarHUD must render on ALL tabs (Map, Upgrades, Leaders, Achievements, Minigames) — moved from GameScreen to App.tsx
FR-53: Locked continents display animated semi-transparent cloud overlay with horizontal drift; pointerEvents none so interaction is unaffected
FR-54: Map panning must NOT be restricted for locked continents — full world exploration always available

## NonFunctional Requirements

NFR-1: All interactive elements must have accessibility labels
NFR-2: Zustand selectors must be scoped to prevent unnecessary re-renders
NFR-3: Design system tokens must be used consistently (no hardcoded colors)
NFR-4: Documentation must match the current implementation
NFR-5: Error boundaries must prevent full-app white screens
NFR-6: All icons must use vector icon library (no emoji)
NFR-7: Modals must queue sequentially (no stacking)
NFR-8: Game must use break_eternity.js Decimal for all economy values
NFR-9: Single Zustand store pattern with selector-based component subscriptions
NFR-10: Map remains crisp at 10x zoom (reduced from 15x per Epic 16)
NFR-11: Pre-computed bounding boxes at build time (extraction script), not runtime parsing

## Additional Requirements

- Brownfield project — no starter template; build on existing codebase
- Persistence via AsyncStorage with custom Decimal serialization (save version 12)
- Game loop via 1-second tick interval with AppState awareness
- Modal queue system for sequential modal display (priority: Offline > Daily > Celebration > Achievement > Bonus Toast)
- SVG world map with 79 country paths, gesture-based interaction (react-native-gesture-handler)
- No CI/CD configured
- No backend — offline-first architecture
- @gorhom/bottom-sheet may become removable after CountryBottomSheet deletion

## UX Design Requirements

UX-DR1: Remove CountryBottomSheet entirely; replace with floating cards at screen bottom
UX-DR2: FloatingUnlockCard — slides up on tap of locked country showing country name, cost, affordability progress bar, and unlock button
UX-DR3: FloatingUpgradeCard — slides up on long-press of unlocked country showing IP level, buy amount toggle (x1/x10/x25/Next Milestone), cost, and buy button
UX-DR4: BottomNavBar — persistent 5-tab navigation bar (Map, Leaders, Minigames, Upgrades, Settings) at 56px + SafeArea height, z-index 110
UX-DR5: LeadersScreen — full screen with accordion continent cards showing leader management
UX-DR6: ContinentCard — expand/collapse showing leader count badge (hired/total), gold highlight glow when a leader hire is affordable
UX-DR7: CountryLeaderRow — country + leader status with contextual action button (IP requirement not met / hire available / upgrade available / max level)
UX-DR8: Milestone glow — amber animated pulse stroke on countries approaching leader thresholds (IP >=8 for hire, >=48 for Lv2, >=98 for Lv3)
UX-DR9: Boost shimmer — subtle opacity-cycling overlay on entire map SVG when boost is active
UX-DR10: 12-step FTUE tutorial rewrite with SVG mask spotlight, auto-advance on game actions, cross-tab flow (steps 0-8 on map, steps 9-12 on Leaders tab)
UX-DR11: Contextual one-time hints post-tutorial (golden, boost, milestone, leader nudge) — auto-dismiss after 4 seconds
UX-DR12: Stats screen accessible via TopBarHUD icon only (removed from bottom nav tabs)
UX-DR13: MinigamesPlaceholderScreen — Coming Soon placeholder tab
UX-DR17: TopBarHUD layout — influence (center-left), intel with icon (center-right), stats icon, gear/settings icon (rightmost)
UX-DR18: CurrencyBadge component — icon + formatted number, reusable across all screens, visually distinct per currency type
UX-DR19: Two-tier non-playable country rendering — future-playable (medium grey, subtle border) vs pure filler (dark muted, no border, no interaction)
UX-DR20: Settings screen opens as modal overlay from HUD gear icon, not as a tab
UX-DR21: Achievements tab — continent progress, missions, milestones (detailed design TBD in future epic)
UX-DR22: Bottom nav tab order: Map, Upgrades, Leaders, Achievements, Minigames (Coming Soon)
UX-DR23: Country color state palette: Locked #7A8A88→#A8B5B2 (keep), Generating teal #26A69A→#4DB6AC, Ready-to-collect vibrant green #4CAF50 with breathing glow, Automated electric blue #5C7AEA→#7C94F4
UX-DR24: Floating rate badge — semi-transparent dark pill above country center, white text [icon] X.XK/s; manual ready-to-collect shows bouncing influence coin icon
UX-DR25: Cloud overlay on locked continents — wispy semi-transparent PNG textures over continent bounding boxes with translateX drift animation; land visible beneath for aspiration
UX-DR26: HUD across all tabs — full HUD (influence + intel + rate + settings gear + stats icon), not slimmed-down

## FR Coverage Map

| Requirement | Epic | Description |
|-------------|------|-------------|
| FR-1 | Epic 1 | Theme colors exist for all referenced values |
| FR-2 | Epic 1 | Null-safe component rendering |
| FR-3 | Epic 8 | Sound system functional |
| FR-4 | Epic 2 | All screens reachable or removed |
| FR-5 | Epic 8 | Save/load error feedback |
| FR-6 | Epic 1 | Meaningful initialization failure UI |
| FR-7 | Epic 7 | Visual + haptic feedback on all actions |
| FR-8 | Epic 5 | Tap-to-collect on map without bottom sheet |
| FR-9 | Epic 9 | 12-step guided onboarding tutorial |
| FR-10 | Epic 10 | Progression stats visibility |
| FR-11 | Epic 10 | Continent progress visual indicators |
| FR-12 | Epic 11 | Balanced game economy |
| FR-13 | Epic 11 | Offline influence (automated countries, 8h cap) |
| FR-14 | Epic 11 | Achievement multiplier rewards |
| FR-15 | Epic 5 | Bulk upgrade purchase (1x/10x/25x) |
| FR-16 | Epic 5 | Golden opportunity tap-to-claim on map |
| FR-17 | Epic 11 | Mission objectives rewarding Intel |
| FR-18 | Epic 11 | Daily rewards with streak |
| FR-19 | Epic 4 | 5-tab bottom navigation bar |
| FR-20 | Epic 6 | Leaders tab with continent/country/leader hierarchy |
| NFR-1 | Epic 12 | Accessibility labels on all interactive elements |
| NFR-2 | Epic 12 | Scoped Zustand selectors |
| NFR-3 | Epic 3 | Consistent design system tokens |
| NFR-4 | Epic 13 | Documentation matches implementation |
| NFR-5 | Epic 1 | Error boundaries |
| NFR-6 | Epic 7 | Vector icons (no emoji) |
| NFR-7 | Epic 10 | Sequential modal queue |
| NFR-8 | Epic 12 | break_eternity.js Decimal usage |
| NFR-9 | Epic 12 | Zustand store pattern |
| UX-DR1 | Epic 5 | Remove CountryBottomSheet |
| UX-DR2 | Epic 5 | FloatingUnlockCard |
| UX-DR3 | Epic 5 | FloatingUpgradeCard |
| UX-DR4 | Epic 4 | BottomNavBar |
| UX-DR5 | Epic 6 | LeadersScreen |
| UX-DR6 | Epic 6 | ContinentCard |
| UX-DR7 | Epic 6 | CountryLeaderRow |
| UX-DR8 | Epic 7 | Milestone glow |
| UX-DR9 | Epic 7 | Boost shimmer |
| UX-DR10 | Epic 9 | 12-step FTUE rewrite |
| UX-DR11 | Epic 9 | Contextual one-time hints |
| UX-DR12 | Epic 4 | Stats via TopBarHUD only |
| UX-DR13 | Epic 4 | Minigames placeholder |
| UX-DR14 | Epic 14 | Remove long-press, tap-to-unlock on map, unlock flow in Upgrades tab |
| UX-DR15 | Epic 14 | Tutorial updated for Upgrades tab flow (no long-press) |
| UX-DR16 | Epic 14 | Milestone badge on Upgrades tab |
| FR-21 | Epic 15 | Higher-fidelity SVG map paths for crisp rendering at high zoom |
| FR-22 | Epic 15 | Gradient fills for country states (locked, unlocked, automated) |
| FR-23 | Epic 15 | Country unlock animation with visual celebration |
| FR-24 | Epic 15 | Ocean gradient background behind map |
| FR-25 | Epic 15 | Extended sound effects (continent complete, zoom, auto-tick) |
| NFR-10 | Epic 15/16 | Map remains crisp at 10x zoom (reduced from 15x per Epic 16) |
| NFR-11 | Epic 15 | Pre-computed bounding boxes at build time (not runtime) |
| FR-26 | Epic 16 | Map tab default on cold launch |
| FR-27 | Epic 16 | MAX_SCALE reduced to 10 |
| FR-28 | Epic 16 | Remove world/continent view modes |
| FR-29 | Epic 16 | Auto-zoom to latest unlocked country |
| FR-30 | Epic 16 | Remove back button from HUD |
| FR-31 | Epic 16 | Remove continent bar (Row 2) from HUD |
| FR-32 | Epic 16 | Hide event button until feature ships |
| FR-33 | Epic 16 | Intel currency display in HUD |
| FR-34 | Epic 16 | CurrencyBadge reusable component |
| FR-35 | Epic 16 | CurrencyBadge applied everywhere currencies appear |
| FR-36 | Epic 16 | Fill missing SVG countries (two-tier rendering) |
| FR-37 | Epic 16 | Settings gear icon in HUD (modal overlay) |
| FR-38 | Epic 16 | Achievements tab in bottom navigation |
| FR-39 | Epic 16 | Minigames Coming Soon toast |
| UX-DR17 | Epic 16 | New TopBarHUD layout |
| UX-DR18 | Epic 16 | CurrencyBadge design (icon + number per currency) |
| UX-DR19 | Epic 16 | Two-tier non-playable country rendering |
| UX-DR20 | Epic 16 | Settings modal overlay from HUD |
| UX-DR21 | Epic 16 | Achievements tab placeholder |
| UX-DR22 | Epic 16 | Bottom nav tab order: Map, Upgrades, Leaders, Achievements, Minigames |
| FR-47 | Epic 18 | Distinct country color states (grey/teal/green/blue) |
| FR-48 | Epic 18 | Breathing pulse on ready-to-collect countries |
| FR-49 | Epic 18 | Remove all in-country SVG text |
| FR-50 | Epic 18 | Floating rate labels above countries |
| FR-51 | Epic 18 | Enlarged HUD currency display |
| FR-52 | Epic 18 | HUD visible on all tabs |
| FR-53 | Epic 18 | Cloud overlay on locked continents |
| FR-54 | Epic 18 | No pan restriction on locked continents |
| UX-DR23 | Epic 18 | Color palette spec for country states |
| UX-DR24 | Epic 18 | Floating rate badge design |
| UX-DR25 | Epic 18 | Cloud overlay visual design |
| UX-DR26 | Epic 18 | Full HUD on all tabs |
