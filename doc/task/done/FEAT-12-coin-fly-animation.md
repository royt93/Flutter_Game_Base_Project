---
id: FEAT-12
title: Coin-fly/reward-fly animation widget
type: feature
priority: P2
effort: M
source: fork nội bộ + agy
---

## Vì sao cần
`CurrencyCounter` hiện đổi số tức thời, không có hiệu ứng "đồng tiền bay từ
điểm A đến B rồi cộng vào số dư" — hiệu ứng rất phổ biến trong casual game,
tăng cảm giác "đã tay" khi nhận thưởng.

## Đề xuất phạm vi
1 widget overlay tạo N icon bay theo quỹ đạo (thẳng hoặc cong nhẹ) từ điểm
nguồn tới `GlobalKey` của `CurrencyCounter`, khi chạm đích thì tăng dần số
hiển thị + tuỳ chọn gọi `fireHaptic`/âm thanh qua `AudioManager`.

## Acceptance criteria
- [ ] Số coin bay đến đích đúng bằng số lượng cộng vào `CurrencyCounter`.
- [ ] Widget test verify animation kết thúc đúng thời điểm, không leak `AnimationController`.
