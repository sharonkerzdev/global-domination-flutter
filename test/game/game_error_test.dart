import 'package:decimal/decimal.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/game/values/result.dart';
import 'package:test/test.dart';

void main() {
  group('UserError variants', () {
    group('InsufficientFunds', () {
      test('constructs and exposes fields correctly', () {
        final cost = Influence(Decimal.fromInt(100));
        final error = InsufficientFunds(required: cost);
        expect(error.required, cost);
        expect(error, isA<UserError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final cost = Influence(Decimal.fromInt(100));
        final a = InsufficientFunds(required: cost);
        final b = InsufficientFunds(required: cost);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = InsufficientFunds(required: Influence(Decimal.fromInt(100)));
        final b = InsufficientFunds(required: Influence(Decimal.fromInt(200)));
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = InsufficientFunds(
          required: Influence(Decimal.fromInt(100)),
        );
        expect(error.toString(), contains('InsufficientFunds'));
        expect(error.toString(), contains('required'));
      });
    });

    group('Locked', () {
      test('constructs and exposes fields correctly', () {
        final error = Locked(reason: 'ip_below_10');
        expect(error.reason, 'ip_below_10');
        expect(error, isA<UserError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = Locked(reason: 'max_level');
        final b = Locked(reason: 'max_level');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = Locked(reason: 'max_level');
        final b = Locked(reason: 'ip_below_10');
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = Locked(reason: 'max_level');
        expect(error.toString(), 'Locked(reason: max_level)');
      });
    });

    group('InvalidTarget', () {
      test('constructs and exposes fields correctly', () {
        final error = InvalidTarget(detail: 'country not adjacent');
        expect(error.detail, 'country not adjacent');
        expect(error, isA<UserError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = InvalidTarget(detail: 'x');
        final b = InvalidTarget(detail: 'x');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = InvalidTarget(detail: 'x');
        final b = InvalidTarget(detail: 'y');
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = InvalidTarget(detail: 'bad target');
        expect(error.toString(), 'InvalidTarget(detail: bad target)');
      });
    });
  });

  group('InternalError variants', () {
    group('MissingCountry', () {
      test('constructs and exposes fields correctly', () {
        final error = MissingCountry(id: CountryId('US'));
        expect(error.id, CountryId('US'));
        expect(error, isA<InternalError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = MissingCountry(id: CountryId('US'));
        final b = MissingCountry(id: CountryId('US'));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = MissingCountry(id: CountryId('US'));
        final b = MissingCountry(id: CountryId('GB'));
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = MissingCountry(id: CountryId('US'));
        expect(error.toString(), contains('MissingCountry'));
        expect(error.toString(), contains('CountryId(US)'));
      });
    });

    group('InvariantBroken', () {
      test('constructs and exposes fields correctly', () {
        final error = InvariantBroken(message: 'state is null');
        expect(error.message, 'state is null');
        expect(error, isA<InternalError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = InvariantBroken(message: 'x');
        final b = InvariantBroken(message: 'x');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = InvariantBroken(message: 'x');
        final b = InvariantBroken(message: 'y');
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = InvariantBroken(message: 'bad state');
        expect(error.toString(), 'InvariantBroken(message: bad state)');
      });
    });

    group('PersistenceFailure', () {
      test('constructs and exposes fields correctly', () {
        final error = PersistenceFailure(cause: 'disk full');
        expect(error.cause, 'disk full');
        expect(error, isA<InternalError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = PersistenceFailure(cause: 'disk full');
        final b = PersistenceFailure(cause: 'disk full');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = PersistenceFailure(cause: 'disk full');
        final b = PersistenceFailure(cause: 'timeout');
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = PersistenceFailure(cause: 'disk full');
        expect(error.toString(), 'PersistenceFailure(cause: disk full)');
      });
    });

    group('MigrationFailure', () {
      test('constructs and exposes fields correctly', () {
        final error = MigrationFailure(
          fromVersion: 1,
          toVersion: 2,
          cause: 'column missing',
        );
        expect(error.fromVersion, 1);
        expect(error.toVersion, 2);
        expect(error.cause, 'column missing');
        expect(error, isA<InternalError>());
        expect(error, isA<GameError>());
      });

      test('equality — same fields', () {
        final a = MigrationFailure(fromVersion: 1, toVersion: 2, cause: 'x');
        final b = MigrationFailure(fromVersion: 1, toVersion: 2, cause: 'x');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('equality — different fields', () {
        final a = MigrationFailure(fromVersion: 1, toVersion: 2, cause: 'x');
        final b = MigrationFailure(fromVersion: 1, toVersion: 3, cause: 'x');
        expect(a, isNot(equals(b)));
      });

      test('toString includes variant name and field values', () {
        final error = MigrationFailure(
          fromVersion: 1,
          toVersion: 2,
          cause: 'bad',
        );
        expect(error.toString(), contains('MigrationFailure'));
        expect(error.toString(), contains('fromVersion: 1'));
        expect(error.toString(), contains('toVersion: 2'));
        expect(error.toString(), contains('cause: bad'));
      });
    });
  });

  group('different variants are not equal', () {
    test('UserError variants differ', () {
      final a = Locked(reason: 'x');
      final b = InvalidTarget(detail: 'x');
      expect(a, isNot(equals(b)));
    });

    test('InternalError variants differ', () {
      final a = InvariantBroken(message: 'x');
      final b = PersistenceFailure(cause: 'x');
      expect(a, isNot(equals(b)));
    });
  });

  group('exhaustive pattern match', () {
    test('GameError → UserError / InternalError', () {
      final GameError userErr = Locked(reason: 'test');
      final GameError internalErr = InvariantBroken(message: 'test');

      final userResult = switch (userErr) {
        UserError() => 'user',
        InternalError() => 'internal',
      };
      expect(userResult, 'user');

      final internalResult = switch (internalErr) {
        UserError() => 'user',
        InternalError() => 'internal',
      };
      expect(internalResult, 'internal');
    });

    test('UserError → individual variants', () {
      final UserError error = Locked(reason: 'test');
      final result = switch (error) {
        InsufficientFunds(:final required) => 'funds: $required',
        InsufficientIntel(:final required) => 'intel: $required',
        Locked(:final reason) => 'locked: $reason',
        InvalidTarget(:final detail) => 'target: $detail',
      };
      expect(result, 'locked: test');
    });

    test('InternalError → individual variants', () {
      final InternalError error = MissingCountry(id: CountryId('US'));
      final result = switch (error) {
        MissingCountry(:final id) => 'missing: $id',
        InvariantBroken(:final message) => 'broken: $message',
        PersistenceFailure(:final cause) => 'persist: $cause',
        MigrationFailure(:final fromVersion, :final toVersion) =>
          'migrate: $fromVersion→$toVersion',
      };
      expect(result, 'missing: CountryId(US)');
    });
  });

  group('named constructors', () {
    test('GameError.userInsufficientFunds produces InsufficientFunds', () {
      final error = GameError.userInsufficientFunds(
        required: Influence(Decimal.fromInt(50)),
      );
      expect(error, isA<InsufficientFunds>());
      expect(error, isA<UserError>());
      expect(
        (error as InsufficientFunds).required,
        Influence(Decimal.fromInt(50)),
      );
    });

    test('GameError.userInsufficientIntel produces InsufficientIntel', () {
      final need = Intel(Decimal.fromInt(100));
      final error = GameError.userInsufficientIntel(required: need);
      expect(error, isA<InsufficientIntel>());
      expect(error, isA<UserError>());
      expect((error as InsufficientIntel).required, need);
    });

    test('GameError.userLocked produces Locked', () {
      final error = GameError.userLocked(reason: 'max_level');
      expect(error, isA<Locked>());
      expect(error, isA<UserError>());
      expect((error as Locked).reason, 'max_level');
    });

    test('GameError.userInvalidTarget produces InvalidTarget', () {
      final error = GameError.userInvalidTarget(detail: 'no such target');
      expect(error, isA<InvalidTarget>());
      expect(error, isA<UserError>());
      expect((error as InvalidTarget).detail, 'no such target');
    });

    test('GameError.internalMissingCountry produces MissingCountry', () {
      final error = GameError.internalMissingCountry(id: CountryId('XX'));
      expect(error, isA<MissingCountry>());
      expect(error, isA<InternalError>());
      expect((error as MissingCountry).id, CountryId('XX'));
    });

    test('GameError.internalInvariantBroken produces InvariantBroken', () {
      final error = GameError.internalInvariantBroken(message: 'oops');
      expect(error, isA<InvariantBroken>());
      expect(error, isA<InternalError>());
      expect((error as InvariantBroken).message, 'oops');
    });

    test(
      'GameError.internalPersistenceFailure produces PersistenceFailure',
      () {
        final error = GameError.internalPersistenceFailure(cause: 'io error');
        expect(error, isA<PersistenceFailure>());
        expect(error, isA<InternalError>());
        expect((error as PersistenceFailure).cause, 'io error');
      },
    );

    test('GameError.internalMigrationFailure produces MigrationFailure', () {
      final error = GameError.internalMigrationFailure(
        fromVersion: 3,
        toVersion: 4,
        cause: 'schema mismatch',
      );
      expect(error, isA<MigrationFailure>());
      expect(error, isA<InternalError>());
      final migration = error as MigrationFailure;
      expect(migration.fromVersion, 3);
      expect(migration.toVersion, 4);
      expect(migration.cause, 'schema mismatch');
    });
  });

  group('Result<T, GameError> composition', () {
    test('Failure with GameError is pattern-matchable', () {
      final Result<int, GameError> result = Result.failure(
        GameError.userLocked(reason: 'test'),
      );

      final output = switch (result) {
        Success(:final value) => 'ok: $value',
        Failure(error: final UserError error) => 'user: $error',
        Failure(error: final InternalError error) => 'internal: $error',
      };
      expect(output, startsWith('user:'));
    });

    test('Success with GameError error type works', () {
      final Result<int, GameError> result = Result.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
    });
  });
}
