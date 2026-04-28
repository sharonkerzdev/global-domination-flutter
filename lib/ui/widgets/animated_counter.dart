import 'package:flutter/material.dart';

/// Display-only transition between formatted strings (~400ms).
///
/// Uses framework implicit animation only — no app-level [AnimationController].
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.formattedValue,
    this.duration = const Duration(milliseconds: 400),
    this.style,
  });

  final String formattedValue;
  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        formattedValue,
        key: ValueKey<String>(formattedValue),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }
}
