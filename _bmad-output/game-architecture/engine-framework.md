# Engine & Framework

### Selected Framework

**Flutter 3.41.6 stable** (Dart 3.11.4) — plain Flutter with `CustomPainter` + `Ticker`, **no game engine layer** (no Flame, no external map library).

**Rationale:**
- Idle game is UI-heavy (bottom nav, tabs, modals, HUD) with a single custom canvas view — plays to Flutter's strengths.
- No sprites, no physics, no scenes, no particle systems — a game-engine layer like Flame would add abstractions without pulling weight.
- Impeller rendering eliminates the JS-bridge bottleneck that constrained the v1 React Native build.
- Single codebase → iOS 16+ and Android API 21+ from day one.

### Project Initialization

Scaffold already created via `flutter create`. Entrypoint at `lib/main.dart`. Mobile target platforms (`ios/`, `android/`) are in scope for v1.0; other platform folders (`web/`, `windows/`, `macos/`, `linux/`) are inert — retain for future desktop/web ports (GDD flags these as *under consideration for later phases*) or delete if disk footprint becomes a concern.

### Framework-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendering | Impeller + `CustomPainter` for map, widgets for UI | GPU-accelerated; enable on Android via manifest flag |
| Layout | Material/Cupertino widgets | Bottom-nav, modals, HUD in widget tree |
| Input | `GestureDetector` + custom hit-testing inside `CustomPainter` | Pan/zoom via transform matrices |
| Animation | `AnimationController` + `Ticker` | Display-refresh-aligned |
| Game loop | `Ticker` driven by `SchedulerBinding` | Foreground only — no background ticks |
| Audio | `audioplayers: ^6.4.0` | Short MP3 SFX; event-bus driven |
| Haptics | `HapticFeedback` (SDK built-in) | Pairs with audio events |
| Persistence | `drift: ^2.26.1` + `sqlite3_flutter_libs: ^0.5.25` | Typed, migration-aware SQLite |
| Fonts | `google_fonts: ^6.2.1` (Fredoka) | Downloaded at runtime; consider bundling |
| Big numbers | `decimal: ^3.0.2` | Arbitrary-precision; must be validated at 1e38+ |
| Build & release | `flutter build ipa` / `appbundle` | Standard store submission |

### MCP Development Environment (already configured in `.mcp.json`)

| MCP | Purpose |
|---|---|
| `dart` (official Dart MCP) | Analyzer, hot reload, widget tree, runtime errors, tests |
| `flutter-mcp` | Flutter-specific dev tooling |
| `context7` | Up-to-date library documentation for Drift, Riverpod, etc. |
| `memory` | Persistent knowledge graph across sessions |
| `sequential-thinking` | Multi-step reasoning aid |

### Remaining Architectural Decisions

These are not resolved by picking Flutter and must be made explicitly in the next step:

1. State management layering (Riverpod + `GameWorld` boundary)
2. Game loop strategy (single `Ticker` owner, fixed vs variable timestep)
3. Persistence write cadence (per-tick vs debounced vs event-driven)
4. Offline earnings algorithm (location, re-entry, determinism)
5. Big-number representation (`Decimal` vs `Influence` value object; rounding rules)
6. Event bus design (custom vs Riverpod streams)
7. Map rendering pipeline (projection, transforms, hit-testing)
8. Navigation (Navigator 1.0 vs `go_router`)
9. Error handling, logging, crash telemetry
10. Theme / design tokens structure
11. Dependency injection + clock abstraction for tests
12. Multiplier stack ordering specification

---
