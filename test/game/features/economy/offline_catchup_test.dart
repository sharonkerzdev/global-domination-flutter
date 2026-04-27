import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/constants.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/economy/offline_catchup.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import '../../../helpers/test_content_registry.dart';

void main() {
  late ContentRegistry content;

  setUp(() {
    content = testMapperContentRegistry();
  });

  group('OfflineCatchup.apply', () {
    test('zero / negative elapsed returns original state and no event', () {
      final seed = GameState.initialSeed(content);
      final t = DateTime.utc(2026, 6, 1, 12);
      final same = OfflineCatchup.apply(seed, content, now: t, lastSavedAt: t);
      expect(same.elapsed, Duration.zero);
      expect(same.event, isNull);

      final futureSaved = t.add(const Duration(seconds: 1));
      final neg = OfflineCatchup.apply(
        seed,
        content,
        now: t,
        lastSavedAt: futureSaved,
      );
      expect(neg.event, isNull);
    });

    test('8-hour cap when gap is 12 hours', () {
      final now = DateTime.utc(2026, 6, 1, 12);
      final saved = now.subtract(const Duration(hours: 12));
      final egypt = CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.tier1,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      );
      final state = GameState(
        countries: {const CountryId('egypt'): egypt},
        totalInfluence: Influence.zero,
        unlockedContinents: {const ContinentId('africa'): true},
      );
      final r = OfflineCatchup.apply(
        state,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(r.elapsed.inHours, GameConstants.maxOfflineHours);
    });

    test('LeaderTier.none earns nothing from Egypt', () {
      final seed = GameState.initialSeed(content);
      final now = DateTime.utc(2026, 6, 1, 13);
      final saved = DateTime.utc(2026, 6, 1, 12);
      final r = OfflineCatchup.apply(
        seed,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(r.totalEarned, Influence.zero);
      expect(r.event, isNotNull);
    });

    test('tier1 leader earns IncomeCalculator rate × seconds', () {
      final egypt = CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.tier1,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      );
      final state = GameState(
        countries: {const CountryId('egypt'): egypt},
        totalInfluence: Influence.zero,
        unlockedContinents: {const ContinentId('africa'): true},
      );
      final now = DateTime.utc(2026, 6, 1, 13);
      final saved = DateTime.utc(2026, 6, 1, 12);
      final stable = state.copyWith(
        goldenOpportunityMultiplier: Decimal.one,
        activeBoost: null,
        activeGoldenEffect: null,
      );
      final rate = IncomeCalculator.compute(egypt, stable, content);
      final expected = rate * Decimal.fromInt(3600);
      final r = OfflineCatchup.apply(
        state,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(r.totalEarned, equals(expected));
      expect(r.state.totalInfluence, equals(expected));
    });

    test('active boost and golden effect do not change offline total', () {
      final now = DateTime.utc(2026, 6, 1, 13);
      final saved = DateTime.utc(2026, 6, 1, 12);
      final egypt = CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.tier1,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      );
      final boosted = GameState(
        countries: {const CountryId('egypt'): egypt},
        totalInfluence: Influence.zero,
        unlockedContinents: {const ContinentId('africa'): true},
        goldenOpportunityMultiplier: Decimal.parse('50'),
        activeBoost: BoostState(
          multiplier: Decimal.fromInt(2),
          expiresAt: now.add(const Duration(seconds: 30)),
        ),
        activeGoldenEffect: ActiveGoldenEffect(
          goldenId: 'golden-1',
          multiplier: 99,
          expiresAt: now.add(const Duration(seconds: 30)),
        ),
      );
      final plain = boosted.copyWith(
        goldenOpportunityMultiplier: Decimal.one,
        activeBoost: null,
        activeGoldenEffect: null,
      );
      final a = OfflineCatchup.apply(
        boosted,
        content,
        now: now,
        lastSavedAt: saved,
      );
      final b = OfflineCatchup.apply(
        plain,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(a.totalEarned, equals(b.totalEarned));
    });

    test('positive elapsed but zero earn still emits event', () {
      final seed = GameState.initialSeed(content);
      final now = DateTime.utc(2026, 6, 1, 13);
      final saved = DateTime.utc(2026, 6, 1, 12);
      final r = OfflineCatchup.apply(
        seed,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(r.totalEarned.isZero, isTrue);
      expect(r.event, isNotNull);
    });

    test('large Decimal snapshot remains precise', () {
      final huge = Influence(Decimal.parse('1e38'));
      final egypt = CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.tier1,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      );
      final state = GameState(
        countries: {const CountryId('egypt'): egypt},
        totalInfluence: huge,
        unlockedContinents: {const ContinentId('africa'): true},
      );
      final now = DateTime.utc(2026, 6, 1, 13);
      final saved = DateTime.utc(2026, 6, 1, 12);
      final r = OfflineCatchup.apply(
        state,
        content,
        now: now,
        lastSavedAt: saved,
      );
      expect(r.state.totalInfluence.value > huge.value, isTrue);
    });
  });
}
