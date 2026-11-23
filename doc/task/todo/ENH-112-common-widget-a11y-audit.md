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

## Kết quả thực hiện (một phần, 2026-11-23)

Đã kiểm và sửa nhóm overlay chặn tương tác. Phần audit 21 widget theo danh sách heuristic CHƯA làm (task giữ ở `todo/`).

### Lỗi thật tìm được: overlay chặn không chặn screen reader

- Đo bằng cây semantics thật (không suy đoán): với `AppVersionGateOverlay` ở chế độ force update, screen reader vẫn nhận nút của app phía sau ("BEHIND BUTTON") cạnh nội dung overlay, nên người dùng TalkBack/VoiceOver có thể điều hướng và kích hoạt app đang bị chặn.
- Đo thêm 4 overlay chặn khác bằng cùng cách: `LoadingOverlay`, `SpotlightOverlay`, `NeonDialog.overlay`, `NeonDialog.overlaySlot` (PauseOverlay dùng overlaySlot) đều để app phía sau lộ ra cho screen reader.
- Sửa (owner chọn: 3 modal thật, giữ Loading): bọc bằng `BlockSemantics` ở `AppVersionGateOverlay`, `SpotlightOverlay`, `NeonDialog.overlay`; `NeonDialog.overlaySlot` chỉ chặn khi có panel (`blocking: panel != null`) vì slot luôn mount với panel nullable. Pause menu được sửa theo vì dùng overlaySlot. Diff thật nhỏ (whitespace-insensitive: 6, 5 và 15 dòng thêm).
- **Cố ý KHÔNG sửa `LoadingOverlay`**: comment ENH-37 trong source cho thấy tác giả đã chọn `liveRegion` thay vì chặn (đây chỉ là spinner tạm, không phải route modal; chặn semantics có thể làm người dùng không quay lại được nếu loading treo). Nó vẫn lộ app phía sau cho screen reader; đây là quyết định thiết kế có chủ đích, mở lại nếu muốn.

### Hiệu chỉnh phương pháp đo (đọc trước khi tin các số ở trên)

Một số probe đầu tiên của tôi dùng `find.bySemanticsLabel` trên dialog dạng route và báo "app phía sau vẫn tới được". Kết luận đó SAI cho route: cùng probe báo giống hệt trên `showDialog` gốc của Flutter, và công cụ tìm theo cây widget (có thể trả element dù node semantics bị gộp hoặc ẩn), nên không phản ánh đúng thứ screen reader đọc. Đã kiểm lại bằng `tester.semantics.simulatedAccessibilityTraversal()`, có 3 đối chứng: overlay thường (phải lộ), `ExcludeSemantics` (phải ẩn), `BlockSemantics` (phải ẩn), và kết quả đúng cả ba. Trên overlay dạng `Stack`, hai cách đo ĐỒNG Ý (kiểm trực tiếp ở 3 ca), nên các test đã commit (dùng `bySemanticsLabel`) vẫn đáng tin; riêng lỗi của gate/spotlight/NeonDialog.overlay/overlaySlot được xác nhận lại bằng cả thứ tự đọc: trước sửa lộ BEHIND, sau sửa chỉ còn nội dung overlay.

### Kiểm chứng

- Tests mới: 5 (gate: force update, maintenance, soft update, ok, đóng soft update trả lại app), 4 (NeonDialog: overlay, slot có panel, slot không panel, slot khi panel đóng), 1 (spotlight). Root 4121 pass, example 472 pass, analyze và audit a11y sạch, API không đổi.
- Mutation check: bỏ `BlockSemantics` hoặc đặt `blocking: false` ở từng overlay đều làm test đỏ; `overlaySlot` luôn chặn hoặc không bao giờ chặn đều đỏ (cả hai chiều được khoá).
- Thiết bị thật: Samsung Galaxy S24 Ultra `SM-S928B`, Android 17, debug `E2E_TEST=true`: `match3_game_flow_test.dart` (tutorial dùng SpotlightOverlay, pause menu dùng overlaySlot) pass, và test sẵn có `BUG-91/BUG-92: GameDemoScreen pause FAB` pass. Log: `doc/task/evidence/ENH-112-s24u-match3-flow-blocksemantics.log`, `ENH-112-s24u-gamedemo-pause-blocksemantics.log`. Chỉ chứng minh luồng vẫn chạy, KHÔNG chứng minh TalkBack thật đọc đúng (test semantics là trên cây widget, chưa bật TalkBack trên máy).

### Còn lại (chưa làm)

- Audit các widget tương tác còn lại trong danh sách 21 (nhớ heuristic báo thừa; ví dụ `CandyTextField` đã đo là ổn).
- Quyết định có chặn semantics cho `LoadingOverlay` hay không.
- Dialog/sheet dạng ROUTE (`NeonDialog.show`, `showModalBottomSheet`, `showDialog`): KHÔNG phải lỗi. Đã kiểm bằng mô phỏng thứ tự đọc của screen reader (`simulatedAccessibilityTraversal`), có đối chứng: route dialog ẩn trang bên dưới (BEHIND không còn trong thứ tự đọc), giống `showDialog` gốc của Flutter. Lý do: `ModalBarrier` của route tự bọc `BlockSemantics`. Chỉ overlay dựng thẳng trong cây (`Stack`) mới cần tự chặn.
- Chưa kiểm các widget dựng overlay trong `Stack` khác (`ConfirmDialog`, `RewardPopup`, `MilestoneCelebrationDialog`, `LevelUpOverlay`) có tự gọi `NeonDialog.overlay/overlaySlot` hay không; `RewardPopup` và `MilestoneCelebrationDialog` chỉ dùng `NeonDialog.panel`, nên chặn hay không tuỳ nơi gọi bọc.

- Audit / điểm: ~9.0/10 cho phần overlay (có đo, sửa gọn, hai chiều được khoá bằng test, có chạy thiết bị thật); phần audit 21 widget chưa chấm.
- Commit/push:
