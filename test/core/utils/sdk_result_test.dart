import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  test(
    'success/failure are typed, comparable and retain diagnostics privately',
    () {
      const success = SdkSuccess<int>(3);
      final failure = SdkFailure<int>(
        kind: SdkErrorKind.storage,
        message: 'safe',
        cause: StateError('secret'),
      );
      expect(success.value, 3);
      expect(success.isSuccess, isTrue);
      expect(failure.isSuccess, isFalse);
      expect(failure.toString(), isNot(contains('secret')));
      expect(failure.cause, isA<StateError>());
      expect(const SdkSuccess<int>(3), success);
      expect(
        failure,
        isNot(
          const SdkFailure<int>(kind: SdkErrorKind.network, message: 'safe'),
        ),
      );
    },
  );

  test('base result value handles both variants and equality ignores diagnostics', () {
    const SdkResult<int> success = SdkSuccess<int>(3);
    final cause = StateError('private cause');
    final stack = StackTrace.fromString('private stack');
    final SdkResult<int> failure = SdkFailure<int>(
      kind: SdkErrorKind.storage,
      message: 'safe',
      retryable: true,
      cause: cause,
      stackTrace: stack,
    );
    expect(success.value, 3);
    expect(success.toString(), 'SdkSuccess<int>(3)');
    expect(failure.value, isNull);
    final typed = failure as SdkFailure<int>;
    expect(typed.cause, same(cause));
    expect(typed.stackTrace, same(stack));
    const equivalent = SdkFailure<int>(
      kind: SdkErrorKind.storage,
      message: 'safe',
      retryable: true,
    );
    expect(typed, equivalent);
    expect(typed.hashCode, equivalent.hashCode);
    expect(success.hashCode, const SdkSuccess<int>(3).hashCode);
    expect(typed.toString(), isNot(contains('private')));
  });

  test('VersionedJsonStore exposes storage failures as SdkResult', () {
    final store = VersionedJsonStore<int>(
      storage: StorageService(null),
      key: 'missing',
      schemaVersion: 1,
      toJson: (_) => {},
      fromJson: (_) => 1,
      migrate: (_, json) => json,
    );
    final result = store.loadResult();
    expect(result, isA<SdkFailure<int>>());
    expect((result as SdkFailure<int>).kind, SdkErrorKind.storage);
  });

  testWidgets('consumer can render typed failure state', (tester) async {
    const result = SdkFailure<void>(
      kind: SdkErrorKind.network,
      message: 'Try again',
      retryable: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommonButton(
          label: result.retryable ? result.message : 'Failed',
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Try again').evaluate(), isNotEmpty);
  });

  group('equality distinguishes every field that is part of a result', () {
    const base = SdkFailure<int>(
      kind: SdkErrorKind.storage,
      message: 'safe',
      retryable: true,
    );

    test('failure: khác kind/message/retryable thì không bằng nhau', () {
      expect(
        base,
        isNot(const SdkFailure<int>(kind: SdkErrorKind.network, message: 'safe', retryable: true)),
      );
      expect(
        base,
        isNot(const SdkFailure<int>(kind: SdkErrorKind.storage, message: 'other', retryable: true)),
      );
      expect(
        base,
        isNot(const SdkFailure<int>(kind: SdkErrorKind.storage, message: 'safe')),
      );
    });

    test('failure: retryable khác nhau cho hashCode khác nhau', () {
      const notRetryable = SdkFailure<int>(
        kind: SdkErrorKind.storage,
        message: 'safe',
      );
      expect(base.hashCode, isNot(notRetryable.hashCode));
    });

    test('success: giá trị khác nhau thì không bằng nhau, cùng giá trị thì bằng', () {
      expect(const SdkSuccess<int>(1), isNot(const SdkSuccess<int>(2)));
      expect(const SdkSuccess<int>(1), const SdkSuccess<int>(1));
      expect(const SdkSuccess<int>(1).hashCode, isNot(const SdkSuccess<int>(2).hashCode));
    });

    test('success và failure không bao giờ bằng nhau', () {
      // ignore: unrelated_type_equality_checks
      expect(const SdkSuccess<int>(1) == base, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(base == const SdkSuccess<int>(1), isFalse);
    });
  });
}
