import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

const _catalog = {
  'potion': ItemDefinition(id: 'potion', maxStack: 10),
  'sword': ItemDefinition(id: 'sword', maxStack: 1, equippable: true),
  'gem': ItemDefinition(id: 'gem', maxStack: 99, rarity: ItemRarity.rare),
};

InventoryService _service({int capacity = 4, StorageService? storage}) =>
    InventoryService(
      storage: storage ?? StorageService(null),
      itemCatalog: _catalog,
      capacity: capacity,
    )..onInit();

void main() {
  group('InventoryService: grant cơ bản', () {
    test('grant item mới tạo 1 slot với đúng quantity', () async {
      final service = _service();
      final result = await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
        transactionId: 'tx1',
      );
      expect(result, isA<SdkSuccess<InventorySnapshot>>());
      expect(service.snapshot.value.quantityOf('potion'), 3);
      expect(service.snapshot.value.slots.length, 1);
    });

    test(
      'grant thêm item cùng loại lấp đầy slot cũ trước khi tạo slot mới',
      () async {
        final service = _service();
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 8)],
          transactionId: 'tx1',
        );
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
          transactionId: 'tx2',
        );
        // maxStack potion = 10: slot 1 đầy lên 10 (dùng 2), slot 2 mới nhận 3 dư.
        expect(service.snapshot.value.quantityOf('potion'), 13);
        expect(service.snapshot.value.slots.length, 2);
        expect(service.snapshot.value.slots[0].quantity, 10);
        expect(service.snapshot.value.slots[1].quantity, 3);
      },
    );

    test('unknown item id bị reject, không tạo slot nào', () async {
      final service = _service();
      final result = await service.grant(
        lines: const [InventoryLine(itemId: 'no_such_item', quantity: 1)],
        transactionId: 'tx1',
      );
      expect(result, isA<SdkFailure<InventorySnapshot>>());
      expect(service.snapshot.value.slots, isEmpty);
    });

    test('quantity <= 0 hoặc transactionId rỗng bị reject', () async {
      final service = _service();
      final r1 = await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 0)],
        transactionId: 'tx1',
      );
      expect(r1, isA<SdkFailure<InventorySnapshot>>());
      final r2 = await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 1)],
        transactionId: '',
      );
      expect(r2, isA<SdkFailure<InventorySnapshot>>());
    });

    test(
      'grant cùng transactionId 2 lần: idempotent, không cấp gấp đôi',
      () async {
        final service = _service();
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
          transactionId: 'dup',
        );
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
          transactionId: 'dup',
        );
        expect(service.snapshot.value.quantityOf('potion'), 3);
      },
    );
  });

  group('InventoryService: capacity + atomicity', () {
    test('vượt capacity: reject toàn bộ batch, không cấp một phần', () async {
      final service = _service(capacity: 1);
      await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 10)],
        transactionId: 'fill',
      );
      // Inventory đã đầy 1/1 slot. Grant thêm 1 loại item khác (sword,
      // không stack chung với potion) phải reject vì hết chỗ.
      final result = await service.grant(
        lines: const [InventoryLine(itemId: 'sword', quantity: 1)],
        transactionId: 'overflow',
      );
      expect(result, isA<SdkFailure<InventorySnapshot>>());
      expect(service.snapshot.value.slots.length, 1);
      expect(service.snapshot.value.quantityOf('sword'), 0);
    });

    test(
      'grant nhiều item 1 lần: nếu 1 dòng vượt capacity thì KHÔNG dòng nào được áp dụng',
      () async {
        final service = _service(capacity: 2);
        final result = await service.grant(
          lines: const [
            InventoryLine(itemId: 'potion', quantity: 3), // slot 1: ok
            InventoryLine(itemId: 'sword', quantity: 1), // slot 2: ok
            InventoryLine(
              itemId: 'gem',
              quantity: 1,
            ), // slot 3: vượt capacity=2
          ],
          transactionId: 'batch',
        );
        expect(result, isA<SdkFailure<InventorySnapshot>>());
        expect(service.snapshot.value.slots, isEmpty);
      },
    );
  });

  group('InventoryService: consume', () {
    test('consume đủ số lượng: trừ đúng, xoá slot rỗng', () async {
      final service = _service();
      await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
        transactionId: 'tx1',
      );
      final result = await service.consume(
        lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
        transactionId: 'tx2',
      );
      expect(result, isA<SdkSuccess<InventorySnapshot>>());
      expect(service.snapshot.value.quantityOf('potion'), 0);
      expect(service.snapshot.value.slots, isEmpty);
    });

    test('consume không đủ số lượng: reject, không trừ gì cả', () async {
      final service = _service();
      await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 2)],
        transactionId: 'tx1',
      );
      final result = await service.consume(
        lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
        transactionId: 'tx2',
      );
      expect(result, isA<SdkFailure<InventorySnapshot>>());
      expect(service.snapshot.value.quantityOf('potion'), 2);
    });

    test(
      'consume nhiều dòng: nếu 1 dòng thiếu hàng thì KHÔNG dòng nào bị trừ',
      () async {
        final service = _service();
        await service.grant(
          lines: const [
            InventoryLine(itemId: 'potion', quantity: 5),
            InventoryLine(itemId: 'gem', quantity: 1),
          ],
          transactionId: 'tx1',
        );
        final result = await service.consume(
          lines: const [
            InventoryLine(itemId: 'potion', quantity: 5),
            InventoryLine(itemId: 'gem', quantity: 10), // không đủ
          ],
          transactionId: 'tx2',
        );
        expect(result, isA<SdkFailure<InventorySnapshot>>());
        expect(service.snapshot.value.quantityOf('potion'), 5);
        expect(service.snapshot.value.quantityOf('gem'), 1);
      },
    );

    test(
      'consume cùng transactionId 2 lần: idempotent, không trừ 2 lần',
      () async {
        final service = _service();
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
          transactionId: 'tx1',
        );
        await service.consume(
          lines: const [InventoryLine(itemId: 'potion', quantity: 2)],
          transactionId: 'dup',
        );
        await service.consume(
          lines: const [InventoryLine(itemId: 'potion', quantity: 2)],
          transactionId: 'dup',
        );
        expect(service.snapshot.value.quantityOf('potion'), 3);
      },
    );
  });

  group('InventoryService: equip/unequip', () {
    test('equip đánh dấu đúng slot, unequip gỡ lại', () async {
      final service = _service();
      await service.grant(
        lines: const [InventoryLine(itemId: 'sword', quantity: 1)],
        transactionId: 'tx1',
      );
      final slotId = service.snapshot.value.slots.first.slotId;

      final equipped = await service.setEquipped(
        slotId: slotId,
        equipped: true,
      );
      expect(equipped, isA<SdkSuccess<InventorySnapshot>>());
      expect(service.snapshot.value.slots.first.equipped, isTrue);

      await service.setEquipped(slotId: slotId, equipped: false);
      expect(service.snapshot.value.slots.first.equipped, isFalse);
    });

    test('equip item không equippable bị reject', () async {
      final service = _service();
      await service.grant(
        lines: const [InventoryLine(itemId: 'potion', quantity: 1)],
        transactionId: 'tx1',
      );
      final slotId = service.snapshot.value.slots.first.slotId;
      final result = await service.setEquipped(slotId: slotId, equipped: true);
      expect(result, isA<SdkFailure<InventorySnapshot>>());
    });

    test('equip slotId không tồn tại bị reject', () async {
      final service = _service();
      final result = await service.setEquipped(slotId: 999, equipped: true);
      expect(result, isA<SdkFailure<InventorySnapshot>>());
    });
  });

  group('InventoryService: move (đổi vị trí hiển thị)', () {
    test('moveSlot hoán đổi thứ tự 2 slot', () async {
      final service = _service();
      await service.grant(
        lines: const [
          InventoryLine(itemId: 'potion', quantity: 1),
          InventoryLine(itemId: 'gem', quantity: 1),
        ],
        transactionId: 'tx1',
      );
      final ids = service.snapshot.value.slots.map((s) => s.slotId).toList();
      final result = await service.moveSlot(
        fromSlotId: ids[0],
        toSlotId: ids[1],
      );
      expect(result, isA<SdkSuccess<InventorySnapshot>>());
      expect(service.snapshot.value.slots.map((s) => s.slotId).toList(), [
        ids[1],
        ids[0],
      ]);
    });
  });

  group('InventoryService: corrupt save + stale item id', () {
    test('save hỏng (JSON invalid) không throw, reset về rỗng', () async {
      final storage = StorageService(null);
      await storage.setString('inventory_service_v1', 'not json {{');
      final service = _service(storage: storage);
      expect(service.snapshot.value.slots, isEmpty);
      expect(() => service.snapshot.value, returnsNormally);
    });

    test(
      'slot tham chiếu item id không còn trong catalog bị bỏ qua khi hydrate',
      () async {
        final storage = StorageService(null);
        await storage.setString('inventory_service_v1', '''
      {"slots": [
        {"slotId": 1, "itemId": "removed_item", "quantity": 5, "equipped": false},
        {"slotId": 2, "itemId": "potion", "quantity": 3, "equipped": false}
      ], "transactions": []}
      ''');
        final service = _service(storage: storage);
        expect(service.snapshot.value.slots.length, 1);
        expect(service.snapshot.value.quantityOf('potion'), 3);
        expect(service.snapshot.value.quantityOf('removed_item'), 0);
      },
    );
  });

  group('InventoryService: persist qua restart', () {
    test(
      'slot/stack/equipped giữ nguyên sau khi tạo lại service mới cùng storage',
      () async {
        final storage = StorageService(null);
        final first = _service(storage: storage);
        await first.grant(
          lines: const [InventoryLine(itemId: 'sword', quantity: 1)],
          transactionId: 'tx1',
        );
        final slotId = first.snapshot.value.slots.first.slotId;
        await first.setEquipped(slotId: slotId, equipped: true);

        final second = _service(storage: storage);
        expect(second.snapshot.value.slots.length, 1);
        expect(second.snapshot.value.slots.first.itemId, 'sword');
        expect(second.snapshot.value.slots.first.equipped, isTrue);

        // Transaction cũ vẫn nhớ qua restart.
        final dup = await second.grant(
          lines: const [InventoryLine(itemId: 'sword', quantity: 1)],
          transactionId: 'tx1',
        );
        expect(dup, isA<SdkSuccess<InventorySnapshot>>());
        expect(second.snapshot.value.slots.length, 1);
      },
    );
  });

  group('InventoryService: concurrent operations', () {
    test(
      'grant và consume đồng thời deterministic, không âm/vượt capacity',
      () async {
        final service = _service(capacity: 10);
        await service.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 5)],
          transactionId: 'seed',
        );

        final results = await Future.wait([
          service.consume(
            lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
            transactionId: 'c1',
          ),
          service.consume(
            lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
            transactionId: 'c2',
          ),
        ]);

        // Chỉ đúng 1 trong 2 consume thành công (chỉ đủ hàng cho 1 lần).
        expect(results.where((r) => r.isSuccess).length, 1);
        expect(service.snapshot.value.quantityOf('potion'), 2);
      },
    );
  });

  group('BUG-40: hydrate ngay trong constructor, không phụ thuộc onInit()', () {
    test(
      'khởi tạo trực tiếp (không gọi onInit()) vẫn đọc đúng inventory cũ',
      () async {
        final storage = StorageService(null);
        final seed = _service(storage: storage);
        await seed.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
          transactionId: 'seed',
        );

        final direct = InventoryService(
          storage: storage,
          itemCatalog: _catalog,
        );

        expect(direct.snapshot.value.quantityOf('potion'), 3);
      },
    );

    test(
      'consume ngay sau khởi tạo trực tiếp trừ đúng trên data cũ, không mất',
      () async {
        final storage = StorageService(null);
        final seed = _service(storage: storage);
        await seed.grant(
          lines: const [InventoryLine(itemId: 'potion', quantity: 3)],
          transactionId: 'seed',
        );

        final direct = InventoryService(
          storage: storage,
          itemCatalog: _catalog,
        );
        await direct.consume(
          lines: const [InventoryLine(itemId: 'potion', quantity: 1)],
          transactionId: 'extra',
        );

        expect(direct.snapshot.value.quantityOf('potion'), 2);
      },
    );
  });
}
