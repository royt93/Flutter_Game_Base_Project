import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
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

  group('Slice 1: metadata CRUD', () {
    test('listSlots() rỗng khi chưa tạo slot nào', () {
      final manager = SaveSlotManager();
      expect(manager.listSlots(), isEmpty);
    });

    test('createSlot tạo đúng slot, sinh id/createdAtMs/lastPlayedAtMs hợp lệ', () {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('Alice');

      expect(slot.displayName, 'Alice');
      expect(slot.id, isNotEmpty);
      expect(slot.createdAtMs, greaterThan(0));
      expect(slot.lastPlayedAtMs, slot.createdAtMs);
      expect(manager.listSlots(), hasLength(1));
    });

    test('createSlot với displayName rỗng/blank throw ArgumentError', () {
      final manager = SaveSlotManager();
      expect(() => manager.createSlot(''), throwsArgumentError);
      expect(() => manager.createSlot('   '), throwsArgumentError);
    });

    test('createSlot sinh id không trùng, kể cả gọi liên tiếp nhiều lần nhanh', () {
      final manager = SaveSlotManager();
      final ids = [for (var i = 0; i < 20; i++) manager.createSlot('Slot $i').id];
      expect(ids.toSet(), hasLength(20)); // toàn bộ 20 id phải khác nhau
    });

    test('listSlots() sắp xếp đúng theo lastPlayedAtMs giảm dần', () async {
      final manager = SaveSlotManager();
      final a = manager.createSlot('A');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = manager.createSlot('B');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final c = manager.createSlot('C');

      // Touch A cuối cùng — A phải lên đầu danh sách dù tạo trước.
      manager.touchSlot(a.id);

      final order = manager.listSlots().map((s) => s.id).toList();
      expect(order.first, a.id);
      expect(order, containsAll([a.id, b.id, c.id]));
    });

    test('renameSlot đổi đúng displayName, không đổi id/timestamps', () {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('Old Name');
      manager.renameSlot(slot.id, 'New Name');

      final renamed = manager.listSlots().single;
      expect(renamed.displayName, 'New Name');
      expect(renamed.id, slot.id);
      expect(renamed.createdAtMs, slot.createdAtMs);
    });

    test('renameSlot với id không tồn tại throw ArgumentError', () {
      final manager = SaveSlotManager();
      expect(() => manager.renameSlot('ghost', 'X'), throwsArgumentError);
    });

    test('touchSlot cập nhật đúng lastPlayedAtMs', () async {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('A');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      manager.touchSlot(slot.id);

      final touched = manager.listSlots().single;
      expect(touched.lastPlayedAtMs, greaterThanOrEqualTo(slot.createdAtMs));
    });

    test('touchSlot với id không tồn tại throw ArgumentError', () {
      final manager = SaveSlotManager();
      expect(() => manager.touchSlot('ghost'), throwsArgumentError);
    });

    test('persist qua "restart": instance mới đọc lại đúng danh sách slot', () async {
      final manager = SaveSlotManager();
      manager.createSlot('Alice');
      manager.createSlot('Bob');
      await manager.debugPendingSaves;

      final restarted = SaveSlotManager();
      expect(restarted.listSlots().map((s) => s.displayName), ['Alice', 'Bob']);
    });
  });

  group('Slice 2: active slot & key namespacing', () {
    test('activeSlotId null khi chưa setActiveSlot', () {
      final manager = SaveSlotManager();
      expect(manager.activeSlotId, isNull);
    });

    test('setActiveSlot rồi activeSlotId trả đúng id, persist qua restart', () async {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('Alice');
      await manager.setActiveSlot(slot.id);

      expect(manager.activeSlotId, slot.id);

      final restarted = SaveSlotManager();
      expect(restarted.activeSlotId, slot.id);
    });

    test('setActiveSlot với id không tồn tại throw ArgumentError, không đổi activeSlotId hiện tại', () async {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('Alice');
      await manager.setActiveSlot(slot.id);

      expect(() => manager.setActiveSlot('ghost'), throwsArgumentError);
      expect(manager.activeSlotId, slot.id); // không bị đổi
    });

    test('keyFor sinh key ổn định, xác định (cùng input luôn ra cùng output)', () {
      final manager = SaveSlotManager();
      expect(manager.keyFor('a', 'profile'), manager.keyFor('a', 'profile'));
    });

    test('keyFor: 2 slotId/suffix khác nhau không bao giờ đụng key nhau', () {
      final manager = SaveSlotManager();
      final keys = {
        manager.keyFor('a', 'profile'),
        manager.keyFor('b', 'profile'),
        manager.keyFor('a', 'settings'),
        manager.keyFor('b', 'settings'),
      };
      expect(keys, hasLength(4));
    });
  });

  group('Slice 3: xoá slot đúng, không sót rác', () {
    test('deleteSlot xoá đúng metadata VÀ mọi key con của slot đó, không đụng slot khác', () async {
      final manager = SaveSlotManager();
      final a = manager.createSlot('Alice');
      final b = manager.createSlot('Bob');

      await storage.setString(manager.keyFor(a.id, 'profile'), 'alice-data');
      await storage.setInt(manager.keyFor(a.id, 'score'), 100);
      await storage.setString(manager.keyFor(b.id, 'profile'), 'bob-data');

      await manager.deleteSlot(a.id);

      expect(
        manager.listSlots().map((s) => s.id),
        [b.id],
      ); // metadata của a đã bị xoá
      expect(
        storage.exportAll().keys.where((k) => k.startsWith('slot_${a.id}_')),
        isEmpty,
      );
      expect(storage.getString(manager.keyFor(b.id, 'profile')), 'bob-data');
    });

    test('deleteSlot đúng activeSlotId hiện tại → activeSlotId trở thành null sau đó', () async {
      final manager = SaveSlotManager();
      final slot = manager.createSlot('Alice');
      await manager.setActiveSlot(slot.id);

      await manager.deleteSlot(slot.id);

      expect(manager.activeSlotId, isNull);
    });

    test('deleteSlot 1 slot KHÔNG phải activeSlotId hiện tại: activeSlotId không đổi', () async {
      final manager = SaveSlotManager();
      final a = manager.createSlot('Alice');
      final b = manager.createSlot('Bob');
      await manager.setActiveSlot(a.id);

      await manager.deleteSlot(b.id);

      expect(manager.activeSlotId, a.id);
    });

    test('deleteSlot với id không tồn tại throw ArgumentError', () async {
      final manager = SaveSlotManager();
      await expectLater(manager.deleteSlot('ghost'), throwsArgumentError);
    });

    test('JSON metadata cũ/thiếu/hỏng: rơi về danh sách slot rỗng an toàn, không throw', () async {
      await storage.setString(
        'save_slot_meta_v1',
        '{"slots": [1, 2, {"id": "", "displayName": "x", "createdAtMs": 1, "lastPlayedAtMs": 1}, {"id": "ok", "displayName": "OK", "createdAtMs": 1, "lastPlayedAtMs": 1}, {"id": "bad", "displayName": "Bad", "createdAtMs": -1, "lastPlayedAtMs": 1}], "schemaVersion": 1}',
      );
      final manager = SaveSlotManager();

      expect(() => manager.listSlots(), returnsNormally);
      expect(manager.listSlots().map((s) => s.id), ['ok']);
    });

    test('JSON hoàn toàn hỏng (không phải object hợp lệ): rơi về danh sách rỗng an toàn', () async {
      await storage.setString('save_slot_meta_v1', 'not even json{{{');
      final manager = SaveSlotManager();

      expect(() => manager.listSlots(), returnsNormally);
      expect(manager.listSlots(), isEmpty);
      expect(() => manager.createSlot('Alice'), returnsNormally);
    });

    test(
      'race: nhiều createSlot/touchSlot/deleteSlot liên tiếp không await giữa các lần vẫn ghi đúng qua "restart"',
      () async {
        final manager = SaveSlotManager();
        final a = manager.createSlot('A');
        final b = manager.createSlot('B');
        manager.touchSlot(a.id);
        final c = manager.createSlot('C');
        unawaited(manager.deleteSlot(b.id));
        manager.touchSlot(c.id);

        await manager.debugPendingSaves;

        final restarted = SaveSlotManager();
        final ids = restarted.listSlots().map((s) => s.id).toSet();
        expect(ids, {a.id, c.id});
        expect(ids.contains(b.id), isFalse);
      },
    );
  });
}
