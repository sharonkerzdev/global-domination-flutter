import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/game_providers.dart';

class RecentlyUnlockedCountryNotifier extends StateNotifier<CountryId?> {
  RecentlyUnlockedCountryNotifier(Stream<GameEvent> events) : super(null) {
    _sub = events.listen((e) {
      if (e is CountryUnlocked) state = e.countryId;
    });
  }

  late final StreamSubscription<GameEvent> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final recentlyUnlockedCountryProvider =
    StateNotifierProvider<RecentlyUnlockedCountryNotifier, CountryId?>((ref) {
      final events = ref.watch(gameWorldEventsProvider);
      return RecentlyUnlockedCountryNotifier(events);
    });

/// Returns `true` whenever no tutorial system is active. Story 9-1 will rewrite
/// this provider to read [GameState.tutorialCompleted].
final tutorialCompletedProvider = Provider<bool>((ref) => true);
