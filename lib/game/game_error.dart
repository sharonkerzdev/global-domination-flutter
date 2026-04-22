import 'package:meta/meta.dart';

import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
sealed class GameError {
  const GameError();

  const factory GameError.userInsufficientFunds({required Influence required}) =
      InsufficientFunds;
  const factory GameError.userLocked({required String reason}) = Locked;
  const factory GameError.userInvalidTarget({required String detail}) =
      InvalidTarget;
  const factory GameError.internalMissingCountry({required CountryId id}) =
      MissingCountry;
  const factory GameError.internalInvariantBroken({required String message}) =
      InvariantBroken;
  const factory GameError.internalPersistenceFailure({required String cause}) =
      PersistenceFailure;
  const factory GameError.internalMigrationFailure({
    required int fromVersion,
    required int toVersion,
    required String cause,
  }) = MigrationFailure;
}

@immutable
sealed class UserError extends GameError {
  const UserError();
}

final class InsufficientFunds extends UserError {
  final Influence required;
  const InsufficientFunds({required this.required});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsufficientFunds && required == other.required);

  @override
  int get hashCode => required.hashCode;

  @override
  String toString() => 'InsufficientFunds(required: $required)';
}

final class Locked extends UserError {
  final String reason;
  const Locked({required this.reason});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Locked && reason == other.reason);

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'Locked(reason: $reason)';
}

final class InvalidTarget extends UserError {
  final String detail;
  const InvalidTarget({required this.detail});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvalidTarget && detail == other.detail);

  @override
  int get hashCode => detail.hashCode;

  @override
  String toString() => 'InvalidTarget(detail: $detail)';
}

@immutable
sealed class InternalError extends GameError {
  const InternalError();
}

final class MissingCountry extends InternalError {
  final CountryId id;
  const MissingCountry({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MissingCountry && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MissingCountry(id: $id)';
}

final class InvariantBroken extends InternalError {
  final String message;
  const InvariantBroken({required this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvariantBroken && message == other.message);

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'InvariantBroken(message: $message)';
}

final class PersistenceFailure extends InternalError {
  final String cause;
  const PersistenceFailure({required this.cause});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersistenceFailure && cause == other.cause);

  @override
  int get hashCode => cause.hashCode;

  @override
  String toString() => 'PersistenceFailure(cause: $cause)';
}

final class MigrationFailure extends InternalError {
  final int fromVersion;
  final int toVersion;
  final String cause;
  const MigrationFailure({
    required this.fromVersion,
    required this.toVersion,
    required this.cause,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationFailure &&
          fromVersion == other.fromVersion &&
          toVersion == other.toVersion &&
          cause == other.cause);

  @override
  int get hashCode => Object.hash(fromVersion, toVersion, cause);

  @override
  String toString() =>
      'MigrationFailure(fromVersion: $fromVersion, toVersion: $toVersion, cause: $cause)';
}
