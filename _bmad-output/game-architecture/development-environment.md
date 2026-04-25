# Development Environment

### Prerequisites

| Tool | Version | Verified |
|---|---|---|
| Flutter SDK | **3.41.6 stable** | ✅ (`flutter --version` on 2026-04-21) |
| Dart | **3.11.4** (bundled) | ✅ |
| Xcode | 16.x (iOS builds) | Per Flutter 3.41 support matrix |
| Android Studio / command-line tools | NDK 27, cmdline-tools latest | Per Flutter 3.41 support matrix |
| CocoaPods | 1.15+ (iOS) | |
| Git | 2.40+ | |

### AI Tooling (MCP Servers — already configured)

These are registered in [.mcp.json](.mcp.json) at the project root — no manual setup required:

| MCP Server | Purpose | Install Type |
|---|---|---|
| `dart` (official Dart MCP) | Analyzer, hot reload, widget tree, runtime errors, tests | `dart mcp-server` (bundled with Dart SDK 3.11+) |
| `flutter-mcp` | Flutter-specific dev tooling | `npx flutter-mcp` |
| `context7` | Up-to-date library documentation | `npx @upstash/context7-mcp` |
| `memory` | Persistent knowledge graph across sessions | `npx @modelcontextprotocol/server-memory` |
| `sequential-thinking` | Multi-step reasoning aid | `npx @modelcontextprotocol/server-sequential-thinking` |

These give the AI direct access to Flutter for scene inspection, widget tree queries, hot reload, and context-aware code generation.

### Setup Commands

```bash
# Clone and enter project
git clone <repo-url> global-domination-flutter
cd global-domination-flutter

# Verify Flutter version
flutter --version
# Expected: Flutter 3.41.6 stable, Dart 3.11.4

# Install dependencies
flutter pub get

# Run code generation (Drift tables)
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test                    # widget + unit tests
dart test                       # pure-Dart tests under test/game/ (no Flutter binding)

# Launch on connected device / simulator
flutter devices
flutter run                      # debug mode with hot reload
flutter run --release           # release build for performance profiling
```

### First-Time Setup Notes

1. **Portrait lock** — add to `lib/main.dart`:
   ```dart
   import 'package:flutter/services.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
     // ...global error handlers and runApp()
   }
   ```
2. **Impeller on Android** — enabled by default in Flutter 3.27+; confirm with `flutter doctor -v`. If perf regressions appear on specific devices, opt out via `AndroidManifest.xml` `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`.
3. **Drift `build.yaml`** — add at project root:
   ```yaml
   targets:
     $default:
       builders:
         drift_dev:
           options:
             store_date_time_values_as_text: true
             named_parameters: true
             write_from_json_string_constructor: false
   ```
4. **Google Fonts offline bundling** (consider post-launch): Google Fonts downloads Fredoka at runtime by default — fine for v1 (first use caches). For production, bundle the TTF in `assets/fonts/` to avoid first-launch network fetch.
5. **Analysis options** — apply the lint config from the Implementation Patterns section of this document to `analysis_options.yaml`.

### First Steps for Epic 1 (Foundation & Project Setup)

1. Apply `analysis_options.yaml` with the lint configuration above
2. Wire `main.dart` with global error handlers + portrait lock
3. Set up Drift: create `lib/data/database/app_database.dart` with empty table list, generate via `build_runner`, verify migrations scaffold works
4. Create `lib/game/game_world.dart` skeleton with empty `applyCommand` + `tick`
5. Create `lib/providers/app_providers.dart` with `clockProvider` + `appDatabaseProvider`
6. Run the **big-number precision spike** (property-test `Decimal` at 1e38+ with compounded multipliers) — this is the earliest risk to validate
7. Run the **canvas performance spike** on Android API 21 device (parse `countries.geojson.json`, render all 79 polygons, pan/zoom — confirm 60fps baseline)

### CI Minimum Pipeline (add in Epic 1)

```yaml
# .github/workflows/ci.yml (sketch — tune to your runner)
- flutter pub get
- dart run build_runner build --delete-conflicting-outputs
- flutter analyze --fatal-infos
- dart test test/game/              # pure-Dart tests
- flutter test test/                 # widget tests
- flutter build apk --debug          # smoke-test build
- flutter build ios --no-codesign --debug
```

---
