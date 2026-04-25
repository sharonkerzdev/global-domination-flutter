# Implementation Patterns

These patterns are mandatory. AI agents MUST follow them; deviations require explicit justification in the story.

### Novel Patterns (Game-Specific)

#### 1. Reducer Composition with `GameWorld` Aggregator

**Purpose:** Keep `GameWorld` small; domain logic lives in per-feature pure-function reducers.

**Reducer contract:**
```dart
// lib/game/features/upgrades/upgrade_reducer.dart
class UpgradeReducer {
  /// Pure function. No side effects. No I/O. No clock reads.
  /// Returns either the new state + the event to emit, or a GameError.
  Result<(GameState, GameEvent), GameError> purchaseIP(
    GameState state,
    PurchaseUpgrade cmd,
    {required DateTime now},
  ) {
    final country = state.countries[cmd.countryId];
    if (country == null) return Result.failure(GameError.internalMissingCountry(cmd.countryId));
    final cost = IncomeCalculator.bulkCost(country, cmd.bulk);
    if (state.influence < cost) return Result.failure(GameError.userInsufficientFunds(required: cost));

    final newCountry = country.copyWith(
      ipLevel: (country.ipLevel + cmd.bulk).clamp(0, GameConstants.ipMaxLevel),
    );
    final newState = state.copyWith(
      influence: state.influence - cost,
      countries: {...state.countries, cmd.countryId: newCountry},
    );
    return Result.success((newState, UpgradePurchased(now, cmd.countryId, cmd.bulk, cost)));
  }
}
```

**Rules:**
1. Reducers are pure — `now` and `rng` flow in as parameters.
2. Reducers return `Result<(NewState, Event), GameError>`.
3. Only `GameWorld` calls reducers and emits events.

#### 2. Sealed Command / Event Dispatch

**Purpose:** Type-safe command handling via exhaustive switches.

```dart
sealed class GameCommand { const GameCommand(); }
final class TapCountry extends GameCommand      { final CountryId id; const TapCountry(this.id); }
final class PurchaseUpgrade extends GameCommand { final CountryId countryId; final int bulk; const PurchaseUpgrade(this.countryId, this.bulk); }
final class HireLeader extends GameCommand      { final CountryId countryId; const HireLeader(this.countryId); }
// ... etc

class GameWorld {
  Result<void, GameError> applyCommand(GameCommand cmd) {
    final now = _clock.now();
    final result = switch (cmd) {
      TapCountry(id: final id)          => _countryReducer.tap(_state, id, now: now),
      PurchaseUpgrade()                  => _upgradeReducer.purchaseIP(_state, cmd, now: now),
      HireLeader(countryId: final id)    => _leaderReducer.hire(_state, id, now: now),
      // exhaustive — compiler error if a new command is added without a case
    };
    return switch (result) {
      Success(value: (final newState, final event)) => () {
          _state = newState;
          _events.add(event);
          return const Result.success(null);
        }(),
      Failure(error: final e) => Result.failure(e),
    };
  }
}
```

**Rules:**
1. Adding a new command REQUIRES updating the switch — compiler enforces.
2. Commands imperative; events past-tense.
3. `StreamController` uses `sync: true` — subscribers observe state + event in same microtask.

#### 3. Declarative Rule Engine for Achievements & Missions

```dart
class AchievementDef {
  final String id;
  final Predicate<GameState> condition;
  final GameState Function(GameState) apply;
  final AchievementReward reward;
}

class AchievementEvaluator {
  GameState evaluate(GameState state, List<AchievementDef> defs) {
    var s = state;
    for (final def in defs) {
      if (s.earnedAchievements.contains(def.id)) continue;
      if (def.condition(s)) {
        s = def.apply(s).copyWith(
          earnedAchievements: {...s.earnedAchievements, def.id},
        );
      }
    }
    return s;
  }
}
```

**Rules:**
1. Achievements and missions are data, not code. Condition functions are pure.
2. Evaluator runs after every `applyCommand`, skipping already-earned achievements.
3. `AchievementEarned` events emitted in the same microtask as the triggering event.

#### 4. Map Hit-Test Pipeline

```dart
class PolygonHitTester {
  final List<CountryPath> _paths;
  final Map<CountryId, Rect> _bboxCache;

  CountryId? hitTest(Offset normalizedPoint) {
    for (final path in _paths) {
      final bbox = _bboxCache[path.id]!;
      if (!bbox.contains(normalizedPoint)) continue; // early reject
      if (_pointInPolygon(normalizedPoint, path.rings)) return path.id;
    }
    return null;
  }

  bool _pointInPolygon(Offset p, List<List<Offset>> rings) {
    bool inside = false;
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final vi = ring[i], vj = ring[j];
        final intersect = ((vi.dy > p.dy) != (vj.dy > p.dy)) &&
            (p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx);
        if (intersect) inside = !inside;
      }
    }
    return inside;
  }
}
```

