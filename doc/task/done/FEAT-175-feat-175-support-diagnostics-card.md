---
id: FEAT-175
title: SupportDiagnosticsCard — Thẻ xuất gói chẩn đoán đã allowlist để chia sẻ support
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
`DiagnosticsExportBundle` đã tạo JSON có giới hạn kích thước, từng section lỗi độc lập và config allowlist; `SettingsScreen` đã có export/erasure quyền dữ liệu. Còn thiếu UI support an toàn để caller cung cấp bundle đã build, người dùng xem thành phần/giới hạn và xác nhận chia sẻ. Không được nối trực tiếp raw `StorageService.exportAll()`.

## Đề xuất phạm vi
Widget `SupportDiagnosticsCard` hiển thị:
- Tóm tắt bundle: app version, generated time đã format, section names, truncated flag, lỗi section (nếu có), không render toàn bộ logs mặc định.
- Nút `Share diagnostics` gọi callback bất đồng bộ với bundle đã lọc do caller cung cấp; busy/disabled khi đang chia sẻ; lỗi caller truyền lại hiển thị an toàn.
- Nút preview tùy chọn mở bản xem `DiagnosticsBundleView` do caller dựng; cho phép đóng và không gọi share.
- Nhắc trước dữ liệu sẽ được chia sẻ; không gửi network, không thu credentials/PII riêng, không xây DiagnosticsExportBundle thứ hai.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime validate appVersion/generatedAt/section/error summaries không rỗng; widget chỉ nhận `SupportDiagnosticsSummary` typed, không nhận raw map/storage dump; section error text không render.
- [x] **Widget test**: 8 test local: summary đầy đủ/truncated/section error, confirm trước share, busy chặn double tap, lỗi share hiện copy generic (không lộ exception text) và retry, preview mở/đóng không share, semantics, textScale 2.0 + 320dp + RTL, CTA qua CommonButton.
- [x] **Integration test (Device)**: `FEAT-175: diagnostics summary previews and confirms local share` pass trên Pixel 7 Pro (`2B051FDH3006MU`), chỉ dùng callback cục bộ, không gửi network. Kết quả: `All tests passed`.
- [x] **Golden test**: normal/truncated/errors × 7 biến thể, viewport 390×844; workflow Linux + Flutter 3.35.1 pass (`39434438230`). 21 PNG đã xác minh trùng với output workflow; lockfiles không thay đổi trong working tree.
- [x] **Interruption test**: host widget test bật/tắt preview và confirm/cancel 5 lần, unmount sạch.
- [x] **Network conditioning test**: N/A — callback demo chỉ local, widget không tự gửi network.
- [x] **Memory leak & profiling test**: widget không sở hữu timer/controller; host unmount khi preview/confirm mở không exception. Không chạy heap profiler.
- [x] **Frame rate / Jank test**: không animation/scroll workload nội bộ; async busy được widget-test. Không thu FrameTiming riêng.
- [x] **IAP & Ad mediation test**: N/A.

## Bảo mật/riêng tư bắt buộc
- Chỉ nhận summary typed, không nhận raw bundle/map/storage dump; caller là owner `DiagnosticsExportBundle` và phải áp dụng config allowlist trước callback. UI xác nhận trước share và không render logs/error detail. Widget tests xác nhận share chỉ chạy sau confirm, section error không hiện text, exception text không lộ; payload allowlist chưa có test consumer-level riêng.

## Hiệu năng & Animation
- [x] Dùng `CommonButton.loading`; xác nhận bắt buộc trước share; không có network side effect nội bộ.

## Chạy lại
```bash
flutter test test/widget/common/support_diagnostics_card_test.dart test/widget/goldens/support_diagnostics_card_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-175
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-175
```

Golden baseline phải render bằng Linux + Flutter 3.35.1 workflow `regenerate-goldens.yml`; file macOS không dùng làm chuẩn.
