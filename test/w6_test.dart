import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/story.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/story_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });

  tearDown(Get.reset);

  group('Endless mode', () {
    test('buildEndlessLevel: objective endless, board 8x8, lượt khởi đầu', () {
      final lv = buildEndlessLevel();
      expect(lv.objective, ObjectiveType.endless);
      expect(lv.rows, 8);
      expect(lv.cols, 8);
      expect(lv.moves, kEndlessStartMoves);
    });

    test('startEndless đặt cờ + reset state', () {
      c.startEndless();
      expect(c.isEndless.value, isTrue);
      expect(c.movesLeft.value, kEndlessStartMoves);
      expect(c.endlessStage.value, 1);
      expect(c.score.value, 0);
      expect(c.level.objective, ObjectiveType.endless);
      expect(c.hasWon, isFalse); // endless không bao giờ "win"
    });

    test('ghép lớn hoàn lượt (stage thấp): match-5 +2, match-4 +1', () {
      c.startEndless();
      final m0 = c.movesLeft.value;
      c.addScore(5, 1); // gemsCleared 5 → +2
      expect(c.movesLeft.value, m0 + 2);
      final m1 = c.movesLeft.value;
      c.addScore(4, 1); // gemsCleared 4 → +1
      expect(c.movesLeft.value, m1 + 1);
      c.addScore(3, 1); // gemsCleared 3 → +0
      expect(c.movesLeft.value, m1 + 1);
    });

    test('stage tăng theo điểm + lưu high score', () {
      c.startEndless();
      // dồn điểm vượt 1 mốc stage
      c.addScore(kEndlessStageScore ~/ 10, 1); // 150 gems * 10 = 1500đ
      expect(c.score.value, greaterThanOrEqualTo(kEndlessStageScore));
      expect(c.endlessStage.value, greaterThanOrEqualTo(2));
      expect(c.endlessHigh.value, c.score.value);
    });

    test('hết lượt → lose, KHÔNG đụng tiến trình màn thường', () {
      c.startEndless();
      c.addScore(10, 1); // có điểm
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.highScores, isEmpty); // không lưu high score level
      expect(c.unlockedLevel.value, 1); // không mở khoá màn
      expect(c.endlessHigh.value, greaterThan(0)); // có lưu high score endless
    });

    test('endless không nằm trong vòng xoay mục tiêu 100 màn', () {
      expect(kRotatingObjectives, isNot(contains(ObjectiveType.endless)));
      expect(kLevels.map((l) => l.objective),
          isNot(contains(ObjectiveType.endless)));
    });
  });

  group('Story / Episode', () {
    test('kStory có 15 beat (5 thế giới CÓ cốt truyện × 3 thời điểm)', () {
      expect(kStory.length, kStoryWorlds * StoryTrigger.values.length);
      expect(kStory.length, 15);
      // chỉ 5 thế giới đầu có cốt truyện; 6-8 (Wave 15) vào thẳng màn.
      for (final w in kWorlds.where((w) => w.index <= kStoryWorlds)) {
        for (final t in StoryTrigger.values) {
          expect(storyBeatFor(t, w.index), isNotNull);
        }
      }
      for (final w in kWorlds.where((w) => w.index > kStoryWorlds)) {
        for (final t in StoryTrigger.values) {
          expect(storyBeatFor(t, w.index), isNull);
        }
      }
    });

    test('trigger bắt đầu màn: intro ở startLevel, mid ở giữa, null nơi khác', () {
      for (final w in kWorlds) {
        expect(storyStartTriggerFor(w.startLevel), StoryTrigger.intro);
        expect(storyStartTriggerFor(w.startLevel + kWorldSize ~/ 2),
            StoryTrigger.mid);
      }
      expect(storyStartTriggerFor(2), isNull); // màn thường
    });

    test('StoryController maybeShow chỉ mở 1 lần (đánh dấu seen)', () {
      final s = Get.put(StoryController());
      expect(s.maybeShow(StoryTrigger.intro, 1), isTrue);
      expect(s.open.value, isTrue);
      s.skip(); // đánh dấu seen
      expect(s.open.value, isFalse);
      expect(s.maybeShow(StoryTrigger.intro, 1), isFalse); // đã xem
    });

    test('maybeShow chạy onComplete khi xem xong', () {
      final s = Get.put(StoryController());
      var done = false;
      s.maybeShow(StoryTrigger.intro, 2, onComplete: () => done = true);
      s.next(); // sang dòng 2
      s.next(); // hết dòng → finish
      expect(done, isTrue);
      expect(s.open.value, isFalse);
    });
  });

  group('Theme theo thế giới', () {
    test('accentForWorld map đúng 5 màu neon', () {
      expect(NeonTheme.accentForWorld(1), NeonTheme.cyan);
      expect(NeonTheme.accentForWorld(2), NeonTheme.magenta);
      expect(NeonTheme.accentForWorld(3), NeonTheme.lime);
      expect(NeonTheme.accentForWorld(4), NeonTheme.orange);
      expect(NeonTheme.accentForWorld(5), NeonTheme.purple);
    });

    test('worldOfLevel trả đúng thế giới', () {
      expect(worldOfLevel(1).index, 1);
      expect(worldOfLevel(20).index, 1);
      expect(worldOfLevel(21).index, 2);
      expect(worldOfLevel(100).index, 5);
    });
  });
}
