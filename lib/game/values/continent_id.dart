import 'package:meta/meta.dart';

@immutable
class ContinentId {
  final String value;
  const ContinentId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ContinentId && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ContinentId($value)';
}
