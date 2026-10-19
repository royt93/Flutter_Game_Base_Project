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
- [ ] **Unit test**: maxBytes dương, labels/error text không rỗng; constructor nhận model summary typed, không nhận map raw/storage dump.
- [ ] **Widget test**: bundle đầy đủ/truncated/section error, share callback đúng một lần, busy chặn double tap, lỗi chia sẻ hiện copy safe và cho retry, preview mở/đóng, semantics/narration, textScale 2.0 + 320dp + RTL, CTA 48dp.
- [ ] **Integration test (Device)**: mock/local caller seam tạo bundle rồi preview và share qua dialog xác nhận (không gửi dữ liệu ra ngoài); thiết bị thật, foreground check và hỏi nếu app khác đang dùng.
- [ ] **Golden test**: summary bình thường/truncated/lỗi × 7 biến thể, viewport 390×844, baselines Linux + Flutter 3.35.1.
- [ ] **Interruption test**: đóng preview/chuyển busy liên tục không gọi share trùng hoặc để overlay mồ côi.
- [ ] **Network conditioning test**: N/A — widget không truyền dữ liệu qua network.
- [ ] **Memory leak & profiling test**: unmount trong preview/busy không timer/controller mồ côi.
- [ ] **Frame rate / Jank test**: không animation nặng; verify main isolate không giữ UI khi callback bất đồng bộ.
- [ ] **IAP & Ad mediation test**: N/A.

## Bảo mật/riêng tư bắt buộc
- Chỉ nhận bundle đã qua `DiagnosticsExportBundle`; cấm raw storage export. UI hiển thị rõ xác nhận trước share. Test xác nhận payload không chứa field ngoài allowlist.

## Hiệu năng & Animation
- [ ] Dùng `AsyncCommonButton`/`CommonButton.loading`, reduced motion mặc định theo widget chung; không có network side effect nội bộ.
