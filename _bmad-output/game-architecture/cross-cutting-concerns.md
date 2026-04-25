# Cross-Cutting Concerns

These patterns apply to **all** systems and MUST be followed by every implementation.

### Error Handling

**Strategy:** Two tiers.

- **Top tier (catastrophic):** Global handlers (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded`) route to `CrashReporter`. Fallback screen with "Restart" CTA.
- **Mid tier (recoverable game ops):** `Result<T, GameError>` (sealed class) for anything that can fail meaningfully. No exceptions for control flow.

**Rules:**
1. NEVER swallow errors silently. Minimum: log at `warning` and return `Result.failure`.
2. UI widgets never catch errors directly — dispatch `GameError` via `Result` and let `ErrorRouter` decide presentation.
3. `GameWorld` throws only on programmer errors / invariant violations. Those are bugs — `runZonedGuarded` catches and logs as crashes.
4. Only `UserError` variants surface in UI. `InternalError` is logged silently.

**`GameError` hierarchy (sealed):**
```
GameError
├── UserError
│   ├── insufficientFunds(required)
│   ├── locked(reason)
│   └── invalidTarget(detail)
└── InternalError
    ├── missingCountry(id)
    ├── invariantBroken(message)
    ├── persistenceFailure(cause)
    └── migrationFailure(fromVersion, toVersion, cause)
```

**Example:**
```dart
Result<CountryState, GameError> purchaseUpgrade(CountryId id, int bulk) {
  final country = _state.countries[id];
  if (country == null) return Result.failure(GameError.internalMissingCountry(id));
  final cost = IncomeCalculator.bulkCost(country, bulk);
  if (_state.influence < cost) {
    return Result.failure(GameError.userInsufficientFunds(required: cost));
  }
  // apply upgrade, emit event...
  return Result.success(newCountry);
}

// main.dart
void main() {
  FlutterError.onError = CrashReporter.instance.report;
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporter.instance.reportAsync(error, stack);
    return true;
  };
  runZonedGuarded(() => runApp(const GlobalDominationApp()),
      (error, stack) => CrashReporter.instance.reportAsync(error, stack));
}
```

### Logging

**Package:** `package:logging` (zero cost when level-gated).

**Levels:**

| Level | Use for | Persisted? |
|---|---|---|
| `SEVERE` | Crash / internal errors | ✅ `crash_logs` table |
| `WARNING` | Recoverable anomaly | ✅ bounded |
| `INFO` | Lifecycle milestones | ✅ recent only |
| `CONFIG` | Startup config (build mode, schema version) | ✅ one-shot |
| `FINE`/`FINER`/`FINEST` | Debug diagnostics | ❌ debug only |

**Rules:**
1. NEVER use `print()`. Always `Logger('Tag').info(...)`.
2. Tag = class/module name: `Logger('GameWorld')`, `Logger('SaveRepository')`, `Logger('WorldMapPainter')`.
3. Root logger configured once in `main.dart`:
   - Release: `Level.WARNING` minimum → `CrashReporter`.
   - Debug: `Level.FINE` → console with timestamp + tag.
4. **No logging in tight hot paths** (per-tick sim math, per-frame painter). Use `assert` for invariants there.
5. No PII — no account system, log only IDs, counts, durations.

**Example:**
```dart
final _log = Logger('SaveRepository');

