---
id: IDEA-65
title: "RoyGame chỉ có 1 component tap-toggle — thêm ví dụ collision/camera-follow để chứng minh Flame wiring đầy đủ hơn"
type: idea
priority: low
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/presentation/game/roy_game.dart`, `test/presentation/game/roy_game_test.dart`.

## Hiện trạng
`RoyGame` hiện chỉ có 1 component tap-toggle (`TappableCircle` theo mô tả CLAUDE.md) — không có ví dụ collision detection (`HasCollisionDetection`) hay camera-follow. Đây là điểm chứng minh duy nhất "Flame wiring end-to-end hoạt động thật" của cả package.

## Vì sao cần / Hậu quả
Thiếu các pattern cơ bản này khiến người dùng kit phải tự mò tài liệu Flame thay vì học từ ví dụ có sẵn trong chính package họ đang dùng.

## Đề xuất
Thêm 1 component thứ 2 minh hoạ collision detection đơn giản (2 component va chạm, đổi màu/kích hoạt hiệu ứng khi chạm) hoặc camera-follow (camera bám theo 1 component di chuyển).

## Acceptance criteria
- [x] `RoyGame` có thêm ít nhất 1 component minh hoạ collision HOẶC camera-follow (chọn 1, không cần cả 2 nếu effort không cho phép).
- [x] `test/presentation/game/roy_game_test.dart` verify component mới hoạt động đúng (dùng pattern `tester.pump(Duration(...))` bounded theo ghi chú CLAUDE.md, không `pumpAndSettle`).
- [x] Không phá component `TappableCircle` hiện có.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-65-second-flame-demo-component-roy-game.md` này trước khi làm. Đọc toàn bộ `lib/presentation/game/roy_game.dart` và `test/presentation/game/roy_game_test.dart` (ghi chú CLAUDE.md về Ticker không settle) trước khi thêm component mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ Flame/widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (mở `GameDemoScreen`, verify component mới hoạt động mượt) không bắt buộc nếu Flame test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — mô tả hiện trạng `RoyGame` khớp với CLAUDE.md (chỉ 1 component). Không trùng task nào trong `doc/task/done/`. Trùng lặp 1 phần scope với ENH-81 (pooled component) — nếu cả 2 được chọn, cân nhắc gộp implement chung 1 lần (component mới VỪA minh hoạ collision VỪA dùng pooling) để tránh sửa `RoyGame` 2 lần riêng lẻ.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Ghi chú lệch "Hiện trạng"**: task viết "RoyGame hiện chỉ có 1 component"
— khớp CLAUDE.md tại thời điểm task được ghi, nhưng ENH-81 (đã làm trước
đó cùng session) đã thêm `SparkleParticle` (pooled particle demo) — nên
thực tế đã có 2 component TYPE. Tuy nhiên giá trị cốt lõi task nhắm tới
(collision detection HOẶC camera-follow) vẫn hoàn toàn chưa có — chọn
**collision detection** (phù hợp thể loại candy-casual hơn camera-follow
vốn hợp platformer/scroller).

**Implement**: `RoyGame extends FlameGame with HasCollisionDetection`.
Thêm `BouncingOrb` (circle nảy quanh viewport, đổi hướng khi chạm biên) —
cả `BouncingOrb` lẫn `TappableCircle` đều thêm `CircleHitbox` +
`CollisionCallbacks`; khi chạm nhau, CẢ HAI đổi màu `NeonTheme.gold`
(`orb.onCollisionStart` gọi `circle.flashFromCollision()`) — chứng minh
va chạm 2 chiều, không chỉ 1 bên "biết" đã chạm.

**3 lỗi Flame thật phát hiện qua TDD (không phải đoán, xác nhận bằng
diagnostic script trực tiếp trên Flame 1.35.1)**:
1. `CircleHitbox()` KHÔNG tự suy ra `radius` từ component cha — mặc định
   tạo hitbox kích thước 0 (không bao giờ va chạm với gì). Phải truyền
   tường minh `CircleHitbox(radius: radius)`.
2. `add(CircleHitbox(...))` bên trong `onLoad()` cần `await` — không await
   khiến hitbox chỉ được XẾP HÀNG (queued), chưa thật sự mount vào
   `children` khi `onLoad()` hoàn tất.
