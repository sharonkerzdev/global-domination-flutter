# Story 2.1: GeoJSON Parser and `CountryPath` Cache

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want `assets/geo/countries.geojson.json` parsed once at boot into a `List<CountryPath>` with precomputed bounding boxes and cached `Path` objects,
So that the map painter and hit-tester operate on ready-to-use data without reparsing on every frame.

## Acceptance Criteria

1. **Given** `assets/geo/countries.geojson.json` exists **When** the parser loads it at boot **Then** it produces a `List<CountryPath>` with 79 entries, each containing the `CountryId`, continent, GeoJSON rings projected to `[0,1]²` equirectangular, bbox, and a built `Path`.

2. **Given** a `geoProvider` as a `FutureProvider<List<CountryPath>>` **When** multiple widgets watch it **Then** they share the same parsed result — parsing happens exactly once per app lifetime.

3. **Given** a `CountryPath` **When** its bbox is read **Then** the bbox exactly encloses all ring vertices (unit-tested on a sample country).

## Tasks / Subtasks

- [x] Task 1: Create `CountryPath` data class (AC: #1, #3)
  - [x] 1.1 Create `lib/ui/features/map/country_path.dart` — `@immutable` data class holding: `CountryId id`, `ContinentId continent`, `List<List<Offset>> rings` (projected [0,1]² coordinates), `Rect bbox`, `Path path`
  - [x] 1.2 The `rings` field stores raw projected coordinates as `List<List<Offset>>` for point-in-polygon hit-testing in Story 2.4. Each inner list is one ring (outer boundary or hole). These are the SAME coordinates used to build `path`, stored separately because `Path` doesn't expose vertices
  - [x] 1.3 Manual `==` / `hashCode` on `id` only (two `CountryPath` objects with the same `CountryId` are the same country)
  - [x] 1.4 This class uses `dart:ui` (`Path`, `Rect`, `Offset`) — it CANNOT live in `lib/game/`. Place in `lib/ui/features/map/`
  - [x] 1.5 Add `toString()` returning `'CountryPath(${id.value})'` for debugging

- [x] Task 2: Create GeoJSON-name-to-CountryId mapping (AC: #1)
  - [x] 2.1 Create `lib/ui/features/map/geo_country_id_mapping.dart` — a `const Map<String, String>` mapping GeoJSON `name` property values to game `CountryId` string values
  - [x] 2.2 The GeoJSON has `name` (display: "Egypt", "South Africa", "Dem. Rep. Congo") and `iso_a2` (two-letter: "EG", "ZA", "CD"). The game uses snake_case IDs ("egypt", "south_africa")
  - [x] 2.3 Provide a `CountryId? geoJsonNameToCountryId(String geoJsonName)` function that looks up the mapping and returns `null` for unrecognized names (defensive — log a warning via `Logger('GeoJsonParser')`)
  - [x] 2.4 The full 79-country mapping must be populated. Derive IDs consistently: lowercase, replace spaces with underscores, strip periods. Special cases: "Dem. Rep. Congo" → "dr_congo", "United States of America" → "united_states", "United Arab Emirates" → "uae", "United Kingdom" → "united_kingdom", "South Korea" → "south_korea", "Papua New Guinea" → "papua_new_guinea", "New Zealand" → "new_zealand". Verify these match what Epic 10 Story 10-1 will populate in `countries.json` — for now only 3 exist (egypt, nigeria, south_africa), so use those as ground truth and derive the rest consistently
  - [x] 2.5 Also extract `ContinentId` — the GeoJSON does NOT have continent info, so provide a `const Map<String, String>` mapping each of the 79 GeoJSON names to their continent (africa, europe, middle_east, asia, south_america, north_america, oceania) per the GDD's 7-continent breakdown. Cross-reference with `assets/data/continents.json`

- [x] Task 3: Create GeoJSON parser (AC: #1, #3)
  - [x] 3.1 Create `lib/ui/features/map/geojson_parser.dart` — `List<CountryPath> parseGeoJson(String geoJsonString)` function
  - [x] 3.2 Parse the `FeatureCollection` — each `Feature` has `geometry.type` of `Polygon` or `MultiPolygon` with coordinate rings as `[lon, lat]` arrays. Handle both types (many countries like Indonesia, Philippines are `MultiPolygon`)
  - [x] 3.3 Apply equirectangular projection: `x = (lon + 180) / 360`, `y = (90 - lat) / 180` — maps to normalized `[0,1]²` space. This is the SAME projection used in the spike parser — validated correct by 5 spike tests [Source: game-architecture.md#Map Rendering Pipeline, line 273]
  - [x] 3.4 For each feature: build `Path` from projected rings (same approach as spike parser), store raw ring vertices as `List<List<Offset>>`, compute `bbox` from `path.getBounds()`
  - [x] 3.5 Map each feature's `name` property to a `CountryId` via the mapping from Task 2. Map to `ContinentId` via continent mapping. Skip features with no valid mapping (log warning)
  - [x] 3.6 Return `List<CountryPath>` sorted by... no — maintain GeoJSON feature order (stable order matters for hit-testing in Story 2.4 where first-match-wins on boundary taps)
  - [x] 3.7 Use `jsonDecode` from `dart:convert` — the file is ~1.6MB minified single-line JSON. No streaming needed (spike proved this works fine)
  - [x] 3.8 Do NOT use `rootBundle.loadString` in the parser itself — the parser is a pure function taking a `String`. Loading is the provider's job

- [x] Task 4: Create `geoProvider` FutureProvider (AC: #2)
  - [x] 4.1 Create `lib/providers/geo_providers.dart` — `final geoProvider = FutureProvider<List<CountryPath>>((ref) async { ... })`
  - [x] 4.2 Inside the provider: `rootBundle.loadString('assets/geo/countries.geojson.json')` → `parseGeoJson(jsonString)`
  - [x] 4.3 Riverpod's `FutureProvider` naturally caches — once resolved, all `ref.watch(geoProvider)` calls get the same `List<CountryPath>`. No additional caching needed. The provider is kept alive because the map tab in `IndexedStack` watches it continuously [Source: project-context.md#Performance Rules — "GeoJSON parsed ONCE on startup"]
  - [x] 4.4 Import path: `lib/providers/geo_providers.dart` imports from `lib/ui/features/map/` — this is acceptable because providers are the composition root and can import from ui/ [Source: project-context.md#Dependency graph — "providers/ → game/, data/, services/" but ui types are OK for providers to reference]

- [x] Task 5: Write tests (AC: #1, #2, #3)
  - [x] 5.1 Create `test/ui/features/map/geojson_parser_test.dart` using `flutter_test` (parser uses `dart:ui` types)
  - [x] 5.2 Test: parsing real `assets/geo/countries.geojson.json` returns exactly 79 entries (validates GeoJSON file integrity). Use `TestWidgetsFlutterBinding.ensureInitialized()` before `rootBundle.loadString`
  - [x] 5.3 Test: every `CountryPath` has a valid `CountryId` (non-empty `.value`), valid `ContinentId`, non-empty `path` (`path.getBounds()` returns non-zero-area `Rect`), and valid `bbox`
  - [x] 5.4 Test: all projected ring vertices fall within `[0,1]²` range (validates equirectangular projection)
  - [x] 5.5 Test: `bbox` exactly encloses all ring vertices for at least 3 sample countries — pick one `Polygon` (e.g. Egypt) and one `MultiPolygon` (e.g. Indonesia or Philippines). Verify `bbox.contains(vertex)` for every vertex in every ring
  - [x] 5.6 Test: `CountryPath` equality is by `id` only — two instances with same `CountryId` are equal
  - [x] 5.7 Create `test/ui/features/map/geo_country_id_mapping_test.dart` — test that all 79 GeoJSON names have valid mappings, no duplicate CountryIds, and known entries match expectations (egypt, nigeria, south_africa match `countries.json`)
  - [x] 5.8 Test: continent mapping covers all 79 countries and maps to one of the 7 valid continent IDs from `continents.json`

- [x] Task 6: Clean up spike code references (AC: #1)
  - [x] 6.1 Do NOT delete spike files yet (Story 1-11 is still in-progress, AC2 pending device profiling). But add a `// TODO(epic-2): Remove spike files once Story 2.1 production parser is verified` comment at the top of `lib/ui/debug/spike_geojson_parser.dart`
  - [x] 6.2 The production parser should NOT import or reuse spike code — write fresh, production-quality code informed by the spike's approach

- [x] Task 7: Verify full test suite passes (AC: all)
  - [x] 7.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 7.2 Run `dart format --set-exit-if-changed .` — clean
  - [x] 7.3 Run `flutter test` — all prior tests plus new tests pass
  - [x] 7.4 No `print()` — use `Logger('GeoJsonParser')` if any logging needed

## Dev Notes

### Architecture Compliance

**`lib/game/` boundary respected.** `CountryPath` uses `dart:ui` types (`Path`, `Rect`, `Offset`) and therefore CANNOT live in `lib/game/`. It lives in `lib/ui/features/map/`. The parser similarly uses `dart:ui` and lives alongside. [Source: project-context.md#Engine-Specific Rules, rule 1 — "`lib/game/` has ZERO Flutter imports"]

**Provider composition root.** `geoProvider` lives in `lib/providers/geo_providers.dart` and imports from `lib/ui/features/map/`. Providers are the composition root and may import from any layer. [Source: project-context.md#Dependency graph]

**Parsing happens once.** The `FutureProvider` caches the parsed result. `IndexedStack` keeps the map tab alive so no re-parsing on tab switch. [Source: project-context.md#Performance Rules — "GeoJSON parsed ONCE on startup"]

### Implementation Approach

**GeoJSON structure.** The file is a standard `FeatureCollection` with 79 features. Each feature has:
- `properties.name` — display name (e.g. "Egypt", "South Africa", "Dem. Rep. Congo")
- `properties.iso_a2` — ISO 3166-1 alpha-2 code (e.g. "EG", "ZA", "CD")
- `geometry.type` — "Polygon" or "MultiPolygon"
- `geometry.coordinates` — nested arrays of `[lon, lat]` coordinate pairs

For `Polygon`: `coordinates[0]` is outer ring, `coordinates[1..]` are holes.
For `MultiPolygon`: each element is a polygon with the same ring structure.

**Equirectangular projection** (same as spike, validated by tests):
```dart
double x = (lon + 180.0) / 360.0;  // [0, 1]
double y = (90.0 - lat) / 180.0;   // [0, 1], y=0 is north pole
```

**ID mapping challenge.** GeoJSON uses display names, game uses snake_case IDs. The mapping is a `const Map<String, String>` with all 79 entries. Only 3 game IDs exist in `countries.json` today (egypt, nigeria, south_africa) — derive the other 76 consistently so Epic 10 Story 10-1 can populate `countries.json` to match. Edge cases to handle: "Dem. Rep. Congo", "United States of America", "United Arab Emirates", "South Korea", "Papua New Guinea".

**Continent mapping.** GeoJSON does NOT include continent information. The parser needs a hardcoded mapping of all 79 countries to their continent. Use the GDD's 7-continent breakdown: Africa (19), Europe (19), Middle East (10), Asia (16), South America (8), North America (4), Oceania (3). [Source: gdd.md#Level Design Framework]

### Library/Framework Requirements

- No new packages — all parsing uses `dart:convert` (already in SDK) and `dart:ui` (Flutter core)
- `package:flutter/services.dart` — `rootBundle.loadString` (in provider only, not parser)
- `package:flutter_riverpod` — `FutureProvider` (already a dependency)
- `package:logging` — for warning on unmapped GeoJSON names (already a dependency)

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/ui/features/map/country_path.dart` | `@immutable` `CountryPath` data class with `CountryId`, `ContinentId`, rings, bbox, `Path` |
| CREATE | `lib/ui/features/map/geo_country_id_mapping.dart` | GeoJSON name → `CountryId` mapping + continent mapping |
| CREATE | `lib/ui/features/map/geojson_parser.dart` | `parseGeoJson(String) → List<CountryPath>` |
| CREATE | `lib/providers/geo_providers.dart` | `geoProvider` FutureProvider that loads + parses GeoJSON |
| CREATE | `test/ui/features/map/geojson_parser_test.dart` | Parser tests: 79 entries, projection, bbox, types |
| CREATE | `test/ui/features/map/geo_country_id_mapping_test.dart` | Mapping coverage and correctness tests |
| MODIFY | `lib/ui/debug/spike_geojson_parser.dart` | Add TODO comment for future cleanup |

### Testing Standards

- **Use `flutter_test`** — parser creates `dart:ui` types (`Path`, `Rect`, `Offset`)
- **Use `TestWidgetsFlutterBinding.ensureInitialized()`** before `rootBundle.loadString`
- **Test against real GeoJSON asset** — validates both the parser AND the data file integrity
- **No `print()`** — `Logger` only
- **No mocking of GeoJSON data for the 79-count test** — the real asset IS the fixture. For isolated unit tests (bbox validation, projection math), extract small test helpers if needed

### Anti-Patterns to Avoid

- Do NOT put `CountryPath` or the parser in `lib/game/` — they use `dart:ui` types
- Do NOT use `InteractiveViewer` — irrelevant to this story but noting for context continuity
- Do NOT allocate anything per-frame — this story is about one-time parsing, not per-frame work
- Do NOT load GeoJSON inside the parser function — the parser takes a `String` argument; loading is the provider's responsibility
- Do NOT call `rootBundle.loadString` in any file under `lib/game/` — content loads through providers/services only
- Do NOT import spike code — write fresh production code. The spike validated the approach, but production code has different structure (CountryId mapping, continent mapping, rings storage)
- Do NOT add any map library packages — custom `CustomPainter` over GeoJSON is mandatory [Source: project-context.md#Forbidden packages]
- Do NOT use `print()` — `Logger('GeoJsonParser')` only
- Do NOT create `Path` objects inside `paint()` — they are pre-built here and reused in Story 2.2

### Previous Story Intelligence

**From Story 1-11 (Canvas Performance Spike — in-progress):**
- Spike GeoJSON parser at `lib/ui/debug/spike_geojson_parser.dart` validates the approach: `jsonDecode` + equirectangular projection + `Path` building works for all 79 countries
- Spike confirmed: both `Polygon` and `MultiPolygon` geometry types must be handled
- Spike confirmed: `path.getBounds()` produces valid bounding boxes
- Spike test confirmed: all projected coordinates fall within `[0,1]²`
- **Key difference from spike:** production parser adds `CountryId` mapping, `ContinentId` mapping, and stores raw `rings` as `List<List<Offset>>` for hit-testing. Spike only stored `name`, `path`, `bbox`
- GeoJSON parse time measured in spike as fast enough (exact ms TBD from Task 7 profiling)
- Spike is marked `// SPIKE: Throwaway` — do not extend it, write fresh production code

**From Story 1-7 (ContentRegistry):**
- `ContentRegistryLoader.loadFromAssets()` pattern uses `rootBundle.loadString` + parallel `Future.wait` — the `geoProvider` follows the same rootBundle pattern but loads a single file
- `ContentRegistry` is `@immutable` with unmodifiable collections — `CountryPath` list should similarly be unmodifiable once parsed
- `contentRegistryProvider` at `lib/providers/app_providers.dart` is the pattern to follow for `geoProvider`

**Key patterns from Epic 1:**
- `@immutable` on all value/data classes
- Manual `==` / `hashCode` (no freezed)
- `const` constructors where possible
- `Logger('Tag')` for any runtime logging
- `avoid_print: error` enforced

### Git Intelligence

All code from Epic 1 (Stories 1.1–1.11) is in the working tree (uncommitted). Recent git commits are project setup only. No dependency changes needed for this story.

### Project Structure Notes

- `lib/ui/features/map/` directory does NOT exist yet — create it. This is where all map-related UI code will live (Stories 2.1–2.4)
- `lib/providers/geo_providers.dart` is a new file alongside existing `app_providers.dart`
- `test/ui/features/map/` directory does NOT exist yet — create it
- `assets/geo/countries.geojson.json` exists (~1.6MB, 79 features, minified single-line)
- `assets/data/countries.json` has only 3 countries (egypt, nigeria, south_africa) — Epic 10 Story 10-1 populates the full 79
- `assets/data/continents.json` has all 7 continents defined

### Cross-Story Context

This is the **first story in Epic 2** and the foundation for all subsequent map stories:
- **Story 2.2** (WorldMapPainter) will consume `CountryPath.path` for rendering and `CountryPath.continent` for color grouping
- **Story 2.3** (Pan/Zoom) will use the view transform that operates on the same `[0,1]²` coordinate space
- **Story 2.4** (Hit Testing) will consume `CountryPath.rings` and `CountryPath.bbox` for the `PolygonHitTester` — this is WHY rings are stored as raw `List<List<Offset>>` separate from the `Path`
- **Story 2.5** (Tick/Influence) will map `CountryPath.id` to game state `CountryState` entries
- **Story 2.7** (Initial Seed) will use `CountryPath` to verify Egypt renders correctly as the starter country

### References

- [Source: epics.md#Story 2.1] — User story, acceptance criteria, BDD scenarios
- [Source: game-architecture.md#Map Rendering Pipeline, lines 271-278] — Projection, pan/zoom, hit-testing, painter, layers, performance guardrail
- [Source: game-architecture.md#Map Hit-Test Pipeline, lines 875-909] — `PolygonHitTester` using `CountryPath` with `id`, `rings`, `bbox`
- [Source: project-context.md#Engine-Specific Rules, rule 1] — `lib/game/` has zero Flutter imports
- [Source: project-context.md#Performance Rules] — GeoJSON parsed once, no per-frame allocations, cache Path objects
- [Source: project-context.md#Dependency graph] — providers/ imports game/, data/, services/; ui/ imports providers/
- [Source: project-context.md#Forbidden packages] — No external map libraries
- [Source: gdd.md#Level Design Framework] — 79 countries, 7 continents, country-to-continent breakdown
- [Source: 1-11 story] — Spike parser validates approach; throwaway code NOT to be extended

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Removed unused import `country_id.dart` from `geojson_parser_test.dart` (flutter analyze --fatal-infos caught it)
- `dart format` auto-formatted 4 files: `geo_providers.dart`, `geojson_parser.dart`, `geo_country_id_mapping_test.dart`, `geojson_parser_test.dart`
- Code review (2026-04-21): fixed HIGH — `Path` now uses `PathFillType.evenOdd` so GeoJSON hole rings (Italy, South Africa, UAE) render as holes in Story 2.2. Removed duplicate warning logs in parser (mapping functions already log). Added 2 tests (evenOdd fillType assertion + multi-ring hole-detection sanity check).

### Completion Notes List

- All 7 tasks complete. Implementation was already authored prior to this session; this session validated and fixed a linting issue (unused import).
- 26 new tests added: 15 in `geojson_parser_test.dart`, 11 in `geo_country_id_mapping_test.dart`
- Full suite: 304 tests pass (0 failures, 0 regressions)
- `flutter analyze --fatal-infos`: no issues
- `dart format --set-exit-if-changed`: clean
- AC1: Parser returns exactly 79 `CountryPath` entries with `CountryId`, `ContinentId`, rings, bbox, and `Path` — validated by test
- AC2: `geoProvider` is a `FutureProvider` that caches via Riverpod — all watchers share the same parsed result
- AC3: bbox exactly encloses all ring vertices — tested for Egypt (Polygon), Indonesia and Philippines (MultiPolygon)

### File List

- lib/ui/features/map/country_path.dart (CREATED)
- lib/ui/features/map/geo_country_id_mapping.dart (CREATED)
- lib/ui/features/map/geojson_parser.dart (CREATED)
- lib/providers/geo_providers.dart (CREATED)
- test/ui/features/map/geojson_parser_test.dart (CREATED)
- test/ui/features/map/geo_country_id_mapping_test.dart (CREATED)
- lib/ui/debug/spike_geojson_parser.dart (MODIFIED — TODO comment added)

## Change Log

- 2026-04-21: Story 2-1 implemented — GeoJSON parser + CountryPath data class + geoProvider + 24 new tests (302 total). Fixed unused import lint warning in geojson_parser_test.dart.
- 2026-04-21: Code review auto-fixes — set `PathFillType.evenOdd` on parser-built `Path` so GeoJSON hole rings render as holes (Italy, South Africa, UAE); removed duplicate warning logs; added 2 tests (304 total).
