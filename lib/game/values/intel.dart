import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/values/influence_formatter.dart';

@immutable
class Intel implements Comparable<Intel> {
  final Decimal value;

  const Intel(this.value);

  static final zero = Intel(Decimal.zero);

  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;

  Intel operator +(Intel other) => Intel(value + other.value);
  Intel operator -(Intel other) => Intel(value - other.value);
  Intel operator *(Decimal factor) => Intel(value * factor);

  Intel multiplyByNum(num factor) =>
      Intel(value * Decimal.parse(factor.toString()));

  bool operator <(Intel other) => value < other.value;
  bool operator >(Intel other) => value > other.value;
  bool operator <=(Intel other) => value <= other.value;
  bool operator >=(Intel other) => value >= other.value;

  @override
  int compareTo(Intel other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Intel && value == other.value);

  @override
  int get hashCode => value.hashCode;

  String format() => InfluenceFormatter.abbreviated(value);

  @override
  String toString() => 'Intel($value)';
}
