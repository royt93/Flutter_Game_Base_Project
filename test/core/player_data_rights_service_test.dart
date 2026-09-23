import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/player_data_rights_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

void main() {
  group('PlayerDataRightsService.requestExport', () {
    test(
      'trả đúng toàn bộ dữ liệu hiện có trong storage kèm metadata '
      '(exportedAtMs, schemaVersion)',
      () async {
        final storage = StorageService(null);
        await storage.setString('player_name', 'Roy');
        await storage.setInt('coins', 500);
        final service = PlayerDataRightsService(
          storage: storage,
          nowMs: () => 123456789,
        );

        final receipt = service.requestExport();

        expect(receipt.exportedAtMs, 123456789);
        expect(receipt.schemaVersion, 1);
        expect(receipt.data['player_name'], 'Roy');
        expect(receipt.data['coins'], 500);
      },
    );

    test('storage rỗng -> vẫn trả receipt hợp lệ, data rỗng, không throw', () {
      final storage = StorageService(null);
      final service = PlayerDataRightsService(storage: storage);

      final receipt = service.requestExport();

      expect(receipt.data, isEmpty);
      expect(receipt.exportedAtMs, greaterThan(0));
    });

    test('toJson() gộp đúng cả 3 field', () async {
      final storage = StorageService(null);
      final service = PlayerDataRightsService(
        storage: storage,
        nowMs: () => 999,
      );
      await storage.setInt('x', 1);

      final json = service.requestExport().toJson();

      expect(json['exportedAtMs'], 999);
      expect(json['schemaVersion'], 1);
      expect((json['data'] as Map)['x'], 1);
    });
  });

  group('PlayerDataRightsService.requestErasure', () {
    test('xoá đúng toàn bộ storage — đọc lại sau khi xoá phải rỗng', () async {
      final storage = StorageService(null);
      await storage.setString('a', '1');
      await storage.setString('b', '2');
      final service = PlayerDataRightsService(storage: storage);

      await service.requestErasure();

      expect(storage.exportAll(), isEmpty);
    });

    test(
      'receipt ghi đúng số key đã xoá (đếm TRƯỚC khi xoá, không phải sau)',
      () async {
        final storage = StorageService(null);
        await storage.setString('a', '1');
        await storage.setString('b', '2');
        await storage.setInt('c', 3);
        final service = PlayerDataRightsService(
          storage: storage,
          nowMs: () => 42,
        );

        final receipt = await service.requestErasure();

        expect(receipt.erasedKeyCount, 3);
        expect(receipt.completedAtMs, 42);
      },
    );

    test('storage rỗng -> erasedKeyCount=0, không throw', () async {
      final storage = StorageService(null);
      final service = PlayerDataRightsService(storage: storage);

      final receipt = await service.requestErasure();

      expect(receipt.erasedKeyCount, 0);
    });

    test(
      'registerErasureHook: mọi hook đã đăng ký đều được gọi, best-effort, '
      'ghi đúng kết quả true trong receipt',
      () async {
        final storage = StorageService(null);
        final service = PlayerDataRightsService(storage: storage);
        var analyticsHookCalled = false;
        var crashHookCalled = false;
        service.registerErasureHook('analytics', () async {
          analyticsHookCalled = true;
        });
        service.registerErasureHook('crashReporter', () async {
          crashHookCalled = true;
        });

        final receipt = await service.requestErasure();

        expect(analyticsHookCalled, isTrue);
        expect(crashHookCalled, isTrue);
        expect(receipt.hookResults, {'analytics': true, 'crashReporter': true});
      },
    );

    test(
      '1 hook throw -> không rethrow, ghi false trong receipt, KHÔNG chặn '
      'hook khác chạy, storage vẫn đã xoá xong TRƯỚC đó',
      () async {
        final storage = StorageService(null);
        await storage.setString('a', '1');
        final service = PlayerDataRightsService(storage: storage);
        var secondHookCalled = false;
        service.registerErasureHook('broken', () async {
          throw StateError('adapter lỗi');
        });
        service.registerErasureHook('ok', () async {
          secondHookCalled = true;
        });

        final receipt = await service.requestErasure();

        expect(receipt.hookResults['broken'], isFalse);
        expect(receipt.hookResults['ok'], isTrue);
        expect(secondHookCalled, isTrue);
        expect(storage.exportAll(), isEmpty);
      },
    );

    test('unregisterErasureHook -> hook không còn được gọi nữa', () async {
      final storage = StorageService(null);
      final service = PlayerDataRightsService(storage: storage);
      var called = false;
      service.registerErasureHook('temp', () async => called = true);
      service.unregisterErasureHook('temp');

      final receipt = await service.requestErasure();

      expect(called, isFalse);
      expect(receipt.hookResults, isEmpty);
    });

    test(
      'đăng ký lại cùng label -> thay thế hook cũ, không gọi cả 2',
      () async {
        final storage = StorageService(null);
        final service = PlayerDataRightsService(storage: storage);
        var oldCalled = false;
        var newCalled = false;
        service.registerErasureHook('x', () async => oldCalled = true);
        service.registerErasureHook('x', () async => newCalled = true);

        await service.requestErasure();

        expect(oldCalled, isFalse);
        expect(newCalled, isTrue);
      },
    );

    test('toJson() gộp đúng cả 3 field', () async {
      final storage = StorageService(null);
      await storage.setString('a', '1');
      final service = PlayerDataRightsService(
        storage: storage,
        nowMs: () => 777,
      );

      final json = (await service.requestErasure()).toJson();

      expect(json['completedAtMs'], 777);
      expect(json['erasedKeyCount'], 1);
      expect(json['hookResults'], isEmpty);
    });
  });
}
