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
}
