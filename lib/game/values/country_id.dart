import 'package:meta/meta.dart';

@immutable
class CountryId {
  final String value;
  const CountryId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CountryId && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CountryId($value)';
}
