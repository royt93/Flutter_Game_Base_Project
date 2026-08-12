import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/season_screen.dart';
import 'package:pop_star_blast/presentation/widgets/pressable_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SeasonScreen` (I6) — chưa có test widget nào.
///
/// Đáng test vì đây là một trong số ít màn **phát coin và booster thật**, và
/// mốc đã nhận chỉ được ghi bằng một bit trong `claimedSeasonMask`. Sai bit
/// hoặc sai thứ tự ghi là nhận lại được cùng một mốc.
///
/// Khác `SkyShrineScreen` ([[X30]]): `_SeasonRow` nhận `seasonPoints`,
/// `claimed`, `canClaim` qua **tham số** dựng trong closure của `Obx` cha, nên
/// phạm vi theo dõi đúng. Giữ nguyên kiểu đó khi sửa màn này.
late GameController ctrl;

const _milestones = GameController.seasonMilestones;
const _rewards = GameController.seasonRewards;

/// Chỉ số mốc đầu tiên thưởng coin và mốc đầu tiên thưởng booster.
int get _coinIdx => _rewards.indexWhere((r) => r.type == 'coins');
int get _boosterIdx => _rewards.indexWhere((r) => r.type != 'coins');

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
      home: const SeasonScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Prefs cho một mùa **đang chạy** với [points] điểm.
///
/// Phải ghi `lastSeasonIndex` khớp mùa hiện tại, nếu không `_checkSeasonRollover()`
/// coi đây là mùa mới và xoá sạch điểm ngay lúc boot — mọi ca kiểm mốc sẽ đọc
/// ra 0 điểm mà không có dấu hiệu gì.
Map<String, Object> _season(int points, {int mask = 0}) => {
  StorageKeys.seasonPoints: points,
  StorageKeys.claimedSeasonMask: mask,
  StorageKeys.lastSeasonIndex: _seasonIndexNow,
};

/// Mùa hiện tại, tính thẳng từ đồng hồ — **không** hỏi `GameController`.
///
/// `currentSeasonIndex` đi qua `todayEpochDay()` vốn đọc `StorageService`, mà
/// map prefs này phải dựng xong TRƯỚC khi `_pump` đăng ký service. Bản đầu gọi
/// `GameController().currentSeasonIndex` ở đây và 17/19 ca đỏ cùng lúc.
///
/// Trùng khớp vì prefs luôn sạch: `maxEpochDaySeen = 0` nên đồng hồ kẹp trả về
/// đúng ngày thật.
int get _seasonIndexNow =>
    (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000) ~/
    GameController.seasonLengthDays;

/// Thẻ của mốc thứ [i] — neo theo nhãn mốc, `.first` là Container gần nhất
/// bọc nhãn đó (chính là thẻ), không phải khung ngoài cùng của ListView.
Finder _row(int i) => find
    .ancestor(
      of: find.text('${_milestones[i]} ${'season_points'.tr}'),
      matching: find.byType(Container),
    )
    .first;

Finder _claimButton(int i) =>
    find.descendant(of: _row(i), matching: find.byType(PressableScale));

