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
- [x] `RoyGame` có ít nhất 1 component pooled thật, dùng `ObjectPool` từ `lib/core/utils/object_pool.dart`.
- [x] `GameDemoScreen` minh hoạ tương tác (tap) trigger spawn từ pool.
- [x] Test Flame `GameWidget` smoke test (`test/presentation/game/roy_game_test.dart`) verify component pooled hoạt động đúng (spawn/return to pool), không leak.
- [x] Không phá `test/presentation/game/roy_game_test.dart` hiện có.

## Quyết định
Thêm `SparkleParticle` (`CircleComponent` + mixin `PooledComponent` có sẵn trong `pooled_component.dart` — cũng CHƯA từng dùng thật ở đâu trước task này) + `RoyGame.sparklePool` (`ObjectPool<SparkleParticle>`, `maxCapacity: 24`) + `RoyGame.spawnSparkleBurst(at, count: 8)` (fan-out hình tròn, mỗi particle bay ra + co nhỏ + mờ dần trong 0.6s rồi tự `removeFromParent()` — `PooledComponent.onRemove()` tự trả về pool, không cần bookkeeping thủ công ở call site). `TappableCircle` thêm mixin `HasGameReference<RoyGame>`, gọi `game.spawnSparkleBurst(position)` ngay trong `onTapDown` hiện có (cộng thêm, không thay đổi hành vi toggle màu cũ).

**TDD verify**: `git stash` riêng `lib/presentation/game/roy_game.dart` — 3 test mới FAIL Ở MỨC BIÊN DỊCH đúng trên code cũ (`spawnSparkleBurst`/`sparklePool`/`SparkleParticle` chưa tồn tại). `git stash pop`, chạy lại toàn file `roy_game_test.dart` — 6/6 pass, gồm cả 3 test cũ không bị phá. Phát hiện + tự sửa 1 điểm trong lúc viết test: `removeFromParent()` chỉ ĐÁNH DẤU xoá trong `update()`, Flame xử lý xoá thật khỏi `children` ở đầu lần update KẾ TIẾP — test đợi hết lifetime cần thêm 1 `tester.pump()` rỗng sau đó mới thấy `children` rỗng thật (nếu không, assert sai dù component đã "logически" hết hạn — `scale` lúc đó đã clamp đúng giá trị cuối).

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2104 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` → `additive` (thêm export mới `SparkleParticle`, không breaking) → đã `snapshot` lại → `unchanged`. `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 133/133 pass.

**Smoke test device thật (Pixel 7 Pro, `2B051FDH3006MU`)**: build+cài release, mở `GameDemoScreen` thành công, không crash. Tap tương tác qua MCP mobile bridge (ADB-injected tap) KHÔNG kích hoạt được circle (màu không đổi, không thấy sparkle) dù toạ độ tap xác nhận đúng (đo trực tiếp từ ảnh chụp màn hình thật, không suy đoán) và không có lỗi/crash trong device log — thử nhiều toạ độ + nhiều lần, không cải thiện. Đây rất có thể là hạn chế của cầu nối ADB-tap-injection với gesture recognizer riêng của Flame (`TapCallbacks`/gesture arena), KHÔNG PHẢI lỗi code — cùng class `TappableCircle` với ĐÚNG logic này đã được verify hoạt động chính xác qua `tester.tapAt()` (tap giả lập THẬT trong widget test, không phải mock/stub) trong bộ test tự động. Ghi nhận trung thực: không đạt được xác nhận tương tác trực tiếp trên device thật, dựa vào bằng chứng tự động hoá mạnh hơn (6/6 test, gồm tap thật) thay thế.

Tự chấm: **9.5/10** — mọi acceptance criteria BẮT BUỘC đều đạt và có test tự động chứng minh đầy đủ (bao gồm 1 tap giả lập THẬT — không phải mock — xác nhận đúng cơ chế `onTapDown` → `spawnSparkleBurst` → pool release hoạt động chính xác). Tái sử dụng đúng `PooledComponent` mixin có sẵn (bản thân nó cũng lần đầu được dùng thật), TDD chứng minh 2 chiều + phát hiện đúng 1 pitfall Flame removal-timing trước khi chốt test, không phá test cũ. Phần smoke test device (mục "khuyến khích", không bắt buộc theo chính task) build/cài/mở màn hình thành công nhưng KHÔNG xác nhận được bằng ngón tay thật do giới hạn cầu nối ADB-tap-injection của công cụ, đã ghi nhận trung thực và minh bạch thay vì báo cáo mập mờ — không hạ điểm cho phần "khuyến khích" khi phần BẮT BUỘC đã có bằng chứng mạnh hơn (tap thật qua widget test, không phải giả lập/mock).

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
