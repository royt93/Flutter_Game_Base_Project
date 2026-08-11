import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/pass_and_play.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/pass_and_play_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2 — `PassAndPlayController` (I59) điều phối 2 lượt hot-seat trên **cùng
/// một bàn gốc**. Điểm mấu chốt: bàn gốc là immutable-by-convention, mỗi lượt
/// nhận một deep copy vì `PopStarGame` mutate thẳng vào grid được truyền.
/// Không có test nào trước batch này, mà đây đúng là chỗ dễ vỡ nhất.
late GameController gameCtrl;
late PassAndPlayController ctrl;

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);
  ctrl = Get.put(PassAndPlayController(gameCtrl));
}

/// Kết thúc lượt hiện tại với [score]. Kết thúc màn là bất đồng bộ qua
/// `ever(gameCtrl.ended, …)` nên phải đi qua `checkEnd`.
void _endTurnWith(int score) {
  gameCtrl.ended.value = false;
  gameCtrl.score.value = score;
  gameCtrl.checkEnd(false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bắt đầu trận', () {
    test('startDuel đặt lượt 1, xoá điểm 2 bên, mode passAndPlay', () async {
      await _boot();
      ctrl.player1Score.value = 999;
      ctrl.player2Score.value = 888;
      ctrl.completed.value = true;

      ctrl.startDuel();

      expect(ctrl.currentPlayer.value, 1);
      expect(ctrl.player1Score.value, 0);
      expect(ctrl.player2Score.value, 0);
      expect(ctrl.awaitingHandoff.value, isFalse);
      expect(ctrl.completed.value, isFalse);
      expect(gameCtrl.mode.value, GameMode.passAndPlay);
      expect(gameCtrl.passAndPlayBaseGrid, isNotNull);
    });
  });

  group('bàn gốc không được mutate giữa 2 lượt', () {
    test('mỗi lượt nhận deep copy, sửa bản chơi không đụng bản gốc', () async {
      await _boot();
      ctrl.startDuel();

      final base = gameCtrl.passAndPlayBaseGrid!;
      final baseSnapshot = base.map((r) => List<int>.from(r)).toList();
      final turn1 = gameCtrl.passAndPlayGrid!;

      // Mô phỏng engine mutate bàn đang chơi (pop/gravity ghi thẳng vào grid).
      turn1[0][0] = -999;
      expect(
        base[0][0],
        baseSnapshot[0][0],
        reason: 'bàn gốc phải miễn nhiễm với thay đổi của lượt đang chơi',
      );

      _endTurnWith(500);
      ctrl.beginPlayer2();

      final turn2 = gameCtrl.passAndPlayGrid!;
      expect(
        turn2,
        equals(baseSnapshot),
        reason:
            'người 2 phải nhận đúng bàn gốc nguyên vẹn, không phải bàn đã '
            'bị người 1 chơi dở',
      );
      expect(identical(turn2, base), isFalse, reason: 'phải là bản sao');
    });

    test('hai lượt là hai object khác nhau', () async {
      await _boot();
      ctrl.startDuel();
      final turn1 = gameCtrl.passAndPlayGrid;
      _endTurnWith(100);
      ctrl.beginPlayer2();
      expect(identical(gameCtrl.passAndPlayGrid, turn1), isFalse);
    });
  });

  group('luân phiên lượt', () {
    test('hết lượt 1 → chờ chuyển máy, chưa xong trận', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(300);

      expect(ctrl.player1Score.value, 300);
      expect(ctrl.awaitingHandoff.value, isTrue);
      expect(ctrl.completed.value, isFalse);
      expect(ctrl.currentPlayer.value, 1, reason: 'chỉ đổi khi beginPlayer2()');
    });

    test('beginPlayer2 chuyển sang người 2 và reset điểm ván', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(300);
      ctrl.beginPlayer2();

      expect(ctrl.currentPlayer.value, 2);
      expect(ctrl.awaitingHandoff.value, isFalse);
      expect(gameCtrl.score.value, 0);
      expect(gameCtrl.ended.value, isFalse);
    });

    test(
      'beginPlayer2 khi chưa chờ chuyển máy → không làm gì (guard)',
      () async {
        await _boot();
        ctrl.startDuel();
        ctrl.beginPlayer2();
        expect(ctrl.currentPlayer.value, 1);
      },
    );

    test('hết lượt 2 → completed, không còn chờ chuyển máy', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(300);
      ctrl.beginPlayer2();
      _endTurnWith(450);

      expect(ctrl.player1Score.value, 300);
      expect(ctrl.player2Score.value, 450);
      expect(ctrl.completed.value, isTrue);
      expect(ctrl.awaitingHandoff.value, isFalse);
    });
  });

  group('phân định kết quả', () {
    test('người 1 điểm cao hơn → thắng', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(900);
      ctrl.beginPlayer2();
      _endTurnWith(100);
      expect(ctrl.outcome, DuelOutcome.player1);
    });

    test('người 2 điểm cao hơn → thắng', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(100);
      ctrl.beginPlayer2();
      _endTurnWith(900);
      expect(ctrl.outcome, DuelOutcome.player2);
    });

    test('bằng điểm → hoà', () async {
      await _boot();
      ctrl.startDuel();
      _endTurnWith(500);
      ctrl.beginPlayer2();
      _endTurnWith(500);
      expect(ctrl.outcome, DuelOutcome.draw);
    });
  });

  group('cô lập với progress campaign', () {
    test('trận đấu không cộng sao/xu/mở khoá level', () async {
      await _boot();
      final coinsBefore = gameCtrl.coins.value;
      final unlockedBefore = gameCtrl.unlockedLevel.value;

      ctrl.startDuel();
      _endTurnWith(99999);
      ctrl.beginPlayer2();
      _endTurnWith(99999);

      expect(gameCtrl.coins.value, coinsBefore);
      expect(gameCtrl.unlockedLevel.value, unlockedBefore);
      expect(gameCtrl.starsEarned.value, 0);
    });

    test('ended ở mode khác không đụng state trận', () async {
      await _boot();
      ctrl.startDuel();

      gameCtrl.startSideMode(GameMode.zen);
      gameCtrl.checkEnd(true);

      expect(ctrl.player1Score.value, 0);
      expect(ctrl.awaitingHandoff.value, isFalse);
      expect(ctrl.completed.value, isFalse);
    });
  });
}
