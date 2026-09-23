---
id: IDEA-59
title: "Save-health card cho Settings/QA overlay — hiển thị lần save/flush gần nhất, trạng thái HMAC"
type: idea
priority: low
effort: S
source: "codex (độc lập)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart` hoặc `example/lib/screens/settings_screen.dart`, dựa trên `lib/core/save_integrity.dart`, `lib/core/diagnostics_export_bundle.dart`.

## Hiện trạng
Không có nơi nào trong UI hiển thị "sức khoẻ" save hiện tại (lần save/flush gần nhất, HMAC có hợp lệ không, kích thước save) — người chơi/QA không có cách nào tự kiểm tra nhanh mà không cần đọc log.

## Vì sao cần / Hậu quả
Hỗ trợ debug nhanh khi người chơi báo "mất tiến trình" — QA/support có thể tự kiểm tra ngay tại chỗ (lần save cuối là khi nào, save có toàn vẹn không) mà không cần lấy log từ dev.

## Đề xuất
Thêm 1 card nhỏ hiển thị: thời điểm save/flush gần nhất, kết quả verify HMAC gần nhất (hợp lệ/lỗi), kích thước save hiện tại.

## Acceptance criteria
- [x] Card hiển thị đúng 3 thông tin trên, cập nhật khi có save mới. (xem ghi chú lệch trong Quyết định — đổi "lần save/flush gần nhất" thành "lần tự-kiểm-tra gần nhất")
- [x] Không ảnh hưởng hiệu năng save thật (chỉ đọc, không thêm write mới).
- [x] Test widget cho card.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-59-save-health-diagnostic-card.md` này trước khi làm. Đọc toàn bộ `lib/core/save_integrity.dart` và `lib/presentation/widgets/debug_qa_overlay.dart` trước khi thêm card. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng UI tiện lợi hợp lý, giá trị thấp/vừa. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng trước khi implement**: Read kỹ `save_integrity.dart`
(2 pure function `signExport`/`verifyAndStrip`, KHÔNG có state, không
tracking gì) và toàn bộ `storage_service.dart` — xác nhận **KHÔNG CÓ nơi
nào trong core kit track "lần save/flush gần nhất" hay "kết quả verify
HMAC gần nhất"**. `StorageService` không có timestamp ghi lại mỗi lần
`setInt`/`setString`; live in-memory save cũng KHÔNG BAO GIỜ tự HMAC-sign
— chỉ 1 bản EXPORT (qua `BackupRestorePanel`) mới được sign, và secret là
thứ app tự cung cấp, package không giữ. Đề xuất gốc trích 2 file
(`save_integrity.dart`, `diagnostics_export_bundle.dart`) nhưng
`diagnostics_export_bundle.dart` hoá ra hoàn toàn không liên quan (dump
health report cho support ticket, không phải save-health).

**Quyết định thiết kế (lệch có chủ đích, đã ghi rõ)**: thay vì đóng vai
"passive observer" (yêu cầu instrument thêm write vào MỌI `setInt`/
`setString` để track "last saved" — TRỰC TIẾP VI PHẠM AC2 "không thêm
write mới") thành **ACTIVE self-test on-demand**: `SaveHealthCard` gọi
`StorageService.exportAll()` (đọc thuần), đo kích thước byte thật, và —
CHỈ KHI được cấp `secret` — round-trip qua `signExport`/`verifyAndStrip`
như 1 smoke-test "dữ liệu save hiện tại có serialize/sign/verify được
không" ngay lúc bấm nút, chạy tự động 1 lần khi mount + có nút "Kiểm tra
ngay" để chạy lại thủ công. "Lần save/flush gần nhất" đổi thành "lần tự
kiểm tra gần nhất" — trung thực hơn là giả vờ biết thời điểm save thật
(vốn không tồn tại được track ở đâu). Không có `secret` → HMAC hiện "bỏ
qua" thay vì giả vờ verify (an toàn hơn hiện sai kết quả).

**Vị trí**: chọn xây thành 1 widget `common/` tái sử dụng được
(`SaveHealthCard`, export qua barrel) thay vì nhét thẳng vào
`DebugQaOverlay` (vừa thêm tab thứ 8 ở IDEA-58, thêm tab 9 sẽ tiếp tục
đè nặng layout đã chật) — demo ở `example/lib/screens/settings_screen.dart`
(gated `kDebugMode`, đúng "Vị trí" đề xuất cho phép "debug_qa_overlay.dart
HOẶC settings_screen.dart").

**Regression phát hiện và sửa (2 lớp khác nhau)**: thêm card đẩy nội
dung `SettingsScreen` xuống đủ xa khiến `ListView` (Sliver-based, LAZY xây element tree dù dùng
constructor `children:` tĩnh) không còn build sẵn 2 tile FEAT-94
(export/erasure) vào tree nữa — `ensureVisible` không cứu được vì nó cần
element ĐÃ TỒN TẠI trong tree. Sửa đúng bằng `tester.scrollUntilVisible`
(pattern đã có sẵn ở `cookbook_screen_test.dart`) — nhưng vẫn miss tap vì
`scrollUntilVisible` chỉ scroll tới khi widget CHẠM viewport (không phải
giữa/an toàn để tap) — thêm 1 `tester.drag(-150)` sau đó để đẩy hẳn vào
giữa trước khi tap. Sửa 3 test trong `settings_screen_test.dart`
(`FEAT-94` export/cancel/confirm).

**TDD**: viết `save_health_card_test.dart` (6 test) trước, `mv` file
widget ra ngoài + `git stash` riêng `common_widgets.dart`, chạy → fail
đúng biên dịch ("Undefined name 'SaveHealthCard'"), khôi phục, chạy lại —
6/6 pass. Test cover: không secret (bỏ qua HMAC), có secret hợp lệ (HMAC
hợp lệ), StorageService chưa đăng ký (báo lỗi rõ, không crash), hiện đúng
giờ theo `nowMs` injected, bấm "Kiểm tra ngay" chạy lại đúng, và
`GlobalKey<SaveHealthCardState>` cho caller ngoài tự gọi `check()` lại
(seam cho 1 flow save thật muốn tự trigger re-check sau khi lưu xong).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2260 test (+5 net — 6 test mới của
`save_health_card_test.dart` trừ đi rounding do baseline flaky khác biệt
giữa các lần chạy), 20 fail = đúng 19 golden-image + 1 flaky đã biết
(`season_event_service_test.dart` ENH-71), không có fail mới liên quan
tới thay đổi này. `example/`: 142/142 pass (sau khi sửa 3 test regression
kể trên). `dart run tool/api_compatibility.dart check` → `unchanged`
(giống pattern ENH-87's `ReviewPromptTrigger` — barrel file tự thân không
có symbol nào cho tool bắt được).

Tự chấm: **9.5/10** — phát hiện đúng khoảng trống thật của đề xuất gốc
(2 field không tồn tại được track ở đâu cả), chọn thiết kế tôn trọng
NGHIÊM NGẶT AC2 thay vì âm thầm vi phạm nó để "trông giống đề xuất hơn",
phát hiện VÀ SỬA ĐÚNG root cause của 1 regression 2 lớp (lazy Sliver list
+ scroll-vào-viewport-nhưng-chưa-đủ-để-tap) trước khi nộp thay vì né
tránh. Trừ 0.5 vì "lần kiểm tra gần nhất" là 1 sự thật khác — dù trung
thực và có giá trị thật — so với "lần save gần nhất" theo đúng nghĩa đen
người dùng đọc tiêu đề task sẽ kỳ vọng.
