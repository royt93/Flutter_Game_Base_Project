import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('ConsentStateService: accessor', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(ConsentStateService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = ConsentStateService(policyVersion: 1);
      Get.put(service, permanent: true);
      expect(ConsentStateService.maybe, same(service));
    });
  });

  group('ConsentStateService: default-deny khi chưa quyết định', () {
    test('category chưa từng grant/deny: status unknown, isGranted false', () {
      final service = ConsentStateService(policyVersion: 1);
      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.unknown);
      expect(service.isGranted(ConsentCategory.analytics), isFalse);
    });
  });

  group('ConsentStateService: grant/deny/reset commands', () {
    test('grant(): status granted, isGranted true', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);

      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.granted);
      expect(service.isGranted(ConsentCategory.analytics), isTrue);
    });

    test('deny(): status denied, isGranted false', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);
      service.deny(ConsentCategory.analytics);

      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.denied);
      expect(service.isGranted(ConsentCategory.analytics), isFalse);
    });

    test('reset(): quay lại unknown', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);
      service.reset(ConsentCategory.analytics);

      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.unknown);
    });

    test('2 category độc lập nhau, không đụng lẫn nhau', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);
      service.deny(ConsentCategory.personalization);

      expect(service.isGranted(ConsentCategory.analytics), isTrue);
      expect(service.isGranted(ConsentCategory.personalization), isFalse);
    });

    test('revoke có hiệu lực tức thì trong cùng instance (không cần đọc lại)', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);
      expect(service.isGranted(ConsentCategory.analytics), isTrue);

      service.deny(ConsentCategory.analytics);
      expect(
        service.isGranted(ConsentCategory.analytics),
        isFalse,
        reason: 'revoke phải có hiệu lực ngay, không cần chờ gì thêm',
      );
    });

    test('grant rồi deny liên tiếp (đồng bộ): kết quả cuối cùng là denied', () {
      final service = ConsentStateService(policyVersion: 1);
      service.grant(ConsentCategory.analytics);
      service.deny(ConsentCategory.analytics);
      service.grant(ConsentCategory.analytics);
      service.deny(ConsentCategory.analytics);

      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.denied);
    });
  });

  group('ConsentStateService: policy version bump bắt review lại', () {
    test('bump policyVersion: category đã granted ở version cũ trở về unknown', () {
      final v1 = ConsentStateService(policyVersion: 1);
      v1.grant(ConsentCategory.analytics);
      expect(v1.isGranted(ConsentCategory.analytics), isTrue);

      // Version mới hơn — mô phỏng app update policy, dùng LẠI cùng
      // storage (persist qua "restart" với version mới).
      final v2 = ConsentStateService(policyVersion: 2);
      expect(
        v2.statusOf(ConsentCategory.analytics),
        ConsentStatus.unknown,
        reason: 'policy version tăng phải bắt review lại, không giữ granted cũ',
      );
      expect(v2.isGranted(ConsentCategory.analytics), isFalse);
    });

    test('grant lại sau khi bump version: ổn định, không bị coi stale nữa', () {
      final v1 = ConsentStateService(policyVersion: 1);
      v1.grant(ConsentCategory.analytics);

      final v2 = ConsentStateService(policyVersion: 2);
      v2.grant(ConsentCategory.analytics);

      // Đọc lại lần nữa (instance mới, vẫn version 2) — phải vẫn granted,
      // không bị coi là stale nữa vì đã ghi đúng policyVersion mới.
      final v2Again = ConsentStateService(policyVersion: 2);
      expect(v2Again.isGranted(ConsentCategory.analytics), isTrue);
    });

    test('cùng policyVersion (không bump): granted cũ vẫn giữ nguyên qua "restart"', () {
      final v1 = ConsentStateService(policyVersion: 1);
      v1.grant(ConsentCategory.analytics);

      final v1Again = ConsentStateService(policyVersion: 1);
      expect(v1Again.isGranted(ConsentCategory.analytics), isTrue);
    });
  });

  group('ConsentStateService: sống qua "restart" app', () {
    test('instance mới đọc từ cùng SharedPreferences vẫn thấy đúng state', () {
      final service1 = ConsentStateService(policyVersion: 1);
      service1.deny(ConsentCategory.personalization);

      final service2 = ConsentStateService(policyVersion: 1);
      expect(service2.statusOf(ConsentCategory.personalization), ConsentStatus.denied);
    });
  });

  group('ConsentStateService: corrupt save không biến thành granted', () {
    test('JSON hỏng hoàn toàn ở top-level: mọi category coi như unknown, không crash', () async {
      await store.setString(StorageKeys.consentStateV1, 'not valid json {{{');
      final service = ConsentStateService(policyVersion: 1);

      expect(service.statusOf(ConsentCategory.analytics), ConsentStatus.unknown);
      expect(() => service.grant(ConsentCategory.analytics), returnsNormally);
    });

    test('1 entry sai kiểu/giá trị status lạ: coi như unknown, không phải granted', () async {
      await store.setString(
        StorageKeys.consentStateV1,
        '{"analytics":{"status":"totally_granted_trust_me","source":"user","policyVersion":1,"updatedAtMs":0}}',
      );
      final service = ConsentStateService(policyVersion: 1);

      expect(
        service.statusOf(ConsentCategory.analytics),
        ConsentStatus.unknown,
        reason: 'giá trị status không khớp enum hợp lệ nào tuyệt đối không được coi là granted',
      );
    });
  });

  group('ConsentStateService: reactive revision', () {
    test('revision tăng đúng lúc grant/deny/reset', () {
      final service = ConsentStateService(policyVersion: 1);
      final before = service.revision.value;

      service.grant(ConsentCategory.analytics);
      expect(service.revision.value, greaterThan(before));

      final afterGrant = service.revision.value;
      service.deny(ConsentCategory.analytics);
      expect(service.revision.value, greaterThan(afterGrant));

      final afterDeny = service.revision.value;
      service.reset(ConsentCategory.analytics);
      expect(service.revision.value, greaterThan(afterDeny));
    });
  });
}
