import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/raid_boss_controller.dart';
import 'package:pop_star_blast/presentation/screens/raid_boss_screen.dart';
import 'package:pop_star_blast/presentation/widgets/token_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F17 — phần UI, trả nợ đã ghi khi đóng task lõi.
///
/// Trước batch này token có đầy đủ API + test logic nhưng người chơi chỉ dùng
/// được **một** trong ba đường tiêu, và không nhìn thấy số dư ở đâu ngoài
/// dialog nhiệm vụ. Tính năng vô hình là tính năng không tồn tại.
late GameController gameCtrl;

int get _today => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

/// Ngày epoch gần nhất từ hôm nay trở đi mà sự kiện Raid đang mở.
int get _raidActiveDay {
  for (var d = _today; d < _today + 8; d++) {
    if (isRaidActiveForEpochDay(d)) return d;
  }
  throw StateError('không tìm được ngày raid mở');
}

Future<void> _pumpChip(
  WidgetTester tester, {
  int tokens = 0,
  bool compact = false,
}) async {
  SharedPreferences.setMockInitialValues({StorageKeys.comboTokens: tokens});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(body: TokenChip(gameCtrl, compact: compact)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpRaid(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final day = _raidActiveDay;
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
}

Finder get _buyRaid => find.byKey(const Key('token_buy_raid'));

void main() {
  tearDown(Get.reset);

  group('chip số dư', () {
    testWidgets('hiện đúng số token', (tester) async {
      await _pumpChip(tester, tokens: 37);
      expect(find.text('37'), findsOneWidget);
    });

    testWidgets('0 token hiện 0, không phải ô trống', (tester) async {
      await _pumpChip(tester, tokens: 0);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('cập nhật ngay khi token đổi', (tester) async {
      await _pumpChip(tester, tokens: 5);
      gameCtrl.comboTokens.value = 9;
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('bản gọn nhỏ hơn bản thường', (tester) async {
      await _pumpChip(tester, tokens: 12, compact: true);
      final compact = tester.getSize(find.byKey(const Key('token_chip')));
      Get.reset();

      await _pumpChip(tester, tokens: 12);
      final full = tester.getSize(find.byKey(const Key('token_chip')));

      expect(compact.width, lessThan(full.width));
    });
  });

  group('mua lượt Raid Boss', () {
    testWidgets('không đủ token -> KHÔNG hiện nút', (tester) async {
      await _pumpRaid(tester, prefs: {StorageKeys.comboTokens: 0});
      expect(
        _buyRaid,
        findsNothing,
        reason: 'quảng cáo thứ bấm vào không ăn là tệ hơn không có nút',
      );
    });

    testWidgets('đủ token -> hiện nút', (tester) async {
      await _pumpRaid(tester, prefs: {StorageKeys.comboTokens: 999});
      expect(_buyRaid, findsOneWidget);
    });

    testWidgets('bấm -> trừ token, trần lượt tăng, nút biến mất', (
      tester,
    ) async {
      await _pumpRaid(tester, prefs: {StorageKeys.comboTokens: 999});
      final raidCtrl = Get.find<RaidBossController>();
      final beforeMax = raidCtrl.maxAttemptsToday;

      await tester.ensureVisible(_buyRaid);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(_buyRaid);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        gameCtrl.comboTokens.value,
        999 - GameController.tokenCostRaidAttempt,
      );
      expect(
        Get.find<RaidBossController>().maxAttemptsToday,
        beforeMax + 1,
        reason: 'mua lượt xong mà trần không đổi thì lượt mua đi đâu mất',
      );
      // Số HIỂN THỊ mới là thứ người chơi thấy. `maxAttemptsToday` là getter
      // đọc thẳng storage nên nó đúng ngay cả khi controller chưa nạp lại —
      // còn `attemptsRemaining` thì không. Mutation-check phát hiện: gỡ đoạn
      // nạp lại controller mà test cũ vẫn xanh, vì nó chỉ hỏi getter.
      final max = beforeMax + 1;
      expect(
        find.text('$max / $max'),
        findsOneWidget,
        reason: 'trả tiền xong vẫn thấy "3 / 4" là mua hụt',
      );
      expect(_buyRaid, findsNothing, reason: '1 lần/ngày');
    });

    testWidgets('đã mua hôm nay -> không hiện nút nữa', (tester) async {
      await _pumpRaid(
        tester,
        prefs: {
          StorageKeys.comboTokens: 999,
          StorageKeys.tokenRaidDay: _raidActiveDay,
        },
      );
      expect(_buyRaid, findsNothing);
      expect(gameCtrl.bonusRaidAttemptsToday, 1);
    });

    testWidgets('mẫu số lượt hiện theo trần thật, không phải hằng số', (
      tester,
    ) async {
      await _pumpRaid(
        tester,
        prefs: {
          StorageKeys.comboTokens: 999,
          StorageKeys.tokenRaidDay: _raidActiveDay,
        },
      );
      final max = RaidBossController.maxDailyAttempts + 1;
      expect(find.text('$max / $max'), findsOneWidget);
    });
  });
}
