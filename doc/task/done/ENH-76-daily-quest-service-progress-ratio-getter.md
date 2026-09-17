---
id: ENH-76
title: "DailyQuestService thiếu progressRatio(id) — cùng gap AchievementService vừa vá ở ENH-74"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/daily_quest_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/daily_quest_service.dart` (`DailyQuestService`).

## Hiện trạng
`DailyQuestService` có `progressOf(id)` (dòng 199, luôn `int`, không cap ở `targetOf`) và `targetOf(id)` (dòng 209, trả `int?`, `null` nếu chưa `register`). Y hệt cấu trúc `AchievementService.progressOf`/`thresholdOf` trước khi được vá `progressRatio` ở ENH-74 (chính session này) — không có getter nào tính sẵn tỉ lệ 0.0–1.0 cho progress-bar UI (`QuestBoardPanel` dùng `ProgressBarStars`, tự tính `(quest.progress / quest.target).clamp(0.0, 1.0)` ngay trong `_QuestRowState.build`).

## Vì sao cần / Hậu quả
Đúng gap vừa vá xong 1 lần ở `AchievementService` (ENH-74) — `DailyQuestService` có cùng cấu trúc API, cùng use case hiển thị (progress-bar), nhưng chưa có getter tương ứng. Không có nó, bất kỳ UI nào khác `QuestBoardPanel` muốn hiển thị tiến trình nhiệm vụ (ví dụ 1 tổng-quan tất cả nhiệm vụ dạng ring/percent) phải tự viết lại đúng logic null-check + clamp mà `QuestBoardPanel` đã viết riêng cho nó.

## Đề xuất
Thêm 1 getter thuần, đọc-only, không đổi hành vi `progressOf`/`targetOf`/`isClaimed`/`register`/`incrementProgress` hiện có — copy chính xác pattern `AchievementService.progressRatio` (ENH-74):

```dart
/// `progressOf(id) / targetOf(id)` clamped to `[0.0, 1.0]` — `0.0`
/// (never throws) if [questId] was never [register]ed or has no
/// progress yet.
double progressRatio(String questId) {
  final target = targetOf(questId);
  if (target == null || target <= 0) return 0.0;
  return (progressOf(questId) / target).clamp(0.0, 1.0);
}
```

## Acceptance criteria
- [x] `questId` chưa từng `register`: `progressRatio` trả `0.0`, không throw.
- [x] Đã `register` nhưng chưa `incrementProgress`: trả `0.0`.
- [x] Progress ở giữa target: trả đúng tỉ lệ.
- [x] Progress đã vượt target: trả clamp đúng `1.0`, không vượt quá.
- [x] Progress đúng bằng target: trả đúng `1.0`.
- [x] Không đổi hành vi `progressOf`/`targetOf`/`isClaimed`/`register`/`incrementProgress` hiện có; không phá test cũ trong `test/core/daily_quest_service_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-76-daily-quest-service-progress-ratio-getter.md` này trước khi làm. Đọc `lib/core/daily_quest_service.dart` toàn bộ (đặc biệt `progressOf`/`targetOf`/`register`/`incrementProgress`) và `lib/core/achievement_service.dart`'s `progressRatio` (ENH-74, đã done — copy chính xác pattern) trước khi thêm getter. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với `AchievementService.progressRatio` ENH-74, không phá API/test hiện có, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `daily_quest_service.dart`: `progressOf`/`targetOf`/`register`/`incrementProgress` tồn tại đúng như mô tả, không có getter nào tên `progressRatio`/`ratio`/`percent`. Cùng bằng chứng độ tin cậy đã dùng ở ENH-74 (`AchievementService`), chỉ khác tên service/method. Effort cực nhỏ (1 getter thuần, copy pattern đã verify), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`.

## Quyết định

Copy chính xác pattern `AchievementService.progressRatio` (ENH-74) — `progressOf(id) / targetOf(id)` clamp `[0.0, 1.0]`, trả `0.0` khi chưa `register` hoặc `target <= 0`.

**Test:** 5 test mới trong `test/core/daily_quest_service_test.dart` nhóm "ENH-76" — chưa register, đã register chưa progress, giữa target, vượt target (clamp), đúng bằng target.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1252/1252 pass. Không đụng `example/` (không bắt buộc).

**Tự chấm điểm: 10/10** — copy pattern đã verify ở ENH-74, test đủ mọi case biên, không có bất ngờ nào (đúng dự đoán trong Ghi chú độ tin cậy).
