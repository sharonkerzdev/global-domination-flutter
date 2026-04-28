import 'package:flutter/material.dart';

import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/ui/theme/hud_palette.dart';
import 'package:global_domination/ui/theme/spacing.dart';
import 'package:global_domination/ui/widgets/animated_counter.dart';

enum _CurrencyKind { influence, intel }

/// Tokenized currency chip for HUD and future reuse (upgrades, rewards, missions).
class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge._({
    super.key,
    required _CurrencyKind kind,
    required Object value,
  }) : _kind = kind,
       _value = value;

  final _CurrencyKind _kind;
  final Object _value;

  factory CurrencyBadge.influence({Key? key, required Influence value}) =>
      CurrencyBadge._(key: key, kind: _CurrencyKind.influence, value: value);

  factory CurrencyBadge.intel({Key? key, required Intel value}) =>
      CurrencyBadge._(key: key, kind: _CurrencyKind.intel, value: value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hud = theme.extension<HudPalette>()!;
    final isInfluence = _kind == _CurrencyKind.influence;
    final accent = isInfluence ? hud.influenceAccent : hud.intelAccent;
    final formatted = isInfluence
        ? (_value as Influence).format()
        : (_value as Intel).format();
    final name = isInfluence ? 'Influence' : 'Intel';
    final icon = isInfluence ? Icons.public : Icons.memory;

    final textStyle = theme.textTheme.titleSmall?.copyWith(
      color: hud.badgeForeground,
      fontWeight: FontWeight.w600,
    );

    return Semantics(
      label: '$name $formatted',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: hud.badgeBackground,
            borderRadius: BorderRadius.circular(hud.badgeBorderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: Spacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedCounter(
                    formattedValue: formatted,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
