import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/features/modals/offline_reward_modal.dart';

final _kAt = DateTime.utc(2026, 4, 1);

void main() {
  group('formatOfflineRewardElapsed', () {
    test('<1m for under one minute', () {
      expect(formatOfflineRewardElapsed(Duration.zero), '<1m');
      expect(formatOfflineRewardElapsed(const Duration(seconds: 59)), '<1m');
    });

    test('Nm for sub-hour', () {
      expect(formatOfflineRewardElapsed(const Duration(minutes: 12)), '12m');
      expect(formatOfflineRewardElapsed(const Duration(minutes: 1)), '1m');
    });

    test('h and mm for one hour+', () {
      expect(
        formatOfflineRewardElapsed(const Duration(hours: 1, minutes: 5)),
        '1h 05m',
      );
      expect(formatOfflineRewardElapsed(const Duration(hours: 8)), '8h 00m');
    });
  });

  group('OfflineRewardModal', () {
    testWidgets('displays amount, elapsed, single Collect, route Semantics', (
      tester,
    ) async {
      final entry = OfflineRewardModalEntry(
        totalEarned: Influence(Decimal.fromInt(1000)),
        elapsed: const Duration(hours: 1, minutes: 5),
        at: _kAt,
      );
      var collected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => OfflineRewardModal(
                        entry: entry,
                        onCollect: () {
                          collected++;
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(entry.totalEarned.format()), findsOneWidget);
      expect(find.text('Time away: 1h 05m'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Collect'), findsOneWidget);
      expect(find.bySemanticsLabel('Offline reward'), findsAtLeastNWidgets(1));
      expect(collected, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();
      expect(collected, 1);
    });

    testWidgets('no overflow on narrow width at 1e38+ formatted scale', (
      tester,
    ) async {
      final huge = Influence(Decimal.parse('1e38') * Decimal.fromInt(2));
      final e = OfflineRewardModalEntry(
        totalEarned: huge,
        elapsed: const Duration(hours: 8),
        at: _kAt,
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(200, 800),
            textScaler: TextScaler.noScaling,
          ),
          child: MaterialApp(
            home: Center(
              child: OfflineRewardModal(entry: e, onCollect: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