**Rules:**
1. Bounding boxes precomputed once from GeoJSON at boot.
2. Early-reject with bbox before ring test.
3. Operates on `[0,1]²` normalized coords AFTER inverse view-transform.

#### 5. Content Loading — Load-Once, Immutable

```dart
class ContentRegistry {
  final Map<CountryId, CountryDef> countries;
  final Map<ContinentId, ContinentDef> continents;
  final List<AchievementDef> achievements;
  final List<MissionDef> missions;
  final List<LeaderDef> leaders;

  const ContentRegistry({ /* ... */ });

  static Future<ContentRegistry> loadFromAssets() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/countries.json'),
      rootBundle.loadString('assets/data/continents.json'),
      rootBundle.loadString('assets/data/achievements.json'),
      rootBundle.loadString('assets/data/missions.json'),
      rootBundle.loadString('assets/data/leaders.json'),
    ]);
    // parse → freeze → return
  }
}

final contentRegistryProvider = FutureProvider<ContentRegistry>(
  (ref) async => ContentRegistry.loadFromAssets(),
);
```

**Rules:**
1. Loaded ONCE at boot; failure triggers error screen + reinstall prompt.
2. Immutable for the session.
3. Reducers receive `ContentRegistry` via DI — never call `rootBundle` themselves.

### Standard Implementation Patterns

#### A. Immutable State with Manual `copyWith`

```dart
@immutable
class CountryState {
  final CountryId id;
  final bool unlocked;
  final int ipLevel;
  final LeaderTier leaderTier;
  final Decimal bankedInfluence;
  final DateTime? lastCollectedAt;

  const CountryState({
    required this.id,
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
    required this.bankedInfluence,
    required this.lastCollectedAt,
  });

  CountryState copyWith({
    bool? unlocked,
    int? ipLevel,
    LeaderTier? leaderTier,
    Decimal? bankedInfluence,
    DateTime? lastCollectedAt,
  }) => CountryState(
    id: id,
    unlocked: unlocked ?? this.unlocked,
    ipLevel: ipLevel ?? this.ipLevel,
    leaderTier: leaderTier ?? this.leaderTier,
    bankedInfluence: bankedInfluence ?? this.bankedInfluence,
    lastCollectedAt: lastCollectedAt ?? this.lastCollectedAt,
  );

  @override bool operator ==(Object other) => /* ... */;
  @override int get hashCode => /* ... */;
}
```

**No `freezed`** for v1 — manual copyWith is ~15 lines per class and costs zero tooling. Revisit if type count grows past ~30.

#### B. Widget → Provider → Notifier → GameWorld (The one true UI path)

```dart
// ui/features/upgrades/upgrade_card.dart
class UpgradeCard extends ConsumerWidget {
  final CountryId countryId;
  const UpgradeCard({required this.countryId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryProvider(countryId));
    final canAfford = ref.watch(canAffordUpgradeProvider(countryId));

    return ElevatedButton(
      onPressed: canAfford
        ? () {
            final result = ref.read(gameWorldProvider.notifier)
              .apply(PurchaseUpgrade(countryId, 1));
            if (result.isFailure) {
              ErrorRouter.of(context).show(result.error!);
            }
          }
        : null,
      child: Text('Upgrade (L${country.ipLevel})'),
    );
  }
}

// providers/game_providers.dart
final gameWorldProvider = StateNotifierProvider<GameWorldNotifier, GameState>((ref) {
  final content = ref.watch(contentRegistryProvider).requireValue;
  final clock = ref.watch(clockProvider);
  return GameWorldNotifier(GameWorld(content: content, clock: clock));
});

class GameWorldNotifier extends StateNotifier<GameState> {
  final GameWorld _world;
  late final StreamSubscription _sub;
  GameWorldNotifier(this._world) : super(_world.state) {
    _sub = _world.events.listen((_) => state = _world.state);
  }
  Result<void, GameError> apply(GameCommand cmd) => _world.applyCommand(cmd);
  @override void dispose() { _sub.cancel(); super.dispose(); }
}

// Fine-grained selector — rebuilds only when this country changes
final countryProvider = Provider.family<CountryState, CountryId>(
  (ref, id) => ref.watch(gameWorldProvider.select((s) => s.countries[id]!)),
);
```

#### C. Async Initialization Gate

