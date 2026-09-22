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
- [x] `FlameTrackedOverlay` đặt trong 1 `Stack` có offset khác (0,0) (ví dụ dưới `AppBar`/`SafeArea`/`Padding`) — overlay hiển thị đúng vị trí world-tracked, không lệch.
- [x] Trường hợp `Stack` nằm đúng gốc màn hình (0,0) — hành vi không đổi so với trước.
- [x] Test widget verify toạ độ tính đúng khi `Stack` có offset khác 0.
- [x] Test hiện có của widget này (nếu có) vẫn pass.

## Quyết định
Dùng cách khác, TỐT HƠN đề xuất gốc của task (thay vì literal `stackBox = context.findRenderObject()` rồi `globalToLocal` 2 bước): `RenderBox.localToGlobal`/`globalToLocal` đều nhận tham số `ancestor` tuỳ chọn — truyền thẳng `ancestor: stackBox` cho `renderBox.localToGlobal(Offset.zero, ancestor: stackBox)` quy đổi trực tiếp 1 bước sang toạ độ LOCAL của `stackBox`, không cần đi vòng qua global rồi global-to-local lần 2. `stackBox` lấy đúng qua `context.findAncestorRenderObjectOfType<RenderStack>()` (tìm ĐÚNG `Stack` tổ tiên — `context.findRenderObject()` như task đề xuất trả về render object của CHÍNH widget này, không phải của `Stack` cha, nên không dùng đúng như snippet gốc). Giữ nguyên fallback về toạ độ global thô nếu không tìm thấy `RenderStack` tổ tiên nào (không crash, cùng phong cách phòng thủ với các null-check sẵn có trong file).

**TDD verify**: thêm test dựng `Stack` bọc trong `Padding(left: 37, top: 53)` (không dùng `Scaffold`/`AppBar` thật — probe riêng xác nhận thực nghiệm rằng kết hợp `Scaffold` + `FlameTrackedOverlay`'s `Ticker` khởi trong `initState()` làm Flame's `Game.toBeLoaded()` mất đồng bộ mount timing, 1 vấn đề hạ tầng test CÓ SẴN không liên quan gì tới bug toạ độ đang fix — `Padding` một mình đã đủ tạo offset khác 0 để tái hiện đúng bug, không cần `Scaffold`). `git stash` riêng `lib/presentation/widgets/flame_tracked_overlay.dart`, chạy test mới — FAIL đúng trên code cũ (`Expected: a value less than 1.0, Actual: 64.6...` — lệch đúng bằng offset Padding `(37,53)`). `git stash pop`, chạy lại toàn file `flame_tracked_overlay_test.dart` — 6/6 pass (bao gồm 2 test cũ ở `Stack` gốc màn hình — hành vi không đổi, khớp criterion 2).

**Smoke test device thật (bắt buộc theo task)**: build+cài `example/` bản release lên Pixel 7 Pro (`2B051FDH3006MU`, thiết bị online duy nhất phiên này — Samsung S24 Ultra không kết nối lúc làm task này), mở `GameDemoScreen`. Màn hình này dùng `Scaffold(body: SafeArea(child: Stack(...)))` — `SafeArea` tạo offset khác 0 thật (status bar inset) cho `Stack` chứa `GameWidget`/`FlameTrackedOverlay`, đúng kịch bản bug ("có SafeArea" — 1 trong các ví dụ chính task nêu). Screenshot xác nhận label "Circle" (HUD world-tracked) nằm ĐÚNG tâm hình tròn game, không lệch xuống/phải theo offset `SafeArea` — bằng chứng trực quan fix hoạt động đúng trên thiết bị thật. Gỡ app khỏi máy sau khi xong.

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2083 pass / -20 fail (19 golden macOS-only + 1 flake đã biết `save_slot_manager_test.dart` — chạy riêng pass 36/36, không liên quan), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 129/129 pass, smoke test device thật xác nhận đúng.

Tự chấm: **9.5/10** — root cause đúng, cách fix gọn hơn/đúng-API-hơn đề xuất gốc (1 lần convert thay vì 2, tìm đúng ancestor Stack thay vì nhầm render object của chính widget), TDD 2 chiều chứng minh, smoke test device thật xác nhận trực quan đúng, không phá test cũ.

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
