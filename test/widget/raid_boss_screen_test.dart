import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/raid_boss_controller.dart';
import 'package:pop_star_blast/presentation/screens/raid_boss_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `RaidBossScreen` (I61) — `raid_boss_controller_test.dart` đã phủ phần
/// controller (rollover tuần/ngày, tiêu lượt, cộng damage, thưởng tuần). Phần
/// chưa ai kiểm là **màn hình**, và nó có một đặc điểm khó chịu: mọi thứ hiển
/// thị phụ thuộc **thứ trong tuần thật** (`isRaidActive`, Thứ 6–CN).
///
/// Test này không đọc thứ hiện tại mà **ép ngày** qua `maxEpochDaySeen`: đồng
/// hồ kẹp ([[X22]]) trả về `max(hôm nay, maxEpochDaySeen)`, nên gieo một mốc
/// tương lai là chọn được đúng thứ mình cần. Nhờ vậy cả hai nhánh
/// active/inactive đều chạy được mọi ngày trong năm, thay vì 3/7 số ngày xanh
/// và 4/7 số ngày bỏ qua.
late GameController gameCtrl;
late RaidBossController raidCtrl;

int get _todayEpochDay =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

/// Ngày epoch gần nhất **từ hôm nay trở đi** có trạng thái raid bằng [active].
///
/// Luôn tiến về phía trước: đồng hồ kẹp bỏ qua mọi mốc quá khứ, gieo ngày cũ
/// là không có tác dụng gì.
int _epochDayWithRaid({required bool active}) {
  for (var d = _todayEpochDay; d < _todayEpochDay + 8; d++) {
    if (isRaidActiveForEpochDay(d) == active) return d;
  }
  throw StateError('không tìm được ngày phù hợp trong 8 ngày tới');
}

Future<void> _pump(
  WidgetTester tester, {
  required bool raidActive,
  Map<String, Object> prefs = const {},
}) async {
  final day = _epochDayWithRaid(active: raidActive);
  SharedPreferences.setMockInitialValues({
    StorageKeys.maxEpochDaySeen: day,
    ...prefs,
  });
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const RaidBossScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  raidCtrl = Get.find<RaidBossController>();
}

/// Prefs của một sự kiện **đang chạy** với [damage] sát thương tích luỹ.
///
/// Phải khớp `raidBossEventWeek` với tuần của ngày đã ép, nếu không
/// `_loadAndRollover()` coi là tuần mới và xoá sạch damage ngay lúc boot.
Map<String, Object> _event(int damage, {bool raidActive = true, int? used}) {
  final day = _epochDayWithRaid(active: raidActive);
  return {
    StorageKeys.raidBossEventWeek: day ~/ 7,
    StorageKeys.raidBossTotalDamage: damage,
    StorageKeys.raidBossLastAttemptDay: day,
    StorageKeys.raidBossAttemptsUsed: ?used,
  };
}

