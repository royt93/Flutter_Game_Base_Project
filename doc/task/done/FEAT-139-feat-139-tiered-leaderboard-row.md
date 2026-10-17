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
- [x] **Unit test**: Mapping tier sang tên/màu/icon, zone sang icon/màu/semantics; validate rank dương, score/name không rỗng và height hữu hạn/dương.
- [x] **Widget test**: Các zone promotion/safe/demotion, highlight current player, tap callback, display-only khi callback null, rank/score transition, Reduced Motion và semantics.
- [x] **Integration test (Device)**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), cập nhật rank/score qua showcase và xác nhận dòng current-player.
- [x] **Golden test**: `runGoldenMatrix` light/dark/vi/RTL/textScale 1.3/2.0/reducedMotion không overflow; test bắt được 2px overflow ở textScale 1.3 và dẫn đến responsive minHeight fix.
- [x] **Interruption test**: Rank/score update mid-transition và pump/unmount không crash hoặc giữ ticker.
- [x] **Network conditioning test**: N/A — row thuần presentation, nhận dữ liệu caller đã đồng bộ, không gọi network/service.
- [x] **Memory leak & profiling test**: Row không sở hữu controller/subscription; transition dùng `AnimatedSwitcher` và `PressableScale` quản lý lifecycle; tests pump update/unmount không báo exception.
- [x] **Frame rate / Jank test**: Có telemetry hỗn hợp Wave 8 Pixel 7 Pro (81 frames, p50=19.00ms, p95=73.98ms, p99=179.05ms, slow=61.7%, jank=13); không phải đo riêng leaderboard, không tuyên bố sustained 60 FPS.
- [x] **IAP & Ad mediation test**: N/A — leaderboard row không mua hàng hoặc hiển thị ads.

## Hiệu năng & Animation
- [x] Stateless row keyed by rank, suitable for lazy lists; rank/score transitions are implicit and no persistent per-row controller is created.
- [ ] Benchmark riêng workload scroll + rank update: chưa đo; không tuyên bố sustained 60 FPS.
