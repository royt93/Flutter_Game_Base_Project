---
id: FEAT-154
title: CommunityLeaderboardCard — Bảng xếp hạng đóng góp cộng đồng
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Social, Collection & Community (Wave 13)
---

## Vì sao cần
Leaderboard đóng góp guild/event giúp người chơi thấy thứ hạng của mình so với cộng đồng và tạo động lực tham gia. Cần trình bày thứ hạng ổn định mà không để widget tự sắp xếp hoặc kết nối dịch vụ leaderboard.

## Đề xuất phạm vi
Widget `CommunityLeaderboardCard` hiển thị:
- Các `CommunityRankEntry` đã được caller sắp xếp: rank, display name, avatar/icon tùy chọn, formatted contribution score và current-player state.
- Highlight người chơi hiện tại; vùng tăng/giữ/giảm hạng tùy chọn theo props.
- Tap hàng gọi `onPlayerTap(playerId)` tùy chọn; nút refresh gọi callback caller nếu được truyền.
- Empty/loading/error states do caller cung cấp.
- Presentation-only: caller sở hữu dữ liệu, thứ tự, tie-break và privacy policy.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate player IDs duy nhất, rank dương, display name/score label không rỗng.
- [ ] **Widget test**: Giữ đúng thứ tự input, current-player highlight, rank zone, long names/text scale, callbacks, empty/loading/error, semantics.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) pass sau khi chạy bù: tap người chơi và refresh gọi caller callback qua showcase.
- [ ] **Golden test**: Current player ở top/mid/outside visible range, zones và empty trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rebuild data khi row tap/refresh không để stale state hoặc callback lặp.
- [ ] **Network conditioning test**: N/A cho widget; timeout/offline thuộc caller service contract test.
- [ ] **Memory leak & profiling test**: MemoryWatchdog trên leaderboard lớn sau scroll/unmount.
- [ ] **Frame rate / Jank test**: Scroll 100+ rows, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Dùng `ListView.builder` khi entries nhiều; row không tạo controller riêng.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo scroll trên thiết bị vật lý.