```dart
// app.dart
class GlobalDominationApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    return MaterialApp(
      theme: appTheme(),
      home: boot.when(
        loading: () => const SplashScreen(),
        error: (err, _) => BootErrorScreen(error: err),
        data: (_) => const AppScaffold(),
      ),
    );
  }
}

final bootstrapProvider = FutureProvider<GameState>((ref) async {
  final content = await ref.watch(contentRegistryProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final repo = ref.read(saveRepositoryProvider);
  final state = await repo.loadOrCreateInitial(content);
  return OfflineCatchup.apply(state, ref.read(clockProvider));
});
```

#### D. Test Patterns

**Pure-Dart tests for `lib/game/`:**
```dart
import 'package:test/test.dart';   // NOT flutter_test
import 'package:global_domination/game/…';

void main() {
  group('IncomeCalculator multiplier stack', () {
    test('applies IP, leader, continent, achievement, global in documented order', () {
      final s = GameStateBuilder()
        .withCountry('egypt', ipLevel: 100, leaderTier: LeaderTier.tier2)
        .withContinentComplete('africa')
        .withAchievement('first_leader')
        .withGlobalUpgrade(influenceAmplifier: Decimal.parse('2.0'))
        .build();
      final rate = IncomeCalculator.compute(s.countries['egypt']!, s);
      expect(rate, Influence(Decimal.parse('…')));
    });
  });
}
```

**Widget tests for `lib/ui/`:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('disables button when unaffordable', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameWorldProvider.overrideWith((ref) => FakeGameWorldNotifier(
          seedState: GameStateBuilder().withPoorPlayer().build(),
        )),
      ],
      child: const MaterialApp(home: UpgradeCard(countryId: CountryId('egypt'))),
    ));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
  });
}
```

**Rules:**
1. `lib/game/` tests import `package:test/test.dart` — never `flutter_test`.
2. Widget tests always override providers.
3. `GameStateBuilder` is the canonical way to construct test states.

#### E. Animation Pattern

Event-driven animations use `AnimationController` + event stream trigger:

```dart
class FlyingNumberLayer extends ConsumerStatefulWidget { /* ... */ }

class _FlyingNumberLayerState extends ConsumerState<FlyingNumberLayer>
    with TickerProviderStateMixin {
  late final StreamSubscription _sub;
  final List<_FlyingNumber> _active = [];

  @override
  void initState() {
    super.initState();
    _sub = ref.read(gameEventsProvider).listen((event) {
      if (event is CountryTapped) _spawnFlyingNumber(event.country, event.amount);
    });
  }
}
```

#### F. Drift Typed Query Pattern

```dart
class SaveRepository {
  final AppDatabase _db;
  final _log = Logger('SaveRepository');

  Future<Result<void, GameError>> persistEvent(GameEvent event) async {
    try {
      await _db.transaction(() async {
        switch (event) {
          case CountryUnlocked(id: final id):
            await (_db.update(_db.countries)..where((t) => t.id.equals(id.value)))
              .write(const CountriesCompanion(unlocked: Value(true)));
          case UpgradePurchased():  /* typed update */
          case LeaderHired():       /* typed update */
          case _: break; // e.g. CountryTapped — not persisted per-event
        }
      });
      return const Result.success(null);
    } catch (e, s) {
      _log.severe('persistEvent failed for ${event.runtimeType}', e, s);
      return Result.failure(GameError.persistenceFailure(e.toString()));
    }
  }
}
```

**Rule:** Never raw SQL — always typed Drift DSL. Schema changes REQUIRE a migration file.

### Consistency Rules Summary

| Rule | Convention | Enforcement |
|---|---|---|
| No Flutter in `lib/game/` | `package:flutter/*` forbidden under `lib/game/**` | `custom_lint` rule + CI grep check |
| Commands imperative; events past-tense | `PurchaseUpgrade` vs `UpgradePurchased` | Code review + naming regex |
| Reducers pure | No clock/RNG/IO; `now`/`rng` as params | Unit tests + review |
| Single multiplier stack | Only `IncomeCalculator.compute` produces income | Grep for duplicates + review |
| All big-number math through `Influence` | No raw `Decimal` outside `values/` | `custom_lint` rule |
| No `print()` | Always `Logger('Tag')` | `avoid_print: error` |
| UI → Command only | Widgets never mutate state directly | Review; private state in Notifier |
| Content is immutable | `ContentRegistry` loaded once | No setters; `@immutable` |
| Every interactive widget has `Semantics` | A11y first | Widget test checks + review |
| `snake_case.dart` + mirror test files | | `flutter_lints` + review |

### Lint Configuration

Add to `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    avoid_print: error
    unnecessary_null_comparison: error
    unrelated_type_equality_checks: error
  exclude:
    - lib/**/*.g.dart         # Drift-generated
    - lib/**/*.freezed.dart   # if/when we adopt
    - build/**

linter:
  rules:
    - always_declare_return_types
    - avoid_returning_null_for_future
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - unawaited_futures
```

---
