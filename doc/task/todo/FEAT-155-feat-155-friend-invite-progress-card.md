---
id: FEAT-155
title: FriendInviteProgressCard — Tiến độ mời bạn bè và mốc thưởng caller-owned
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Social, Collection & Community (Wave 13)
---

## Vì sao cần
Chương trình giới thiệu bạn bè cần cho người chơi thấy số lời mời hợp lệ, tiến độ tới mốc thưởng và cách chia sẻ lời mời. Card cần tăng mức hiển thị cho referral mà không tự tạo attribution hoặc xác nhận lượt mời.

## Đề xuất phạm vi
Widget `FriendInviteProgressCard` hiển thị:
- Tiêu đề/copy caller cung cấp, số lời mời đã hoàn tất, tổng mục tiêu và progress.
- Mốc thưởng caller cung cấp (`MilestoneReward`) cùng trạng thái locked/claimable/claimed.
- Nút `Invite Friends` gọi `onInvite`; nút claim (nếu claimable) gọi `onClaimReward`.
- Mã/link invite nếu caller truyền, với `onCopyInvite` tùy chọn; widget không tự tạo deep link/attribution.
- Presentation-only: caller dùng `InviteFriendCoordinator`/analytics/referral backend để kiểm tra lượt hợp lệ và cấp thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate invite count không âm, goal > 0, milestone/reward labels hợp lệ.
- [ ] **Widget test**: Progress, milestone states, invite/claim/copy callbacks, maxed state, semantics, Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro gọi invite/copy/claim caller seams; không dùng simulator, không gửi lời mời thật.
- [ ] **Golden test**: 0%, gần mốc, hoàn tất, claimed và không có mã invite trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Dismiss/rebuild trong lúc caller action pending không gọi action hai lần.
- [ ] **Network conditioning test**: Referral validation/backend retry thuộc consumer contract tests; widget không fetch.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau mount/unmount; kiểm tra không giữ clipboard/controller listener.
- [ ] **Frame rate / Jank test**: Progress update/entrance, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — referral reward không đi qua IAP/ad trong widget.

## Hiệu năng & Animation
- [ ] Progress transition ngắn và tuân Reduced Motion; không lưu referral data trong widget.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
