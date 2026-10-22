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
- [x] **Unit test**: contrast black/white gần 21:1, cùng màu 1:1, ngưỡng finite và >0, sample text không rỗng; runtime `ArgumentError`.
- [x] **Widget test**: 7 unit/widget tests pass ngày 2026-10-20; normal/large pass/fail, custom threshold, semantics ratio + result, callback, 320dp + textScale 2.0 + RTL, text/icon đi kèm trạng thái. Host showcase test pass.
- [x] **Integration test (Device)**: `FEAT-173: contrast preview reports pass/fail and routes editor` báo `All tests passed` trên TECNO; log xác minh tại `/tmp/feat173_smoke_tecno.log`. Smoke kiểm tra pass/fail và callback đổi bộ đếm `Contrast edits: 1`, không mở editor thật.
- [x] **Golden test**: normal_pass/normal_fail/large_pass/custom_threshold × 7 biến thể, viewport 390×844; baselines Linux + Flutter 3.35.1 đã có trong repo. Workflow `39434438230` render lại cả 4 matrix thành công, không tạo thay đổi cho contrast PNG.
- [x] **Interruption test**: test đổi cặp màu 5 lần, kiểm tra status mỗi lần rồi unmount sạch; không exception hoặc transient callback còn lại.
- [x] **Network conditioning test**: N/A — không network.
- [x] **Memory leak & profiling test**: stateless, không controller/timer; unmount test pass. Không chạy heap profiler.
- [x] **Frame rate / Jank test**: không animation/controller; không thu FrameTiming riêng hoặc tuyên bố 60 FPS.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Kết quả cập nhật tức thì; biểu tượng + text status đi kèm màu; không animation nội bộ.
