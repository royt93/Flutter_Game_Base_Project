---
id: FEAT-157
title: UpgradePreviewPanel — So sánh chỉ số trước/sau và chi phí nâng cấp
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Progression, Crafting & Collection Meta UI (Wave 14)
---

## Vì sao cần
Nâng cấp thường tiêu hao tài nguyên và khó đảo ngược. Panel cần cho người chơi so sánh thuộc tính hiện tại/sau nâng cấp, cost và kết quả trước khi xác nhận.

## Đề xuất phạm vi
Widget `UpgradePreviewPanel` hiển thị:
- Tên item/upgrade level, danh sách `UpgradeStatChange` với giá trị hiện tại và giá trị sau nâng cấp đã format sẵn.
- Chi phí theo currency/item caller cung cấp và affordability state từ caller.
- Nút `Upgrade` gọi `onUpgrade`; disable khi không đủ tài nguyên/đã max theo props.
- Không tính công thức stat/cost, tiêu hao ví hay commit upgrade trong widget.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate labels không rỗng, cost không âm, stat values hữu hạn; max/affordable state hợp lệ.
- [ ] **Widget test**: Before/after diff, cost, affordable/insufficient/max states, callback, semantics, Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro xem preview, upgrade seam cập nhật showcase state; không dùng simulator.
- [ ] **Golden test**: Tăng/giảm stats, nhiều currency, insufficient/max trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rebuild khi upgrade callback pending không gọi callback kép từ widget.
- [ ] **Network conditioning test**: N/A — widget presentation-only; purchase/cloud upgrade thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau mount/unmount panel.
- [ ] **Frame rate / Jank test**: FrameTiming nếu preview có animation; báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — không tự gọi store/ad SDK.

## Hiệu năng & Animation
- [ ] Chỉ animate thay đổi giá trị ngắn nếu được chốt; Reduced Motion phải bỏ transition.
- [ ] Sustained 60 FPS benchmark: chỉ tuyên bố sau đo trên thiết bị vật lý.
