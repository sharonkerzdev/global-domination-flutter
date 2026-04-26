import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

@immutable
class BoostState {
  const BoostState({required this.multiplier, required this.expiresAt});

  final Decimal multiplier;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoostState &&
          multiplier == other.multiplier &&
          expiresAt == other.expiresAt);

  @override
  int get hashCode => Object.hash(multiplier, expiresAt);

  @override
  String toString() =>
      'BoostState(multiplier: $multiplier, expiresAt: $expiresAt)';
}