Future<Result<void, GameError>> save(GameState state) async {
  final sw = Stopwatch()..start();
  _log.info('save start: schemaVersion=${state.meta.schemaVersion}');
  try {
    await _db.transaction(() async { /* ... */ });
    _log.info('save ok in ${sw.elapsedMilliseconds}ms');
    return const Result.success(null);
  } catch (e, s) {
    _log.severe('save failed', e, s);
    return Result.failure(GameError.persistenceFailure(e.toString()));
  }
}
```

### Configuration Management

**Four distinct config types, kept strictly separate:**

| Type | Storage | Access | Example |
|---|---|---|---|
| Game constants | `const` in `lib/game/config/constants.dart` | `GameConstants.maxOfflineHours` | `maxOfflineHours = 8`, `ipMaxLevel = 200` |
| Balance values | `const` in `lib/game/config/balance.dart` | `BalanceConfig.ipCostMultiplier` | `ipCostMultiplier = 1.5`, `leaderUnlockIpLevel = 10` |
| Content data | `assets/data/*.json` loaded at startup | `ContentRegistry.countries[id]` | 79 countries, 27 achievements |
| Player settings | `settings` table in Drift | `SettingsNotifier` (Riverpod) | `soundEnabled: true` |

**Rules:**
1. Never hardcode balance numbers in UI or sim logic — always read from `BalanceConfig` or `ContentRegistry`.
2. Content files are the source of truth for tunable game data.
3. No remote config for v1 — balance tuning ships with store releases.

**Content example (`assets/data/countries.json`):**
```json
[
  { "id": "egypt", "continent": "africa", "baseInfluence": "1",
    "unlockCost": "0", "tier": 1, "generationSeconds": 1 },
  { "id": "nigeria", "continent": "africa", "baseInfluence": "5",
    "unlockCost": "5", "tier": 1, "generationSeconds": 1 }
]
```

### Event System

**Pattern:** Sealed class hierarchy + `StreamController.broadcast()` owned by `GameWorld`.

**Rules:**
1. Typed events only — no `String` event names. Consumers use exhaustive `switch`.
2. Sync emission, async consumers. `GameWorld` emits after state update; subscribers process on microtask.
3. Immutable event payloads — snapshot values, not mutable references.
4. Past-tense naming: `CountryUnlocked`, not `UnlockCountry`. Future-tense inputs go through `applyEvent(GameCommand)`.
5. No cross-service event chains. Only `GameWorld` emits `GameEvent`s — services never re-emit.
6. Debug builds record events to `event_log` table for replay.

**Example:**
```dart
sealed class GameEvent {
  final DateTime at;
  const GameEvent(this.at);
}

final class CountryUnlocked extends GameEvent {
  final CountryId id;
  final Continent continent;
  final Influence cost;
  const CountryUnlocked(super.at, this.id, this.continent, this.cost);
}

// Audio subscriber
audioService.events.listen((event) {
  switch (event) {
    case CountryTapped():       _sfx.play(Sfx.collect);
    case CountryUnlocked():     _sfx.play(Sfx.unlock);
    case LeaderHired():         _sfx.play(Sfx.upgrade);
    case UpgradePurchased():    _sfx.play(Sfx.upgrade);
    case GoldenClaimed():       _sfx.play(Sfx.golden);
    case ContinentCompleted():  _sfx.play(Sfx.milestone);
    case _:                     break;
  }
});
```

### Debug / Development Tools

All gated on `kDebugMode` — zero code size impact in release.

| Tool | Activation | Purpose |
|---|---|---|
| Debug overlay | 5-tap HUD title | FPS, tick duration, events/s, provider count |
| Cheat panel | Long-press HUD | Grant Influence, unlock continent, trigger Golden, skip tutorial, force offline catch-up |
| State inspector | Menu in debug overlay | Dumps `GameState` as JSON |
| Event log viewer | Menu in debug overlay | Last 200 `GameEvent`s |
| Save viewer | Menu in debug overlay | Row-level Drift query UI |
| Performance HUD | Toggle in debug overlay | Flutter's `showPerformanceOverlay` |
| Assertion-heavy mode | Always on in debug | `assert(invariant)` in sim hot paths |

**Rules:**
1. All debug entry points MUST be behind `if (kDebugMode)` or `assert(() { …; return true; }())`.
2. Cheats never ship — both the activator and the code are `kDebugMode`-gated.
3. Crash log ring buffer is the ONE exception: active in release, bounded 100 entries, reachable only via a 5-second settings long-press ("Support" screen) — for field debugging.

---