Finder get _claimButton => find.byType(NeonButton);

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester, raidActive: true);
      expect(find.byType(RaidBossScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liệt kê đủ mọi mốc thưởng', (tester) async {
      await _pump(tester, raidActive: true);
      for (final tier in kRaidRewardTiers) {
        expect(
          find.text(
            'raid_boss_tier_req'.trParams({'dmg': '${tier.requiredDamage}'}),
          ),
          findsOneWidget,
          reason: 'thiếu mốc ${tier.requiredDamage} damage',
        );
      }
    });

    testWidgets('X31: nhãn xu dịch theo locale, không hard-code tiếng Việt', (
      tester,
    ) async {
      // Màn này chạy dưới locale 'en' nên nếu ai đó viết thẳng " xu" vào code
      // thì ca này đỏ ngay. Trước khi sửa, 21/22 ngôn ngữ đều thấy chữ Việt.
      await _pump(tester, raidActive: true);

      for (final tier in kRaidRewardTiers) {
        expect(
          find.text('${tier.coinReward} ${'coins_short'.tr}'),
          findsOneWidget,
        );
      }
      expect(find.textContaining(' xu'), findsNothing);
    });

    testWidgets('hiện số lượt còn lại trên tổng lượt/ngày', (tester) async {
      await _pump(tester, raidActive: true);
      expect(
        find.text(
          '${RaidBossController.maxDailyAttempts} / '
          '${RaidBossController.maxDailyAttempts}',
        ),
        findsOneWidget,
      );
    });
  });

  group('cửa sổ sự kiện (Thứ 6 - CN)', () {
    testWidgets('trong cửa sổ -> báo đang diễn ra', (tester) async {
      await _pump(tester, raidActive: true);

      expect(raidCtrl.isRaidActive, isTrue);
      expect(find.text('raid_boss_event_active'.tr), findsOneWidget);
      expect(find.text('raid_boss_event_inactive'.tr), findsNothing);
    });

    testWidgets('ngoài cửa sổ -> báo chưa diễn ra, không cho vào', (
      tester,
    ) async {
      await _pump(tester, raidActive: false);

      expect(raidCtrl.isRaidActive, isFalse);
      expect(find.text('raid_boss_event_inactive'.tr), findsOneWidget);
      expect(
        raidCtrl.canStartRaid(),
        isFalse,
        reason: 'còn lượt nhưng ngoài cuối tuần thì vẫn không được đánh',
      );
    });

    testWidgets('hết lượt trong ngày -> không cho vào dù đang trong cửa sổ', (
      tester,
    ) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(0, used: RaidBossController.maxDailyAttempts),
      );

      expect(raidCtrl.attemptsRemaining.value, 0);
      expect(raidCtrl.canStartRaid(), isFalse);
      expect(
        find.text('0 / ${RaidBossController.maxDailyAttempts}'),
        findsOneWidget,
      );
    });
  });

  group('mốc thưởng theo sát thương', () {
    testWidgets('chưa đủ mốc đầu -> chưa có mốc nào được tích', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.first.requiredDamage - 1),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(kRaidRewardTiers.length),
      );
    });

    testWidgets('đủ mốc giữa -> tích đúng số mốc đã qua', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers[1].requiredDamage),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(kRaidRewardTiers.length - 2),
      );
    });

    testWidgets('damage tăng trong lúc màn đang mở -> mốc tự tích thêm', (
      tester,
    ) async {
      await _pump(tester, raidActive: true, prefs: _event(0));
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      raidCtrl.recordDamage(kRaidRewardTiers.first.requiredDamage);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('nhận thưởng tuần', () {
    testWidgets('chưa đủ mốc đầu -> không hiện nút nhận', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.first.requiredDamage - 1),
      );

      expect(_claimButton, findsNothing);
    });

    testWidgets('đủ mốc đầu -> hiện nút nhận', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.first.requiredDamage),
      );

      expect(_claimButton, findsOneWidget);
    });

    testWidgets('nhận -> cộng đúng tổng xu của MỌI mốc đã qua', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.last.requiredDamage),
      );
      final coinsBefore = gameCtrl.coins.value;

      final claimed = raidCtrl.claimWeeklyReward(gameCtrl);

      final expected = kRaidRewardTiers
          .map((t) => t.coinReward)
          .reduce((a, b) => a + b);
      expect(claimed, expected);
      expect(gameCtrl.coins.value - coinsBefore, expected);
    });

    testWidgets('đã nhận tuần này -> không hiện nút nữa', (tester) async {
      final day = _epochDayWithRaid(active: true);
      await _pump(
        tester,
        raidActive: true,
        prefs: {
          ..._event(kRaidRewardTiers.last.requiredDamage),
          StorageKeys.raidBossRewardClaimedWeek: day ~/ 7,
        },
      );

      expect(_claimButton, findsNothing);
      expect(raidCtrl.canClaimWeeklyReward(), isFalse);
    });

    testWidgets('nhận hai lần không cộng thêm xu', (tester) async {
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.last.requiredDamage),
      );

      raidCtrl.claimWeeklyReward(gameCtrl);
      final afterFirst = gameCtrl.coins.value;

      expect(raidCtrl.claimWeeklyReward(gameCtrl), 0);
      expect(gameCtrl.coins.value, afterFirst);
    });

    testWidgets('nút nhận vẫn nằm đó sau khi nhận, nhưng bấm nữa vô hại', (
      tester,
    ) async {
      // Ghi lại đúng như đo được. `canClaimWeeklyReward()` đọc
      // `raidBossRewardClaimedWeek` từ storage — không phải observable — nên
      // `Obx` không biết gì khi nhận xong và nút chưa biến mất ngay.
      //
      // Không phải lỗ hổng: guard trong `claimWeeklyReward` chặn lần hai, xu
      // không nhân đôi (ca ngay trên chứng minh). Chỉ là hiển thị lỗi thời tới
      // lần rebuild sau. Cùng họ với [[X30]] nhưng không mất tiền, nên để lại
      // và chốt hành vi ở đây.
      await _pump(
        tester,
        raidActive: true,
        prefs: _event(kRaidRewardTiers.last.requiredDamage),
      );

      raidCtrl.claimWeeklyReward(gameCtrl);
      await tester.pump(const Duration(milliseconds: 250));
      final coinsAfter = gameCtrl.coins.value;

      expect(_claimButton, findsOneWidget);
      expect(raidCtrl.claimWeeklyReward(gameCtrl), 0);
      expect(gameCtrl.coins.value, coinsAfter);
    });
  });

  group('sang tuần mới', () {
    testWidgets('damage và lượt đều reset', (tester) async {
      final day = _epochDayWithRaid(active: true);
      await _pump(
        tester,
        raidActive: true,
        prefs: {
          StorageKeys.raidBossEventWeek: day ~/ 7 - 1,
          StorageKeys.raidBossTotalDamage: 9999,
          StorageKeys.raidBossAttemptsUsed: RaidBossController.maxDailyAttempts,
        },
      );

      expect(raidCtrl.totalDamageThisEvent.value, 0);
      expect(
        raidCtrl.attemptsRemaining.value,
        RaidBossController.maxDailyAttempts,
      );
      expect(_claimButton, findsNothing);
    });

    testWidgets('cùng tuần, sang ngày mới -> giữ damage, hoàn lượt', (
      tester,
    ) async {
      final day = _epochDayWithRaid(active: true);
      await _pump(
        tester,
        raidActive: true,
        prefs: {
          StorageKeys.raidBossEventWeek: day ~/ 7,
          StorageKeys.raidBossTotalDamage: 120,
          StorageKeys.raidBossLastAttemptDay: day - 1,
          StorageKeys.raidBossAttemptsUsed: RaidBossController.maxDailyAttempts,
        },
      );

      expect(
        raidCtrl.totalDamageThisEvent.value,
        120,
        reason: 'damage cộng dồn cả tuần, không reset theo ngày',
      );
      expect(
        raidCtrl.attemptsRemaining.value,
        RaidBossController.maxDailyAttempts,
      );
    });
  });

  group('save hỏng', () {
    testWidgets('số lượt đã dùng vượt trần -> kẹp về 0, không âm', (
      tester,
    ) async {
      await _pump(tester, raidActive: true, prefs: _event(0, used: 999));

      expect(raidCtrl.attemptsRemaining.value, 0);
      expect(
        find.text('0 / ${RaidBossController.maxDailyAttempts}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('damage âm -> không mở mốc nào, không hiện nút nhận', (
      tester,
    ) async {
      await _pump(tester, raidActive: true, prefs: _event(-500));

      expect(_claimButton, findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
