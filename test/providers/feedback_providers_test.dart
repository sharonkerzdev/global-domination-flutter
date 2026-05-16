import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/services/audio_service.dart';
import 'package:global_domination/services/haptics_service.dart';

void main() {
  test('audio + haptics service providers construct without errors', () {
    final controller = StreamController<GameEvent>.broadcast(sync: true);
    addTearDown(() => controller.close());

    final container = ProviderContainer(
      overrides: [gameWorldEventsProvider.overrideWithValue(controller.stream)],
    );
    addTearDown(container.dispose);

    final audio = container.read(audioServiceProvider);
    expect(audio, isA<AudioService>());

    final haptics = container.read(hapticsServiceProvider);
    expect(haptics, isA<HapticsService>());
  });
}
