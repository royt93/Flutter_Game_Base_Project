---
id: IDEA-60
title: "Directional screen shake theo vector va chạm Flame — ScreenShake hiện tại có hướng ngẫu nhiên/đồng đều"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
`lib/presentation/widgets/common/screen_shake.dart` (mở rộng), tích hợp với Flame collision callback.

## Hiện trạng
`ScreenShake` hiện có hiệu ứng rung màn hình chung, không nhận vector hướng va chạm để làm rung có định hướng (ví dụ va chạm từ bên trái làm màn hình rung lệch phải mạnh hơn).

## Vì sao cần / Hậu quả
Game-feel/juice tốt hơn cho các va chạm Flame — cảm giác phản hồi vật lý rõ ràng hơn shake đồng đều ngẫu nhiên.

## Đề xuất
Thêm tham số `direction: Vector2?` optional cho `ScreenShake` — khi có, thiên vị biên độ rung theo hướng đó; khi không có (mặc định), giữ hành vi ngẫu nhiên đồng đều như hiện tại.

## Acceptance criteria
- [x] `ScreenShake(direction: ...)` rung có thiên hướng đúng theo vector truyền vào. (đổi vị trí tham số — xem Quyết định)
- [x] `ScreenShake()` không truyền `direction` giữ nguyên hành vi cũ.
- [x] Test widget verify offset rung thiên đúng hướng khi có `direction`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-60-directional-screen-shake-flame-collision.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/screen_shake.dart` và test hiện có trước khi thêm tham số mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (cảm nhận trực quan hiệu ứng juice) không bắt buộc nếu widget test đủ chứng minh offset đúng.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng game-feel hợp lý, giá trị thấp/vừa, không phải bug. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Sửa 2 điểm lệch so với đề xuất gốc (đã Read code thật trước khi làm)**:
1. Đề xuất viết "tham số `direction: Vector2?` cho `ScreenShake`" —
   `ScreenShake` là WIDGET (`Transform.translate` thuần, không có logic
   toán học); toán rung nằm ở `ScreenShakeController.shake()`/`offsetAt()`.
   Thêm `direction` vào `shake()` mới đúng chỗ — 1 controller có thể được
   tái sử dụng cho NHIỀU lần shake khác hướng nhau (mỗi va chạm 1 hướng
   khác), không hợp lý nếu cố định `direction` ở constructor widget (chỉ
   tạo 1 lần/màn hình).
2. Kiểu `Vector2?` → đổi thành `Offset?`. `screen_shake.dart` hiện KHÔNG
   phụ thuộc Flame/vector_math gì cả (chỉ `dart:math`) — dùng `Vector2`
   sẽ kéo Flame vào 1 widget "game-feel" thuần Flutter, vốn dùng được cho
   bất kỳ hiệu ứng rung nào (card, button...) không riêng Flame. `Offset`
   (đã có sẵn, `dart:ui` qua `material.dart`) biểu diễn hướng 2D y hệt —
   1 `Vector2` từ Flame convert 1 dòng (`Offset(v.x, v.y)`) nếu cần, ghi
   rõ trong doc comment. Cũng sửa mô tả sai trong "Hiện trạng" của task:
   shake hiện tại KHÔNG "ngẫu nhiên" — là dao động sin/cos tất định (1
   ellipse đối xứng), không phải random.

**Implement**: `shake({..., Offset? direction})` chuẩn hoá `direction`
thành unit vector (tự bảo vệ chia 0 khi `direction == Offset.zero` hoặc
`null` → coi như không có hướng). `offsetAt()`: giữ nguyên `primary`
(sin)/`secondary` (cos lệch pha) y hệt công thức cũ; khi có `dir`, chiếu
`primary` HOÀN TOÀN dọc theo `dir`, `secondary` dọc theo trục vuông góc
NHƯNG NHÂN thêm `_perpendicularFactor = 0.35` để giảm biên độ — tạo hiệu
ứng ellipse kéo dài theo hướng va chạm thay vì ellipse đối xứng. Khi
`direction == null` (mặc định), trả về đúng `Offset(primary, secondary)`
— chính xác công thức gốc, không lệch dù chỉ 1 phép tính.

**TDD**: `git stash` riêng `screen_shake.dart`, chạy 5 test mới nhóm
"IDEA-60" → fail đúng biên dịch ("No named parameter 'direction'"),
khôi phục, chạy lại — 13/13 pass (8 test cũ + 5 mới). Test mới: (1) không
`direction` → khớp CHÍNH XÁC công thức toán gốc tại nhiều mốc `t` (so
sánh trực tiếp `sin`/`cos` tính tay, sai số `1e-9`) — chứng minh AC2
đúng nghĩa đen, không chỉ "không crash"; (2) có `direction` → tổng biên
độ chiếu lên hướng đó LỚN HƠN tổng biên độ chiếu lên trục vuông góc, lấy
mẫu nhiều mốc `t` trong suốt vòng decay (không chỉ 1 điểm ngẫu nhiên,
tránh false-positive do pha dao động); (3) `direction` không phải unit
vector vẫn tự chuẩn hoá đúng; (4) `direction: Offset.zero` fallback an
toàn về công thức không hướng (test chia-cho-0); (5) gọi lại `shake()`
KHÔNG truyền `direction` xoá `direction` cũ, không bị dính lại.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2266 test (+13 đúng số test mới), 19 fail —
đúng baseline golden-image, không fail mới. `example/`: 142/142 pass
(demo `ScreenShake` sẵn có trong `WidgetShowcaseScreen` không đổi API,
không cần cập nhật). `dart run tool/api_compatibility.dart check` →
`unchanged` (thêm param optional trên method của class đã export sẵn,
không phải symbol mới cấp file). Không cần smoke test device (task tự
ghi optional, widget test đã chứng minh đủ bằng phép chiếu toán học
chính xác, không chỉ "trông có vẻ đúng hướng bằng mắt").

Tự chấm: **9.5/10** — sửa đúng 2 lệch (vị trí tham số + kiểu dữ liệu)
với lý do rõ ràng, không phá backward-compat dù chỉ 1 phép tính (test
so khớp công thức chính xác), TDD chứng minh cả trường hợp biên (zero
vector, không-unit vector, dính state giữa 2 lần shake). Trừ 0.5 vì
`_perpendicularFactor = 0.35` là hằng số chọn theo cảm tính (ghi rõ
trong comment là vậy), chưa có xác nhận cảm quan thật trên device.
