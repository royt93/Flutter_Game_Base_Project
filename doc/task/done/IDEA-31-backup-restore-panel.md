---
id: IDEA-31
title: "BackupRestorePanel — UI export/import save, hiện StorageService.exportAll()/save_integrity.dart chưa có mặt UI nào"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: M
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/core/save_integrity.dart`, `lib/core/storage_service.dart` (`exportAll`/`importAll`).

## Hiện trạng
`StorageService.exportAll()`/`importAll()` và HMAC sign/verify của `save_integrity.dart` đã tồn tại ở tầng core, nhưng KHÔNG có widget nào trong `common/` thực sự đưa chúng lên UI — không có luồng "Export save"/"Restore từ file"/"chuyển máy qua QR" nào. Team có sẵn phần lõi nhưng vẫn phải tự xây UI (wiring file picker, hiển thị/quét QR, trạng thái lỗi "checksum sai").

## Vì sao cần / Hậu quả
Phần khó nhất (đảm bảo toàn vẹn dữ liệu qua HMAC) đã có sẵn nhưng không ai dùng được nếu thiếu UI — giá trị của `save_integrity.dart` chưa được khai thác trọn vẹn.

## Đề xuất
`BackupRestorePanel` (ghép từ `PanelCard`/`CommonButton`/`ConfirmDialog`) gọi `signExport`/`verifyAndStrip`, giao JSON string kết quả cho `Future<void> Function(String) onExport`/`Future<String?> Function() onImport` do caller cung cấp (cơ chế file/QR/share thực tế vẫn thuộc về app, giống style seam của `CloudSaveProvider`), có sẵn trạng thái lỗi "save hỏng" nối với `FormatException` của `verifyAndStrip`.

## Acceptance criteria
- [x] Panel gọi đúng signExport khi export, verifyAndStrip khi import, hiển thị đúng trạng thái lỗi khi checksum sai.
- [x] onExport/onImport là callback do caller cung cấp, panel không tự quyết định cơ chế lưu file/QR/share cụ thể.
- [x] Test: export rồi import lại đúng dữ liệu gốc; import 1 chuỗi bị chỉnh sửa (checksum sai) hiển thị đúng trạng thái lỗi, không crash.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. Thực hiện trên **TECNO BG6** (`118743744X002560`) — xem `## Quyết định`.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-31-backup-restore-panel.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — giá trị rõ nhưng độ tin cậy medium, cần xác nhận UI export/import save có thực sự là nhu cầu phổ biến của game dùng kit này hay chỉ hữu ích cho 1 số nhỏ trước khi đầu tư effort M.

## Quyết định

Implement `BackupRestorePanel extends StatefulWidget` tại `lib/presentation/widgets/common/backup_restore_panel.dart`, export qua `common_widgets.dart` (nhóm "Layout & Cards").

**Seam convention giống `CloudSaveProvider`/`PurchaseSeam`:** panel không tự quyết định cơ chế file/QR/share — `onExport(signedJson)` và `onImport() -> signedJson?` do caller cung cấp. `secret` (khoá HMAC cho `signExport`/`verifyAndStrip`) cũng do caller truyền vào, đúng lý do chính `save_integrity.dart` đã nêu: secret đóng cứng trong package sẽ bị lộ ngay khi 1 game build từ kit bị decompile.

**Luồng Export:** `_storage.exportAll()` → `signExport(data, secret)` → `jsonEncode` → giao cho `onExport`. Không cần confirm (không phá huỷ dữ liệu).

**Luồng Import (có confirm, vì `importAll()` ghi đè toàn bộ save):** bấm "Restore save" → `showConfirmDialog` cảnh báo rõ "This replaces all current progress... cannot be undone" → OK → `onImport()` → nếu `null` (người dùng huỷ file picker) coi là no-op im lặng, không phải lỗi → `jsonDecode` → phải là `Map` → `verifyAndStrip(decoded, secret)` (throw `FormatException` nếu thiếu checksum hoặc checksum sai) → `_storage.importAll(verified)`. Mọi nhánh lỗi (JSON hỏng, không phải Map, thiếu checksum, checksum sai, exception bất kỳ) đều bị bắt và hiển thị message inline, không bao giờ crash hay để `importAll` chạm vào dữ liệu chưa xác minh.