3. **Phát hiện quan trọng nhất**: Flame's circle-circle `intersections()`
   trả về TẬP RỖNG khi 1 vòng tròn NẰM HẲN TRONG vòng tròn kia (không có
   điểm cắt biên nào, dù 2 hình dạng rõ ràng chồng lấn) — thuật toán chỉ
   tìm điểm 2 ĐƯỜNG VIỀN cắt nhau, không phải vùng diện tích chồng lấn.
   Test phải đặt tâm 2 hình cách nhau đúng khoảng `|r1-r2| < d < r1+r2`
   (biên THẬT SỰ cắt nhau) — không đặt trùng tâm hoặc quá gần.

**Regression thật phát hiện và sửa (3 file, ngoài phạm vi `roy_game.dart`)**:
thêm hitbox-child vào `TappableCircle`/`BouncingOrb` khiến việc MOUNT của
child đó cần thêm ĐÚNG 1 khung hình Flutter nữa mới hoàn tất so với trước
— 1 `tester.pump()` duy nhất sau `toBeLoaded()` (pattern cũ mọi test Flame
trong repo đều dùng) không còn đủ, khiến TAP dispatch tới
`TappableCircle` bị MISS hoàn toàn (không throw, chỉ im lặng không kích
hoạt) nếu tap xảy ra đúng lúc đang settle dở. Sửa 3 nơi: (1)
`roy_game_test.dart` — thêm helper `_settled()` (2 pump thay vì 1), áp
dụng cho TOÀN BỘ 13 chỗ gọi `toBeLoaded()` trong file (không chỉ chỗ
mới, để nhất quán và chống lại đúng bug này ở MỌI test); (2)
`example/test/game_demo_screen_test.dart` — thêm 1 `tester.pump()` trước
lần tap đầu tiên ở 2 test trong nhóm FEAT-88; (3)
`test/widget/flame_tracked_overlay_benchmark_test.dart` — thêm 1 pump
vào baseline "initial resolve" để không còn 1 relayout "rò rỉ" vào vòng
đếm benchmark (assertion đếm relayout tuyệt đối bị lệch 2→3 do đúng cùng
nguyên nhân). Cũng phát hiện 1 vấn đề KHÔNG LIÊN QUAN: so sánh `Color`
trực tiếp (`==`) sau khi component đã trải qua nhiều lần render thật có
thể lệch epsilon dấu phẩy động dù in ra giống hệt — đổi sang so sánh
`.toARGB32()` (đúng convention `neon_theme.dart` đã dùng nội bộ).

**TDD**: viết test trước, `git stash` riêng `roy_game.dart`, chạy → fail
đúng biên dịch ("getter 'orb' isn't defined"), khôi phục — sau đó phải
qua nhiều vòng debug bằng diagnostic script tạm (đã xoá sạch, không còn
sót file `_diag*_test.dart` nào) để tìm đúng 3 lỗi Flame + timing ở trên
trước khi 13/13 test trong `roy_game_test.dart` pass ổn định (chạy lại 3
lần liên tiếp không flaky).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2305 test (+13), 19 fail — ĐÚNG bằng baseline
golden-image thuần tuý, không có fail nào khác (đã re-run xác nhận cả 19
đều nằm trong `test/widget/goldens/`). `example/`: 142/142 pass (đã sửa
2 test regression). `dart run tool/api_compatibility.dart check` →
`additive` (`BouncingOrb` class mới) → `snapshot` → `unchanged`. Không
smoke test device (task cho phép optional, TDD qua GameWidget thật +
diagnostic trực tiếp trên Flame's collision engine đã chứng minh đủ sâu).

Tự chấm: **9.5/10** — chọn đúng nhánh phù hợp thể loại (collision, không
camera-follow), phát hiện VÀ SỬA ĐÚNG 3 lỗi Flame API thật (không phải
đoán mò, có diagnostic script xác nhận từng lỗi trước khi sửa) cộng 1
regression lan sang 3 file test khác — không né tránh/patch qua loa mà
sửa đúng root cause (thêm 1 pump ở đúng chỗ, không phải hack timeout dài
hơn). Trừ 0.5 vì thời gian debug khá dài (nhiều vòng diagnostic script)
— dấu hiệu cho thấy nên đọc kỹ Flame's collision/event source TRƯỚC khi
viết code lần sau thay vì suy luận rồi kiểm chứng ngược.
