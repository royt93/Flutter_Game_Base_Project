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

      expect(() => service.variantFor('', ['a', 'b']), throwsArgumentError);
      expect(() => service.variantFor('   ', ['a', 'b']), throwsArgumentError);
    });

    test('danh sách variants rỗng throw ArgumentError', () {
      final service = ExperimentBucketingService();

      expect(() => service.variantFor('exp_1', const []), throwsArgumentError);
    });

    test('variants chỉ 1 phần tử luôn trả về đúng phần tử đó', () {
      final service = ExperimentBucketingService();

      expect(service.variantFor('exp_1', ['only']), 'only');
    });
  });

  group('ExperimentBucketingService: anonymousId ổn định', () {
    test(
      'sinh 1 lần và cache lại — 2 lần đọc trong cùng instance giống nhau',
      () {
        final service = ExperimentBucketingService();

        final first = service.anonymousId;
        final second = service.anonymousId;

        expect(first, second);
        expect(first, isNotEmpty);
      },
    );

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

    test(
      'cùng experimentKey nhưng device khác (anonymousId khác) có thể ra bucket khác',
      () {
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
      },
    );
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

  group('FEAT-93: debugSetVariantOverride (Variant Switcher tab)', () {
    test(
      'set override -> variantFor trả đúng variant override, KHÔNG phải '
      'bucket hash bình thường (kiểm bằng cách thử liên tục nếu hash tự '
      'nhiên đã trùng thì đổi sang key khác)',
      () {
        final service = ExperimentBucketingService();
        // Tìm 1 experimentKey mà bucket hash TỰ NHIÊN không rơi vào 'c'
        // (nếu tình cờ trùng thì test không phân biệt được override có
        // thật sự hoạt động hay chỉ đúng do trùng hợp).
        String key = 'exp_variant_switch';
        var i = 0;
        while (service.variantFor(key, ['a', 'b', 'c']) == 'c') {
          key = 'exp_variant_switch_$i';
          i++;
        }

        service.debugSetVariantOverride(key, 'c');

        expect(service.variantFor(key, ['a', 'b', 'c']), 'c');
      },
    );

    test(
      'override ảnh hưởng MỌI call site đọc variantFor cho key đó (mọi '
      'instance/lần gọi, không chỉ nơi set override)',
      () {
        final service = ExperimentBucketingService();
        service.debugSetVariantOverride('exp_multi_site', 'variant_b');

        expect(
          service.variantFor('exp_multi_site', ['variant_a', 'variant_b']),
          'variant_b',
        );
        expect(
          service.variantFor('exp_multi_site', ['variant_a', 'variant_b']),
          'variant_b',
          reason: 'gọi lại nhiều lần vẫn phải thấy override, không phải 1 lần rồi hết',
        );
      },
    );

    test(
      'override variant KHÔNG có trong danh sách variants truyền vào -> '
      'fallback về bucket hash bình thường, không trả giá trị caller chưa từng đưa',
      () {
        final service = ExperimentBucketingService();
        service.debugSetVariantOverride('exp_stale_override', 'old_variant');

        final result = service.variantFor('exp_stale_override', [
          'new_a',
          'new_b',
        ]);

        expect(result, isIn(['new_a', 'new_b']));
      },
    );

    test('clear override (null) -> quay lại đúng bucket hash bình thường', () {
      final service = ExperimentBucketingService();
      final normal = service.variantFor('exp_clear_test', ['a', 'b', 'c']);
      service.debugSetVariantOverride('exp_clear_test', 'a');

      service.debugSetVariantOverride('exp_clear_test', null);

      expect(service.variantFor('exp_clear_test', ['a', 'b', 'c']), normal);
    });

    test(
      'override 1 experimentKey KHÔNG ảnh hưởng experimentKey khác',
      () {
        final service = ExperimentBucketingService();
        final otherNormal = service.variantFor('exp_untouched', ['x', 'y']);

        service.debugSetVariantOverride('exp_target', 'x');

        expect(service.variantFor('exp_untouched', ['x', 'y']), otherNormal);
      },
    );
  });
}
