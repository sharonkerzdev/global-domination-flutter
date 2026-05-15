import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/providers/map_focus_providers.dart';

// Story 9-1 will rewrite tutorialCompletedProvider to read GameState.tutorialCompleted.
// Update this test then to cover the GameState-driven path.
void main() {
  test('tutorialCompletedProvider returns true by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(tutorialCompletedProvider), isTrue);
  });
}
