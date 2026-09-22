import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/disaster_recovery_save_export.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subclass that throws on [importWithPrefix] for a chosen prefix — the
/// only way to genuinely test "a restore that fails mid-way" without a
/// real crash.
class _ThrowingStorageService extends StorageService {
  _ThrowingStorageService(super.prefs, this.failingPrefix);

  final String failingPrefix;

  @override
  Future<void> importWithPrefix(String prefix, Map<String, Object?> data) {
    if (prefix == failingPrefix) {
      throw Exception('simulated crash mid-restore');
    }
    return super.importWithPrefix(prefix, data);
  }
}

void main() {
  tearDown(Get.reset);

  late StorageService storage;
  late SaveSlotManager slotManager;

  Future<void> boot({StorageService Function(SharedPreferences)? build}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = build != null ? build(prefs) : StorageService(prefs);
    Get.put(storage, permanent: true);
    slotManager = SaveSlotManager();
  }

  group('buildExport', () {
    test('slotId không tồn tại -> SdkFailure validation', () async {
      await boot();
      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );

      final result = export.buildExport(
        slotIds: ['slot_999'],
        appVersion: '1.0',
      );

      expect(result, isA<SdkFailure<Map<String, Object?>>>());
      expect((result as SdkFailure).kind, SdkErrorKind.validation);
    });

    test('export đúng slot đã tạo, đúng dữ liệu key/value bên trong', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      await storage.setString(slotManager.keyFor(slot.id, 'coins'), '100');

      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final result = export.buildExport(slotIds: [slot.id], appVersion: '1.0');

      expect(result, isA<SdkSuccess<Map<String, Object?>>>());
      final bundle = (result as SdkSuccess).value;
      final slots = bundle['slots'] as List;
      expect(slots, hasLength(1));
      final data = (slots.single as Map)['data'] as Map;
      expect(data[slotManager.keyFor(slot.id, 'coins')], '100');
    });

    test(
      'vượt maxBytes -> SdkFailure validation, không export 1 phần',
      () async {
        await boot();
        final slot = slotManager.createSlot('Alice');
        await storage.setString(
          slotManager.keyFor(slot.id, 'blob'),
          'x' * 1000,
        );

        final export = DisasterRecoverySaveExport(
          storage: storage,
          slotManager: slotManager,
          maxBytes: 50,
        );
        final result = export.buildExport(
          slotIds: [slot.id],
          appVersion: '1.0',
        );

        expect(result, isA<SdkFailure<Map<String, Object?>>>());
        expect((result as SdkFailure).kind, SdkErrorKind.validation);
      },
    );
  });

  group('sign + previewRestore: round trip và validate không mutate storage', () {
    test('round trip đúng: sign rồi preview lại ra đúng slot/meta', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      await storage.setString(slotManager.keyFor(slot.id, 'coins'), '100');

      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                  as SdkSuccess)
              .value;
      final signed = export.sign(built, 'secret');

      final preview = export.previewRestore(signed, 'secret');
      expect(preview, isA<SdkSuccess<RestorePreview>>());
      final entries = (preview as SdkSuccess).value.entries;
      expect(entries, hasLength(1));
      expect(entries.single.meta.displayName, 'Alice');
    });

    test('sai secret -> SdkFailure validation, không throw ra ngoài', () async {
      await boot();
      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [], appVersion: '1.0') as SdkSuccess)
              .value;
      final signed = export.sign(built, 'right-secret');

      final result = export.previewRestore(signed, 'wrong-secret');
      expect(result, isA<SdkFailure<RestorePreview>>());
      expect((result as SdkFailure).kind, SdkErrorKind.validation);
    });

    test(
      'bundle bị tamper sau khi ký -> SdkFailure validation (checksum sai)',
      () async {
        await boot();
        final slot = slotManager.createSlot('Alice');
        final export = DisasterRecoverySaveExport(
          storage: storage,
          slotManager: slotManager,
        );
        final built =
            (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                    as SdkSuccess)
                .value;
        final signed = Map<String, Object?>.from(export.sign(built, 'secret'));
        signed['appVersion'] = '9.9.9-tampered';

        final result = export.previewRestore(signed, 'secret');
        expect(result, isA<SdkFailure<RestorePreview>>());
      },
    );

    test(
      'schemaVersion tương lai (chưa hỗ trợ) -> SdkFailure validation',
      () async {
        await boot();
        final export = DisasterRecoverySaveExport(
          storage: storage,
          slotManager: slotManager,
        );
        final built = Map<String, Object?>.from(
          (export.buildExport(slotIds: [], appVersion: '1.0') as SdkSuccess)
              .value,
        );
        built['schemaVersion'] = 999;
        final signed = export.sign(built, 'secret');

        final result = export.previewRestore(signed, 'secret');
        expect(result, isA<SdkFailure<RestorePreview>>());
      },
    );

    test('"slots" thiếu hoặc sai type -> SdkFailure validation', () async {
      await boot();
      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built = Map<String, Object?>.from(
        (export.buildExport(slotIds: [], appVersion: '1.0') as SdkSuccess)
            .value,
      );
      built['slots'] = 'not a list';
      final signed = export.sign(built, 'secret');

      final result = export.previewRestore(signed, 'secret');
      expect(result, isA<SdkFailure<RestorePreview>>());
    });

    test(
      'PHÁT HIỆN THẬT: previewRestore KHÔNG mutate storage dù dữ liệu preview trùng slot đang tồn tại',
      () async {
        await boot();
        final slot = slotManager.createSlot('Alice');
        await storage.setString(slotManager.keyFor(slot.id, 'coins'), '100');

        final export = DisasterRecoverySaveExport(
          storage: storage,
          slotManager: slotManager,
        );
        final built =
            (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                    as SdkSuccess)
                .value;
        final signed = export.sign(built, 'secret');

        // Đổi coins thành giá trị KHÁC sau khi export, rồi preview lại
        // đúng export cũ (chứa coins=100) — preview không được đụng gì.
        await storage.setString(slotManager.keyFor(slot.id, 'coins'), '999');
        final before = storage.exportAll();

        export.previewRestore(signed, 'secret');

        expect(storage.exportAll(), before);
        expect(storage.getString(slotManager.keyFor(slot.id, 'coins')), '999');
      },
    );
  });

  group('applyRestore: happy path', () {
    test('restore đúng dữ liệu về local storage', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      await storage.setString(slotManager.keyFor(slot.id, 'coins'), '100');

      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                  as SdkSuccess)
              .value;
      final signed = export.sign(built, 'secret');

      // Mô phỏng mất dữ liệu cục bộ.
      await storage.setString(slotManager.keyFor(slot.id, 'coins'), '0');

      final preview =
          (export.previewRestore(signed, 'secret') as SdkSuccess).value;
      final result = await export.applyRestore(preview);

      expect(result, isA<SdkSuccess<void>>());
      expect(storage.getString(slotManager.keyFor(slot.id, 'coins')), '100');
    });

    test('ghi đúng recoveryLog khi thành công', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                  as SdkSuccess)
              .value;
      final preview =
          (export.previewRestore(export.sign(built, 's'), 's') as SdkSuccess)
              .value;

      await export.applyRestore(preview);

      expect(export.recoveryLog, hasLength(1));
      expect(export.recoveryLog.single.succeeded, isTrue);
      expect(export.recoveryLog.single.slotId, slot.id);
    });
  });

  group('PHÁT HIỆN THẬT: crash giữa restore đa-slot giữ last-known-good', () {
    test(
      'slot A restore thành công, slot B throw giữa chừng -> A vẫn giữ dữ liệu mới, '
      'B giữ nguyên dữ liệu CŨ (không ghi dở dang), recoveryLog ghi đủ cả 2',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final slotManagerStorage = StorageService(prefs);
        Get.put(slotManagerStorage, permanent: true);
        final manager = SaveSlotManager();
        final slotA = manager.createSlot('Alice');
        final slotB = manager.createSlot('Bob');
        await slotManagerStorage.setString(
          manager.keyFor(slotA.id, 'coins'),
          '111',
        );
        await slotManagerStorage.setString(
          manager.keyFor(slotB.id, 'coins'),
          '222',
        );

        final exportBuilder = DisasterRecoverySaveExport(
          storage: slotManagerStorage,
          slotManager: manager,
        );
        final built =
            (exportBuilder.buildExport(
                      slotIds: [slotA.id, slotB.id],
                      appVersion: '1.0',
                    )
                    as SdkSuccess)
                .value;
        final signed = exportBuilder.sign(built, 's');

        // Mô phỏng save cục bộ đã đổi (khác bundle) trước khi restore.
        await slotManagerStorage.setString(
          manager.keyFor(slotA.id, 'coins'),
          '999',
        );
        await slotManagerStorage.setString(
          manager.keyFor(slotB.id, 'coins'),
          '888',
        );

        // Dùng storage THROW đúng lúc restore slot B để mô phỏng crash.
        final throwingStorage = _ThrowingStorageService(
          prefs,
          manager.keyFor(slotB.id, ''),
        );
        final crashExport = DisasterRecoverySaveExport(
          storage: throwingStorage,
          slotManager: manager,
        );
        final preview =
            (crashExport.previewRestore(signed, 's') as SdkSuccess).value;

        final result = await crashExport.applyRestore(preview);

        expect(result, isA<SdkFailure<void>>());
        // Slot A restore trước B trong list -> đã áp dụng thành công.
        expect(
          throwingStorage.getString(manager.keyFor(slotA.id, 'coins')),
          '111',
        );
        // Slot B thất bại giữa chừng -> giữ nguyên giá trị CŨ (888), không
        // phải giá trị mới (222) và không phải trạng thái dở dang nào khác.
        expect(
          throwingStorage.getString(manager.keyFor(slotB.id, 'coins')),
          '888',
        );

        expect(crashExport.recoveryLog, hasLength(2));
        expect(crashExport.recoveryLog[0].succeeded, isTrue);
        expect(crashExport.recoveryLog[0].slotId, slotA.id);
        expect(crashExport.recoveryLog[1].succeeded, isFalse);
        expect(crashExport.recoveryLog[1].slotId, slotB.id);
      },
    );

    test(
      'recoveryLog cộng dồn qua nhiều lần applyRestore, không reset',
      () async {
        await boot();
        final slot = slotManager.createSlot('Alice');
        final export = DisasterRecoverySaveExport(
          storage: storage,
          slotManager: slotManager,
        );
        final built =
            (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                    as SdkSuccess)
                .value;
        final preview =
            (export.previewRestore(export.sign(built, 's'), 's') as SdkSuccess)
                .value;

        await export.applyRestore(preview);
        await export.applyRestore(preview);

        expect(export.recoveryLog, hasLength(2));
      },
    );
  });

  group('BUG-41: applyRestore đăng ký lại slot metadata (không mồ côi)', () {
    test('round-trip đầy đủ: export -> xoá slot khỏi thiết bị (mô phỏng mất '
        'app state) -> applyRestore -> listSlots() thấy đúng slot', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      await storage.setString(slotManager.keyFor(slot.id, 'coins'), '100');

      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                  as SdkSuccess)
              .value;
      final signed = export.sign(built, 'secret');

      // Mô phỏng mất toàn bộ app state cho slot này (data lẫn metadata) —
      // deleteSlot xoá cả 2 (SaveSlotManager chỉ có 1 instance đọc/ghi
      // đúng 1 StorageService.to dùng chung trong 1 test, nên không thể
      // mô phỏng "thiết bị khác" bằng 1 SaveSlotManager thứ 2; deleteSlot
      // trên cùng manager mới thật sự tạo lại đúng trạng thái "chưa từng
      // biết slot này" mà applyRestore cần khôi phục).
      await slotManager.deleteSlot(slot.id);
      expect(slotManager.listSlots(), isEmpty);
      expect(storage.getString(slotManager.keyFor(slot.id, 'coins')), isNull);

      final preview =
          (export.previewRestore(signed, 'secret') as SdkSuccess).value;
      final result = await export.applyRestore(preview);

      expect(result, isA<SdkSuccess<void>>());
      final slots = slotManager.listSlots();
      expect(slots, hasLength(1));
      expect(slots.single.id, slot.id);
      expect(slots.single.displayName, 'Alice');
      expect(storage.getString(slotManager.keyFor(slot.id, 'coins')), '100');
    });

    test('restore vào slot ĐÃ có sẵn trong listSlots() (case backup/overwrite) '
        'không tạo entry trùng', () async {
      await boot();
      final slot = slotManager.createSlot('Alice');
      final export = DisasterRecoverySaveExport(
        storage: storage,
        slotManager: slotManager,
      );
      final built =
          (export.buildExport(slotIds: [slot.id], appVersion: '1.0')
                  as SdkSuccess)
              .value;
      final preview =
          (export.previewRestore(export.sign(built, 's'), 's') as SdkSuccess)
              .value;

      await export.applyRestore(preview);

      expect(slotManager.listSlots(), hasLength(1));
    });

    test('slot A restore ok, slot B throw giữa chừng trên SaveSlotManager '
        'rỗng: A có metadata, B KHÔNG thêm metadata mồ côi', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final seedStorage = StorageService(prefs);
      Get.put(seedStorage, permanent: true);
      final seedManager = SaveSlotManager();
      final slotA = seedManager.createSlot('Alice');
      final slotB = seedManager.createSlot('Bob');
      await seedStorage.setString(seedManager.keyFor(slotA.id, 'coins'), '111');
      await seedStorage.setString(seedManager.keyFor(slotB.id, 'coins'), '222');

      final exportBuilder = DisasterRecoverySaveExport(
        storage: seedStorage,
        slotManager: seedManager,
      );
      final built =
          (exportBuilder.buildExport(
                    slotIds: [slotA.id, slotB.id],
                    appVersion: '1.0',
                  )
                  as SdkSuccess)
              .value;
      final signed = exportBuilder.sign(built, 's');

      // Mô phỏng mất cả 2 slot (data + metadata) trước khi restore — cùng
      // lý do đã giải thích ở test round-trip phía trên: 1 SaveSlotManager
      // mới vẫn đọc chung StorageService.to đã có sẵn slotA/slotB, không
      // mô phỏng được "chưa từng biết slot này" trừ khi xoá thật.
      await seedManager.deleteSlot(slotA.id);
      await seedManager.deleteSlot(slotB.id);
      expect(seedManager.listSlots(), isEmpty);

      final throwingStorage = _ThrowingStorageService(
        prefs,
        seedManager.keyFor(slotB.id, ''),
      );
      final crashExport = DisasterRecoverySaveExport(
        storage: throwingStorage,
        slotManager: seedManager,
      );
      final preview =
          (crashExport.previewRestore(signed, 's') as SdkSuccess).value;

      final result = await crashExport.applyRestore(preview);

      expect(result, isA<SdkFailure<void>>());
      final slots = seedManager.listSlots();
      expect(slots.map((s) => s.id), [slotA.id]);
    });
  });
}
