# I21 — Đa dạng số màu gem theo từng level, không chỉ theo world

**Epic:** Gameplay depth · **SP:** 2 · **Pri:** Should · **Deps:** —

## Mục tiêu
`lib/data/levels.dart:115` hiện tính `colorCount = 4 + (world ~/ 3).clamp(0, 3)`
— chỉ đổi mỗi 60 level (3 world), toàn bộ 200 level chỉ có 4 giá trị
colorCount (4/5/6/7). Đổi sang công thức dao động theo level `i`, không chỉ
theo world, để các level liền kề có cảm giác khác nhau (không phải 60 level
liền dùng chung 1 colorCount).

Đề xuất (khởi điểm cho subtask, không phải quyết định cuối):
```dart
final base = 4 + (world ~/ 3).clamp(0, 3); // ramp cũ giữ nguyên (4..7)
final wobble = (i % 3) - 1; // -1, 0, +1 xoay vòng mỗi 3 level
final colorCount = (base + wobble).clamp(4, 7);
```
Giữ nguyên trần/sàn khó (4..7) — chỉ thêm biến thiên cục bộ quanh baseline,
không đổi đường cong khó tổng thể đã cân bằng (`targetScore` neo theo
`cells * 6 * ramp`, xem note trong `levels.dart`).

## Vì sao
User feedback: số màu gem lặp lại y hệt suốt một mảng dài level, thiếu đa
dạng. Ramp hiện tại đúng hướng (khó dần theo world) nhưng bước nhảy quá thưa
(60 level/bước) khiến trải nghiệm đơn điệu ở quy mô nhỏ hơn (level-to-level).

## Acceptance criteria
- [x] colorCount đổi ở granularity level, không chỉ world (level liền kề có
      thể khác colorCount).
- [x] Không phá vỡ trần/sàn khó hiện có (vẫn trong khoảng 4..7 toàn campaign,
      xu hướng tăng dần theo world giữ nguyên).
- [x] `targetScore`/objective (`clearColor`, `collect` dùng `i % colorCount`,
      `cells / colorCount`) vẫn tính đúng với colorCount mới (đã là biến cục
      bộ trong `List.generate`, không cần sửa các dòng này).
- [x] `test/data/levels_test.dart` cập nhật/thêm assertion phản ánh phân bố
      colorCount mới (không còn kỳ vọng "hằng số suốt 60 level").
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh.

Đã code đúng công thức đề xuất trong Mục tiêu (`colorBase + (i % 3) - 1`,
clamp 4..7). Test mới xác nhận mỗi world có ≥2 giá trị colorCount khác nhau.

## Subtasks
1. `lib/data/levels.dart` — sửa dòng tính `colorCount` trong `kLevels`
   generator (giữ nguyên mọi chỗ dùng `colorCount` khác, chúng đọc biến cục
   bộ nên tự động ăn theo).
2. `test/data/levels_test.dart` — sửa test cứng theo công thức cũ (nếu có),
   thêm assertion xác nhận có ≥2 giá trị colorCount khác nhau trong cùng 1
   world (chứng minh đã đa dạng ở granularity level).

## Ghi chú
Không đụng `kTimeAttackLevel`/`kZenLevel`/`kEndlessBoard`/`kDailyChallengeLevel`
— các mode này có công thức colorCount riêng, ngoài phạm vi (chỉ campaign
200 level bị báo thiếu đa dạng).

DoD chung: `../README.md`.
