import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/leaders_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

/// Leaders tab — accordion of unlocked continents with per-country hire /
/// upgrade controls. See Story 7.8 for state-table semantics.
class LeadersScreen extends ConsumerWidget {
  const LeadersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(leadersTabModelProvider);

    return modelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (model) {
        if (model.isEmpty) {
          return const _EmptyState();
        }
        return _LeadersBody(model: model);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          'No continents unlocked yet.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _LeadersBody extends StatelessWidget {
  const _LeadersBody({required this.model});

  final LeadersTabModel model;

  @override
  Widget build(BuildContext context) {
    final sections = model.sections;
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: Spacing.sm,
        bottom: Spacing.lg,
        left: Spacing.sm,
        right: Spacing.sm,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) =>
          _ContinentAccordion(section: sections[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Continent accordion
// ---------------------------------------------------------------------------

class _ContinentAccordion extends StatelessWidget {
  const _ContinentAccordion({required this.section});

  final ContinentLeadersSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: Spacing.xs,
        horizontal: Spacing.xs,
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.public, color: scheme.primary),
        title: Text(
          section.continentName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: _HeaderSubtitle(section: section),
        trailing: section.hasAffordableAction
            ? _AffordableDot(color: scheme.tertiary)
            : null,
        childrenPadding: const EdgeInsets.only(
          left: Spacing.sm,
          right: Spacing.sm,
          bottom: Spacing.sm,
        ),
        children: section.rows.isEmpty
            ? [const _EmptySectionRow()]
            : [
                for (final row in section.rows)
                  _CountryLeaderRowWidget(row: row),
              ],
      ),
    );
  }
}

class _HeaderSubtitle extends StatelessWidget {
  const _HeaderSubtitle({required this.section});

  final ContinentLeadersSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${section.hiredCount} / ${section.totalCount} Leaders hired',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AffordableDot extends StatelessWidget {
  const _AffordableDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('leaders.affordable_dot'),
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EmptySectionRow extends StatelessWidget {
  const _EmptySectionRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.md,
      ),
      child: Text(
        'No countries unlocked here yet.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country row
// ---------------------------------------------------------------------------

class _CountryLeaderRowWidget extends ConsumerWidget {
  const _CountryLeaderRowWidget({required this.row});

  final CountryLeaderRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final approachingBorder = row.approaching != ApproachingThreshold.none
        ? Border.all(color: scheme.tertiary.withValues(alpha: 0.5))
        : null;

    final container = Container(
      key: row.approaching != ApproachingThreshold.none
          ? Key('leaders.row.${row.countryId.value}.approaching')
          : Key('leaders.row.${row.countryId.value}'),
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: approachingBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.groups, size: 20, color: scheme.primary),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'IP ${row.ipLevel} · ${_tierLabel(row.currentTier)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _ActionButton(row: row),
        ],
      ),
    );

    return container;
  }

  static String _tierLabel(LeaderTier tier) {
    switch (tier) {
      case LeaderTier.none:
        return 'No leader';
      case LeaderTier.tier1:
        return 'Tier 1 Leader';
      case LeaderTier.tier2:
        return 'Tier 2 Leader';
      case LeaderTier.tier3:
        return 'Tier 3 (MAX)';
    }
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.row});

  final CountryLeaderRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _actionLabel(row);
    final semanticsLabel = _semanticsLabel(row);

    VoidCallback? onPressed;
    switch (row.action) {
      case LeaderRowAction.reachIp10First:
      case LeaderRowAction.maxTier:
        onPressed = null;
      case LeaderRowAction.hire:
        onPressed = row.canAfford
            ? () => ref
                  .read(gameWorldProvider.notifier)
                  .apply(HireLeader(countryId: row.countryId))
            : null;
      case LeaderRowAction.upgradeToTier2:
      case LeaderRowAction.upgradeToTier3:
        onPressed = row.canAfford
            ? () => ref
                  .read(gameWorldProvider.notifier)
                  .apply(UpgradeLeader(countryId: row.countryId))
            : null;
    }

    final enabled = onPressed != null;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  static String _actionLabel(CountryLeaderRow row) {
    switch (row.action) {
      case LeaderRowAction.reachIp10First:
        return 'Reach IP 10 first';
      case LeaderRowAction.hire:
        return 'Hire (${row.actionCost!.format()})';
      case LeaderRowAction.upgradeToTier2:
        return 'Upgrade to Tier 2 (${row.actionCost!.format()})';
      case LeaderRowAction.upgradeToTier3:
        return 'Upgrade to Tier 3 (${row.actionCost!.format()})';
      case LeaderRowAction.maxTier:
        return 'Max tier reached';
    }
  }

  static String _semanticsLabel(CountryLeaderRow row) {
    switch (row.action) {
      case LeaderRowAction.reachIp10First:
        return 'Reach IP 10 first to hire leader';
      case LeaderRowAction.hire:
        return 'Hire leader for ${row.displayName}';
      case LeaderRowAction.upgradeToTier2:
        return 'Upgrade ${row.displayName} leader to tier 2';
      case LeaderRowAction.upgradeToTier3:
        return 'Upgrade ${row.displayName} leader to tier 3';
      case LeaderRowAction.maxTier:
        return 'Max tier reached';
    }
  }
}
