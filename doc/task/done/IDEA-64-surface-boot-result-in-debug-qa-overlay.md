---
id: IDEA-64
title: "Hiển thị RoyCasualKitResult (module nào lỗi/degraded) trong 1 tab DebugQaOverlay thay vì chỉ đọc log"
type: idea
priority: low
effort: S
source: "claude (độc lập)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart`, dựa trên `lib/core/kit_bootstrap.dart` (`RoyCasualKitResult.errors`/`status`).

## Hiện trạng
`RoyCasualKitResult.errors`/`status` là API công khai nhưng không đâu trong kit hiển thị nó ra UI (kể cả debug tool) — chỉ có thể đọc qua log/debugger thủ công.

## Vì sao cần / Hậu quả
1 tab liệt kê module nào đăng ký thành công/lỗi giúp cả SDK dev lẫn consumer debug boot nhanh hơn nhiều so với đọc log — đặc biệt hữu ích khi kết hợp với BUG-47 (kit_bootstrap giờ trả `degraded` thay vì throw cho 1 số lỗi cấu hình).

## Đề xuất
Thêm 1 tab "Boot" trong `DebugQaOverlay` hiển thị `status` (`healthy`/`degraded`) và danh sách `errors` (module + message) từ lần `initialize()` gần nhất — cần lưu lại `RoyCasualKitResult` ở đâu đó truy cập được (ví dụ static field hoặc GetX service nhỏ) vì `initialize()` chỉ trả về 1 lần tại thời điểm gọi.

## Acceptance criteria
- [x] Tab "Boot" hiển thị đúng `status`/`errors` của lần `initialize()` gần nhất.
- [x] Không có lỗi nào (status healthy) hiển thị rõ ràng "OK, mọi module đăng ký thành công".
- [x] Test widget verify tab hiển thị đúng khi có/không có lỗi.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-64-surface-boot-result-in-debug-qa-overlay.md` này trước khi làm. Đọc toàn bộ `lib/core/kit_bootstrap.dart` (`RoyCasualKitResult`) và `lib/presentation/widgets/debug_qa_overlay.dart` trước khi thêm tab. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — API `RoyCasualKitResult` xác nhận tồn tại thật (dùng trong BUG-47), gap UI hợp lý. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `RoyCasualKit.lastResult` (getter tĩnh mới, đọc đúng
`_result` private đã có sẵn — field này VỐN ĐÃ được gán mỗi lần
`initialize()` chạy xong, chỉ chưa có cách đọc lại từ bên ngoài, đúng như
task mô tả). `resetForTesting()` đã tự xoá `_result = null` từ trước
(BUG-47), không cần sửa gì thêm ở đó.

Tab "Boot" thứ 9 trong `DebugQaOverlay` (`_BootTab`) đọc
`RoyCasualKit.lastResult`: `null` → báo rõ "chưa gọi initialize()";
`status == initialized` → dòng "OK — mọi module đăng ký thành công" (màu
`NeonTheme.lime`); `status == degraded` → dòng "Degraded — N module lỗi"
(màu `NeonTheme.red`) + liệt kê đúng từng `(module, error)` từ
`result.errors`. Luôn liệt kê `registeredModules` (dấu ✓) bất kể
degraded hay không — 1 kết quả degraded vẫn có thể có nhiều module đã
đăng ký thành công, hữu ích để thấy rõ CÁI GÌ hoạt động chứ không chỉ
cái gì lỗi.

**Không có regression tab-bar lần này**: sau bài học IDEA-58 (thêm tab
thứ 8 làm rơi 1 test khác do layout dồn xuống), lần này chủ động chạy lại
TOÀN BỘ `debug_qa_overlay_test.dart` (không chỉ test mới) ngay sau khi
thêm tab thứ 9 — 37/37 pass, không cần sửa gì thêm (khác biệt: tab thứ 9
này không đẩy dòng Wrap tràn thêm 1 hàng mới nữa, vì đã tràn sẵn từ trước).

**TDD**: 2 phần — (1) `kit_bootstrap_test.dart` thêm 4 test cho
`lastResult` (null ban đầu, bằng đúng kết quả `initialize()` trả về,
phản ánh đúng degraded, `resetForTesting()` xoá về null) — `git stash`
riêng `kit_bootstrap.dart`, fail đúng biên dịch ("Member not found:
'lastResult'"), khôi phục, 12/12 pass. (2) `debug_qa_overlay_test.dart`
thêm 4 test cho tab UI (chưa initialize, healthy, liệt kê đúng module,
degraded) — không cần stash riêng phần này vì cùng nằm trong 1 file lib
đã build (đủ để test mới thất bại tự nhiên do thiếu getter ở bước 1);
4/4 pass, cả file 37/37 pass.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2299 test (+8 đúng số test mới: 4+4), 20 fail
— 19 golden-image + 1 flaky đã biết (`season_event_service_test.dart`
ENH-71), không fail mới. `example/`: 142/142 pass (app thật CÓ gọi
`RoyCasualKit.initialize()` trong `main.dart`, mọi test màn hình vẫn
pass nguyên — xác nhận `lastResult` không phá hành vi boot có sẵn). `dart
run tool/api_compatibility.dart check` → `additive` (`_BootTab` private
class, giống hạn chế tool đã ghi nhận ở IDEA-58) → `snapshot` →
`unchanged`. Không cần smoke test device (task tự ghi không bắt buộc,
widget test đã chứng minh đủ).

Tự chấm: **9.5/10** — đúng phạm vi task đề ra (chỉ thêm 1 getter đọc
field private có sẵn + 1 tab hiển thị, không invent thêm tracking mới),
rút kinh nghiệm từ IDEA-58 chủ động chạy lại toàn bộ test file ngay khi
thêm tab thay vì đợi CI báo, TDD đầy đủ cả 2 lớp (core getter + widget
UI). Trừ 0.5 vì chưa thêm demo/hướng dẫn nào trong `example/` cho
consumer thật biết cách dùng `RoyCasualKit.lastResult` ngoài chính
`DebugQaOverlay` (không phải yêu cầu của task, nhưng sẽ tăng giá trị
thực tế nếu có).