Future<void> _tapClaim(WidgetTester tester, int i) async {
  final f = _claimButton(i);
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(SeasonScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liệt kê đủ mọi mốc mùa', (tester) async {
      await _pump(tester);
      for (final m in _milestones) {
        expect(
          find.text('$m ${'season_points'.tr}'),
          findsOneWidget,
          reason: 'thiếu mốc $m',
        );
      }
    });

    testWidgets('mốc chưa đạt hiện tiến độ hiện tại/mục tiêu', (tester) async {
      await _pump(tester, prefs: _season(10));
      expect(find.text('10/${_milestones.first}'), findsOneWidget);
    });

    testWidgets('mốc đã nhận hiện nhãn "đã nhận", không còn nút', (
      tester,
    ) async {
      await _pump(tester, prefs: _season(_milestones.last, mask: 1));

      expect(find.text('ach_claimed'.tr), findsOneWidget);
      expect(
        _claimButton(0),
        findsNothing,
        reason: 'còn nút là còn đường bấm lại',
      );
    });
  });

  group('mốc chưa đạt', () {
    testWidgets('thiếu đúng 1 điểm -> bấm không ăn', (tester) async {
      await _pump(tester, prefs: _season(_milestones.first - 1));
      final coinsBefore = ctrl.coins.value;

      await _tapClaim(tester, 0);

      expect(ctrl.isSeasonClaimed(0), isFalse);
      expect(ctrl.coins.value, coinsBefore);
    });

    testWidgets('claimSeason cũng chặn, không chỉ UI', (tester) async {
      // Nút khoá có `onTap: null` nên ca bấm ở trên không chạm tới guard trong
      // controller. Gọi thẳng để khoá tuyến phòng thủ thứ hai.
      await _pump(tester, prefs: _season(0));
      expect(ctrl.claimSeason(0), isFalse);
      expect(ctrl.claimedSeasonMask.value, 0);
    });
  });

  group('nhận mốc', () {
    testWidgets('đủ điểm -> nhận coin đúng số, đánh dấu đã nhận', (
      tester,
    ) async {
      final i = _coinIdx;
      await _pump(tester, prefs: _season(_milestones[i]));
      final coinsBefore = ctrl.coins.value;

      await _tapClaim(tester, i);

      expect(ctrl.isSeasonClaimed(i), isTrue);
      expect(
        ctrl.coins.value - coinsBefore,
        _rewards[i].amount * ctrl.weekendCoinMultiplier,
        reason: 'so với hệ số cuối tuần đang chạy, không hard-code x1',
      );
    });

    testWidgets('vừa đúng mốc (không dư điểm) là nhận được', (tester) async {
      await _pump(tester, prefs: _season(_milestones.first));
      expect(ctrl.canClaimSeason(0), isTrue);

      await _tapClaim(tester, 0);

      expect(ctrl.isSeasonClaimed(0), isTrue);
    });

    testWidgets('mốc thưởng booster -> cộng booster, KHÔNG cộng coin', (
      tester,
    ) async {
      final i = _boosterIdx;
      await _pump(tester, prefs: _season(_milestones[i]));
      final coinsBefore = ctrl.coins.value;
      final reward = _rewards[i];
      final before = switch (reward.type) {
        'bomb' => ctrl.bombCount.value,
        'shuffle' => ctrl.shuffleCount.value,
        _ => ctrl.undoCount.value,
      };

      await _tapClaim(tester, i);

      final after = switch (reward.type) {
        'bomb' => ctrl.bombCount.value,
        'shuffle' => ctrl.shuffleCount.value,
        _ => ctrl.undoCount.value,
      };
      expect(after - before, reward.amount);
      expect(ctrl.coins.value, coinsBefore);
    });

    testWidgets('nhận xong nút biến mất, không bấm lại được', (tester) async {
      await _pump(tester, prefs: _season(_milestones.first));

      await _tapClaim(tester, 0);
      final coinsAfterFirst = ctrl.coins.value;

      expect(_claimButton(0), findsNothing);
      expect(ctrl.claimSeason(0), isFalse);
      expect(ctrl.coins.value, coinsAfterFirst);
    });

    testWidgets('nhận mốc cao không tự nhận luôn mốc thấp', (tester) async {
      // Bit riêng cho từng mốc: nhận mốc 2 không được set nhầm bit 0/1.
      await _pump(tester, prefs: _season(_milestones.last));

      await _tapClaim(tester, 2);

      expect(ctrl.isSeasonClaimed(2), isTrue);
      expect(ctrl.isSeasonClaimed(0), isFalse);
      expect(ctrl.isSeasonClaimed(1), isFalse);
      expect(_claimButton(0), findsOneWidget);
    });

    testWidgets('nhận hết mọi mốc -> mask đủ bit, không còn nút nào', (
      tester,
    ) async {
      await _pump(tester, prefs: _season(_milestones.last));

      for (var i = 0; i < _milestones.length; i++) {
        await _tapClaim(tester, i);
      }

      expect(ctrl.claimedSeasonMask.value, (1 << _milestones.length) - 1);
      expect(find.byType(PressableScale), findsNothing);
    });

    testWidgets('mask và coin được persist ngay', (tester) async {
      final i = _coinIdx;
      await _pump(tester, prefs: _season(_milestones[i]));

      await _tapClaim(tester, i);

      final store = StorageService.to;
      expect(store.getInt(StorageKeys.claimedSeasonMask), 1 << i);
      expect(store.getInt(StorageKeys.coins), ctrl.coins.value);
    });

    testWidgets('hiệu ứng xu bay hiện ra sau khi nhận', (tester) async {
      await _pump(tester, prefs: _season(_milestones.first));
      expect(find.byKey(const ValueKey('season-fly-0')), findsNothing);

      await _tapClaim(tester, 0);

      expect(find.byKey(const ValueKey('season-fly-0')), findsOneWidget);
    });
  });

  group('sang mùa mới', () {
    testWidgets('điểm và mốc đã nhận đều reset về 0', (tester) async {
      // `lastSeasonIndex` của mùa trước → `_checkSeasonRollover()` phải dọn.
      await _pump(
        tester,
        prefs: {
          StorageKeys.seasonPoints: 999,
          StorageKeys.claimedSeasonMask: (1 << _milestones.length) - 1,
          StorageKeys.lastSeasonIndex: _seasonIndexNow - 1,
        },
      );

      expect(ctrl.seasonPoints.value, 0);
      expect(ctrl.claimedSeasonMask.value, 0);
      expect(find.text('0/${_milestones.first}'), findsOneWidget);
    });

    testWidgets('reset được ghi xuống đĩa, không chỉ trong bộ nhớ', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs: {
          StorageKeys.seasonPoints: 999,
          StorageKeys.lastSeasonIndex: _seasonIndexNow - 1,
        },
      );

      final store = StorageService.to;
      await store.flush();
      expect(store.getInt(StorageKeys.seasonPoints), 0);
      expect(
        store.getInt(StorageKeys.lastSeasonIndex),
        _seasonIndexNow,
        reason: 'không ghi mốc mùa mới thì lần boot sau lại reset lần nữa',
      );
    });

    testWidgets('cùng mùa -> KHÔNG reset', (tester) async {
      await _pump(tester, prefs: _season(120, mask: 1));

      expect(ctrl.seasonPoints.value, 120);
      expect(ctrl.claimedSeasonMask.value, 1);
    });
  });

  group('save hỏng', () {
    testWidgets('mask bật hết trong khi 0 điểm -> hiện đã nhận, không ném', (
      tester,
    ) async {
      // Save không nhất quán (sửa tay hoặc kill app giữa 2 lệnh ghi). Màn hình
      // phải sống được và tuyệt đối không phát bù.
      await _pump(
        tester,
        prefs: _season(0, mask: (1 << _milestones.length) - 1),
      );
      final coinsBefore = ctrl.coins.value;

      expect(find.byType(PressableScale), findsNothing);
      expect(ctrl.claimSeason(0), isFalse);
      expect(ctrl.coins.value, coinsBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('điểm âm -> không mốc nào mở, không ném', (tester) async {
      await _pump(tester, prefs: _season(-500));

      expect(ctrl.canClaimSeason(0), isFalse);
      expect(find.byType(SeasonScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
