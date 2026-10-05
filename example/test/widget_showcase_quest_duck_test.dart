import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/quest_board_panel.dart';
import 'package:roy_casual_kit_example/screens/widget_showcase_screen.dart';

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is CommonButton && widget.label == label,
);

/// Records every playSfx call; completes it on demand so the screen's
/// "duck" indicator can be observed while the SFX is still playing.
class _SpyAudioManager extends AudioManager {
  final calls = <({String file, bool duck})>[];

  @override
  Future<void> playSfx(
    String fileName, {
    double volume = 1.0,
    bool duck = false,
  }) async {
    calls.add((file: fileName, duck: duck));
  }
}

Future<void> _pumpShowcase(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 16600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: AppTranslations.fallback,
      fallbackLocale: AppTranslations.fallback,
      home: const WidgetShowcaseScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  tearDown(Get.reset);

  testWidgets(
    'QuestBoardPanel demo: "Win 1 match" đưa quest 2/3 lên 3/3 rồi mới nhận '
    'được thưởng, và tiến độ không vượt target',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('Win 3 matches'), findsOneWidget);
      expect(find.text('Use 1 booster'), findsOneWidget);

      // Quest "Use 1 booster" đã 1/1 nên nút nhận của nó bấm được; quest "Win 3
      // matches" mới 2/3 nên nút nhận bị khoá.
      final claimButtons = _button('Nhận thưởng');
      expect(claimButtons, findsNWidgets(2));
      expect(
        tester
            .widgetList<CommonButton>(claimButtons)
            .where((button) => button.onTap != null),
        hasLength(1),
      );

      await tester.tap(_button('Win 1 match').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widgetList<CommonButton>(claimButtons)
            .where((button) => button.onTap != null),
        hasLength(2),
        reason: 'quest Win 3 matches đạt 3/3 -> mở nút nhận',
      );

      // Bấm thêm lần nữa: đã đủ target, không được đẩy progress lên 4/3.
      await tester.tap(_button('Win 1 match').last);
      await tester.pump(const Duration(milliseconds: 100));
      final panel = tester.widget<QuestBoardPanel>(
        find.byType(QuestBoardPanel),
      );
      expect(
        panel.quests.singleWhere((quest) => quest.id == 'win_3').progress,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QuestBoardPanel demo: nhận thưởng đổi nút sang "Đã nhận" và khoá lại',
    (tester) async {
      await _pumpShowcase(tester);

      final claimable = find.byWidgetPredicate(
        (widget) =>
            widget is CommonButton &&
            widget.label == 'Nhận thưởng' &&
            widget.onTap != null,
      );
      expect(claimable, findsOneWidget);

      await tester.tap(claimable.last);
      await tester.pump(const Duration(milliseconds: 100));

      final claimed = _button('Đã nhận');
      expect(claimed, findsOneWidget);
      expect(tester.widget<CommonButton>(claimed).onTap, isNull);
      expect(claimable, findsNothing);

      // Quest còn lại (2/3) vẫn chưa nhận được — nhận 1 quest không lan sang
      // quest kia.
      expect(claimable, findsNothing);
      await tester.tap(_button('Win 1 match').last);
      // Hàng quest vừa đủ điều kiện chạy animation "pop" 300ms (ScaleTransition):
      // chờ xong để nút lên đúng kích thước và nhận được tap.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(claimable, findsOneWidget);

      // Nhận nốt quest thắng 3 trận: cả 2 quest đều ở trạng thái "Đã nhận".
      await tester.tap(claimable.last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(claimed, findsNWidgets(2));
      expect(claimable, findsNothing);
      final panel = tester.widget<QuestBoardPanel>(
        find.byType(QuestBoardPanel),
      );
      expect(panel.quests.every((quest) => quest.claimed), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audio duck demo: không có AudioManager thì bấm nút không đổi duckCount',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('duckCount: 0'), findsOneWidget);
      await tester.tap(_button('Play SFX (duck bgm)').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('duckCount: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('audio duck demo: có AudioManager thì phát SFX với duck=true', (
    tester,
  ) async {
    final audio =
        Get.put<AudioManager>(_SpyAudioManager(), permanent: true)
            as _SpyAudioManager;
    await _pumpShowcase(tester);

    await tester.tap(_button('Play SFX (duck bgm)').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(audio.calls, hasLength(1));
    expect(audio.calls.single.duck, isTrue);
    expect(audio.calls.single.file, 'audio/demo_sfx.mp3');
    // Fake playSfx không tự duck nên duckCount thật về lại 0 sau khi xong.
    expect(find.text('duckCount: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
