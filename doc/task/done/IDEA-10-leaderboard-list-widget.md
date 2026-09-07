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

## Quyết định
Làm widget riêng `LeaderboardList` (+ `LeaderboardEntry` data class) tại
`lib/presentation/widgets/common/leaderboard_list.dart`, compose từ
`AvatarFrame` cho avatar slot, tự vẽ row (rank + tên + điểm + border accent
khi `highlighted`) theo đúng convention `VictoryCardTemplate`/`CommonListTile`
— rank/tên/điểm là string do app cung cấp, widget không tự tính ranking.
Export qua `common_widgets.dart`, demo trong `WidgetShowcaseScreen`. TDD:
test viết trước (4 case: render rank/tên/điểm, avatar tuỳ chọn, highlighted
row có border còn lại thì không, empty list không throw), xác nhận fail
đúng lý do trước khi viết widget. Verify: `flutter analyze`/`flutter test`
sạch ở root + `example/`, kiểm tra live trên Pixel 7 Pro thật — render đúng,
không exception.
