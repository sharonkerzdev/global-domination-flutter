import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/continent_progress_providers.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/stats_providers.dart';
import 'package:global_domination/ui/features/continents/continent_progress_bar.dart';
import 'package:global_domination/ui/theme/spacing.dart';
import 'package:global_domination/ui/widgets/currency_badge.dart';

/// Full-screen stats route pushed above the shell from the HUD stats icon.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Stats')),
      ),
      body: const _StatsBody(),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(statsProgressSummaryProvider);
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Spacing.xl),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CurrencyHeader(),
                  SizedBox(height: Spacing.md),
                  _ProgressSection(),
                  SizedBox(height: Spacing.lg),
                  _ContinentProgressSection(),
                  SizedBox(height: Spacing.lg),
                  _MultiplierSection(),
                  SizedBox(height: Spacing.lg),
                  _TemporaryEffectsSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyHeader extends StatelessWidget {
  const _CurrencyHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Totals',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final inf = ref.watch(totalInfluenceProvider);
                  return CurrencyBadge.influence(value: inf);
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final intel = ref.watch(totalIntelProvider);
                  return CurrencyBadge.intel(value: intel);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(statsProgressSummaryProvider);
    if (summary == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Spacing.sm),
          _statRow(
            context,
            label: 'Countries owned',
            value: '${summary.ownedCountries} / ${summary.totalCountries}',
            semanticValue:
                '${summary.ownedCountries} of ${summary.totalCountries} countries',
          ),
          _statRow(
            context,
            label: 'Continents completed',
            value:
                '${summary.completedContinents} / ${summary.totalContinents}',
            semanticValue:
                '${summary.completedContinents} of ${summary.totalContinents} continents',
          ),
          _statRow(
            context,
            label: 'Achievements earned',
            value:
                '${summary.earnedAchievements} / ${summary.totalAchievements}',
            semanticValue:
                '${summary.earnedAchievements} of ${summary.totalAchievements} achievements',
          ),
        ],
      ),
    );
  }
}

class _ContinentProgressSection extends ConsumerWidget {
  const _ContinentProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(continentProgressRowsProvider);
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continent progress',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Spacing.sm),
          for (final row in rows) _ContinentProgressRow(row: row),
        ],
      ),
    );
  }
}

class _ContinentProgressRow extends StatelessWidget {
  const _ContinentProgressRow({required this.row});

  final ContinentProgressRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label:
          '${row.continentName} progress, ${row.ownedCount} of ${row.totalCount} owned, ${row.highestReachedTier} percent reached',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.continentName,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 2,
                  ),
                  child: Text(
                    '${row.ownedCount} / ${row.totalCount} owned',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            ContinentProgressBar(
              ownedCount: row.ownedCount,
              totalCount: row.totalCount,
              reachedMilestoneTiers: row.reachedMilestoneTiers,
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

class _MultiplierSection extends ConsumerWidget {
  const _MultiplierSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(statsMultiplierBreakdownProvider);
    if (m == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final leaderDetail =
        'T1: ${m.leaderTier1Count} · T2: ${m.leaderTier2Count} · T3: ${m.leaderTier3Count}';
    final leaderSubtitle = m.leadersHired == 0
        ? leaderDetail
        : '$leaderDetail · Σ mult ${formatStatMultiplier(m.leaderMultiplierSum)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active multipliers',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Spacing.sm),
          _statRow(
            context,
            label: 'Influence Power',
            value: formatStatMultiplier(m.influencePowerFactor),
            subtitle: 'IP levels (unlocked): ${m.ipLevelSum}',
            semanticValue:
                'Influence power multiplier ${formatStatMultiplier(m.influencePowerFactor)}. Total IP levels ${m.ipLevelSum}',
          ),
          _statRow(
            context,
            label: 'Leaders',
            value: '${m.leadersHired} hired',
            subtitle: leaderSubtitle,
            semanticValue:
                '${m.leadersHired} leaders. $leaderDetail. Sum of leader multipliers ${formatStatMultiplier(m.leaderMultiplierSum)}',
          ),
          _statRow(
            context,
            label: 'Continents',
            value: formatStatMultiplier(m.continentBonusProduct),
            semanticValue:
                'Continent bonus ${formatStatMultiplier(m.continentBonusProduct)}',
          ),
          _statRow(
            context,
            label: 'Achievements',
            value: formatStatMultiplier(m.achievementBonusFactor),
            semanticValue:
                'Achievement bonus ${formatStatMultiplier(m.achievementBonusFactor)}',
          ),
          _statRow(
            context,
            label: 'Global Upgrades',
            value: formatStatMultiplier(m.globalUpgradeProduct),
            semanticValue:
                'Global upgrades ${formatStatMultiplier(m.globalUpgradeProduct)}',
          ),
        ],
      ),
    );
  }
}

class _TemporaryEffectsSection extends ConsumerWidget {
  const _TemporaryEffectsSection();

  static Decimal? _activeGoldenMultiplier(StatsMultiplierBreakdown m) {
    if (m.goldenOpportunityMultiplier == Decimal.one) return null;
    return m.goldenOpportunityMultiplier;
  }

  static bool _hasTemporary(StatsMultiplierBreakdown m) {
    final boost = m.boostMultiplier != null;
    return _activeGoldenMultiplier(m) != null || boost;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(statsMultiplierBreakdownProvider);
    if (m == null || !_hasTemporary(m)) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final goldenMultiplier = _activeGoldenMultiplier(m);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temporary effects',
            style: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Spacing.sm),
          if (goldenMultiplier != null)
            _statRow(
              context,
              label: 'Golden Opportunity',
              value: formatStatMultiplier(goldenMultiplier),
              semanticValue:
                  'Golden opportunity ${formatStatMultiplier(goldenMultiplier)}',
            ),
          if (m.boostMultiplier != null)
            _statRow(
              context,
              label: 'Boost',
              value: formatStatMultiplier(m.boostMultiplier!),
              semanticValue:
                  'Boost ${formatStatMultiplier(m.boostMultiplier!)}',
            ),
        ],
      ),
    );
  }
}

Widget _statRow(
  BuildContext context, {
  required String label,
  required String value,
  String? subtitle,
  required String semanticValue,
}) {
  final scheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final labelStyle = textTheme.bodyLarge?.copyWith(color: scheme.onSurface);
  final valueStyle = textTheme.titleSmall?.copyWith(
    color: scheme.onSurface,
    fontWeight: FontWeight.w600,
  );
  final subStyle = textTheme.bodySmall?.copyWith(
    color: scheme.onSurfaceVariant,
  );

  return Semantics(
    container: true,
    label: '$label. $semanticValue',
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: labelStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(subtitle, style: subStyle),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.topRight,
                child: Text(value, style: valueStyle, textAlign: TextAlign.end),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
