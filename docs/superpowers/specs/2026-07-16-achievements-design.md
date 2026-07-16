# Achievements system — design spec

**Ngày:** 2026-07-16 · **Task ID dự kiến:** I22 (tiếp nối I1-I21) · **Epic:** Meta/retention

## Mục tiêu
Thêm 1 hệ thống thành tựu (achievements) hoàn toàn vanity — không ảnh hưởng
gameplay/pay-to-win — để tăng động lực chơi dài hạn ngoài 200 level campaign
đã có. Tách biệt hoàn toàn khỏi Relic/Perk (F14, vốn có tác động gameplay).

## Phạm vi
- Danh sách cố định ~20-25 thành tựu, mỗi cái unlock **đúng 1 lần**, không tier.
- Thưởng: cộng coin 1 lần (dùng lại hệ coin economy hiện có, không thêm
  currency mới).
- Không thêm ads/IAP/analytics — đúng ranh giới đã chốt trước đó (loại trừ
  I19/I20).

## 1. Data model — `lib/data/achievements.dart`
```dart
enum AchievementMetric {
  totalGemsPopped,
  maxComboEver,
  levelsThreeStarred,
  boardsFullyCleared,
  totalBoostersUsed,
}

class Achievement {
  const Achievement({
    required this.id,
    required this.metric,
    required this.threshold,
    required this.coinReward,
    required this.titleKey,
    required this.descKey,
  });
  final String id; // vd 'gems_1000'
  final AchievementMetric metric;
  final int threshold;
  final int coinReward;
  final String titleKey; // key i18n
  final String descKey;
}

const List<Achievement> kAchievements = [ /* ~20-25 mốc, rải đều theo 5 metric */ ];
```
Mỗi metric có 4-5 mốc tăng dần (vd `totalGemsPopped`: 500 / 2.000 / 10.000 /
50.000 / 200.000) để cộng đủ ~20-25 item mà không cần cơ chế tier riêng.

## 2. Counter tích lũy đời — `GameController`
Thêm 5 field `RxInt` mới + `StorageKeys` tương ứng
(`totalGemsPopped`, `maxComboEver`, `levelsThreeStarred`, `boardsFullyCleared`,
`totalBoostersUsed`). Cộng dồn tại các điểm hiện có, không đổi luồng chính:

- `registerPop(int baseScore, {int groupSize = 1})` — thêm tham số **named,
  có default 1** (không phá 8 call site test hiện có trong
  `test/presentation/game_controller_test.dart` đang gọi `registerPop(10)`
  không kèm groupSize) để cộng vào `totalGemsPopped`. 2 call site thật trong
  `pop_star_game.dart:457,580` (đã biết `group.length` sẵn tại chỗ gọi) truyền
  `groupSize: group.length`. `maxComboEver = max(maxComboEver, comboCount)`
  ngay sau khi `comboCount.value++`.
- `checkEnd(boardCleared)` — khi `boardCleared == true`: `boardsFullyCleared++`.
  Trong `_saveBestScore()` (dòng 672-683, đã đọc `bestStar` trước khi ghi đè
  `StorageKeys.star(id)`): nếu `starsEarned.value == 3 && bestStar < 3` →
  `levelsThreeStarred++` — tận dụng đúng điểm so sánh có sẵn, tránh cộng lặp
  khi replay level đã 3-sao.
- `useBomb/useShuffle/useUndo/useRainbow/useSwap/useFreeze` — mỗi lần dùng
  thành công (nhánh sau `if (!activeGame!.trigger...()) return;`) →
  `totalBoostersUsed++`.

Tất cả 5 counter persist ngay lập tức qua `StorageService.to.setInt` (cùng
pattern `_grant`), và được `remove` trong `resetProgress()`.

## 3. Cơ chế unlock
```dart
final unlockedAchievementIds = <String>{}.obs; // load từ StorageKeys.unlockedAchievements (CSV, giống activePerks)
final justUnlockedAchievement = Rxn<Achievement>();

void _checkAchievements() {
  for (final a in kAchievements) {
    if (unlockedAchievementIds.contains(a.id)) continue;
    if (_metricValue(a.metric) < a.threshold) continue;
    unlockedAchievementIds.add(a.id);
    StorageService.to.setString(StorageKeys.unlockedAchievements, unlockedAchievementIds.join(','));
    coins.value += a.coinReward * weekendCoinMultiplier;
    StorageService.to.setInt(StorageKeys.coins, coins.value);
    justUnlockedAchievement.value = a; // UI lắng nghe, tự set null sau khi xử lý
  }
}
```
`_checkAchievements()` gọi ở cuối mỗi điểm cộng counter ở trên (sau
`registerPop`, sau `checkEnd`, sau mỗi `use*` thành công). Vì tối đa 25 item,
loop tuyến tính không cần tối ưu.

`justUnlockedAchievement` theo đúng pattern `justUnlocked`/`ended` đã có
(Rx để consumer lắng nghe async, tự clear sau khi xử lý) — không dùng
`Get.dialog`/`showDialog` (no-op trong Flame full-screen app theo convention
dự án).

## 4. UI
- **`AchievementsScreen`** (`lib/presentation/screens/achievements_screen.dart`,
  mới) — `ListView` các thành tựu, mỗi card hiện icon khoá/mở (tuỳ
  `unlockedAchievementIds.contains(id)`), title/desc, và progress dạng
  `hiện tại/threshold` nếu chưa đạt (tái dùng style card có sẵn, không thiết
  kế widget mới).
- **Home Screen** — thêm 1 `NeonIconButton` mới (`Icons.emoji_events_rounded`
  hoặc tương tự, tránh trùng `Icons.military_tech_rounded` đã dùng cho Season
  Pass) vào hàng icon cuối cùng (`lib/presentation/screens/home_screen.dart`
  dòng ~246-286).
- **Guide Screen** — thêm 1 rule/section cuối trỏ sang `AchievementsScreen`
  (theo đúng pattern `_rules` list hiện có).
- **Unlock dialog** — trong `GameScreenController` (nơi đã `ever(gameCtrl.ended,
  ...)`), thêm `ever(gameCtrl.justUnlockedAchievement, ...)` để hiện
  `NeonDialog.overlay` ăn mừng (icon + title + `+N coin`), tap để đóng, tự
  clear giá trị Rx sau khi hiện.

## 5. i18n
Theo đúng convention: title/desc của 25 thành tựu + 2-3 label UI
(`achievements_title`, nút Home) vào `_extraEn`/`_extraVi` (fallback +
tiếng Việt), rồi 1 wave `_wNByLang` mới cho 20 ngôn ngữ còn lại (theo mẫu
`_w29ByLang`/`_w31ByLang` đã có trong `app_translations.dart`).

## 6. Test
- `test/data/achievements_test.dart` — test thuần: `_checkAchievements`
  logic qua hàm tách riêng dạng thuần (input: giá trị counter + set đã
  unlock, output: id mới unlock) để không cần widget harness.
- `test/widget/achievements_screen_test.dart` — render list, khoá/mở đúng
  theo state giả lập.
- Test luồng unlock dialog trong 1 test hiện có (hoặc thêm mới) mô phỏng đủ
  điều kiện 1 mốc thấp (vd `boardsFullyCleared >= 1`) rồi verify dialog xuất
  hiện.

## Ngoài phạm vi (không làm)
- Không thêm tier/bronze-silver-gold.
- Không thêm animation/particle riêng cho achievement dialog (dùng lại
  `NeonDialog.overlay` có sẵn).
- Không thêm push notification/local reminder khi gần đạt mốc.
