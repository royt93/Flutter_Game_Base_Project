import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/secure_storage_adapter.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

class _ThrowingSecureStorageAdapter implements SecureStorageAdapter {
  @override
  Future<String?> read(String key) => throw Exception('keystore locked');
  @override
  Future<void> write(String key, String value) =>
      throw Exception('keystore locked');
  @override
  Future<void> delete(String key) => throw Exception('keystore locked');
  @override
  Future<void> clear() => throw Exception('keystore locked');
}

void main() {
  tearDown(Get.reset);

  group('không có adapter đăng ký', () {
    test('read/write/delete/clear đều trả SdkFailure rõ ràng', () async {
      expect((await SecureStorage.read('k')).isSuccess, isFalse);
      expect((await SecureStorage.write('k', 'v')).isSuccess, isFalse);
      expect((await SecureStorage.delete('k')).isSuccess, isFalse);
      expect((await SecureStorage.clear()).isSuccess, isFalse);
    });

    test(
      'KHÔNG BAO GIỜ fallback ghi secret vào StorageService thường',
      () async {
        final storage = StorageService(null);
        Get.put<StorageService>(storage);

        await SecureStorage.write('api_token', 'super-secret-value');

        // Không có key nào bị lộ vào storage thường qua bất kỳ đường nào.
        expect(storage.exportAll(), isEmpty);
      },
    );

    test('isAvailable == false', () {
      expect(SecureStorage.isAvailable, isFalse);
    });
  });

  group('có adapter đăng ký (FakeSecureStorageAdapter)', () {
    setUp(() => Get.put<SecureStorageAdapter>(FakeSecureStorageAdapter()));

    test('write rồi read trả đúng giá trị', () async {
      final write = await SecureStorage.write('token', 'abc123');
      expect(write.isSuccess, isTrue);

      final read = await SecureStorage.read('token');
      expect(read.isSuccess, isTrue);
      expect(read.value, 'abc123');
    });

    test(
      'read key chưa từng ghi trả về null (thành công, không lỗi)',
      () async {
        final read = await SecureStorage.read('missing');
        expect(read.isSuccess, isTrue);
        expect(read.value, isNull);
      },
    );

    test('delete xoá đúng key, không đụng key khác', () async {
      await SecureStorage.write('a', '1');
      await SecureStorage.write('b', '2');

      await SecureStorage.delete('a');

      expect((await SecureStorage.read('a')).value, isNull);
      expect((await SecureStorage.read('b')).value, '2');
    });

    test('clear xoá hết mọi key', () async {
      await SecureStorage.write('a', '1');
      await SecureStorage.write('b', '2');

      await SecureStorage.clear();

      expect((await SecureStorage.read('a')).value, isNull);
      expect((await SecureStorage.read('b')).value, isNull);
    });

    test(
      'key rỗng bị từ chối TRƯỚC khi chạm tới adapter (validation)',
      () async {
        final result = await SecureStorage.write('', 'v');
        expect(result.isSuccess, isFalse);
        expect((result as SdkFailure).kind, SdkErrorKind.validation);
      },
    );

    test('isAvailable == true', () {
      expect(SecureStorage.isAvailable, isTrue);
    });

    test(
      'ghi đồng thời 2 key khác nhau đều thành công, không đụng nhau',
      () async {
        final results = await Future.wait([
          SecureStorage.write('x', '1'),
          SecureStorage.write('y', '2'),
        ]);

        expect(results.every((r) => r.isSuccess), isTrue);
        expect((await SecureStorage.read('x')).value, '1');
        expect((await SecureStorage.read('y')).value, '2');
      },
    );

    test(
      'Get.delete adapter giữa chừng: lần gọi SAU đó báo lỗi rõ ràng (không cache)',
      () async {
        await SecureStorage.write('token', 'abc');
        await Get.delete<SecureStorageAdapter>(force: true);

        final result = await SecureStorage.read('token');
        expect(result.isSuccess, isFalse);
      },
    );
  });

  group('adapter throw lỗi platform', () {
    setUp(() => Get.put<SecureStorageAdapter>(_ThrowingSecureStorageAdapter()));

    test(
      'lỗi được bọc thành SdkFailure(platform), message KHÔNG lộ value',
      () async {
        final result = await SecureStorage.write('token', 'top-secret-value');

        expect(result.isSuccess, isFalse);
        final failure = result as SdkFailure;
        expect(failure.kind, SdkErrorKind.platform);
        expect(failure.message, isNot(contains('top-secret-value')));
      },
    );
  });

  group('FakeSecureStorageAdapter', () {
    test('round-trip read/write/delete/clear hoạt động đúng độc lập', () async {
      final fake = FakeSecureStorageAdapter();
      await fake.write('k', 'v');
      expect(await fake.read('k'), 'v');

      await fake.delete('k');
      expect(await fake.read('k'), isNull);

      await fake.write('a', '1');
      await fake.write('b', '2');
      await fake.clear();
      expect(await fake.read('a'), isNull);
      expect(await fake.read('b'), isNull);
    });
  });
}
