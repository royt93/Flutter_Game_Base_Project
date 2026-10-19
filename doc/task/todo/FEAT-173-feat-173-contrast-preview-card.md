---
id: FEAT-173
title: ContrastPreviewCard — Preview tương phản chữ/nền với ngưỡng WCAG
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
`NeonTheme.colorBlindSafe` đổi palette gem cho game, nhưng không giúp designer/caller đánh giá độ đọc của các cặp text/background dùng trong panel và button. Cần một card preview tùy chỉnh để xem cặp màu, tỷ lệ tương phản WCAG và nhãn đạt/nguy cơ mà không đổi global theme.

## Đề xuất phạm vi
Widget `ContrastPreviewCard` hiển thị:
- Foreground/background màu caller truyền vào, cùng sample text caller cung cấp.
- Tỷ lệ contrast tính bằng `Color.computeLuminance()` nội bộ, không package mới.
- Ngưỡng WCAG AA normal text 4.5:1 và large text 3:1; caller có thể yêu cầu ngưỡng rõ ràng bằng scalar hữu hạn dương.
- Badge pass/fail có cả icon/màu và chữ (không chỉ encode bằng màu).
- `onTap` tuỳ chọn mở editor caller; preview không cập nhật `NeonTheme` hoặc lưu palette.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: contrast black/white gần 21:1, cùng màu 1:1, ngưỡng finite và >0, sample text không rỗng; runtime `ArgumentError`.
- [ ] **Widget test**: pass/fail normal/large, threshold custom, semantics đọc tỷ lệ + kết quả, callback, 320dp + textScale 2.0 + RTL, kết quả đạt/fail có text/icon rõ khi màu sắc không phân biệt được.
- [ ] **Integration test (Device)**: showcase card hiện pass/fail cho cặp màu mẫu; tap seam mở caller editor; thiết bị thật, kiểm tra foreground và hỏi nếu app khác đang dùng.
- [ ] **Golden test**: WCAG pass/fail/custom threshold × 7 biến thể, viewport 390×844, baselines Linux + Flutter 3.35.1.
- [ ] **Interruption test**: đổi cặp màu liên tục không state/ticker mồ côi.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: stateless hoặc không ticker; unmount sạch.
- [ ] **Frame rate / Jank test**: không animation/controller, perf-critical interaction không thuộc scope.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Kết-resulta cập nhật tức thì; biểu tượng + text status luôn đi kèm màu; không animation cần thiết.
