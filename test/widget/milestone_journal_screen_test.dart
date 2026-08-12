import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/milestone_journal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `MilestoneJournalScreen` (I72 + [[I87]]) — chưa có test widget nào.
///
/// Điểm cần khoá của I87: nút chia sẻ **chỉ hiện khi có mốc**. Chia sẻ một tấm
/// thẻ rỗng ra ngoài app còn tệ hơn không có nút.
late GameController ctrl;

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const MilestoneJournalScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
}

Finder get _shareButton => find.byKey(const Key('journey_share_button'));

void main() {
  tearDown(Get.reset);

  testWidgets('máy sạch vẫn có mốc: mở game hôm nay đã là 1 mốc', (
    tester,
  ) async {
    // Kỳ vọng ban đầu của tôi ("máy sạch thì feed rỗng") SAI. `_checkLoginStreak`
    // chạy trong `onInit` và đẩy `loginStreakCount` lên 1 ngay lần boot đầu, nên
    // `buildMilestoneJournal` luôn trả về ít nhất mốc login-streak.
    //
    // Hệ quả: nhánh `entries.isEmpty` của màn hình gần như **không với tới
    // được** trên thiết bị thật. Guard `if (entries.isNotEmpty)` quanh nút chia
    // sẻ vẫn giữ — nó rẻ và đúng — nhưng đừng đọc bộ test này như bằng chứng
    // nhánh rỗng đã được phủ.
    await _pump(tester);

    expect(find.text('milestone_journal_empty'.tr), findsNothing);
    expect(_shareButton, findsOneWidget);
  });

  testWidgets('có mốc -> liệt kê mốc và hiện nút chia sẻ', (tester) async {
    await _pump(tester, prefs: {StorageKeys.lastClaimDay: 100});

    expect(find.text('milestone_daily_claim'.tr), findsOneWidget);
    expect(_shareButton, findsOneWidget);
    expect(find.text('journey_share_action'.tr), findsWidgets);
  });

  testWidgets('nhiều mốc -> hiện đủ, không ném', (tester) async {
    await _pump(
      tester,
      prefs: {
        StorageKeys.lastClaimDay: 100,
        StorageKeys.lastSpinDay: 99,
        StorageKeys.lastGauntletDay: 98,
        StorageKeys.lastDailyChallengeDay: 97,
      },
    );

    expect(find.text('milestone_daily_claim'.tr), findsOneWidget);
    expect(find.text('milestone_spin_wheel'.tr), findsOneWidget);
    expect(find.text('milestone_gauntlet'.tr), findsOneWidget);
    expect(_shareButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('I87 — số ngày chơi', () {
    testWidgets('nạp từ save rồi CỘNG ngày hôm nay', (tester) async {
      // Boot hôm nay là một ngày chơi, nên 42 + 1. Không phải off-by-one.
      await _pump(
        tester,
        prefs: {
          StorageKeys.lastClaimDay: 100,
          StorageKeys.totalDaysPlayed: 42,
        },
      );

      expect(ctrl.totalDaysPlayed.value, 43);
      expect(StorageService.to.getInt(StorageKeys.totalDaysPlayed), 43);
    });

    testWidgets('cùng ngày mở lại KHÔNG cộng thêm', (tester) async {
      // Chốt chống lạm phát: `_checkLoginStreak` thoát sớm khi `prevDay == today`.
      final today =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      await _pump(
        tester,
        prefs: {
          StorageKeys.lastClaimDay: 100,
          StorageKeys.totalDaysPlayed: 42,
          StorageKeys.lastLoginEpochDay: today,
        },
      );

      expect(ctrl.totalDaysPlayed.value, 42);
    });

    testWidgets('save cũ chưa có bộ đếm -> bù về 1, không để 0', (
      tester,
    ) async {
      // Bắt được trên máy thật: người chơi đã mở game hôm nay TRƯỚC khi cập
      // nhật bản có bộ đếm sẽ rơi vào nhánh thoát sớm và thẻ chia sẻ hiện
      // "0 days".
      final today =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      await _pump(
        tester,
        prefs: {
          StorageKeys.lastClaimDay: 100,
          StorageKeys.lastLoginEpochDay: today,
          // không có totalDaysPlayed
        },
      );

      expect(ctrl.totalDaysPlayed.value, 1);
      expect(StorageService.to.getInt(StorageKeys.totalDaysPlayed), 1);
    });

    testWidgets('bù chỉ chạy khi đang là 0, không đè giá trị thật', (
      tester,
    ) async {
      final today =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      await _pump(
        tester,
        prefs: {
          StorageKeys.lastClaimDay: 100,
          StorageKeys.lastLoginEpochDay: today,
          StorageKeys.totalDaysPlayed: 77,
        },
      );

      expect(ctrl.totalDaysPlayed.value, 77);
    });

    testWidgets('KHÔNG reset khi đứt streak', (tester) async {
      // Đây là điểm khác biệt duy nhất so với `loginStreakCount`: vắng dài rồi
      // quay lại thì streak về 1, nhưng số ngày đã chơi là chuyện đã rồi.
      final today =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      await _pump(
        tester,
        prefs: {
          StorageKeys.lastClaimDay: 100,
          StorageKeys.totalDaysPlayed: 42,
          StorageKeys.loginStreakCount: 9,
          StorageKeys.lastLoginEpochDay: today - 30,
        },
      );

      expect(ctrl.loginStreakCount.value, 1, reason: 'streak phải đứt');
      expect(ctrl.totalDaysPlayed.value, 43);
    });
  });

  testWidgets('save hỏng: mốc kiểu sai -> vẫn dựng được', (tester) async {
    await _pump(
      tester,
      prefs: {
        StorageKeys.lastClaimDay: 'khong-phai-so',
        StorageKeys.totalDaysPlayed: 'rac',
      },
    );

    expect(find.byType(MilestoneJournalScreen), findsOneWidget);
    // Giá trị rác -> [[X28]] trả default 0, rồi boot hôm nay cộng 1.
    expect(ctrl.totalDaysPlayed.value, 1);
    expect(tester.takeException(), isNull);
  });
}
