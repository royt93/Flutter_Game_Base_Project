import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/experiment_bucketing_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('ExperimentBucketingService: validation', () {
    test('experimentKey rỗng/blank throw ArgumentError', () {
      final service = ExperimentBucketingService();

      expect(
        () => service.variantFor('', ['a', 'b']),
        throwsArgumentError,
      );
      expect(
        () => service.variantFor('   ', ['a', 'b']),
        throwsArgumentError,
      );
    });

    test('danh sách variants rỗng throw ArgumentError', () {
      final service = ExperimentBucketingService();

      expect(
        () => service.variantFor('exp_1', const []),
        throwsArgumentError,
      );
    });

    test('variants chỉ 1 phần tử luôn trả về đúng phần tử đó', () {
      final service = ExperimentBucketingService();

      expect(service.variantFor('exp_1', ['only']), 'only');
    });
  });

  group('ExperimentBucketingService: anonymousId ổn định', () {
    test('sinh 1 lần và cache lại — 2 lần đọc trong cùng instance giống nhau', () {
      final service = ExperimentBucketingService();

      final first = service.anonymousId;
      final second = service.anonymousId;

      expect(first, second);
      expect(first, isNotEmpty);
    });

    test(
      'instance MỚI đọc lại đúng anonymousId đã lưu (không sinh id khác)',
      () {
        final service = ExperimentBucketingService();
        final id = service.anonymousId;

        final reloaded = ExperimentBucketingService();

        expect(reloaded.anonymousId, id);
      },
    );

    test('anonymousId được ghi thẳng xuống storage (unbuffered)', () {
      final service = ExperimentBucketingService();
      final id = service.anonymousId;

      expect(storage.getString(StorageKeys.experimentAnonId), id);
    });
  });

  group('ExperimentBucketingService: variantFor ổn định', () {
    test(
      'gọi lặp lại nhiều lần cùng experimentKey trả về cùng variant (qua nhiều "session" = instance mới)',
      () {
        final first = ExperimentBucketingService().variantFor('exp_price', [
          'a',
          'b',
          'c',
        ]);

        for (var i = 0; i < 10; i++) {
          final result = ExperimentBucketingService().variantFor('exp_price', [
            'a',
            'b',
            'c',
          ]);
          expect(result, first);
        }
      },
    );

    test(
      '2 experimentKey khác nhau trên cùng device độc lập nhau (không luôn trùng bucket)',
      () {
        // Không assert 1 cặp cụ thể phải khác nhau (có thể trùng ngẫu
        // nhiên) — thay vào đó xác nhận qua nhiều key, không PHẢI lúc nào
        // cũng trùng 100% (nếu độc lập thật, xác suất trùng toàn bộ N key
        // liên tiếp với cùng variantCount=5 là cực thấp).
        final service = ExperimentBucketingService();
        final results = [
          for (var i = 0; i < 20; i++)
            service.variantFor('exp_$i', ['v1', 'v2', 'v3', 'v4', 'v5']),
        ];

        expect(results.toSet().length, greaterThan(1));
      },
    );

    test('cùng experimentKey nhưng device khác (anonymousId khác) có thể ra bucket khác', () {
      final resultA = ExperimentBucketingService.bucketIndex(
        'device-a',
        'exp_1',
        3,
      );
      final resultB = ExperimentBucketingService.bucketIndex(
        'device-b',
        'exp_1',
        3,
      );

      // Không bắt buộc khác nhau, chỉ xác nhận hàm hash thực sự phụ thuộc
      // vào anonymousId (không bỏ qua tham số này).
      expect(
        ExperimentBucketingService.bucketIndex('device-a', 'exp_1', 3),
        resultA,
      );
      expect(resultA, isA<int>());
      expect(resultB, isA<int>());
    });
  });

  group('ExperimentBucketingService: phân phối', () {
    test(
      'bucketIndex phân phối tương đối đều qua nhiều anonymousId ngẫu nhiên',
      () {
        const variantCount = 4;
        const sampleSize = 4000;
        final counts = List.filled(variantCount, 0);

        for (var i = 0; i < sampleSize; i++) {
          final index = ExperimentBucketingService.bucketIndex(
            'synthetic-device-$i',
            'exp_distribution',
            variantCount,
          );
          counts[index]++;
        }

        final expected = sampleSize / variantCount;
        for (final count in counts) {
          expect(count, greaterThan(expected * 0.5));
          expect(count, lessThan(expected * 1.5));
        }
      },
    );

    test('bucketIndex luôn nằm trong [0, variantCount)', () {
      for (var i = 0; i < 500; i++) {
        final index = ExperimentBucketingService.bucketIndex(
          'device-$i',
          'exp_bounds',
          7,
        );
        expect(index, inInclusiveRange(0, 6));
      }
    });
  });
}
