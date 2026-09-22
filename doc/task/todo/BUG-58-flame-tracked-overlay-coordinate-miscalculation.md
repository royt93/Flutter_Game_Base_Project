---
id: BUG-58
title: "FlameTrackedOverlay dùng toạ độ global thay vì local của Stack cha — HUD lệch nếu Stack không nằm đúng gốc màn hình"
type: bug
priority: P1
effort: S
source: "agy (độc lập), verify lại qua Read lib/presentation/widgets/flame_tracked_overlay.dart:90-128"
---

## Vị trí
`lib/presentation/widgets/flame_tracked_overlay.dart` — nơi tính `gameWidgetTopLeft`/vị trí `Positioned`.

## Hiện trạng
Code lấy `gameWidgetTopLeft = renderBox.localToGlobal(Offset.zero)` (toạ độ GLOBAL/màn hình) rồi dùng trực tiếp để tính vị trí cho `Positioned` bên trong `Stack`. `Positioned` cần toạ độ LOCAL tương đối với `RenderBox` của `Stack` cha, không phải toạ độ màn hình tuyệt đối.

## Vì sao cần / Hậu quả
Nếu `Stack` chứa `FlameTrackedOverlay` không nằm đúng gốc (0,0) màn hình — ví dụ nằm dưới `NeonAppBar`, có `SafeArea`, padding, hoặc margin — toạ độ tính sai bị cộng dồn lệch xuống dưới/sang phải, khiến overlay HUD (điểm số, tên nhân vật...) bay lệch khỏi vị trí thật của entity trong game. Đây là widget duy nhất của package làm nhiệm vụ này (theo CLAUDE.md), lỗi ảnh hưởng trực tiếp tới mọi HUD dùng world-tracking.

## Đề xuất
Chuyển đổi toạ độ sang hệ quy chiếu local của `Stack` cha:
```dart
final stackBox = context.findRenderObject() as RenderBox?;
final gameWidgetTopLeft = stackBox != null
    ? stackBox.globalToLocal(renderBox.localToGlobal(Offset.zero))
    : renderBox.localToGlobal(Offset.zero);
```

## Acceptance criteria
- [ ] `FlameTrackedOverlay` đặt trong 1 `Stack` có offset khác (0,0) (ví dụ dưới `AppBar`/`SafeArea`/`Padding`) — overlay hiển thị đúng vị trí world-tracked, không lệch.
- [ ] Trường hợp `Stack` nằm đúng gốc màn hình (0,0) hành vi không đổi so với trước.
- [ ] Test widget verify toạ độ tính đúng khi `Stack` có offset khác 0.
- [ ] Test hiện có của widget này (nếu có) vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-58-flame-tracked-overlay-coordinate-miscalculation.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/flame_tracked_overlay.dart` và `example/lib/screens/game_demo_screen.dart` (cách dùng thật) trước khi sửa. Implement bằng TDD — viết test dựng 1 `Stack` có offset (ví dụ bọc trong `Padding`) trước khi sửa để tái hiện lệch toạ độ.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật (mở `GameDemoScreen`, verify HUD/overlay bám đúng vị trí entity khi có `AppBar`/padding phía trên) — bắt buộc vì đây là bug ảnh hưởng trực tiếp UI quan sát được.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp code, xác nhận dùng `renderBox.localToGlobal(Offset.zero)` trực tiếp không qua `stackBox.globalToLocal`, khớp mô tả agy. Không trùng task nào trong `doc/task/done/`.
