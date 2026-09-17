import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
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

  group('PurchaseLedgerService: consumable validation', () {
    test('grantConsumable với sku rỗng/blank throw ArgumentError', () {
      final service = PurchaseLedgerService();

      expect(() => service.grantConsumable('', 1), throwsArgumentError);
      expect(() => service.grantConsumable('   ', 1), throwsArgumentError);
    });

    test('grantConsumable với amount <= 0 throw ArgumentError', () {
      final service = PurchaseLedgerService();

      expect(() => service.grantConsumable('hints', 0), throwsArgumentError);
      expect(() => service.grantConsumable('hints', -1), throwsArgumentError);
    });

    test('consume với sku rỗng/amount <= 0 throw ArgumentError', () {
      final service = PurchaseLedgerService();

      expect(() => service.consume('', 1), throwsArgumentError);
      expect(() => service.consume('hints', 0), throwsArgumentError);
      expect(() => service.consume('hints', -1), throwsArgumentError);
    });
  });

  group('PurchaseLedgerService: consumable balance', () {
    test('balanceOf trả về 0 cho sku chưa từng grant, không throw', () {
      final service = PurchaseLedgerService();

      expect(() => service.balanceOf('unknown'), returnsNormally);
      expect(service.balanceOf('unknown'), 0);
    });

    test('grantConsumable cộng dồn đúng qua nhiều lần gọi', () {
      final service = PurchaseLedgerService();

      service.grantConsumable('hints', 3);
      service.grantConsumable('hints', 2);

      expect(service.balanceOf('hints'), 5);
    });

    test('consume đủ số dư trừ đúng và trả về true', () {
      final service = PurchaseLedgerService();
      service.grantConsumable('hints', 5);

      final result = service.consume('hints', 3);

      expect(result, isTrue);
      expect(service.balanceOf('hints'), 2);
    });

    test('consume đúng bằng toàn bộ số dư về 0 vẫn hợp lệ', () {
      final service = PurchaseLedgerService();
      service.grantConsumable('hints', 5);

      expect(service.consume('hints', 5), isTrue);
      expect(service.balanceOf('hints'), 0);
    });

    test(
      'consume vượt quá số dư hiện có bị từ chối (false), số dư KHÔNG đổi — không bao giờ âm',
      () {
        final service = PurchaseLedgerService();
        service.grantConsumable('hints', 3);

        final result = service.consume('hints', 4);

        expect(result, isFalse);
        expect(service.balanceOf('hints'), 3);
      },
    );

    test('consume trên sku chưa từng grant (số dư 0) bị từ chối, không throw', () {
      final service = PurchaseLedgerService();

      expect(service.consume('never_granted', 1), isFalse);
      expect(service.balanceOf('never_granted'), 0);
    });

    test('nhiều sku consumable độc lập nhau', () {
      final service = PurchaseLedgerService();
      service.grantConsumable('hints', 5);
      service.grantConsumable('lives', 2);

      service.consume('hints', 5);

      expect(service.balanceOf('hints'), 0);
      expect(service.balanceOf('lives'), 2);
    });
  });

  group('PurchaseLedgerService: permanent', () {
    test('grantPermanent với sku rỗng/blank throw ArgumentError', () {
      final service = PurchaseLedgerService();

      expect(() => service.grantPermanent(''), throwsArgumentError);
      expect(() => service.grantPermanent('   '), throwsArgumentError);
    });

    test('owns() trả về false cho sku chưa từng grant, không throw', () {
      final service = PurchaseLedgerService();

      expect(() => service.owns('unknown'), returnsNormally);
      expect(service.owns('unknown'), isFalse);
    });

    test('grantPermanent rồi owns() trả về true', () {
      final service = PurchaseLedgerService();

      service.grantPermanent('remove_ads');

      expect(service.owns('remove_ads'), isTrue);
    });

    test('grantPermanent gọi lại nhiều lần vẫn idempotent, không lỗi', () {
      final service = PurchaseLedgerService();

      service.grantPermanent('remove_ads');
      expect(() => service.grantPermanent('remove_ads'), returnsNormally);

      expect(service.owns('remove_ads'), isTrue);
    });
  });

  group('PurchaseLedgerService: persist/corrupt', () {
    test(
      'grantPermanent + owns() bền vững qua "restart" (instance mới đọc lại đúng)',
      () async {
        final service = PurchaseLedgerService();
        service.grantPermanent('remove_ads');
        service.grantConsumable('hints', 7);

        await service.debugPendingSaves;

        final reloaded = PurchaseLedgerService();
        expect(reloaded.owns('remove_ads'), isTrue);
        expect(reloaded.balanceOf('hints'), 7);
      },
    );

    test('drops corrupt entries instead of crashing hydration', () async {
      await storage.setString(
        'purchase_ledger_v1',
        '{"consumables":{"good":3,"negative":-1,"wrongType":"3","":9},'
        '"permanents":["good_perm","",42],'
        '"schemaVersion":1}',
      );
      final service = PurchaseLedgerService();

      expect(service.balanceOf('good'), 3);
      expect(service.balanceOf('negative'), 0);
      expect(service.balanceOf('wrongType'), 0);
      expect(service.owns('good_perm'), isTrue);
    });

    test(
      'burst nhiều grantConsumable/consume liên tiếp không await giữa các lần vẫn ghi đúng xuống disk',
      () async {
        final service = PurchaseLedgerService();

        for (var i = 0; i < 10; i++) {
          service.grantConsumable('gems', 1);
        }
        service.consume('gems', 4);

        await service.debugPendingSaves;

        final reloaded = PurchaseLedgerService();
        expect(reloaded.balanceOf('gems'), 6);
      },
    );
  });

  group('IDEA-50: revokePermanent/revokeConsumable', () {
    test('revokePermanent gỡ đúng quyền sở hữu, owns() trả về false sau đó', () {
      final service = PurchaseLedgerService();
      service.grantPermanent('remove_ads');
      expect(service.owns('remove_ads'), isTrue);

      service.revokePermanent('remove_ads');

      expect(service.owns('remove_ads'), isFalse);
    });

    test('revokePermanent với sku chưa từng sở hữu: no-op, không throw', () {
      final service = PurchaseLedgerService();
      expect(() => service.revokePermanent('never_granted'), returnsNormally);
      expect(service.owns('never_granted'), isFalse);
    });

    test('revokeConsumable trừ đúng số dư khi đủ', () {
      final service = PurchaseLedgerService();
      service.grantConsumable('gems', 10);

      service.revokeConsumable('gems', 4);

      expect(service.balanceOf('gems'), 6);
    });

    test('revokeConsumable với amount lớn hơn số dư hiện có: clamp về 0, không throw', () {
      final service = PurchaseLedgerService();
      service.grantConsumable('gems', 3);

      expect(() => service.revokeConsumable('gems', 100), returnsNormally);

      expect(service.balanceOf('gems'), 0);
    });

    test('revokeConsumable trên sku chưa từng grant: clamp về 0, không throw', () {
      final service = PurchaseLedgerService();
      expect(() => service.revokeConsumable('never_granted', 5), returnsNormally);
      expect(service.balanceOf('never_granted'), 0);
    });

    test('revokePermanent/revokeConsumable với sku rỗng/blank throw ArgumentError', () {
      final service = PurchaseLedgerService();
      expect(() => service.revokePermanent(''), throwsArgumentError);
      expect(() => service.revokePermanent('   '), throwsArgumentError);
      expect(() => service.revokeConsumable('', 1), throwsArgumentError);
      expect(() => service.revokeConsumable('   ', 1), throwsArgumentError);
    });

    test('revokeConsumable với amount <= 0 throw ArgumentError', () {
      final service = PurchaseLedgerService();
      expect(() => service.revokeConsumable('gems', 0), throwsArgumentError);
      expect(() => service.revokeConsumable('gems', -1), throwsArgumentError);
    });

    test(
      'revokePermanent/revokeConsumable bền vững qua "restart" (instance mới đọc lại đúng)',
      () async {
        final service = PurchaseLedgerService();
        service.grantPermanent('remove_ads');
        service.grantConsumable('gems', 10);
        await service.debugPendingSaves;

        service.revokePermanent('remove_ads');
        service.revokeConsumable('gems', 4);
        await service.debugPendingSaves;

        final reloaded = PurchaseLedgerService();
        expect(reloaded.owns('remove_ads'), isFalse);
        expect(reloaded.balanceOf('gems'), 6);
      },
    );

    group('ENH-71: storageKey tuỳ chỉnh', () {
      test('không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ', () async {
        final service = PurchaseLedgerService();
        service.grantConsumable('gems', 10);
        await service.debugPendingSaves;

        expect(storage.getString('purchase_ledger_v1'), isNotNull);
      });

      test('2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau', () async {
        final a = PurchaseLedgerService(storageKey: 'ledger_a');
        final b = PurchaseLedgerService(storageKey: 'ledger_b');

        a.grantConsumable('gems', 10);
        b.grantConsumable('gems', 20);
        await a.debugPendingSaves;
        await b.debugPendingSaves;

        expect(a.balanceOf('gems'), 10);
        expect(b.balanceOf('gems'), 20);
      });

      test('storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới đọc lại đúng)', () async {
        final service = PurchaseLedgerService(storageKey: 'ledger_custom');
        service.grantPermanent('remove_ads');
        await service.debugPendingSaves;

        final restarted = PurchaseLedgerService(storageKey: 'ledger_custom');
        expect(restarted.owns('remove_ads'), isTrue);
      });

      test('không đổi hành vi grantConsumable/consume/grantPermanent/owns hiện có khi dùng storageKey tuỳ chỉnh', () {
        final service = PurchaseLedgerService(storageKey: 'k');
        service.grantConsumable('gems', 10);
        expect(service.consume('gems', 4), isTrue);
        expect(service.balanceOf('gems'), 6);

        service.grantPermanent('remove_ads');
        expect(service.owns('remove_ads'), isTrue);
      });
    });
  });
}
