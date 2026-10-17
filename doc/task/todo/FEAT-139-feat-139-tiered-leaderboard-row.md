---
id: FEAT-139
title: TieredLeaderboardRow — Hàng leaderboard phân hạng với trạng thái thăng/xuống hạng tuần
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Retention & Live-Ops Expansion (Wave 9)
---

## Vì sao cần
Bảng xếp hạng phân hạng (Bronze/Silver/Gold/Diamond) tạo mục tiêu cạnh tranh tuần và động lực quay lại trước khi mùa giải kết thúc. Dòng leaderboard cần làm nổi bật hạng, vị trí người chơi, điểm, và trạng thái thăng hạng/giữ hạng/xuống hạng.

## Đề xuất phạm vi
Widget `TieredLeaderboardRow` hiển thị:
- `rank`, `playerName`, `score`, `tier` (Bronze/Silver/Gold/Diamond), avatar/icon tùy chọn.
- Màu viền/nền và badge huy hiệu theo tier; màu không phải chỉ dấu duy nhất (hiển thị cả tên tier và icon).
- Vùng phân hạng theo thứ tự caller cung cấp (`promotion`, `safe`, `demotion`); người chơi hiện tại được làm nổi bật.
- Thay đổi điểm/vị trí có thể chạy chuyển động trượt ngắn; Reduced Motion hiển thị trạng thái cuối ngay.
- Widget thuần trình bày: caller cấp thứ hạng đã tính và dữ liệu đã đồng bộ; không tự truy cập network hoặc leaderboard service.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Kiểm tra mapping tier sang màu/icon/label, validate rank dương, score không âm, playerName không rỗng và zone hợp lệ.
- [ ] **Widget test**: Render từng tier/zone, highlight player hiện tại, điểm thay đổi cập nhật đúng; Reduced Motion bỏ slide; semantics thông báo rank/tier/score/zone.
- [ ] **Integration test (Device)**: Smoke trên Pixel 7 Pro với mẫu danh sách nhiều tier và dòng người chơi hiện tại; kiểm tra thao tác cuộn/tap nếu có callback.
- [ ] **Golden test**: Ma trận Bronze/Silver/Gold/Diamond × promotion/safe/demotion trên light/dark, RTL và textScale 1.0/1.4.
- [ ] **Interruption test**: Thay dữ liệu leaderboard hoặc route dispose giữa slide animation; không để controller/ticker mồ côi.
- [ ] **Network conditioning test**: Integration/service test riêng mô phỏng response chậm/lỗi và dữ liệu stale tại seam caller; row widget không tự retry hay gọi network.
- [ ] **Memory leak & profiling test**: Dùng MemoryLifecycleWatchdog cho mount/update/unmount lặp lại; xác nhận không orphan animation controller/subscription.
- [ ] **Frame rate / Jank test**: Profile danh sách leaderboard với tối thiểu 50 dòng dưới cuộn và cập nhật rank; báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A (leaderboard row không mua hàng/không hiển thị quảng cáo).

## Hiệu năng & Animation
- [ ] Row phải thân thiện với `ListView.builder`/lazy lists; không tạo controller lặp vô hạn khi off-screen.
- [ ] Sustained 60 FPS benchmark: đo dưới workload scroll + rank update; không tuyên bố nếu chưa đạt.
