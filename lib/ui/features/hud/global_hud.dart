import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/ui/features/settings/settings_modal.dart';
import 'package:global_domination/ui/features/stats/stats_screen.dart';
import 'package:global_domination/ui/theme/hud_palette.dart';
import 'package:global_domination/ui/theme/spacing.dart';
import 'package:global_domination/ui/widgets/currency_badge.dart';

/// Top shell bar: currency badges plus stats/settings affordances.
class GlobalHud extends StatelessWidget {
  const GlobalHud({super.key});

  static const double _minTouch = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hud = Theme.of(context).extension<HudPalette>()!;
    final iconColor = hud.iconForeground;

    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final inf = ref.watch(totalInfluenceProvider);
                          return CurrencyBadge.influence(value: inf);
                        },
                      ),
                      const SizedBox(width: Spacing.sm),
                      Consumer(
                        builder: (context, ref, _) {
                          final intel = ref.watch(totalIntelProvider);
                          return CurrencyBadge.intel(value: intel);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Stats',
              button: true,
              child: IconButton(
                tooltip: 'Stats',
                style: IconButton.styleFrom(
                  minimumSize: const Size(_minTouch, _minTouch),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.query_stats, color: iconColor),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const StatsScreen(),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              label: 'Settings',
              button: true,
              child: IconButton(
                tooltip: 'Settings',
                style: IconButton.styleFrom(
                  minimumSize: const Size(_minTouch, _minTouch),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.settings, color: iconColor),
                onPressed: () => showSettingsModal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