**Animation (IDEA-21 motion convention):** vùng thông báo trạng thái (idle/working/success/error) dùng `AnimatedSize` + `Curves.easeOut` — status/warning-class, không phải celebration, nên KHÔNG dùng overshoot; `reducedMotion` → `Duration.zero`. Khi đang xử lý (`working`), cả 2 nút bị vô hiệu hoá (`onTap: null`) và hiện `CircularProgressIndicator` nhỏ thay icon, tránh double-submit.

**Test:** `test/widget/common/backup_restore_panel_test.dart`, 13 test case — render ban đầu, export (thành công + round-trip verify được bằng `verifyAndStrip`, throw → error message, trạng thái working vô hiệu hoá nút), import (hiện đúng confirm dialog, bấm Cancel không gọi `onImport`, trả `null` không lỗi, round-trip đúng dữ liệu qua `storage.importAll`, checksum sai → đúng message tiếng Việt từ `save_integrity.dart`, thiếu checksum → đúng message, JSON hỏng/không phải Map → error không crash), reducedMotion.

**StrokeText double-render (lặp lại lỗi đã biết):** `CommonButton` render qua `StrokeText` (2 `Text` cùng nội dung: lớp viền + lớp nền) — `find.text(...)` khớp 2 widget. Sửa: `.last` khi `tap()` (lớp nền mới thực sự hit-test được, tránh warning "would not hit test"), `findsWidgets` khi chỉ kiểm tra tồn tại.

**Demo + device smoke test:** thêm demo round-trip vào `example/lib/screens/widget_showcase_screen.dart` (nhóm "Layout & Cards", sau `GameOverCardTemplate`) — `onExport` lưu chuỗi JSON cuối vào 1 biến state, `onImport` trả lại chính chuỗi đó (mô phỏng "khôi phục bản backup gần nhất", không cần file picker/QR thật cho mục đích demo). Việc thêm demo làm `ListView` eager-build trong showcase dài hơn ngưỡng `physicalSize` cố định của `widget_showcase_screen_test.dart` (test dựng toàn bộ màn hình không cuộn) — nút "Bump heat" ở section Game Feel rơi ra ngoài viewport 8500px cũ, gây lỗi hit-test không liên quan tới logic panel. Fix: tăng `physicalSize` test từ `Size(1080, 8500)` lên `Size(1080, 9000)` (cùng nguyên nhân/loại fix đã áp dụng trước đây cho các demo mới khác trong file này).

Device smoke test thật trên **TECNO BG6** (`118743744X002560`, máy hiện tại của phiên — Samsung SM-S928B trước đó mất kết nối adb giữa phiên): cài APK debug mới (phải `adb uninstall` trước do đổi chữ ký so với bản cũ), cuộn tới demo `BackupRestorePanel` trong Widget Kit → bấm "Export save" → hiện đúng icon check xanh + "Save exported." → bấm "Restore save" → confirm dialog "Restore save?" hiện đúng cảnh báo → bấm OK → hiện đúng "Save restored." → `adb logcat` lọc `level=Error` cho tiến trình app: không có dòng nào. Full round-trip export→confirm→restore hoạt động đúng trên thiết bị thật, không crash.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 828/828 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass (sau khi sửa `physicalSize`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart`'s gate KHÔNG áp dụng cho widget này (tool chỉ quét trực tiếp các file được `export` từ `lib/roy_casual_kit.dart` — `BackupRestorePanel` chỉ lộ diện gián tiếp qua barrel `common_widgets.dart`, đã được ghi nhận qua CHANGELOG dù gate tự động không track).

**Tự chấm điểm:** 9.5/10 — đúng yêu cầu "Đề xuất" (seam convention, confirm gate cho import phá huỷ), test bao phủ đủ mọi nhánh lỗi/corrupt của luồng sign/verify, device smoke test thật với bằng chứng cụ thể (không giả lập), động curve/reducedMotion đúng quy ước, không over-engineer (không tự ý thêm cơ chế file/QR cụ thể nào — đúng phạm vi "Đề xuất" yêu cầu).
