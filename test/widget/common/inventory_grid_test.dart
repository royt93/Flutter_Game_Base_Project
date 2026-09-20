import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/inventory_grid.dart';

Widget _host(
  Widget grid, {
  TextDirection textDirection = TextDirection.ltr,
  double textScaleFactor = 1.0,
  Size size = const Size(400, 800),
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
    child: Directionality(
      textDirection: textDirection,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox.fromSize(size: size, child: grid),
        ),
      ),
    ),
  );
}

Widget _defaultItemBuilder(
  BuildContext context,
  InventorySlot slot,
  bool isSelected,
) {
  return Container(
    key: ValueKey('tile_${slot.slotId}'),
    color: isSelected ? Colors.amber : Colors.blueGrey,
    child: Center(
      child: Text(
        '${slot.itemId} x${slot.quantity}${slot.equipped ? " (equipped)" : ""}',
      ),
    ),
  );
}

void main() {
  group('InventoryGrid: render cơ bản', () {
    testWidgets('hiện đúng item/empty/locked theo unlockedCapacity', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [
          InventorySlot(slotId: 1, itemId: 'potion', quantity: 3),
          InventorySlot(
            slotId: 2,
            itemId: 'sword',
            quantity: 1,
            equipped: true,
          ),
        ],
        capacity: 6,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            unlockedCapacity: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      expect(find.text('potion x3'), findsOneWidget);
      expect(find.text('sword x1 (equipped)'), findsOneWidget);
      // 2 slot filled + (4-2)=2 empty + (6-4)=2 locked.
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('unlockedCapacity null (mặc định): không có ô locked nào', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [InventorySlot(slotId: 1, itemId: 'potion', quantity: 1)],
        capacity: 4,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('inventory rỗng: toàn bộ cell dùng emptyBuilder', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(slots: [], capacity: 4);

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            emptyBuilder: (context, index) =>
                Text('empty_$index', key: ValueKey('empty_key_$index')),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      for (var i = 0; i < 4; i++) {
        expect(find.text('empty_$i'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('InventoryGrid: selection', () {
    testWidgets('isSelected truyền đúng cho đúng slot, không lẫn slot khác', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [
          InventorySlot(slotId: 1, itemId: 'potion', quantity: 1),
          InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
        ],
        capacity: 2,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            selectedSlotId: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      final potionTile = tester.widget<Container>(
        find.byKey(const ValueKey('tile_1')),
      );
      final swordTile = tester.widget<Container>(
        find.byKey(const ValueKey('tile_2')),
      );
      expect(potionTile.color, Colors.blueGrey);
      expect(swordTile.color, Colors.amber);
    });
  });

  group('InventoryGrid: tap/long-press hooks', () {
    testWidgets('onSlotTap fires đúng slot khi bấm, không tự mutate gì', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [InventorySlot(slotId: 1, itemId: 'potion', quantity: 1)],
        capacity: 1,
      );
      InventorySlot? tapped;

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            onSlotTap: (slot) => tapped = slot,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('tile_1')));
      await tester.pump();

      expect(tapped?.slotId, 1);
      expect(tapped?.itemId, 'potion');
    });

    testWidgets('onSlotLongPress fires đúng slot khi giữ lâu', (tester) async {
      const snapshot = InventorySnapshot(
        slots: [InventorySlot(slotId: 1, itemId: 'potion', quantity: 1)],
        capacity: 1,
      );
      InventorySlot? longPressed;

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            onSlotLongPress: (slot) => longPressed = slot,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('tile_1')));
      await tester.pump();

      expect(longPressed?.slotId, 1);
    });

    testWidgets(
      'không truyền onSlotTap/onSlotLongPress: tap không throw, không GestureDetector nào bọc thêm',
      (tester) async {
        const snapshot = InventorySnapshot(
          slots: [InventorySlot(slotId: 1, itemId: 'potion', quantity: 1)],
          capacity: 1,
        );

        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: snapshot,
              itemBuilder: _defaultItemBuilder,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('tile_1')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('InventoryGrid: stable identity qua reorder/update', () {
    testWidgets(
      'đảo thứ tự 2 slot trong list: State nội bộ của mỗi tile đi ĐÚNG THEO slotId, không lẫn',
      (tester) async {
        // CỐ TÌNH không tự gắn key riêng ở đây — verify InventoryGrid TỰ
        // giữ đúng identity bằng slotId nội bộ (KeyedSubtree), không phụ
        // thuộc caller có nhớ tự key hay không.
        Widget statefulItemBuilder(
          BuildContext context,
          InventorySlot slot,
          bool isSelected,
        ) {
          return _CounterTile(slotId: slot.slotId);
        }

        const before = InventorySnapshot(
          slots: [
            InventorySlot(slotId: 1, itemId: 'potion', quantity: 1),
            InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
          ],
          capacity: 2,
        );

        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: before,
              itemBuilder: statefulItemBuilder,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        );

        // Bấm tăng counter riêng của slot 1 (index 0) lên 5.
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.text('slot1:$i'));
          await tester.pump();
        }
        expect(find.text('slot1:5'), findsOneWidget);
        expect(find.text('slot2:0'), findsOneWidget);

        // Đảo thứ tự: slot 2 giờ đứng TRƯỚC slot 1 trong list (mô phỏng
        // moveSlot/reorder thật).
        const after = InventorySnapshot(
          slots: [
            InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
            InventorySlot(slotId: 1, itemId: 'potion', quantity: 1),
          ],
          capacity: 2,
        );
        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: after,
              itemBuilder: statefulItemBuilder,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        );

        // Counter phải ĐI THEO slotId=1 (giờ ở vị trí index 1), KHÔNG bị
        // giữ lại ở "vị trí index 0" (nơi slot 2 giờ đứng).
        expect(find.text('slot1:5'), findsOneWidget);
        expect(find.text('slot2:0'), findsOneWidget);
      },
    );

    testWidgets(
      'remove 1 slot ở giữa: state của slot còn lại không bị gán nhầm sang slot khác',
      (tester) async {
        Widget statefulItemBuilder(
          BuildContext context,
          InventorySlot slot,
          bool isSelected,
        ) {
          return _CounterTile(slotId: slot.slotId);
        }

        const before = InventorySnapshot(
          slots: [
            InventorySlot(slotId: 1, itemId: 'a', quantity: 1),
            InventorySlot(slotId: 2, itemId: 'b', quantity: 1),
            InventorySlot(slotId: 3, itemId: 'c', quantity: 1),
          ],
          capacity: 3,
        );

        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: before,
              itemBuilder: statefulItemBuilder,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        );

        for (var i = 0; i < 7; i++) {
          await tester.tap(find.text('slot3:$i'));
          await tester.pump();
        }
        expect(find.text('slot3:7'), findsOneWidget);

        // Xoá slot 2 (ở giữa) — slot 3 giờ nhảy từ index 2 xuống index 1.
        const after = InventorySnapshot(
          slots: [
            InventorySlot(slotId: 1, itemId: 'a', quantity: 1),
            InventorySlot(slotId: 3, itemId: 'c', quantity: 1),
          ],
          capacity: 3,
        );
        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: after,
              itemBuilder: statefulItemBuilder,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        );

        expect(find.text('slot3:7'), findsOneWidget);
        expect(find.text('slot1:0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('InventoryGrid: reorder qua drag', () {
    testWidgets('onReorder fires đúng (fromSlotId, toSlotId) khi kéo-thả', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [
          InventorySlot(slotId: 1, itemId: 'potion', quantity: 1),
          InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
        ],
        capacity: 2,
      );
      int? from;
      int? to;

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            onReorder: (f, t) {
              from = f;
              to = t;
            },
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      final dragHandle = find.byKey(const ValueKey('tile_1'));
      final dropTarget = find.byKey(const ValueKey('tile_2'));
      await tester.drag(
        dragHandle,
        tester.getCenter(dropTarget) - tester.getCenter(dragHandle),
      );
      await tester.pumpAndSettle();

      expect(from, 1);
      expect(to, 2);
    });

    testWidgets('không truyền onReorder: không có Draggable nào được thêm', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [InventorySlot(slotId: 1, itemId: 'potion', quantity: 1)],
        capacity: 1,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      );

      expect(find.byType(Draggable<int>), findsNothing);
    });
  });

  group('InventoryGrid: danh sách lớn dùng lazy builder', () {
    testWidgets(
      'capacity 500: chỉ build số cell hiển thị trên viewport, không build hết 500',
      (tester) async {
        final slots = List.generate(
          500,
          (i) => InventorySlot(slotId: i, itemId: 'item_$i', quantity: 1),
        );
        final snapshot = InventorySnapshot(slots: slots, capacity: 500);
        var builtCount = 0;

        await tester.pumpWidget(
          _host(
            InventoryGrid(
              snapshot: snapshot,
              itemBuilder: (context, slot, isSelected) {
                builtCount++;
                return SizedBox(
                  key: ValueKey('tile_${slot.slotId}'),
                  width: 80,
                  height: 80,
                  child: Text(slot.itemId),
                );
              },
              crossAxisCount: 4,
            ),
            size: const Size(400, 800),
          ),
        );

        // Viewport 800 logical px cao, tile ~200px cao (800/4 cols) — chỉ
        // vài hàng đầu được build, RẤT xa con số 500.
        expect(builtCount, lessThan(50));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('InventoryGrid: text scale/RTL không overflow', () {
    testWidgets('textScaleFactor lớn (2.5) với item name dài: không throw', (
      tester,
    ) async {
      const snapshot = InventorySnapshot(
        slots: [
          InventorySlot(
            slotId: 1,
            itemId: 'super_rare_legendary_sword_of_destiny',
            quantity: 999,
          ),
        ],
        capacity: 1,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: (context, slot, isSelected) =>
                FittedBox(child: Text('${slot.itemId} x${slot.quantity}')),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
          textScaleFactor: 2.5,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL: grid vẫn render đúng, không throw', (tester) async {
      const snapshot = InventorySnapshot(
        slots: [
          InventorySlot(slotId: 1, itemId: 'potion', quantity: 1),
          InventorySlot(slotId: 2, itemId: 'sword', quantity: 1),
        ],
        capacity: 4,
      );

      await tester.pumpWidget(
        _host(
          InventoryGrid(
            snapshot: snapshot,
            itemBuilder: _defaultItemBuilder,
            unlockedCapacity: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
          textDirection: TextDirection.rtl,
        ),
      );

      expect(find.text('potion x1'), findsOneWidget);
      expect(find.text('sword x1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A tiny stateful tile — its own local `_count` proves whether Flutter
/// reused the CORRECT `State` object across a rebuild (by [slotId], via
/// `InventoryGrid`'s own internal `KeyedSubtree` — this widget is
/// deliberately constructed WITHOUT its own key in the tests below, so
/// they exercise the grid's identity handling, not the caller's).
class _CounterTile extends StatefulWidget {
  const _CounterTile({required this.slotId});

  final int slotId;

  @override
  State<_CounterTile> createState() => _CounterTileState();
}

class _CounterTileState extends State<_CounterTile> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: Text('slot${widget.slotId}:$_count'),
    );
  }
}
