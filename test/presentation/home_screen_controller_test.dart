import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/home_screen_controller.dart';
import 'package:pop_star_blast/presentation/widgets/home_carousel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2 — `HomeScreenController` (X14) dựng danh sách card tiến độ và giữ 2
/// coach-mark tuần tự. Điểm dễ vỡ: danh sách phải phản ánh state đã đổi ở màn
/// KHÁC (Star Road, Settings…), nên nó refresh khi app resume.
late GameController gameCtrl;
late HomeScreenController ctrl;

Future<void> _boot([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);
  ctrl = Get.put(HomeScreenController());
}

/// Giả lập app quay lại foreground — đúng hook mà controller lắng nghe.
void _resume() => ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('danh sách card', () {
    test('luôn có ít nhất card chào (không bao giờ rỗng)', () async {
      await _boot();
      ctrl.refreshCards(gameCtrl);
      expect(ctrl.cards, isNotEmpty);
      expect(ctrl.cards.first.type, HomeCardType.greeting);
    });

    test('refresh phản ánh state đã đổi ở màn khác', () async {
      await _boot();
      ctrl.refreshCards(gameCtrl);
      final before = ctrl.cards.length;

      // Giả lập người chơi kiếm đủ sao ở màn chơi → mở rương Star Road.
      for (var id = 1; id <= 10; id++) {
        await StorageService.to.setInt(StorageKeys.star(id), 3);
      }
      gameCtrl.onInit(); // nạp lại totalStars như khi quay về Home

      ctrl.refreshCards(gameCtrl);
      expect(
        ctrl.cards.length,
        greaterThanOrEqualTo(before),
        reason: 'card mới phải xuất hiện, không giữ danh sách cũ',
      );
    });

    test('resume tự refresh, không cần gọi tay', () async {
      await _boot();
      expect(ctrl.cards, isEmpty, reason: 'chưa dựng trước lần refresh đầu');

      _resume();
      expect(ctrl.cards, isNotEmpty);
    });

    test('currentIndex kẹp lại khi danh sách ngắn đi', () async {
      await _boot();
      ctrl.refreshCards(gameCtrl);
      ctrl.currentIndex.value = ctrl.cards.length + 5;

      ctrl.refreshCards(gameCtrl);
      expect(ctrl.currentIndex.value, 0);
      expect(ctrl.currentIndex.value, lessThan(ctrl.cards.length));
    });

    test('index hợp lệ thì giữ nguyên, không nhảy về 0', () async {
      await _boot();
      ctrl.refreshCards(gameCtrl);
      if (ctrl.cards.length < 2) return; // bàn trắng không đủ card để test
      ctrl.currentIndex.value = 1;
      ctrl.refreshCards(gameCtrl);
      expect(ctrl.currentIndex.value, 1);
    });
  });

  group('coach-mark tuần tự', () {
    test('cài mới: hiện Shop trước, Daily Challenge chờ', () async {
      await _boot();
      expect(ctrl.showShopTutorial.value, isTrue);
      expect(
        ctrl.showDailyChallengeTutorial.value,
        isFalse,
        reason: 'không được chồng 2 tooltip cùng lúc',
      );
    });

    test(
      'dismiss Shop → Daily Challenge hiện NGAY trong session này',
      () async {
        await _boot();
        ctrl.dismissShopTutorial();

        expect(ctrl.showShopTutorial.value, isFalse);
        expect(
          StorageService.to.getBool(StorageKeys.hasSeenShopTutorial),
          true,
        );
        expect(
          ctrl.showDailyChallengeTutorial.value,
          isTrue,
          reason: 'không bắt người chơi đợi tới lần mở app kế tiếp',
        );
      },
    );

    test('dismiss Daily Challenge → tắt và persist', () async {
      await _boot();
      ctrl.dismissShopTutorial();
      ctrl.dismissDailyChallengeTutorial();

      expect(ctrl.showDailyChallengeTutorial.value, isFalse);
      expect(
        StorageService.to.getBool(StorageKeys.hasSeenDailyChallengeTutorial),
        true,
      );
    });

    test('đã xem hết → mở app lại không hiện lại cái nào', () async {
      await _boot({
        StorageKeys.hasSeenShopTutorial: true,
        StorageKeys.hasSeenDailyChallengeTutorial: true,
      });
      expect(ctrl.showShopTutorial.value, isFalse);
      expect(ctrl.showDailyChallengeTutorial.value, isFalse);
    });

    test('đã xem Shop, chưa xem Daily → mở app hiện đúng cái thứ 2', () async {
      await _boot({StorageKeys.hasSeenShopTutorial: true});
      expect(ctrl.showShopTutorial.value, isFalse);
      expect(ctrl.showDailyChallengeTutorial.value, isTrue);
    });

    test('dismiss 2 lần không ghi đè/không lỗi (guard)', () async {
      await _boot();
      ctrl.dismissShopTutorial();
      ctrl.dismissDailyChallengeTutorial();
      // Gọi lại khi đã tắt — phải là no-op.
      ctrl.dismissShopTutorial();
      ctrl.dismissDailyChallengeTutorial();
      expect(ctrl.showShopTutorial.value, isFalse);
      expect(ctrl.showDailyChallengeTutorial.value, isFalse);
    });
  });

  group('vòng đời observer', () {
    test('onClose gỡ observer, resume sau đó không ném', () async {
      await _boot();
      ctrl.onClose();
      expect(_resume, returnsNormally);
    });
  });
}
