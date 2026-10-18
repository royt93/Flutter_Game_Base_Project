---
id: FEAT-153
title: GuildContributionCard — Đóng góp guild vào mục tiêu cộng đồng và mốc thưởng
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Social, Collection & Community (Wave 13)
---

## Vì sao cần
Mục tiêu guild tạo động lực chơi cùng cộng đồng. Người chơi cần thấy đóng góp cá nhân, tiến độ chung và phần thưởng mốc kế tiếp để hiểu hành động của mình có tác động ra sao.

## Đề xuất phạm vi
Widget `GuildContributionCard` hiển thị:
- Tên guild/event goal, tiến độ tổng và mục tiêu tiếp theo; số đóng góp cá nhân do caller cung cấp.
- Mốc thưởng đã đạt/kế tiếp và trạng thái claim theo props caller.
- Nút `Contribute` gọi `onContribute`; nút claim mốc gọi `onClaimMilestone(milestoneId)` khi caller cho phép.
- Empty/loading/error states tùy chọn nếu data guild chưa có.
- Presentation-only: caller đồng bộ dữ liệu guild, xác thực đóng góp và cấp thưởng; widget không gọi network.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate goal > 0, progress không âm, milestone IDs duy nhất và tăng đơn điệu.
- [ ] **Widget test**: Progress tổng/cá nhân, milestones, claim/contribute callbacks, disabled/loading/error, semantics, Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) pass sau khi chạy bù: contribute tăng tổng và claim milestone gọi caller callback qua showcase. Lần chạy đầu fail vì milestone nằm ngoài viewport, đã sửa bằng cuộn vào vùng nhìn thấy.
- [ ] **Golden test**: Chưa đóng góp/đang tiến triển/goal hoàn tất/error trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: App pause/rebuild trong lúc update không gọi callback trùng hoặc hiển thị progress stale.
- [ ] **Network conditioning test**: Service/consumer contract test riêng nếu caller sync guild từ backend; UI chỉ test state props.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau mount/unmount và cập nhật milestone.
- [ ] **Frame rate / Jank test**: Animation progress và milestone list; báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — không có store/ad flow trong widget.

## Hiệu năng & Animation
- [ ] Progress animation ngắn, tuân Reduced Motion; không animate lại toàn card ở mỗi update.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
