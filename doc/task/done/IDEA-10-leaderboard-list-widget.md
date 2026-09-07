---
id: IDEA-10
title: "Leaderboard list widget hiển thị thuần (dữ liệu do app cung cấp)"
type: idea
priority: exclusive (độ tin cậy thấp/marginal — xem ghi chú)
effort: S-M
source: Claude, audit round 2 (fork agent)
---

## Ý tưởng
`WidgetShowcaseScreen`'s demo hiện giả 1 dòng "Leaderboard" bằng
`CommonListTile` thường — chưa có widget leaderboard thật (rank + tên +
điểm + avatar, style candy). Theo đúng convention `VictoryCardTemplate`:
app cung cấp data, widget không tự nghĩ ra cơ chế ranking.

## Ghi chú độ tin cậy
Marginal — có thể chỉ cần compose `PanelCard`/`ListTileRow`/`AvatarFrame` có
sẵn là đủ, không cần 1 widget riêng. Cân nhắc kỹ trước khi làm, có thể đóng
task này luôn nếu xác nhận không đáng làm riêng.
