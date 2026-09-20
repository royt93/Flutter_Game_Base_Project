import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/onboarding_coordinator_service.dart';
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

  group('Slice 1: isFlowSeen/markFlowSeen cơ bản', () {
    test(
      'chưa markFlowSeen: isFlowSeen trả về false, không throw kể cả chưa registerFlow',
      () {
        final service = OnboardingCoordinatorService();
        expect(service.isFlowSeen('intro'), isFalse);
      },
    );

    test('markFlowSeen rồi isFlowSeen trả về true', () {
      final service = OnboardingCoordinatorService();
      service.markFlowSeen('intro');
      expect(service.isFlowSeen('intro'), isTrue);
    });

    test('2 flowId độc lập nhau', () {
      final service = OnboardingCoordinatorService();
      service.markFlowSeen('intro');
      expect(service.isFlowSeen('intro'), isTrue);
      expect(service.isFlowSeen('shop_tip'), isFalse);
    });

    test('flowId/version rỗng hoặc <= 0 throw ArgumentError', () {
      final service = OnboardingCoordinatorService();
      expect(() => service.isFlowSeen(''), throwsArgumentError);
      expect(() => service.isFlowSeen('   '), throwsArgumentError);
      expect(() => service.markFlowSeen(''), throwsArgumentError);
      expect(
        () => service.markFlowSeen('intro', version: 0),
        throwsArgumentError,
      );
      expect(
        () => service.markFlowSeen('intro', version: -1),
        throwsArgumentError,
      );
      expect(() => service.registerFlow(''), throwsArgumentError);
      expect(
        () => service.registerFlow('intro', version: 0),
        throwsArgumentError,
      );
    });

    test(
      'bump version cho 1 flowId đã seen ở version cũ → isFlowSeen(version mới) false đúng 1 lần, không ảnh hưởng flowId khác',
      () {
        final service = OnboardingCoordinatorService();
        service.markFlowSeen('intro', version: 1);
        service.markFlowSeen('shop_tip', version: 1);

        expect(service.isFlowSeen('intro', version: 2), isFalse);
        expect(
          service.isFlowSeen('shop_tip', version: 1),
          isTrue,
        ); // không bị ảnh hưởng

        service.markFlowSeen('intro', version: 2);
        expect(service.isFlowSeen('intro', version: 2), isTrue);
      },
    );

    test(
      'markFlowSeen với version thấp hơn version đã ghi nhận: không "un-seen" (monotonic)',
      () {
        final service = OnboardingCoordinatorService();
        service.markFlowSeen('intro', version: 3);
        service.markFlowSeen(
          'intro',
          version: 1,
        ); // cố tình gọi lại version cũ hơn

        expect(
          service.isFlowSeen('intro', version: 3),
          isTrue,
        ); // vẫn giữ nguyên mốc cao nhất
      },
    );

    test('persist qua "restart" (instance mới đọc lại đúng)', () async {
      final service = OnboardingCoordinatorService();
      service.markFlowSeen('intro', version: 2);
      await service.debugPendingSaves;

      final restarted = OnboardingCoordinatorService();
      expect(restarted.isFlowSeen('intro', version: 2), isTrue);
      expect(restarted.isFlowSeen('intro', version: 3), isFalse);
    });
  });

  group('Slice 2: nextEligibleFlow — eligibility & priority', () {
    test('chưa registerFlow gì: nextEligibleFlow trả về null', () {
      final service = OnboardingCoordinatorService();
      expect(service.nextEligibleFlow(), isNull);
    });

    test('1 flow registered, chưa seen: trả về đúng flow đó', () {
      final service = OnboardingCoordinatorService();
      service.registerFlow('intro');
      expect(service.nextEligibleFlow(), 'intro');
    });

    test('1 flow registered, đã seen: trả về null', () {
      final service = OnboardingCoordinatorService();
      service.registerFlow('intro');
      service.markFlowSeen('intro');
      expect(service.nextEligibleFlow(), isNull);
    });

    test('nhiều flow: priority cao hơn trả về trước', () {
      final service = OnboardingCoordinatorService();
      service.registerFlow('shop_tip', priority: 0);
      service.registerFlow('intro', priority: 10);
      expect(service.nextEligibleFlow(), 'intro');
    });

    test(
      'cùng priority: theo đúng thứ tự registerFlow được gọi (đăng ký trước chạy trước)',
      () {
        final service = OnboardingCoordinatorService();
        service.registerFlow('first', priority: 5);
        service.registerFlow('second', priority: 5);
        service.registerFlow('third', priority: 5);
        expect(service.nextEligibleFlow(), 'first');
      },
    );

    test(
      'sau khi markFlowSeen 1 flow, gọi lại nextEligibleFlow không trả về chính flow đó nữa, chuyển sang flow tiếp theo',
      () {
        final service = OnboardingCoordinatorService();
        service.registerFlow('intro', priority: 10);
        service.registerFlow('shop_tip', priority: 0);

        expect(service.nextEligibleFlow(), 'intro');
        service.markFlowSeen('intro');
        expect(service.nextEligibleFlow(), 'shop_tip');
        service.markFlowSeen('shop_tip');
        expect(service.nextEligibleFlow(), isNull);
      },
    );

    test(
      'registerFlow lại cùng flowId (re-declare mỗi boot): cập nhật priority/version, không tự reset seen state',
      () {
        final service = OnboardingCoordinatorService();
        service.registerFlow('intro', priority: 0);
        service.markFlowSeen('intro');
        expect(service.nextEligibleFlow(), isNull);

        // Re-declare lại đúng flowId (mô phỏng app khởi động lại, gọi lại
        // registerFlow ở đầu vòng đời) — không được tự làm flow "hiện lại".
        service.registerFlow('intro', priority: 100);
        expect(service.nextEligibleFlow(), isNull);
      },
    );

    test(
      'bump version qua registerFlow: flow đã seen ở version cũ trở thành eligible lại đúng 1 lần',
      () {
        final service = OnboardingCoordinatorService();
        service.registerFlow('intro', version: 1);
        service.markFlowSeen('intro', version: 1);
        expect(service.nextEligibleFlow(), isNull);

        service.registerFlow('intro', version: 2);
        expect(service.nextEligibleFlow(), 'intro');

        service.markFlowSeen('intro', version: 2);
        expect(service.nextEligibleFlow(), isNull);
      },
    );
  });

  group('Slice 3: migration & corrupt-data hardening', () {
    test(
      'JSON hỏng (field sai kiểu, key rỗng, giá trị âm) bị lọc bỏ an toàn, không throw',
      () async {
        await storage.setString(
          'onboarding_seen_v1',
          '{"intro": 2, "": 1, "bad": "not an int", "negative": -1, "schemaVersion": 1}',
        );
        final service = OnboardingCoordinatorService();

        expect(() => service.isFlowSeen('intro'), returnsNormally);
        expect(service.isFlowSeen('intro', version: 2), isTrue);
        expect(service.isFlowSeen('bad'), isFalse);
        expect(service.isFlowSeen('negative'), isFalse);
      },
    );

    test(
      'JSON hoàn toàn hỏng (không phải object hợp lệ): rơi về "chưa flow nào từng thấy" an toàn',
      () async {
        await storage.setString('onboarding_seen_v1', 'not even json{{{');
        final service = OnboardingCoordinatorService();

        expect(() => service.isFlowSeen('intro'), returnsNormally);
        expect(service.isFlowSeen('intro'), isFalse);
        expect(() => service.markFlowSeen('intro'), returnsNormally);
      },
    );

    test(
      'nhiều markFlowSeen liên tiếp không await giữa các lần cho nhiều flowId khác nhau vẫn persist đúng toàn bộ qua "restart"',
      () async {
        final service = OnboardingCoordinatorService();

        service.markFlowSeen('a');
        service.markFlowSeen('b', version: 2);
        service.markFlowSeen('c');

        await service.debugPendingSaves;

        final restarted = OnboardingCoordinatorService();
        expect(restarted.isFlowSeen('a'), isTrue);
        expect(restarted.isFlowSeen('b', version: 2), isTrue);
        expect(restarted.isFlowSeen('c'), isTrue);
      },
    );
  });

  group('ENH-71: storageKey tuỳ chỉnh', () {
    test(
      'không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ',
      () async {
        final service = OnboardingCoordinatorService();
        service.markFlowSeen('intro');
        await service.debugPendingSaves;

        expect(storage.getString('onboarding_seen_v1'), isNotNull);
      },
    );

    test(
      '2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau',
      () async {
        final a = OnboardingCoordinatorService(storageKey: 'onboard_a');
        final b = OnboardingCoordinatorService(storageKey: 'onboard_b');

        a.markFlowSeen('intro');
        await a.debugPendingSaves;
        await b.debugPendingSaves;

        expect(a.isFlowSeen('intro'), isTrue);
        expect(b.isFlowSeen('intro'), isFalse);
      },
    );

    test(
      'storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới đọc lại đúng)',
      () async {
        final service = OnboardingCoordinatorService(
          storageKey: 'onboard_custom',
        );
        service.markFlowSeen('intro');
        await service.debugPendingSaves;

        final restarted = OnboardingCoordinatorService(
          storageKey: 'onboard_custom',
        );
        expect(restarted.isFlowSeen('intro'), isTrue);
      },
    );

    test(
      'không đổi hành vi markFlowSeen/isFlowSeen/nextEligibleFlow hiện có khi dùng storageKey tuỳ chỉnh',
      () {
        final service = OnboardingCoordinatorService(storageKey: 'k');
        service.registerFlow('intro');
        expect(service.nextEligibleFlow(), 'intro');

        service.markFlowSeen('intro');
        expect(service.isFlowSeen('intro'), isTrue);
        expect(service.nextEligibleFlow(), isNull);
      },
    );
  });
}
