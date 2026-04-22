# Story 1.7: `ContentRegistry` Loads from Assets at Boot

Status: done

## Story

As a developer,
I want a `ContentRegistry` that loads `countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, and `global_upgrades.json` from `assets/data/` once at boot and exposes immutable typed collections,
So that reducers and UI read from one in-memory source of truth and never call `rootBundle` themselves.

## Acceptance Criteria

1. **Given** minimal placeholder JSON files exist at `assets/data/*.json` (even if most are empty arrays for now) **When** `ContentRegistryLoader.loadFromAssets()` is awaited **Then** it returns an immutable `ContentRegistry` with `Map<CountryId, CountryDef>`, `Map<ContinentId, ContinentDef>`, and lists for achievements/missions/leaders/global upgrades.

2. **Given** a `contentRegistryProvider` defined in `lib/providers/app_providers.dart` as a `FutureProvider<ContentRegistry>` **When** any widget calls `ref.watch(contentRegistryProvider)` **Then** it resolves to the same registry instance across the app lifetime (no duplicate loads).

3. **Given** a malformed JSON file in `assets/data/` **When** the app boots **Then** `ContentRegistryLoader.loadFromAssets()` throws a `ContentLoadException` and the app displays a `BootErrorScreen` with reinstall guidance.

## Tasks / Subtasks

- [x] Task 1: Create ID value types (AC: #1)
  - [x] 1.1 Create `lib/game/values/country_id.dart` — `CountryId` wrapper around `String` with `const` constructor, `==`, `hashCode`, `toString`
  - [x] 1.2 Create `lib/game/values/continent_id.dart` — `ContinentId` wrapper around `String`, same pattern

- [x]Task 2: Create content definition classes in `lib/game/content/` (AC: #1)
  - [x]2.1 Create `country_def.dart` — `@immutable CountryDef` with: `CountryId id`, `ContinentId continent`, `Decimal baseInfluence`, `Decimal unlockCost`, `int tier`, `int generationSeconds`; `factory CountryDef.fromJson(Map<String, dynamic>)`
  - [x]2.2 Create `continent_def.dart` — `@immutable ContinentDef` with: `ContinentId id`, `String name`, `Decimal unlockThreshold`, `Decimal completionBonus`, `List<MilestoneReward> milestoneRewards`; `factory ContinentDef.fromJson(Map<String, dynamic>)`
  - [x]2.3 Create `leader_def.dart` — `@immutable LeaderDef` with: `String id`, `String name`, `List<Decimal> tierMultipliers` (4 tiers: 1.0, 1.5, 2.0, 3.0); `factory LeaderDef.fromJson(Map<String, dynamic>)`
  - [x]2.4 Create `achievement_def.dart` — `@immutable AchievementDef` with: `String id`, `String name`, `String conditionType`, `Map<String, dynamic> conditionParams`, `String rewardType` (multiplier|intel), `Decimal rewardValue`; `factory AchievementDef.fromJson(Map<String, dynamic>)`
  - [x]2.5 Create `mission_def.dart` — `@immutable MissionDef` with: `String id`, `String name`, `String conditionType`, `Map<String, dynamic> conditionParams`, `Decimal rewardIntel`; `factory MissionDef.fromJson(Map<String, dynamic>)`
  - [x]2.6 Create `global_upgrade_def.dart` — `@immutable GlobalUpgradeDef` with: `String id`, `String name`, `Decimal influenceAmplifier`; `factory GlobalUpgradeDef.fromJson(Map<String, dynamic>)`

- [x]Task 3: Create `ContentRegistry` (pure Dart) (AC: #1)
  - [x]3.1 Create `lib/game/content/content_registry.dart` — immutable class holding: `Map<CountryId, CountryDef> countries`, `Map<ContinentId, ContinentDef> continents`, `List<LeaderDef> leaders`, `List<AchievementDef> achievements`, `List<MissionDef> missions`, `List<GlobalUpgradeDef> globalUpgrades`
  - [x]3.2 Add `factory ContentRegistry.fromJsonStrings({required String countriesJson, required String continentsJson, required String leadersJson, required String achievementsJson, required String missionsJson, required String globalUpgradesJson})` — parses all 6 JSON strings, builds typed maps/lists, returns frozen registry
  - [x]3.3 Add validation: empty `countries` map → throw `ContentLoadException`; continent referenced by a country must exist in `continents` map

- [x]Task 4: Create `ContentRegistryLoader` (Flutter-aware) (AC: #1, #3)
  - [x]4.1 Create `lib/services/content_registry_loader.dart` — `static Future<ContentRegistry> loadFromAssets()` that calls `rootBundle.loadString(...)` for all 6 files via `Future.wait`, passes strings to `ContentRegistry.fromJsonStrings()`
  - [x]4.2 Wrap the entire load in try/catch — on `FormatException` or any parse failure, throw `ContentLoadException` with a descriptive message

- [x]Task 5: Create `ContentLoadException` (AC: #3)
  - [x]5.1 Create `lib/game/content/content_load_exception.dart` — simple `Exception` subclass with `final String message` (pure Dart, no Flutter imports). This is a boot-time-only exception, NOT part of the `GameError` hierarchy (Story 1.8)

- [x]Task 6: Create placeholder JSON assets (AC: #1)
  - [x]6.1 Create `assets/data/countries.json` — array with 3 placeholder countries: `egypt` (tier 1, Africa, baseInfluence "1", unlockCost "0", genSec 1), `nigeria` (tier 1, Africa, baseInfluence "5", unlockCost "5", genSec 1), `south_africa` (tier 1, Africa, baseInfluence "15", unlockCost "25", genSec 2). Schema matches architecture example. Full 79-country data lands in Epic 10.
  - [x]6.2 Create `assets/data/continents.json` — array with 7 continents: africa (threshold "0", bonus "0.25"), europe (threshold "1000000000", bonus "0.50"), asia (threshold "100000000000000", bonus "0.75"), north_america (threshold "100000000000000000000", bonus "1.00"), south_america (threshold "100000000000000000000000000", bonus "1.25"), antarctica (threshold "100000000000000000000000000000000", bonus "1.50"), oceania (threshold "1e38", bonus "1.75"). Include milestone rewards array (empty for now).
  - [x]6.3 Create `assets/data/leaders.json` — array with 1 placeholder: `{"id": "default_leader", "name": "General", "tierMultipliers": ["1.0", "1.5", "2.0", "3.0"]}`
  - [x]6.4 Create `assets/data/achievements.json` — empty array `[]`
  - [x]6.5 Create `assets/data/missions.json` — empty array `[]`
  - [x]6.6 Create `assets/data/global_upgrades.json` — empty array `[]`

- [x]Task 7: Update `pubspec.yaml` asset declarations (AC: #1)
  - [x]7.1 Add `- assets/data/` to the `assets:` section in `pubspec.yaml`

- [x]Task 8: Create Riverpod provider (AC: #2)
  - [x]8.1 Create `lib/providers/app_providers.dart` — define `final contentRegistryProvider = FutureProvider<ContentRegistry>((ref) async => ContentRegistryLoader.loadFromAssets());`

- [x]Task 9: Create `BootErrorScreen` (AC: #3)
  - [x]9.1 Create `lib/ui/boot_error_screen.dart` — simple `StatelessWidget` displaying error message and "Please reinstall the app" guidance. Uses `MaterialApp` wrapping so it can render independently of the main app scaffold.

- [x] Task 10: Wire boot gate into app startup (AC: #2, #3)
  - [x]10.1 In `lib/app.dart` (or create if not exists), add a `ConsumerWidget` that watches `contentRegistryProvider` — on loading show splash/spinner, on error show `BootErrorScreen`, on data proceed to main app
  - [x]10.2 Ensure `main.dart` uses the boot gate as the root widget

- [x] Task 11: Write tests (AC: #1, #2, #3)
  - [x]11.1 Create `test/game/content/content_registry_test.dart` — pure Dart tests using `package:test/test.dart`:
    - Test: `ContentRegistry.fromJsonStrings` with valid JSON → correct maps/lists populated
    - Test: countries map keyed by `CountryId`, continents by `ContinentId`
    - Test: `Decimal` fields parsed correctly (baseInfluence, unlockCost, thresholds)
    - Test: empty achievements/missions arrays parse to empty lists (valid)
    - Test: malformed JSON throws `ContentLoadException`
    - Test: country referencing non-existent continent throws `ContentLoadException`
    - Test: empty countries JSON (empty array) throws `ContentLoadException`
  - [x]11.2 Create `test/game/values/country_id_test.dart` — equality, hashCode, toString
  - [x]11.3 Create `test/game/values/continent_id_test.dart` — equality, hashCode, toString
  - [x]11.4 Create `test/game/content/country_def_test.dart` — `fromJson` parsing, field validation
  - [x]11.5 Create `test/game/content/continent_def_test.dart` — `fromJson` parsing, threshold as Decimal
  - [x]11.6 Create `test/services/content_registry_loader_test.dart` — Flutter test using `flutter_test` and `TestDefaultBinaryMessengerBinding` to mock `rootBundle`:
    - Test: loads all 6 files and returns valid registry
    - Test: missing asset file throws `ContentLoadException`
    - Test: malformed JSON in any file throws `ContentLoadException`

- [x] Task 12: Run analyzer and full test suite (AC: all)
  - [x]12.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x]12.2 Run `dart test test/game/` — all pure-Dart tests pass (including existing 118)
  - [x]12.3 Run `flutter test` — all tests pass
  - [x]12.4 Verify `lib/game/content/` has ZERO Flutter imports via grep
  - [x]12.5 Verify `test/game/content/` uses `package:test/test.dart` only (no `flutter_test`)

## Dev Notes

### Architecture Compliance

**CRITICAL: `lib/game/` has ZERO Flutter imports — this story has a split-layer design.**

The architecture pattern at [Source: game-architecture.md#Pattern 5] shows `ContentRegistry.loadFromAssets()` calling `rootBundle.loadString(...)`. However, `rootBundle` is from `package:flutter/services.dart`, which is forbidden in `lib/game/`. The resolution:

- **`lib/game/content/content_registry.dart`** — pure Dart. Constructor and `fromJsonStrings()` factory. Parses JSON, builds typed maps, validates. NO `rootBundle`, NO Flutter.
- **`lib/services/content_registry_loader.dart`** — Flutter-aware. Calls `rootBundle.loadString(...)` for all 6 files, passes raw strings to `ContentRegistry.fromJsonStrings()`.
- **`lib/providers/app_providers.dart`** — Riverpod `FutureProvider` calls `ContentRegistryLoader.loadFromAssets()`.

This split preserves the architecture boundary while matching the intent. The `ContentRegistry` class itself is testable with pure Dart tests (no Flutter dependency for parsing logic).

### Implementation Approach

**ID value types:**

`CountryId` and `ContinentId` are typed wrappers around `String`. Same pattern as `Influence`/`Intel` wrapping `Decimal` — prevent mixing up raw strings. Architecture specifies them at `lib/game/values/country_id.dart` and `continent_id.dart`. [Source: game-architecture.md#File Structure, line 562]

```dart
@immutable
class CountryId {
  final String value;
  const CountryId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CountryId && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CountryId($value)';
}
```

**Content definition classes:**

Each `*Def` class is `@immutable`, has a `const` constructor, and a `factory fromJson(Map<String, dynamic>)` that parses from decoded JSON. All numeric economy values (`baseInfluence`, `unlockCost`, thresholds, bonuses, multipliers) are `Decimal` — parsed via `Decimal.parse(json['field'] as String)`. This is critical: JSON stores big numbers as strings, never as `num` (which would lose precision via `double`).

```dart
@immutable
class CountryDef {
  final CountryId id;
  final ContinentId continent;
  final Decimal baseInfluence;
  final Decimal unlockCost;
  final int tier;
  final int generationSeconds;

  const CountryDef({
    required this.id,
    required this.continent,
    required this.baseInfluence,
    required this.unlockCost,
    required this.tier,
    required this.generationSeconds,
  });

  factory CountryDef.fromJson(Map<String, dynamic> json) {
    return CountryDef(
      id: CountryId(json['id'] as String),
      continent: ContinentId(json['continent'] as String),
      baseInfluence: Decimal.parse(json['baseInfluence'] as String),
      unlockCost: Decimal.parse(json['unlockCost'] as String),
      tier: json['tier'] as int,
      generationSeconds: json['generationSeconds'] as int,
    );
  }
}
```

**ContentRegistry.fromJsonStrings():**

```dart
factory ContentRegistry.fromJsonStrings({
  required String countriesJson,
  required String continentsJson,
  required String leadersJson,
  required String achievementsJson,
  required String missionsJson,
  required String globalUpgradesJson,
}) {
  final continents = _parseContinents(continentsJson);
  final countries = _parseCountries(countriesJson, continents);
  // ... parse remaining
  return ContentRegistry(
    countries: Map.unmodifiable(countries),
    continents: Map.unmodifiable(continents),
    leaders: List.unmodifiable(leaders),
    achievements: List.unmodifiable(achievements),
    missions: List.unmodifiable(missions),
    globalUpgrades: List.unmodifiable(globalUpgrades),
  );
}
```

Use `Map.unmodifiable()` and `List.unmodifiable()` to enforce immutability at runtime.

**ContentRegistryLoader (Flutter-aware):**

```dart
import 'package:flutter/services.dart' show rootBundle;

class ContentRegistryLoader {
  static Future<ContentRegistry> loadFromAssets() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/data/countries.json'),
        rootBundle.loadString('assets/data/continents.json'),
        rootBundle.loadString('assets/data/leaders.json'),
        rootBundle.loadString('assets/data/achievements.json'),
        rootBundle.loadString('assets/data/missions.json'),
        rootBundle.loadString('assets/data/global_upgrades.json'),
      ]);
      return ContentRegistry.fromJsonStrings(
        countriesJson: results[0],
        continentsJson: results[1],
        leadersJson: results[2],
        achievementsJson: results[3],
        missionsJson: results[4],
        globalUpgradesJson: results[5],
      );
    } on ContentLoadException {
      rethrow;
    } catch (e) {
      throw ContentLoadException('Failed to load game content: $e');
    }
  }
}
```

**JSON asset format — big numbers are STRINGS, not numbers:**

```json
{ "id": "egypt", "continent": "africa", "baseInfluence": "1", "unlockCost": "0", "tier": 1, "generationSeconds": 1 }
```

`baseInfluence` and `unlockCost` are strings because they're parsed to `Decimal`. Integer fields (`tier`, `generationSeconds`) are JSON numbers since they stay as `int`.

**Placeholder data:** Story 1.7 creates minimal placeholder data (3 countries, 7 continents, 1 leader, empty achievements/missions/global_upgrades). Full 79-country content lands in Epic 10 (Story 10.1). The placeholders are sufficient to validate the loading pipeline and unblock Epic 2 (map renderer needs country defs).

**Boot gate pattern:**

The boot gate is a `ConsumerWidget` wrapping the main app that watches `contentRegistryProvider`:
- `AsyncLoading` → show a simple splash/loading indicator
- `AsyncError` → show `BootErrorScreen`
- `AsyncData` → render the main app

This ensures `ContentRegistry` is fully loaded before any game screen accesses it. Downstream providers/widgets can use `ref.watch(contentRegistryProvider).requireValue` safely.

**Error handling note:** Story 1.8 (GameError sealed hierarchy) has NOT been implemented yet. `ContentLoadException` is a simple `Exception` subclass for boot-time failures only — it is NOT part of the `GameError` hierarchy. When Story 1.8 lands, it may introduce a `BootError` variant, but for now a standalone exception class is correct and won't conflict.

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/game/values/country_id.dart` | Typed ID wrapper for countries |
| CREATE | `lib/game/values/continent_id.dart` | Typed ID wrapper for continents |
| CREATE | `lib/game/content/content_registry.dart` | Immutable registry — pure Dart |
| CREATE | `lib/game/content/country_def.dart` | Country content definition |
| CREATE | `lib/game/content/continent_def.dart` | Continent content definition |
| CREATE | `lib/game/content/leader_def.dart` | Leader content definition |
| CREATE | `lib/game/content/achievement_def.dart` | Achievement content definition |
| CREATE | `lib/game/content/mission_def.dart` | Mission content definition |
| CREATE | `lib/game/content/global_upgrade_def.dart` | Global upgrade content definition |
| CREATE | `lib/game/content/content_load_exception.dart` | Boot-time load error |
| CREATE | `lib/services/content_registry_loader.dart` | Flutter rootBundle loader |
| CREATE | `lib/providers/app_providers.dart` | Riverpod FutureProvider for registry |
| CREATE | `lib/ui/boot_error_screen.dart` | Error screen on content load failure |
| MODIFY | `lib/app.dart` | Add boot gate watching contentRegistryProvider |
| MODIFY | `pubspec.yaml` | Add `assets/data/` to assets section |
| CREATE | `assets/data/countries.json` | 3 placeholder countries |
| CREATE | `assets/data/continents.json` | 7 continents with thresholds/bonuses |
| CREATE | `assets/data/leaders.json` | 1 placeholder leader |
| CREATE | `assets/data/achievements.json` | Empty array |
| CREATE | `assets/data/missions.json` | Empty array |
| CREATE | `assets/data/global_upgrades.json` | Empty array |
| CREATE | `test/game/values/country_id_test.dart` | ID value type tests |
| CREATE | `test/game/values/continent_id_test.dart` | ID value type tests |
| CREATE | `test/game/content/content_registry_test.dart` | Registry parsing + validation tests |
| CREATE | `test/game/content/country_def_test.dart` | CountryDef parsing tests |
| CREATE | `test/game/content/continent_def_test.dart` | ContinentDef parsing tests |
| CREATE | `test/services/content_registry_loader_test.dart` | Loader integration test (Flutter) |

### Testing Standards

- **`test/game/content/` and `test/game/values/`** — use `package:test/test.dart` only (NOT `flutter_test`). These test pure-Dart code under `lib/game/`.
- **`test/services/content_registry_loader_test.dart`** — use `package:flutter_test/flutter_test.dart` because it tests Flutter-aware code that uses `rootBundle`.
- Test `fromJson` parsing for each `*Def` class with valid and malformed input.
- Test `ContentRegistry.fromJsonStrings` with cross-referencing validation (country→continent).
- Test error cases: malformed JSON, missing required fields, empty countries, invalid continent references.
- Mock `rootBundle` in loader tests using `TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.setMockMessageHandler` or by serving fake asset bundles.

### Anti-Patterns to Avoid

- Do NOT put `rootBundle.loadString()` anywhere in `lib/game/` — it requires `package:flutter/services.dart` which violates the zero-Flutter-imports rule.
- Do NOT store big numbers as JSON `number` type — use JSON strings and parse with `Decimal.parse()`. JSON numbers lose precision via `double`.
- Do NOT make `ContentRegistry` mutable — all collections must be `Map.unmodifiable()` / `List.unmodifiable()`.
- Do NOT use `dart:convert` `jsonDecode` in `lib/game/content/` — it's acceptable since `dart:convert` is pure Dart (NOT a Flutter import).
- Do NOT create a singleton pattern for `ContentRegistry` — Riverpod's `FutureProvider` handles single-instance lifecycle.
- Do NOT use `print()` — use `Logger('ContentRegistry')` if any logging is needed (but prefer no logging in content loading since it's boot-time only).
- Do NOT use `double` for any economy values in `*Def` classes — always `Decimal`.
- Do NOT create `fromJson` constructors that silently swallow parse errors — throw `ContentLoadException` on any malformed data.
- Do NOT use `json_serializable` or `freezed` — manual parsing per project convention. [Source: project-context.md#File content discipline]
- Do NOT add `ContentRegistry` to `lib/data/` — it's game content, not persistence. It belongs in `lib/game/content/`.

### Previous Story Intelligence

**From Story 1.6 (Big-Number Precision Spike):**
- Precision spike PASSED — `Decimal` provides zero rounding at 1e38+ with compounded multipliers
- Benchmark: multiplication ~0.73-1.54us, addition ~0.12-0.29us — well under 10us threshold
- No caching follow-up needed — `Decimal` arithmetic is fast enough for per-tick use
- 118 total tests passing, zero analyzer issues
- `Decimal.parse('1e38')` works for scientific notation strings in JSON

**From Story 1.5 (Influence/Intel Value Objects):**
- `Influence` and `Intel` exist at `lib/game/values/influence.dart` and `intel.dart`
- Pattern: `@immutable`, `const` constructor, static `zero`, typed operators
- `depend_on_referenced_packages` lint: `package:meta` required explicit dep — already resolved
- Value objects use `Decimal.parse('...')` for construction from strings — same approach for `*Def.fromJson`
- `InfluenceFormatter` moved to `lib/game/values/` (not `lib/utils/`) during code review — keep content classes in `lib/game/content/`

**From Story 1.4 (Drift Database Scaffold):**
- `lib/data/database/app_database.dart` exists with empty tables
- `DecimalConverter` at `lib/data/database/converters/decimal_converter.dart` — stores `Decimal` as TEXT

**From Story 1.3 (Architecture Boundary Enforcement):**
- `test/architecture/game_boundary_test.dart` enforces no Flutter imports in `lib/game/`
- New files in `lib/game/content/` will be automatically covered by this boundary test

**From Story 1.1 (Safety Net):**
- `lib/main.dart` has global error handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`)
- `ProviderScope` wraps the root widget
- `lib/app.dart` may already exist — check before creating

**Key patterns established across previous stories:**
- File naming: `snake_case.dart`, one public class per file
- Test naming: `{source_name}_test.dart` mirroring lib path
- All `lib/game/` tests use `package:test/test.dart`
- `@immutable` annotation on all value/content classes
- `const` constructors wherever possible

### Git Intelligence

Recent commits are infrastructure-only (no feature code on master). Stories 1.1-1.6 are implemented but uncommitted (visible in git status as working tree changes). Key observations:
- `lib/game/values/` has 3 files (influence, intel, influence_formatter)
- `lib/game/content/` does NOT exist yet — create it
- `assets/data/` does NOT exist yet — create it
- `lib/providers/data_providers.dart` exists (from Story 1.4) — `app_providers.dart` is new

### Project Structure Notes

- `lib/game/content/` is a new directory — matches architecture file tree exactly [Source: game-architecture.md#File Structure, lines 564-570]
- `assets/data/` is a new directory — matches architecture asset layout [Source: game-architecture.md#File Structure, lines 536-544]
- Architecture specifies 5 `*_def.dart` files in `content/` (country, continent, leader, achievement, mission). Epics also reference `global_upgrades.json` which needs a corresponding `global_upgrade_def.dart`.
- `lib/providers/app_providers.dart` is the canonical location for the `contentRegistryProvider` per the acceptance criteria and architecture (`lib/providers/` is the composition root)
- `CountryId` and `ContinentId` at `lib/game/values/` per architecture — these don't exist yet

### References

- [Source: epics.md#Story 1.7] — Acceptance criteria, user story statement
- [Source: epics.md#FR45] — "79 countries and 7 continents loaded once at boot from assets/data into immutable ContentRegistry"
- [Source: epics.md#FR46] — "27 achievements and all missions loaded from content JSON — condition functions are data-driven"
- [Source: epics.md#NFR27] — Config discipline: game constants, balance values, content data, player settings kept strictly separate
- [Source: game-architecture.md#Pattern 5 "Content Loading"] — `ContentRegistry` class structure, `loadFromAssets()` pattern, rules (load once, immutable, failure → error screen)
- [Source: game-architecture.md#File Structure, lines 564-570] — `lib/game/content/` directory with `content_registry.dart` + 5 `*_def.dart` files
- [Source: game-architecture.md#Configuration Discipline] — Content data loaded at startup, accessed via `ContentRegistry.countries[id]`
- [Source: game-architecture.md#Content Example] — JSON schema for countries.json with string-encoded Decimals
- [Source: project-context.md#Critical Implementation Rules, rule 1] — `lib/game/` has ZERO Flutter imports
- [Source: project-context.md#Performance Rules] — "rootBundle.loadString(...) outside boot — ContentRegistry loads once and is immutable"
- [Source: project-context.md#Code Organization Rules] — Dependency graph: `game/` imports nothing; `providers/` imports `game/` + `data/` + `services/`
- [Source: project-context.md#Anti-patterns] — "Calling rootBundle.loadString in reducers or on the tick path — content loads once via ContentRegistry"

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- All 12 tasks and subtasks implemented and verified
- Split-layer design: pure Dart `ContentRegistry` + Flutter-aware `ContentRegistryLoader` preserves `lib/game/` zero-Flutter-imports boundary
- All `*Def` classes use `Decimal.parse()` for big numbers stored as JSON strings — no `double` precision loss
- Collections wrapped with `Map.unmodifiable()` and `List.unmodifiable()` for runtime immutability
- Boot gate (`GlobalDominationApp`) watches `contentRegistryProvider` — loading→spinner, error→`BootErrorScreen`, data→main app
- 31 new tests added (122 pure Dart total, 149 Flutter total), zero analyzer issues
- Verified: zero Flutter imports in `lib/game/content/`, zero `flutter_test` in `test/game/`

### Change Log

- 2026-04-21: Story 1.7 implemented — ContentRegistry, 6 content def classes, loader, provider, boot gate, placeholder JSON assets, 31 tests
- 2026-04-21: Code review — 0 HIGH, 1 MEDIUM (unnecessary import), 0 LOW. Fixed: removed unused `package:flutter/foundation.dart` import from loader test. Analyzer clean, 149 tests pass.

### File List

- CREATE `lib/game/values/country_id.dart`
- CREATE `lib/game/values/continent_id.dart`
- CREATE `lib/game/content/content_load_exception.dart`
- CREATE `lib/game/content/country_def.dart`
- CREATE `lib/game/content/continent_def.dart`
- CREATE `lib/game/content/leader_def.dart`
- CREATE `lib/game/content/achievement_def.dart`
- CREATE `lib/game/content/mission_def.dart`
- CREATE `lib/game/content/global_upgrade_def.dart`
- CREATE `lib/game/content/content_registry.dart`
- CREATE `lib/services/content_registry_loader.dart`
- CREATE `lib/providers/app_providers.dart`
- CREATE `lib/ui/boot_error_screen.dart`
- CREATE `lib/app.dart`
- MODIFY `lib/main.dart`
- MODIFY `pubspec.yaml`
- CREATE `assets/data/countries.json`
- CREATE `assets/data/continents.json`
- CREATE `assets/data/leaders.json`
- CREATE `assets/data/achievements.json`
- CREATE `assets/data/missions.json`
- CREATE `assets/data/global_upgrades.json`
- CREATE `test/game/values/country_id_test.dart`
- CREATE `test/game/values/continent_id_test.dart`
- CREATE `test/game/content/country_def_test.dart`
- CREATE `test/game/content/continent_def_test.dart`
- CREATE `test/game/content/content_registry_test.dart`
- CREATE `test/services/content_registry_loader_test.dart`
