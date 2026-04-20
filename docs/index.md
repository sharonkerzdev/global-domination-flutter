# Project Documentation Index

> Global Domination Game — Generated: 2026-04-06

## Project Overview

- **Type:** Monolith — single cohesive codebase
- **Primary Language:** TypeScript (strict mode)
- **Framework:** React Native 0.81.5 + Expo SDK 54
- **Architecture:** Engine → Store → UI (3-layer, separated concerns)

## Quick Reference

- **Tech Stack:** React Native + Expo + Zustand + break_eternity.js + MapLibre + Reanimated
- **Entry Point:** `index.ts` → `App.tsx`
- **Architecture Pattern:** Engine (pure math) → Store (Zustand) → UI (React components)
- **Persistence:** AsyncStorage with custom Decimal serialization (save v13, migration from v12)
- **Game Content:** 79 countries, 7 continents, 20+ achievements, 3 global upgrades, 7 continent upgrades
- **Active Play:** Golden opportunities (10-100x), boosts (30s 2x), missions (3 types), daily rewards (7-day cycle)
- **Platforms:** iOS + Android (portrait, offline-first, New Architecture enabled)
- **Tests:** Jest + jest-expo + @testing-library/react-native

## Generated Documentation

- [Project Overview](./project-overview.md) — Executive summary, tech stack, game systems, content inventory
- [Architecture](./architecture.md) — Full architecture: 3-layer pattern, state management, data flow, game systems, UI, map, build/deploy
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory tree, critical folders, entry points, data flow between modules
- [Component Inventory](./component-inventory.md) — 29+ components: design system (7), map (3), leaders (2), modals (4), toasts (3), features (5), system (5)
- [Data Models](./data-models.md) — TypeScript interfaces, entity relationships, serialization, data configuration
- [Development Guide](./development-guide.md) — Setup, scripts, patterns, testing, conventions, balance tuning, EAS build/deploy
- [Migration Guide](./MIGRATION.md) — Expo Go → Development Build migration (for MapLibre native module)

## Existing Project Documentation

- [PRD](../PRD.md) — Product Requirements Document: vision, game loops, world structure, monetization
- [Architecture Guidelines](../ARCHITECTURE.md) — Original architecture guidelines (folder structure, principles)
- [MVP Scope](../MVP_SCOPE.md) — Current MVP scope definition
- [Tech Decisions](../TECH_DECISIONS.md) — Technology stack rationale and decisions

## Planning Artifacts

- [Game Design Document](../_bmad-output/planning-artifacts/gdd.md) — Full GDD with mechanics, systems, progression, economy
- [Epic Breakdowns](../_bmad-output/planning-artifacts/epics/index.md) — 18 epics with story-level detail
- [Epic List](../_bmad-output/planning-artifacts/epics/epic-list.md) — Summary table of all epics with status
- [Requirements Inventory](../_bmad-output/planning-artifacts/epics/requirements-inventory.md) — Functional/non-functional requirements with coverage
- [Sprint Status](../_bmad-output/implementation-artifacts/sprint-status.yaml) — Current sprint tracking
- [Project Context](../_bmad-output/project-context.md) — AI-optimized rules (28 rules)
- [Playtest Plan](../_bmad-output/playtest-plan.md) — Structured playtesting methodology

## Getting Started

### For New Developers

1. Read [Project Overview](./project-overview.md) for the big picture
2. Review [Architecture](./architecture.md) for technical decisions and data flow
3. Follow [Development Guide](./development-guide.md) for setup and running
4. Browse [Source Tree Analysis](./source-tree-analysis.md) to understand the codebase layout
5. Check [Component Inventory](./component-inventory.md) when working on UI

### For AI-Assisted Development

When using this documentation as context for AI coding assistants:

- **For new features:** Start with [Architecture](./architecture.md) + [Data Models](./data-models.md)
- **For UI changes:** Reference [Component Inventory](./component-inventory.md) + [Architecture](./architecture.md) UI section
- **For balance changes:** See [Development Guide](./development-guide.md) Balance Tuning section
- **For new game entities:** Follow patterns in [Data Models](./data-models.md) + [Development Guide](./development-guide.md)
- **For understanding the economy:** See [Architecture](./architecture.md) Game Systems section
- **For testing:** See [Development Guide](./development-guide.md) Testing section
- **For planning context:** See [Game Design Document](../_bmad-output/planning-artifacts/gdd.md) + [Epic Breakdowns](../_bmad-output/planning-artifacts/epics/index.md)

### Key Files to Know

| Purpose | File | Size |
|---|---|---|
| App entry | `App.tsx` | ~468 LOC |
| Game state + actions | `src/stores/gameStore.ts` | ~2,225 LOC |
| All game math | `src/engine/formulas.ts` | Core formulas |
| Achievement logic | `src/engine/achievementUnlocks.ts` | 20+ achievements |
| Continent milestones | `src/engine/continentMilestones.ts` | 25/50/75% milestones |
| World definition | `src/data/gameData.ts` | 79 countries, 7 continents |
| Active play config | `src/data/activePlayConfig.ts` | Golden/boost/mission timing |
| Country ↔ map mapping | `src/data/countryMapping.ts` | Game ID ↔ ISO-2 |
| Daily rewards | `src/data/dailyRewardsConfig.ts` | 7-day cycle |
| Type definitions | `src/types/game.ts` | Core interfaces |
| Main game screen | `src/screens/GameScreen.tsx` | Map + modals + tutorial |
| Game loop hook | `src/hooks/useGameLoop.ts` | 1s tick interval |
| Modal queue hook | `src/hooks/useModalQueue.ts` | Priority queue |
| Save/load system | `src/utils/saveSystem.ts` | v13, migration |
| Theme/design tokens | `src/styles/theme.ts` | Fredoka, colors, spacing |
| Map component | `src/components/map/MapLibreMap.tsx` | MapLibre GL renderer |
