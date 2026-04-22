import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/values/influence_formatter.dart';

@immutable
class Influence implements Comparable<Influence> {
  final Decimal value;

  const Influence(this.value);

  static final zero = Influence(Decimal.zero);

  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;

  Influence operator +(Influence other) => Influence(value + other.value);
  Influence operator -(Influence other) => Influence(value - other.value);
  Influence operator *(Decimal factor) => Influence(value * factor);

  Influence multiplyByNum(num factor) =>
      Influence(value * Decimal.parse(factor.toString()));

  bool operator <(Influence other) => value < other.value;
  bool operator >(Influence other) => value > other.value;
  bool operator <=(Influence other) => value <= other.value;
  bool operator >=(Influence other) => value >= other.value;

  @override
  int compareTo(Influence other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Influence && value == other.value);

  @override
  int get hashCode => value.hashCode;

  String format() => InfluenceFormatter.abbreviated(value);

  @override
  String toString() => 'Influence($value)';
}
