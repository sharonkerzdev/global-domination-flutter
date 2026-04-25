import 'package:meta/meta.dart';

@immutable
class ActiveGoldenEffect {
  const ActiveGoldenEffect({
    required this.goldenId,
    required this.multiplier,
    required this.expiresAt,
  });

  final String goldenId;
  final int multiplier;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveGoldenEffect &&
          goldenId == other.goldenId &&
          multiplier == other.multiplier &&
          expiresAt == other.expiresAt);

  @override
  int get hashCode => Object.hash(goldenId, multiplier, expiresAt);

  @override
  String toString() =>
      'ActiveGoldenEffect(goldenId: $goldenId, multiplier: $multiplier, '
      'expiresAt: $expiresAt)';
}
