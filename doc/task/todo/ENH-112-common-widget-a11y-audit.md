---
id: ENH-112
title: "Widget common: kiểm tra a11y cho 21 widget tương tác chưa có test semantics riêng"
type: enhancement
layer: lib/presentation/widgets/common, test/widget/common
priority: P3
effort: M
source: "Khảo sát 2026-11-23 theo định hướng owner (widget common). Heuristic đo, CHƯA xác nhận từng widget có lỗi a11y thật."
---

## Bằng chứng đã đo

- 169 file widget được export, 169 class public. Bộ `viewport_sweep_test.dart` tham chiếu 168/169 (`TooltipBubble` có test riêng `tooltip_bubble_test.dart`); `runViewportSweep` chỉ kiểm tra **layout** (không overflow, mục tiêu nằm trong viewport), không kiểm tra semantics.
- 125/169 widget có callback chạm hoặc đổi giá trị.
- Heuristic (grep): 21 widget tương tác không có test nào vừa nhắc tên widget vừa dùng `meetsGuideline`/`getSemantics`/`bySemanticsLabel`/`ensureSemantics`:
  `AppVersionGateOverlay`, `AsyncCommonButton`, `CandyTextField`, `QuestBoardPanel`, `BackupRestorePanel`, `PiggyBankVault`, `ExpandablePanel`, `SwipeableActionTile`, `StreakShieldCard`, `InboxMessageCard`, `DailyOfferStack`, `EventCalendarCard`, `ComebackBundleCard`, `CollectionAlbumPanel`, `GuildContributionCard`, `CommunityLeaderboardCard`, `FriendInviteProgressCard`, `CraftingRecipeCard`, `CharacterCollectionGrid`, `RankPromotionDialog`, `TeamRosterList`.

## Giới hạn của bằng chứng (đọc kỹ trước khi làm)

- Heuristic có thể báo THỪA: nhiều widget đã dựng `Semantics` trong mã nguồn và test kiểm hành vi bằng cách khác. Ví dụ `AsyncCommonButton` (5 chỗ dùng `Semantics`, 6 test nhắc tên) và `SwipeableActionTile` (6 chỗ) khó có thể là lỗ hổng.
- Thử trực tiếp `CandyTextField` bằng cây semantics thật: nhãn "Player name" được đọc đúng cả khi rỗng lẫn khi đã nhập (value "Alex"); nghĩa là widget này ổn dù không có `Semantics` tự viết (Flutter dùng `hintText`). Không phải mọi mục trong danh sách là lỗi.
- Chưa kiểm tra từng widget còn lại, cũng chưa đo kích thước vùng chạm, tương phản màu hay thứ tự focus bằng bộ guideline.

## Phạm vi đề xuất

1. Với mỗi widget trong danh sách, đọc source và test hiện có, rồi viết test semantics tối thiểu: nhãn, trạng thái, hành động tap/increase (`meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline`).
2. Chỉ widget thực sự thiếu nhãn hoặc vùng chạm nhỏ mới sửa code; widget ổn chỉ thêm test khoá hành vi.
3. Cân nhắc đưa kiểm tra semantics cơ bản vào `runViewportSweep` để 168 widget được phủ cùng lúc (cần đo tác động: có thể làm nhiều widget đỏ cùng lúc).

## Câu hỏi owner cần chốt

- Mức ưu tiên so với web (ENH-111): làm a11y cho cả 21 widget, hay chọn nhóm theo mức dùng trong game?
- Có muốn ép guideline vào sweep chung (một chỗ, phủ rộng nhưng có thể nhiều lỗi lộ ra cùng lúc) hay làm từng widget?

## Acceptance criteria

- [ ] Mỗi widget trong danh sách có kết luận ghi lại: ổn (kèm test khoá), hoặc lỗi (kèm sửa và test).
- [ ] Không thay đổi hành vi hay giao diện của widget đã ổn.
- [ ] `flutter test` sạch; golden không đổi (nếu có thay đổi hình ảnh phải qua workflow regenerate, không tạo golden trên macOS).
- [ ] Audit >9/10.

## Kết quả thực hiện

- Kết luận từng widget:
- Audit / điểm:
- Tests:
- Commit/push:
