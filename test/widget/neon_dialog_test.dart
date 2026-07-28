import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/presentation/widgets/neon_dialog.dart';

// overlaySlot() nhận panelKey kiểu `Object?` nên `ValueKey(panelKey)` bên
// trong luôn suy ra `ValueKey<Object?>` — khác runtimeType với
// `ValueKey<String>('x')` viết trực tiếp trong test (Dart coi 2 generic
// instantiation này là kiểu khác nhau ⇒ `==` luôn false dù cùng value). So
// khớp theo `.value` để không phụ thuộc type argument của ValueKey.
Finder _byPanelKey(Object value) => find.byWidgetPredicate(
  (w) =>
      w is KeyedSubtree &&
      w.key is ValueKey &&
      (w.key as ValueKey).value == value,
);

void main() {
  testWidgets('panel render title/message/action, tap action gọi onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: NeonDialog.panel(
              title: 'You Win!',
              color: NeonTheme.gold,
              message: 'Great job',
              icon: Icons.star_rounded,
              actions: [
                NeonDialogAction(
                  label: 'NEXT',
                  color: NeonTheme.gold,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('You Win!'), findsOneWidget);
    expect(find.text('Great job'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    expect(tapped, isTrue);
  });

  testWidgets('overlay render panel trên barrier, tap barrier gọi onBarrier', (
    tester,
  ) async {
    var barrierTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            NeonDialog.overlay(
              onBarrier: () => barrierTapped = true,
              panel: NeonDialog.panel(
                title: 'Paused',
                color: NeonTheme.cyan,
                actions: const [],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    expect(barrierTapped, isTrue);
  });

  testWidgets('overlaySlot ẩn khi panel null, hiện khi panel có giá trị', (
    tester,
  ) async {
    Widget build(Widget? panel) => MaterialApp(
      home: Stack(
        children: [NeonDialog.overlaySlot(panel: panel, panelKey: 'streak')],
      ),
    );

    await tester.pumpWidget(build(null));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Streak'), findsNothing);

    await tester.pumpWidget(
      build(
        NeonDialog.panel(
          title: 'Streak',
          color: NeonTheme.red,
          actions: const [],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Streak'), findsOneWidget);
  });

  testWidgets(
    'overlaySlot: panelKey giữ nguyên qua rebuild dù panel là instance mới '
    '→ AnimatedSwitcher không replay animation (fix identity-fragility)',
    (tester) async {
      Widget build() => MaterialApp(
        home: Stack(
          children: [
            NeonDialog.overlaySlot(
              panelKey: 'streak',
              panel: NeonDialog.panel(
                title: 'Streak',
                color: NeonTheme.red,
                actions: const [],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      // _byPanelKey (không phải find.byType(KeyedSubtree)) vì AnimatedSwitcher
      // tự bọc thêm 1 KeyedSubtree nội bộ (key số _childNumber) quanh mỗi
      // transition — byType sẽ đếm luôn cái đó, gây false positive/negative.
      expect(_byPanelKey('streak'), findsOneWidget);

      // Rebuild với panel là 1 instance HOÀN TOÀN MỚI (NeonDialog.panel gọi
      // lại) nhưng panelKey giữ nguyên — mô phỏng đúng tình huống Obx/setState
      // rebuild panel mỗi frame trong lúc dialog vẫn đang mở.
      await tester.pumpWidget(build());
      await tester.pump();

      // Vẫn đúng 1 widget mang key 'streak' (không đổi key ⇒ không tạo entry
      // mới) và không có animation nào đang chạy (transientCallbackCount ==
      // 0) → chứng minh AnimatedSwitcher coi là "vẫn child cũ", không replay.
      // Nếu bug cũ (ValueKey(panel) theo identity instance) còn tồn tại, key
      // sẽ đổi mỗi rebuild → tạo entry mới → animation chạy → assert fail.
      expect(_byPanelKey('streak'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('Streak'), findsOneWidget);
    },
  );

  testWidgets(
    'overlaySlot: panelKey đổi giá trị → AnimatedSwitcher replay animation '
    'khi chuyển sang dialog khác',
    (tester) async {
      Widget build(String panelKey) => MaterialApp(
        home: Stack(
          children: [
            NeonDialog.overlaySlot(
              panelKey: panelKey,
              panel: NeonDialog.panel(
                title: panelKey,
                color: NeonTheme.red,
                actions: const [],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build('win'));
      await tester.pumpAndSettle();
      expect(_byPanelKey('win'), findsOneWidget);

      await tester.pumpWidget(build('lose'));
      await tester.pump();

      // Ngay sau khi panelKey đổi, dialog cũ ('win') + mới ('lose') cùng tồn
      // tại giữa lúc crossfade, và có animation đang chạy → chứng minh
      // AnimatedSwitcher NHẬN RA đây là dialog khác và bắt đầu animation,
      // thay vì swap thẳng không animate.
      expect(_byPanelKey('win'), findsOneWidget);
      expect(_byPanelKey('lose'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpAndSettle();
      expect(_byPanelKey('win'), findsNothing);
      expect(_byPanelKey('lose'), findsOneWidget);
      expect(find.text('lose'), findsOneWidget);
    },
  );
}
