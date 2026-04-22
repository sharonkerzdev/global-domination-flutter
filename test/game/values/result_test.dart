import 'package:global_domination/game/values/result.dart';
import 'package:test/test.dart';

void main() {
  group('Success', () {
    test('is Success with correct properties', () {
      final result = Result<int, String>.success(42);
      expect(result, isA<Success<int, String>>());
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('getOrElse returns value', () {
      final result = Result<int, String>.success(42);
      expect(result.getOrElse((_) => -1), 42);
    });

    test('map transforms value', () {
      final result = Result<int, String>.success(42);
      final mapped = result.map((v) => v.toString());
      expect(mapped, isA<Success<String, String>>());
      expect(mapped.valueOrNull, '42');
    });

    test('equality — same value', () {
      final a = Result<int, String>.success(42);
      final b = Result<int, String>.success(42);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality — different value', () {
      final a = Result<int, String>.success(42);
      final b = Result<int, String>.success(99);
      expect(a, isNot(equals(b)));
    });

    test('toString includes variant name and payload', () {
      final result = Result<int, String>.success(42);
      expect(result.toString(), 'Success(42)');
    });
  });

  group('Failure', () {
    test('is Failure with correct properties', () {
      final result = Result<int, String>.failure('err');
      expect(result, isA<Failure<int, String>>());
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull, 'err');
      expect(result.valueOrNull, isNull);
    });

    test('getOrElse calls fallback', () {
      final result = Result<int, String>.failure('err');
      expect(result.getOrElse((e) => e.length), 3);
    });

    test('map passes through Failure', () {
      final result = Result<int, String>.failure('err');
      final mapped = result.map((v) => v.toString());
      expect(mapped, isA<Failure<String, String>>());
      expect(mapped.errorOrNull, 'err');
    });

    test('equality — same error', () {
      final a = Result<int, String>.failure('err');
      final b = Result<int, String>.failure('err');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality — different error', () {
      final a = Result<int, String>.failure('err');
      final b = Result<int, String>.failure('other');
      expect(a, isNot(equals(b)));
    });

    test('toString includes variant name and payload', () {
      final result = Result<int, String>.failure('err');
      expect(result.toString(), 'Failure(err)');
    });
  });

  group('Success vs Failure', () {
    test('are not equal', () {
      final success = Result<String, String>.success('val');
      final failure = Result<String, String>.failure('val');
      expect(success, isNot(equals(failure)));
    });

    test('exhaustive pattern match', () {
      final Result<int, String> success = Result.success(42);
      final Result<int, String> failure = Result.failure('err');

      final successResult = switch (success) {
        Success(:final value) => 'got $value',
        Failure(:final error) => 'err $error',
      };
      expect(successResult, 'got 42');

      final failureResult = switch (failure) {
        Success(:final value) => 'got $value',
        Failure(:final error) => 'err $error',
      };
      expect(failureResult, 'err err');
    });
  });
}
