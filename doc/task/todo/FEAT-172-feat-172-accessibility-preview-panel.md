---
id: FEAT-172
title: AccessibilityPreviewPanel — Preview cỡ chữ và vùng chạm 48dp ngay trong ứng dụng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
`SettingsScreen` hiện có locale, audio, dark mode, color-blind-safe và wake-lock, nhưng người chơi chưa có cách kiểm tra nhanh giao diện ở cỡ chữ lớn hay nhận biết các vùng chạm. Panel preview giúp kiểm tra bố cục trước khi quay lại game mà không thay đổi cỡ chữ toàn hệ thống.

## Đề xuất phạm vi
Widget `AccessibilityPreviewPanel` hiển thị:
- Mẫu UI giả lập caller-provided (`preview`) trong vùng cuộn riêng, không sửa `MediaQuery` của ứng dụng cha.
- Nút preview text scale 1.0/1.3/2.0 chỉ áp dụng trong subtree preview.
- Overlay tùy chọn viền vùng tương tác bằng `ColoredBox`/`Stack` do caller cấp các `GlobalKey` mục tiêu; không suy đoán hitbox tự động.
- `onClose` tuỳ chọn đóng panel; không lưu preference hay gọi Settings API.
- Bố cục hoạt động trong parent bounded height; trạng thái/label được caller định dạng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `preview` bắt buộc, `targets` có key duy nhất, height hợp lệ nếu nhận maxHeight; throw `ArgumentError` runtime.
- [ ] **Widget test**: scale 1/1.3/2 đổi subtree preview, widget bên ngoài giữ scale gốc, bật/tắt highlight chỉ vẽ overlay cho target đã có render box, target list rỗng, close callback, semantics cho các điều khiển, 320dp + scale 2.0 không overflow, reduced motion không giữ ticker.
- [ ] **Integration test (Device)**: mở panel trong showcase, thử scale 2.0, đóng panel; thiết bị thật, kiểm tra serial/foreground và hỏi nếu app khác đang dùng; không dùng simulator.
- [ ] **Golden test**: baseline/scale 1.3/scale 2/highlight × 7 biến thể, viewport 390×844; baselines Linux + Flutter 3.35.1 theo `CLAUDE.md`.
- [ ] **Interruption test**: đổi scale/highlight liên tục rồi unmount, không callback/ticker mồ côi.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: không controller riêng; `transientCallbackCount == 0` sau unmount.
- [ ] **Frame rate / Jank test**: không thêm animation/controller; kiểm tra layout update ở 2x và ghi FrameTiming chỉ khi cần benchmark (không tuyên bố 60 FPS).
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Chuyển scale tức thì (preview tool, không phải game animation); highlight bật/tắt không tạo ticker; tăng kích thước chữ không làm mất focus/tap semantics.
