import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/ui/features/map/game_loop.dart';

// ---------------------------------------------------------------------------
// Spy notifier — records tick calls, extends GameWorldNotifier
// ---------------------------------------------------------------------------

final _emptyContent = const ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
);

class _SpyGameWorldNotifier extends GameWorldNotifier {
  _SpyGameWorldNotifier()
    : super(
        GameWorld(
          content: _emptyContent,
          clock: const SystemClock(),
          initialState: GameState(),
        ),
      );

  final List<Duration> ticks = [];

  @override
  void tick(Duration dt) => ticks.add(dt);

  @override
  void apply(GameCommand cmd) {}
}

Widget _buildApp(_SpyGameWorldNotifier notifier) {
  return ProviderScope(
    overrides: [gameWorldProvider.overrideWith((ref) => notifier)],
    child: const MaterialApp(home: GameLoop(child: SizedBox.expand())),
  );
}

void main() {
  group('GameLoop', () {
    testWidgets('calls tick each frame while active', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(_buildApp(notifier));

      // Pump a few frames
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(notifier.ticks.length, greaterThanOrEqualTo(3));
    });

    testWidgets('tick delta is clamped to 100ms max', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(_buildApp(notifier));

      // Simulate a large frame gap (tab-switch spike)
      await tester.pump(const Duration(milliseconds: 500));

      // All ticks should be clamped to ≤100ms
      for (final dt in notifier.ticks) {
        expect(dt.inMilliseconds, lessThanOrEqualTo(100));
      }
    });

    testWidgets('stops ticking on AppLifecycleState.paused', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(_buildApp(notifier));

      await tester.pump(const Duration(milliseconds: 16));
      final countBeforePause = notifier.ticks.length;

      // Simulate lifecycle paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Pump more frames — no new ticks should be added
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(notifier.ticks.length, equals(countBeforePause));
    });

    testWidgets('stops ticking on AppLifecycleState.inactive', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(_buildApp(notifier));

      await tester.pump(const Duration(milliseconds: 16));
      final countBefore = notifier.ticks.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(notifier.ticks.length, equals(countBefore));
    });

    testWidgets('resumes ticking on AppLifecycleState.resumed', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(_buildApp(notifier));

      await tester.pump(const Duration(milliseconds: 16));

      // Pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final countAfterPause = notifier.ticks.length;

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(notifier.ticks.length, greaterThan(countAfterPause));
    });

    testWidgets('renders child widget', (tester) async {
      final notifier = _SpyGameWorldNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameWorldProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: GameLoop(child: Text('hello'))),
        ),
      );
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
