import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/upgrades_providers.dart';
import 'package:global_domination/ui/features/continents/continent_progress_bar.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(upgradesTabModelProvider);

    return modelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (model) {
        if (model.isEmpty) {
          return const _EmptyState();
        }
        return _UpgradesBody(model: model);
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
// Body – list of continent sections
// ---------------------------------------------------------------------------

class _UpgradesBody extends StatefulWidget {
  const _UpgradesBody({required this.model});

  final UpgradesTabModel model;

  @override
  State<_UpgradesBody> createState() => _UpgradesBodyState();
}

class _UpgradesBodyState extends State<_UpgradesBody> {
  final Map<CountryId, int> _bulkByCountry = {};

  int _bulk(CountryId id) => _bulkByCountry[id] ?? 1;

  void _setBulk(CountryId id, int bulk) {
    setState(() => _bulkByCountry[id] = bulk);
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.model.sections;
    final items = <_ListItem>[];
    for (final section in sections) {
      items.add(_HeaderItem(section));
      for (final row in section.countries) {
        items.add(_CountryItem(row));
      }
      items.add(_TeaserItem(section.teaser));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: Spacing.sm,
        bottom: Spacing.lg,
        left: Spacing.sm,
        right: Spacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _HeaderItem) {
          return _ContinentHeader(section: item.section);
        } else if (item is _CountryItem) {
          final row = item.row;
          return _CountryUpgradeCard(
            row: row,
            selectedBulk: _bulk(row.countryId),
            onBulkChanged: (v) => _setBulk(row.countryId, v),
          );
        } else if (item is _TeaserItem) {
          return _TeaserCard(teaser: item.teaser);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

abstract class _ListItem {}

class _HeaderItem extends _ListItem {
  _HeaderItem(this.section);
  final ContinentUpgradeSection section;
}

class _CountryItem extends _ListItem {
  _CountryItem(this.row);
  final CountryUpgradeRow row;
}

class _TeaserItem extends _ListItem {
  _TeaserItem(this.teaser);
  final NextUnlockTeaserRow teaser;
}

// ---------------------------------------------------------------------------
// Continent section header
// ---------------------------------------------------------------------------

class _ContinentHeader extends StatelessWidget {
  const _ContinentHeader({required this.section});

  final ContinentUpgradeSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: Spacing.sm,
        right: Spacing.sm,
        top: Spacing.lg,
        bottom: Spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: Spacing.xs),
              Text(
                section.continentName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _OwnedBadge(
                ownedCount: section.ownedCount,
                totalCount: section.totalCount,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          ContinentProgressBar(
            ownedCount: section.ownedCount,
            totalCount: section.totalCount,
            reachedMilestoneTiers: section.reachedMilestoneTiers,
            semanticLabel:
                '${section.continentName} progress, ${section.ownedCount} of ${section.totalCount} owned, ${_highestTierOf(section.reachedMilestoneTiers)} percent reached',
          ),
        ],
      ),
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge({required this.ownedCount, required this.totalCount});

  final int ownedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      child: Text(
        '$ownedCount / $totalCount owned',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

int _highestTierOf(Set<int> tiers) {
  return tiers.isEmpty ? 0 : tiers.reduce((a, b) => a > b ? a : b);
}

// ---------------------------------------------------------------------------
// Country upgrade card
// ---------------------------------------------------------------------------

const _kBulkOptions = [1, 10, 25];

class _CountryUpgradeCard extends ConsumerWidget {
  const _CountryUpgradeCard({
    required this.row,
    required this.selectedBulk,
    required this.onBulkChanged,
  });

  final CountryUpgradeRow row;
  final int selectedBulk;
  final ValueChanged<int> onBulkChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final contentAsync = ref.watch(contentRegistryProvider);
    final totalInfluence = ref.watch(
      gameWorldProvider.select((s) => s.totalInfluence),
    );

    UpgradePurchasePreview? preview;
    if (contentAsync.hasValue) {
      preview = upgradePurchasePreview(
        row,
        selectedBulk,
        totalInfluence,
        contentAsync.requireValue,
      );
    }

    final canBuy = preview != null && !preview.isDisabled;

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: Spacing.xs,
        horizontal: Spacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: scheme.primary),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    row.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (row.isMaxLevel)
                  _MaxBadge()
                else
                  Text(
                    'IP ${row.ipLevel}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Rate: ${row.currentRate.format()}/s',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (!row.isMaxLevel) ...[
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  _BulkSelector(
                    selected: selectedBulk,
                    onChanged: onBulkChanged,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text(
                      preview?.cost != null ? preview!.cost!.format() : '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _BuyButton(
                    enabled: canBuy,
                    semanticLabel: _buySemanticsLabel(row, preview),
                    onTap: canBuy
                        ? () => ref
                              .read(gameWorldProvider.notifier)
                              .apply(
                                PurchaseUpgrade(
                                  countryId: row.countryId,
                                  bulk: selectedBulk,
                                ),
                              )
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buySemanticsLabel(
    CountryUpgradeRow row,
    UpgradePurchasePreview? preview,
  ) {
    final levels = preview?.actualLevels ?? selectedBulk;
    final noun = levels == 1 ? 'upgrade' : 'upgrades';
    return 'Buy $levels ${row.displayName} $noun';
  }
}

class _MaxBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'MAX',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BulkSelector extends StatelessWidget {
  const _BulkSelector({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      style: SegmentedButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      segments: [
        for (final v in _kBulkOptions)
          ButtonSegment<int>(value: v, label: Text('$v')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.enabled,
    required this.semanticLabel,
    this.onTap,
  });

  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
        ),
        child: const Text('Buy'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Teaser card
// ---------------------------------------------------------------------------

class _TeaserCard extends ConsumerWidget {
  const _TeaserCard({required this.teaser});

  final NextUnlockTeaserRow teaser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (teaser.kind) {
      case TeaserKind.nextUnlock:
        final canUnlock = teaser.canAfford;
        return Card(
          margin: const EdgeInsets.symmetric(
            vertical: Spacing.xs,
            horizontal: Spacing.xs,
          ),
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(Icons.lock_open, size: 18, color: scheme.tertiary),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teaser.countryName ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (teaser.unlockCost != null)
                        Text(
                          teaser.unlockCost!.format(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Semantics(
                  label: 'Unlock ${teaser.countryName ?? "country"}',
                  button: true,
                  enabled: canUnlock,
                  child: FilledButton.tonal(
                    onPressed: canUnlock
                        ? () => ref
                              .read(gameWorldProvider.notifier)
                              .apply(
                                UnlockCountry(countryId: teaser.countryId!),
                              )
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xs,
                      ),
                    ),
                    child: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        );

      case TeaserKind.continentComplete:
        return _NonActionableTeaser(
          icon: Icons.check_circle_outline,
          message: 'All countries unlocked!',
        );

      case TeaserKind.futureContinent:
        return _NonActionableTeaser(
          icon: Icons.explore,
          message: teaser.countryName != null
              ? 'Next: ${teaser.countryName}'
              : 'More continents coming...',
        );

      case TeaserKind.worldComplete:
        return _NonActionableTeaser(
          icon: Icons.emoji_events,
          message: 'World domination complete!',
        );
    }
  }
}

class _NonActionableTeaser extends StatelessWidget {
  const _NonActionableTeaser({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: Spacing.xs,
        horizontal: Spacing.xs,
      ),
      color: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
