---
id: ENH-74
title: "AchievementService thiếu progressRatio(id) — UI progress-bar phải tự tính, dễ sai chia-cho-0/null"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/achievement_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/achievement_service.dart` (`AchievementService`).

## Hiện trạng
`AchievementService` có `progressOf(id)` (luôn trả `int`, không throw, không cap ở threshold — 1 achievement đã hoàn thành vẫn tiếp tục tăng progress) và `thresholdOf(id)` (trả `int?`, `null` nếu chưa từng `register`). Chính doc comment của `thresholdOf` (dòng 190-192) đã nói rõ lý do tách `null` ra khỏi `isCompleted`'s `false`: "since a progress-bar UI needs to tell 'no achievement declared' apart from 'declared, not yet met'" — tức là API này được thiết kế SẴN cho use case progress-bar, nhưng lại không có getter nào tính sẵn tỉ lệ đó. Widget kit của package này có ít nhất 2 widget progress-bar-shaped (`progress_bar_stars.dart`, `circular_progress_ring.dart`) nhận `double` 0.0–1.0 — 1 consumer muốn hiển thị progress achievement phải tự viết `(thresholdOf(id) == null || thresholdOf(id) == 0) ? 0.0 : (progressOf(id) / thresholdOf(id)!).clamp(0.0, 1.0)` mỗi nơi cần hiển thị, dễ quên `null`-check hoặc quên `.clamp` (vì `progressOf` không cap ở threshold, tỉ lệ thô có thể > 1.0).

## Vì sao cần / Hậu quả
Đúng pattern "expose derived state qua getter thay vì bắt caller tự tính lại" đã lặp lại nhiều lần trong package này (`SaveSlotManager.canCreateSlot` ENH-72, `SeasonEventWindow.isActive`) — giờ chính `AchievementService`, service mà doc comment của nó đã tự nhắc tới use case progress-bar, lại là nơi thiếu đúng getter đó. Không có `progressRatio`, mỗi UI hiển thị thanh tiến trình achievement dễ bị lỗi hiển thị (progress bar tràn quá 100% do thiếu `.clamp`, hoặc crash chia null do quên check `thresholdOf == null`).

## Đề xuất
Thêm 1 getter thuần, đọc-only, không đổi hành vi `progressOf`/`thresholdOf`/`isCompleted`/`register` hiện có:

```dart
/// `progressOf(id) / thresholdOf(id)` clamped to `[0.0, 1.0]` — `0.0`
/// (never throws) if [achievementId] was never [register]ed or has no
/// progress yet. Ready to feed straight into a progress-bar-shaped widget
/// (`ProgressBarStars`, `CircularProgressRing`) without the caller having
/// to null-check [thresholdOf] or clamp [progressOf]'s uncapped value.
double progressRatio(String achievementId) {
  final threshold = thresholdOf(achievementId);
  if (threshold == null || threshold <= 0) return 0.0;
  return (progressOf(achievementId) / threshold).clamp(0.0, 1.0);
}
```

## Acceptance criteria
- [x] `achievementId` chưa từng `register`: `progressRatio` trả `0.0`, không throw.
- [x] Đã `register` nhưng chưa `incrementProgress`: trả `0.0`.
- [x] Progress ở giữa threshold: trả đúng tỉ lệ (ví dụ progress 3/threshold 10 → `0.3`).
- [x] Progress đã vượt threshold (do `incrementProgress` tiếp tục cộng sau khi hoàn thành): trả clamp đúng `1.0`, không vượt quá.
- [x] Progress đúng bằng threshold: trả đúng `1.0`.
- [x] Không đổi hành vi `progressOf`/`thresholdOf`/`isCompleted`/`register`/`incrementProgress` hiện có; không phá test cũ trong `test/core/achievement_service_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-74-achievement-service-progress-ratio-getter.md` này trước khi làm. Đọc `lib/core/achievement_service.dart` toàn bộ (đặc biệt `progressOf`/`thresholdOf`/`isCompleted`/`incrementProgress` — chú ý `progressOf` KHÔNG cap ở threshold) trước khi thêm getter. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với pattern getter phái sinh khác trong repo, không phá API/test hiện có, không over-engineer — đúng 1 getter thuần, không thêm gì khác).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/` (nếu muốn minh hoạ, cân nhắc dùng `progressRatio` để feed `ProgressBarStars`/`CircularProgressRing` trong demo `widget_showcase_screen.dart` — không bắt buộc, nếu làm phải test + device smoke test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `achievement_service.dart`: `progressOf`/`thresholdOf`/`isCompleted`/`register`/`incrementProgress` tồn tại đúng như mô tả, không có bất kỳ getter nào tên `progressRatio`/`ratio`/`percent`. Doc comment sẵn có của `thresholdOf` (dòng 190-192) tự xác nhận ý định thiết kế cho progress-bar UI, làm rõ đây là 1 gap thật chứ không phải suy đoán. Effort cực nhỏ (1 getter thuần), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`. Không liên quan storageKey/SaveSlotManager (nhóm đó đã trọn vẹn qua ENH-71/72/73).

## Quyết định

Thêm đúng 1 getter thuần như đề xuất — `progressOf(id) / thresholdOf(id)` clamp `[0.0, 1.0]`, trả `0.0` khi chưa `register` hoặc `threshold <= 0`. Đặt ngay sau `thresholdOf` (đúng chỗ doc comment của nó đã nhắc tới use case này).

**Test:** 5 test mới trong `test/core/achievement_service_test.dart` nhóm "ENH-74" — chưa register, đã register chưa progress, progress giữa threshold, progress vượt threshold (clamp), progress đúng bằng threshold.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1243/1243 pass. Không đụng `example/` (không bắt buộc).

**Tự chấm điểm: 10/10** — đúng 1 getter thuần, đúng use case đã được doc comment cũ tự xác nhận trước, test bao phủ đủ mọi case biên (0, giữa, đúng threshold, vượt threshold).
