import 'package:flutter/material.dart';

import 'package:global_domination/ui/theme/hud_palette.dart';

const Duration _flyingNumberDuration = Duration(milliseconds: 1000);
const double _flyingNumberDistance = 120.0;

/// A single ephemeral floating-number widget that translates upward and fades.
///
/// Uses [TweenAnimationBuilder] (no AnimationController / Ticker) per the
/// project one-Ticker rule. [onEnd] fires when the animation completes so the
/// parent can remove this widget from its [Stack].
class FlyingNumber extends StatelessWidget {
  const FlyingNumber({
    required this.amount,
    required this.screenOffset,
    required this.onEnd,
    required this.reduceMotion,
    super.key,
  });

  /// Formatted influence string to display (e.g. "42", "1.2K").
  final String amount;

  /// Top-left position in screen/stack coordinates where the number originates.
  final Offset screenOffset;

  /// Called when the animation finishes so the parent can clean up.
  final VoidCallback onEnd;

  /// When true, skip translate/fade and show a static number for 500 ms instead.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final hud =
        Theme.of(context).extension<HudPalette>() ?? HudPalette.defaults;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: hud.badgeForeground,
      fontWeight: FontWeight.bold,
    );
    final text = Text(amount, style: style, textAlign: TextAlign.center);

    if (reduceMotion) {
      return _StaticFlyingNumber(
        screenOffset: screenOffset,
        onEnd: onEnd,
        child: text,
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: _flyingNumberDuration,
          curve: Curves.easeOut,
          onEnd: onEnd,
          builder: (context, t, child) {
            final dy = -_flyingNumberDistance * t;
            final opacity = 1.0 - t;
            return CustomSingleChildLayout(
              delegate: _FlyingNumberPositionDelegate(
                screenOffset + Offset(0, dy),
              ),
              child: Opacity(opacity: opacity, child: child),
            );
          },
          child: text,
        ),
      ),
    );
  }
}

class _FlyingNumberPositionDelegate extends SingleChildLayoutDelegate {
  const _FlyingNumberPositionDelegate(this.offset);

  final Offset offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width > childSize.width
        ? size.width - childSize.width
        : 0.0;
    final maxTop = size.height > childSize.height
        ? size.height - childSize.height
        : 0.0;
    final left = offset.dx.clamp(0.0, maxLeft).toDouble();
    final top = offset.dy.clamp(0.0, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_FlyingNumberPositionDelegate oldDelegate) {
    return offset != oldDelegate.offset;
  }
}

/// Static (no-motion) variant shown when platform reduce-motion is active.
class _StaticFlyingNumber extends StatefulWidget {
  const _StaticFlyingNumber({
    required this.child,
    required this.screenOffset,
    required this.onEnd,
  });

  final Widget child;
  final Offset screenOffset;
  final VoidCallback onEnd;

  @override
  State<_StaticFlyingNumber> createState() => _StaticFlyingNumberState();
}

class _StaticFlyingNumberState extends State<_StaticFlyingNumber> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) widget.onEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _FlyingNumberPositionDelegate(widget.screenOffset),
          child: widget.child,
        ),
      ),
    );
  }
}
