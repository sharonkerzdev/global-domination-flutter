import 'dart:math' as math;

/// Injectable random number generation for the simulation. Schedulers and
/// reducers take [Rng] as a parameter; they never call [math.Random] directly.
abstract class Rng {
  int nextInt(int max);
  double nextDouble();
}

/// Deterministic [Rng] for tests and replays. Same [seed] yields the same stream.
final class SeededRng implements Rng {
  SeededRng(this.seed) : _random = math.Random(seed);

  final int seed;
  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SeededRng && other.seed == seed);

  @override
  int get hashCode => seed.hashCode;
}

/// Production [Rng] backed by a non-deterministic [math.Random]. This is the
/// only place in [lib/game/] where [math.Random] with no seed may be used.
final class SystemRng implements Rng {
  SystemRng() : _random = math.Random();

  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();
}
