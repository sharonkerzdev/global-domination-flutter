import 'package:flutter/material.dart';

import '../../../ui/theme/milestone_colors.dart';
import '../../../ui/theme/spacing.dart';

/// Reusable progress bar widget showing continent ownership with milestone tiers.
class ContinentProgressBar extends StatefulWidget {
  const ContinentProgressBar({
    required this.ownedCount,
    required this.totalCount,
    required this.reachedMilestoneTiers,
    this.semanticLabel,
    super.key,
  });

  final int ownedCount;
  final int totalCount;
  final Set<int> reachedMilestoneTiers;
  final String? semanticLabel;

  @override
  State<ContinentProgressBar> createState() => _ContinentProgressBarState();
}

class _ContinentProgressBarState extends State<ContinentProgressBar> {
  late Set<int> _activelyPulsingTiers;

  @override
  void initState() {
    super.initState();
    _activelyPulsingTiers = const {};
  }

  @override
  void didUpdateWidget(ContinentProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newlyReached = widget.reachedMilestoneTiers.difference(
      oldWidget.reachedMilestoneTiers,
    );
    if (newlyReached.isNotEmpty) {
      _activelyPulsingTiers = newlyReached;
    }
  }

  void _onPulseFinished(int tier) {
    setState(() {
      _activelyPulsingTiers.remove(tier);
    });
  }

  @override
  Widget build(BuildContext context) {
    final milestones = Theme.of(context).extension<MilestoneColors>()!;
    final highestReached = widget.reachedMilestoneTiers.isEmpty
        ? 0
        : widget.reachedMilestoneTiers.reduce((a, b) => a > b ? a : b);
    final isComplete = highestReached >= 100;

    final barContent = SizedBox(
      height: Spacing.sm,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return Stack(
            children: [
              // Track background
              Container(
                decoration: BoxDecoration(
                  color: milestones.track,
                  borderRadius: BorderRadius.circular(Spacing.xs),
                ),
              ),
              // Animated fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: widget.totalCount == 0
                    ? 0
                    : barWidth * (widget.ownedCount / widget.totalCount),
                decoration: BoxDecoration(
                  color: _fillColorFor(highestReached, milestones),
                  borderRadius: BorderRadius.circular(Spacing.xs),
                ),
              ),
              // Tick marks at 25 / 50 / 75 / 100
              for (final tier in const [25, 50, 75, 100])
                Positioned(
                  left: (barWidth * tier / 100) - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: _Tick(
                    key: ValueKey('continent-progress-tick-$tier'),
                    tier: tier,
                    filled:
                        isComplete ||
                        widget.reachedMilestoneTiers.contains(tier),
                    highestReachedTier: highestReached,
                    pulsing: _activelyPulsingTiers.contains(tier),
                    milestones: milestones,
                    onPulseFinished: _onPulseFinished,
                  ),
                ),
            ],
          );
        },
      ),
    );

    if (widget.semanticLabel != null) {
      return Semantics(
        container: true,
        label: widget.semanticLabel,
        child: barContent,
      );
    }

    return barContent;
  }
}

/// Tick mark for milestone progress bar.
class _Tick extends StatelessWidget {
  const _Tick({
    super.key,
    required this.tier,
    required this.filled,
    required this.highestReachedTier,
    required this.pulsing,
    required this.milestones,
    required this.onPulseFinished,
  });

  final int tier;
  final bool filled;
  final int highestReachedTier;
  final bool pulsing;
  final MilestoneColors milestones;
  final void Function(int) onPulseFinished;

  @override
  Widget build(BuildContext context) {
    if (pulsing && filled) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        onEnd: () => onPulseFinished(tier),
        builder: (context, t, child) {
          final startColor = milestones.pulseAccent;
          final endColor = _tickColorForTier(
            tier,
            highestReachedTier,
            milestones,
          );
          final color = Color.lerp(startColor, endColor, t) ?? endColor;
          return Container(decoration: BoxDecoration(color: color));
        },
      );
    }

    if (filled) {
      return Container(
        decoration: BoxDecoration(
          color: _tickColorForTier(tier, highestReachedTier, milestones),
        ),
      );
    }

    return Container(decoration: BoxDecoration(color: milestones.tick));
  }
}

Color _tickColorForTier(int tier, int highestReachedTier, MilestoneColors m) {
  if (highestReachedTier >= 100) {
    return m.milestone100;
  }
  return _milestoneColorForTier(tier, m);
}

Color _milestoneColorForTier(int tier, MilestoneColors m) {
  switch (tier) {
    case 25:
      return m.milestone25;
    case 50:
      return m.milestone50;
    case 75:
      return m.milestone75;
    case 100:
      return m.milestone100;
    default:
      return m.track;
  }
}

Color _fillColorFor(int highestReached, MilestoneColors m) {
  switch (highestReached) {
    case 0:
      return m.track;
    case 25:
      return m.milestone25;
    case 50:
      return m.milestone50;
    case 75:
      return m.milestone75;
    case 100:
      return m.milestone100;
    default:
      return m.track;
  }
}
