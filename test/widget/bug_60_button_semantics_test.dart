// BUG-60: NeonButton, CommonButton, NeonDialogButton, và mỗi tab của
// SegmentedTabBar bọc `Semantics(button: true, label: ...)` quanh 1 Text
// con mà không `excludeSemantics: true` — screen reader (TalkBack/VoiceOver)
// đọc CẢ label tường minh của wrapper LẪN semantics ngầm định của Text con,
// nghe lặp label. Test này verify bằng cách đếm số SemanticsNode con còn lộ
// ra dưới node của chính nút bấm: phải là 0 sau khi có `excludeSemantics`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/segmented_tab_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_button.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

/// Số SemanticsNode con (không tính chính node của [finder]) còn lộ ra
/// trong accessibility tree — phải bằng 0 khi `excludeSemantics: true` đã
/// ẩn hết semantics ngầm định của các widget con (Text, Icon, ...).
int _descendantSemanticsNodeCount(WidgetTester tester, Finder finder) {
  final node = tester.renderObject(finder).debugSemantics;
  if (node == null) return 0;
  return node.childrenCount;
}

void main() {
  testWidgets(
    'NeonButton: không còn SemanticsNode con nào lộ ra (excludeSemantics)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: NeonButton(label: 'Chơi ngay', color: Colors.blue, onTap: () {}),
          ),
        ),
      );

      expect(_descendantSemanticsNodeCount(tester, find.byType(NeonButton)), 0);
      expect(tester.getSemantics(find.byType(NeonButton)).label, 'Chơi ngay');
      handle.dispose();
    },
  );

  testWidgets(
    'CommonButton: không còn SemanticsNode con nào lộ ra (excludeSemantics)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Lưu', onTap: () {}),
          ),
        ),
      );

      expect(
        _descendantSemanticsNodeCount(tester, find.byType(CommonButton)),
        0,
      );
      expect(tester.getSemantics(find.byType(CommonButton)).label, 'Lưu');
      handle.dispose();
    },
  );

  testWidgets(
    'NeonDialogButton: không còn SemanticsNode con nào lộ ra (excludeSemantics)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: NeonDialogButton(
              action: NeonDialogAction(
                label: 'Đồng ý',
                color: Colors.blue,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        _descendantSemanticsNodeCount(tester, find.byType(NeonDialogButton)),
        0,
      );
      expect(
        tester.getSemantics(find.byType(NeonDialogButton)).label,
        'Đồng ý',
      );
      handle.dispose();
    },
  );

  testWidgets(
    'SegmentedTabBar: mỗi tab không còn SemanticsNode con nào lộ ra (excludeSemantics)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SegmentedTabBar(
              labels: const ['Dễ', 'Khó'],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final tabFinder = find.ancestor(
        of: find.text('Dễ'),
        matching: find.byType(Semantics),
      ).first;
      expect(_descendantSemanticsNodeCount(tester, tabFinder), 0);
      expect(tester.getSemantics(tabFinder).label, 'Dễ');
      handle.dispose();
    },
  );

  testWidgets(
    'hành vi tap của cả 4 widget không đổi sau khi thêm excludeSemantics',
    (tester) async {
      var neonTapped = false;
      var commonTapped = false;
      var dialogTapped = false;
      var changedTo = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: [
                NeonButton(
                  label: 'A',
                  color: Colors.blue,
                  onTap: () => neonTapped = true,
                ),
                CommonButton(label: 'B', onTap: () => commonTapped = true),
                NeonDialogButton(
                  action: NeonDialogAction(
                    label: 'C',
                    color: Colors.blue,
                    onTap: () => dialogTapped = true,
                  ),
                ),
                SegmentedTabBar(
                  labels: const ['X', 'Y'],
                  selectedIndex: 0,
                  onChanged: (i) => changedTo = i,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(NeonButton));
      await tester.tap(find.byType(CommonButton));
      await tester.tap(find.byType(NeonDialogButton));
      await tester.tap(find.text('Y'));
      await tester.pump();

      expect(neonTapped, isTrue);
      expect(commonTapped, isTrue);
      expect(dialogTapped, isTrue);
      expect(changedTo, 1);
    },
  );
}
