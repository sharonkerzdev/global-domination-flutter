import 'package:meta/meta.dart';

@immutable
sealed class Result<T, E> {
  const Result();

  const factory Result.success(T value) = Success<T, E>;
  const factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess;
  bool get isFailure;
  T? get valueOrNull;
  E? get errorOrNull;

  T getOrElse(T Function(E) orElse);
  Result<U, E> map<U>(U Function(T) f);
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T? get valueOrNull => value;

  @override
  E? get errorOrNull => null;

  @override
  T getOrElse(T Function(E) orElse) => value;

  @override
  Result<U, E> map<U>(U Function(T) f) => Success<U, E>(f(value));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Success<T, E> && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  T getOrElse(T Function(E) orElse) => orElse(error);

  @override
  Result<U, E> map<U>(U Function(T) f) => Failure<U, E>(error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T, E> && error == other.error);

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}
