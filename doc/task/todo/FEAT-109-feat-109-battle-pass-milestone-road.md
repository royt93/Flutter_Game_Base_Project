---
id: FEAT-109
title: BattlePassRoad / MilestoneTrack — Đường ray mốc phần thưởng Free & VIP
type: feature
priority: P0
effort: L
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Tính năng giữ chân người chơi quan trọng nhất của casual/live-ops game. Hiển thị chuỗi mốc tiến độ mùa, quà Free và quà VIP.

## Đề xuất phạm vi
Widget BattlePassRoad nhận danh sách MilestoneItem, vẽ đường ray tiến độ nối giữa các mốc, đánh dấu trạng thái locked/claimable/claimed và hỗ trợ cuộn tới mốc hiện tại.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán tỷ lệ tiến độ giữa 2 mốc kề nhau và xác định danh sách phần thưởng có thể nhận.
- [ ] **Widget test**: Render danh sách 10 mốc, cuộn đến mốc số 5, tap nút nhận quà mốc và kiểm tra callback onClaimMilestone được gọi đúng mốc.
- [ ] **Integration test**: Mở BattlePass trên thiết bị thật, cuộn mượt mà qua 30 mốc phần thưởng không giật khung hình.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: ListView.builder ảo hoá các mốc ngoài màn hình, vẽ đường nối tiến độ bằng CustomPainter tối ưu.
