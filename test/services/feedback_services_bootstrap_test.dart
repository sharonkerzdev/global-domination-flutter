import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/services/audio_backend.dart';
import 'package:global_domination/services/audio_service.dart';
import 'package:global_domination/services/haptics_service.dart';

import '../helpers/fake_audio_backend.dart';
import '../helpers/fake_haptics_backend.dart';

void main() {
  testWidgets('service providers fire backends on broadcast events', (
    tester,
  ) async {
    final events = StreamController<GameEvent>.broadcast(sync: true);
    addTearDown(events.close);
    final audioBackend = FakeAudioBackend();
    final hapticsBackend = FakeHapticsBackend();
    final clock = const SystemClock();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameWorldEventsProvider.overrideWithValue(events.stream),
          audioServiceProvider.overrideWith(
            (ref) => AudioService(
              events: ref.watch(gameWorldEventsProvider),
              readEnabled: () => true,
              clock: clock,
              backend: audioBackend,
            ),
          ),
          hapticsServiceProvider.overrideWith(
            (ref) => HapticsService(
              events: ref.watch(gameWorldEventsProvider),
              readEnabled: () => true,
              clock: clock,
              backend: hapticsBackend,
            ),
          ),
        ],
        child: _BootstrapHarness(events: events.stream),
      ),
    );
    await tester.pump();

    events.add(
      CountryTapped(
        DateTime.utc(2026, 1, 1),
        countryId: const CountryId('egypt'),
        collected: Influence.zero,
      ),
    );
    await tester.pump();

    expect(audioBackend.playCalls, [Sfx.collect]);
    expect(hapticsBackend.calls, ['light']);
  });
}

class _BootstrapHarness extends ConsumerStatefulWidget {
  const _BootstrapHarness({required this.events});

  final Stream<GameEvent> events;

  @override
  ConsumerState<_BootstrapHarness> createState() => _BootstrapHarnessState();
}

class _BootstrapHarnessState extends ConsumerState<_BootstrapHarness> {
  late final AudioService _audio;
  late final HapticsService _haptics;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    unawaited(_audio.attach());
    _haptics = ref.read(hapticsServiceProvider);
    _haptics.attach();
  }

  @override
  void dispose() {
    unawaited(_audio.detach());
    unawaited(_haptics.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox());
}
