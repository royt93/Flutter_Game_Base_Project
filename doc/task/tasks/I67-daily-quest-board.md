# I67 — Daily Quest Board

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu

Mỗi ngày hệ thống chọn cố định 3 nhiệm vụ nhỏ từ 1 pool cố định, theo
epoch-day (mọi player thấy đúng cùng 1 bộ 3 trong ngày). Mỗi quest có tiến
độ + thưởng xu riêng, nhận độc lập. Hết ngày reset về 3 quest mới (có thể
trùng entry cũ trong pool, không bắt buộc khác 100%).

## Vì sao

Khác Weekly Goal (I50 — 1 mục tiêu/tuần, cộng dồn xuyên mode) và Daily
Reward Streak / Daily Spin (điểm danh/random theo ngày, không có khái niệm
"nhiệm vụ" gắn objective cụ thể) — I67 tạo lý do quay lại app *nhiều lần
trong ngày* để hoàn thành đủ 3 mục tiêu ngắn, không trùng lặp với các hệ
thống theo-ngày đã có (Login Streak Calendar, Daily Reward, Daily Spin,
Lucky Color).

## Acceptance criteria

- [ ] `lib/data/daily_quests.dart` mới (pure logic, giống
  `lib/data/lucky_color.dart` + `gauntlet_modifiers.dart`):
  ```dart
  enum QuestKind { popGems, winAnyMode, threeStarLevel }

  class DailyQuest {
    final QuestKind kind;
    final int target;
    final int coinReward;
    final String nameKey;
    const DailyQuest({
      required this.kind,
      required this.target,
      required this.coinReward,
      required this.nameKey,
    });
  }

  const List<DailyQuest> kDailyQuestPool = [/* 7-8 template, kind/target/
      reward khác nhau, vd popGems 30/60/100, winAnyMode 1/2, threeStarLevel 1 */];

  /// Chọn đúng 3 quest cho [epochDay], seeded (`Random(epochDay)`), không
  /// trùng index trong cùng 1 ngày. Thuần — không đọc storage, không gọi
  /// `DateTime.now()`.
  List<DailyQuest> questsForDay(int epochDay);
  ```
- [ ] `GameController` thêm `RxList<int> dailyQuestProgress` (3 phần tử,
  song song `questsForDay(currentDay)`), `RxSet<int> dailyQuestClaimed`
  (index đã nhận thưởng trong ngày), lưu/khôi phục qua `StorageKeys` mới.
- [ ] Đầu mỗi lần app tính lại ngày hiện tại: nếu khác
  `StorageKeys.dailyQuestDay` đã lưu → reset `dailyQuestProgress = [0,0,0]`,
  reset `dailyQuestClaimed`, lưu ngày mới, tính lại `questsForDay`.
- [ ] Hook tiến độ tại đúng 3 điểm đã có sẵn trong `GameController` (không
  thêm hook mới vào `pop_star_game.dart`):
  - `registerPop(groupSize)` → cộng `groupSize` vào mọi quest active có
    `kind == QuestKind.popGems`.
  - `checkEnd(cleared)` khi thắng (bất kỳ mode) → +1 vào quest
    `kind == QuestKind.winAnyMode`.
  - `checkEnd(cleared)` khi thắng campaign VÀ đạt 3 sao → +1 vào quest
    `kind == QuestKind.threeStarLevel`.
- [ ] Khi 1 quest đạt `target`: hiện nút nhận thưởng riêng cho quest đó
  (không tự động cộng xu); bấm xong thêm index vào `dailyQuestClaimed`,
  chặn nhận 2 lần.
- [ ] UI: panel/dialog liệt kê 3 quest hôm nay, thanh tiến độ/target, nút
  nhận từng cái — theo "Dialog pattern" trong CLAUDE.md nếu render trong
  `GameScreen`.
- [ ] Unit test `test/data/daily_quests_test.dart`: `questsForDay(epochDay)`
  xác định + luôn đúng 3 phần tử, cùng `epochDay` luôn ra cùng bộ 3. Test
  progress-reset-khi-qua-ngày-mới và chặn nhận thưởng 2 lần/ngày cho cùng
  quest (đặt cùng file hoặc file controller test tương ứng).
- [ ] i18n đủ 22 locale cho `nameKey` mọi entry trong `kDailyQuestPool` +
  text UI (tiêu đề panel, nút nhận).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Không thêm hook mới vào `pop_star_game.dart` — cả 3 `QuestKind` đều bám
  đúng 2 điểm gọi đã tồn tại (`registerPop`, `checkEnd`).
- `questsForDay` PHẢI thuần để test được xác định — nhận `epochDay` làm
  tham số, không đọc storage/thời gian hệ thống bên trong.
- Tách biệt hoàn toàn `StorageKeys` khỏi Weekly Goal (I50) và Daily
  Reward/Spin hiện có — không tái dùng field nào của 2 hệ thống đó.

DoD chung: `../README.md`.
