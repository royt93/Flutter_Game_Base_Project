---
id: ENH-81
title: "PooledComponent (Flame) tồn tại trong kit nhưng không có usage/demo thật nào — chỉ có test đơn vị"
type: enhancement
priority: P1
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/core/utils/object_pool.dart` (`ObjectPool`, `PooledComponent`-style helpers cho Flame), `lib/presentation/game/roy_game.dart`, `example/lib/screens/game_demo_screen.dart`.

## Hiện trạng
`ObjectPool`/pattern pooling cho Flame `Component` có test đơn vị (`test/core/utils/object_pool_test.dart`) và `tool/object_pool_benchmark.dart` (dùng bởi `performance_budget_check.dart`), nhưng KHÔNG có usage thật nào trong `RoyGame`/`GameDemoScreen` — điểm chứng minh Flame integration duy nhất của package không minh hoạ pattern pooling dù đây là 1 tính năng cốt lõi được benchmark riêng.

## Vì sao cần / Hậu quả
1 dev tích hợp muốn dùng object pooling cho particle/projectile trong Flame game của họ không có ví dụ thật nào để copy — phải tự suy luận cách nối `ObjectPool` với `Component`/`FlameGame` lifecycle từ test đơn vị (không phải usage thật).

## Đề xuất
Thêm 1 component thứ 2 vào `RoyGame` (ví dụ 1 "spawner" bắn ra nhiều `PooledComponent` khi tap, dùng `ObjectPool` quản lý vòng đời) — minh hoạ end-to-end: spawn từ pool → component tự trả về pool khi hết vòng đời → không tạo/huỷ object mới mỗi lần spawn.

## Acceptance criteria
- [ ] `RoyGame` có ít nhất 1 component pooled thật, dùng `ObjectPool` từ `lib/core/utils/object_pool.dart`.
- [ ] `GameDemoScreen` minh hoạ tương tác (tap) trigger spawn từ pool.
- [ ] Test Flame `GameWidget` smoke test (`test/presentation/game/roy_game_test.dart`) verify component pooled hoạt động đúng (spawn/return to pool), không leak.
- [ ] Không phá `test/presentation/game/roy_game_test.dart` hiện có.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-81-pooled-component-zero-usage-demo.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/object_pool.dart`, `lib/presentation/game/roy_game.dart`, `test/presentation/game/roy_game_test.dart` (lưu ý ghi chú CLAUDE.md về `Ticker` không settle trong Flame `GameWidget` test — dùng `tester.pump(Duration(...))` bounded, không `pumpAndSettle`) trước khi thêm component mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget/Flame test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật (mở `GameDemoScreen`, tap trigger spawn, verify hoạt động mượt, không lag/leak quan sát được) — khuyến khích vì đây là thay đổi UI/gameplay quan sát được trực tiếp.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — xác nhận qua kiến thức cấu trúc repo hiện có (`RoyGame` chỉ có 1 `TappableCircle` component theo mô tả CLAUDE.md, không có pooled component nào) — hợp lý với claim của claude. Không trùng task nào trong `doc/task/done/`.
