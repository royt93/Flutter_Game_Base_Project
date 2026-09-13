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
- [ ] Panel gọi đúng signExport khi export, verifyAndStrip khi import, hiển thị đúng trạng thái lỗi khi checksum sai.
- [ ] onExport/onImport là callback do caller cung cấp, panel không tự quyết định cơ chế lưu file/QR/share cụ thể.
- [ ] Test: export rồi import lại đúng dữ liệu gốc; import 1 chuỗi bị chỉnh sửa (checksum sai) hiển thị đúng trạng thái lỗi, không crash.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

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
