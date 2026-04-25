# Executive Summary

**Global Domination** is a mobile-first idle/incremental strategy game — tap 79 countries across 7 continents on an interactive canvas-rendered world map — built as a v2 Flutter rewrite of a shipped React Native codebase.

The architecture follows a **strict three-layer vertical split**: a **pure-Dart `GameWorld` simulation** (zero Flutter imports), a **Drift/SQLite persistence layer** with typed migrations, and a **Flutter UI layer** using `CustomPainter` for the world map and `riverpod` for state distribution. A single `Ticker` drives the variable-timestep simulation; events from the sim flow through a typed `Stream<GameEvent>` that audio, haptics, and persistence services subscribe to — UI never calls `playSound()` or mutates state directly.

**Key architectural decisions:**

- **Framework:** Plain Flutter 3.41.6 — no game-engine layer (Flame rejected), no external map library (`CustomPainter` over GeoJSON)
- **State:** `Riverpod 2.6` wraps a headless `GameWorld`, serving both reactive rebuilds and dependency injection
- **Numbers:** `decimal` 3.0 wrapped in `Influence` / `Intel` value objects for arbitrary precision at 1e38+
- **Persistence:** Drift 2.26 normalized schema with event-driven writes + schema-backup-before-migrate (no-OTA constraint)
- **Offline earnings:** Single `OfflineEarningsEvent` on `AppLifecycleState.resumed`, deterministic via injectable `Clock`
- **Organization:** Layered + feature-hybrid — `lib/{game,data,ui,services,providers,utils}/`, with per-feature folders within each layer

**Core systems:** 12 systems mapped 1:1 to the 12 Flutter-rewrite epics from the GDD. **Patterns defined:** 5 novel + 6 standard, all with concrete code examples. **Enforcement:** `custom_lint` rules + CI grep checks + widget tests make architectural boundaries visible in PR diffs, not just aspirational.

**Ready for:** Epic-level story creation and implementation.

---
