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

Hoàn thành (2026-11-23): sửa nhóm overlay chặn tương tác; đo 21 widget bằng quét semantics tự động (17 sạch, 2 lỗi thật đã sửa, 1 báo thừa, 1 lỗi thật tách thành ENH-113). Phần chưa làm liệt kê ở mục "Chưa làm".

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

### Đo 21 widget bằng quét semantics tự động (2026-11-23)

- Phương pháp: tạm gắn một bộ quét vào `runViewportSweep` (đã gỡ sau khi đo, không commit), chạy qua toàn bộ 339 test sweep ở viewport 360x640, text 1x. Mỗi node có hành động chạm (tap, long press, tăng/giảm) phải có nhãn hoặc giá trị và vùng chạm >= 44dp. Đối chứng: nút 20x20 không nhãn bị báo cả hai lỗi; nút có nhãn 48x48 sạch.
- Kết quả: **17/21 widget sạch**. Bốn phát hiện, đã phân loại sau khi đọc source và đo trực tiếp:

| Widget | Phát hiện của máy quét | Kết luận | Xử lý |
| --- | --- | --- | --- |
| `ExpandablePanel` | header là nút không nhãn (khi không truyền `semanticLabel`) | **Lỗi thật.** Screen reader nghe một nút rỗng rồi một nút khác chứa chữ; `Semantics` ngoài và `GestureDetector` trong `PressableScale` đều khai báo hành động tap. | Sửa: bỏ `onTap` thừa trên `Semantics` ngoài (1 dòng). Header nay là một nút tên "Gameplay settings"; có `semanticLabel` thì nhãn gộp thành một nút duy nhất. 4 test mới (tên, một nút duy nhất, tap qua screen reader, trạng thái expanded và button), mutation-check 3 lỗi đều đỏ. |
| `EventCalendarCard` | nút mở sự kiện 40x40 | **Lỗi thật** (dưới 44dp; nhãn thì ổn qua tooltip). | Sửa: bỏ `visualDensity: compact`, nút thành 48x48, card cao hơn 3px (135 -> 138). 1 test mới, mutation-check đỏ khi khôi phục compact. Golden `eventcalendarcard_week_schedule_*` (7 ảnh) đã tạo lại qua workflow; xem mục Golden bên dưới. |
| `CommunityLeaderboardCard` | nút refresh 48x48 "không nhãn" | **Báo thừa.** Máy quét chỉ nhìn `label`; Flutter ghi `IconButton.tooltip` được dùng cho accessibility, và `refreshLabel` bắt buộc không rỗng. | Không sửa. |
| `CollectionAlbumPanel` | chip lọc nhỏ hơn 44 | **Lỗi thật**: ba chip cao 33px (rộng 63, 87, 112), `GestureDetector` không có vùng chạm tối thiểu. | CHƯA sửa: đổi kích thước sẽ đổi 28 golden (`collectionalbumpanel_*`) cần workflow Linux. |

### Hai lần thử sửa thất bại (để người sau không lặp lại)

- Với `ExpandablePanel`, bọc header bằng `MergeSemantics` (ngoài và trong `Semantics`) làm XẤU hơn: mất luôn nhãn `semanticLabel` tường minh. Đã hoàn nguyên. Nguyên nhân gốc thật sự là hai nơi cùng khai báo hành động tap, không phải thiếu merge. Bỏ `container: true` cũng không đổi gì.
- Với `EventCalendarCard`, đặt `constraints: BoxConstraints(minWidth: 44, minHeight: 44)` không có tác dụng (nút vẫn 40) vì `visualDensity: compact` trừ đi; phải bỏ density.

### Golden (đã làm, 2026-11-23)

Golden chỉ được sinh bằng workflow `regenerate-goldens.yml` trên Linux. Đã chạy (run `45145690466`, commit nguồn `ededf8cd`) và copy đúng 7 PNG `eventcalendarcard_week_schedule_*` (commit `e007809b`); so sánh trực quan ảnh cũ/mới: card cao hơn vài px, nút lớn hơn, không có lỗi render. Lệch pixel của 7 ảnh: 7.89% cho 5 biến thể 1x, 0.24% và 0.34% cho hai biến thể text scale (đúng thay đổi bố cục dự kiến).

Artifact còn khác 655 file ngoài ý muốn, nhưng ở cả 655 file đó 0.000% pixel khác và chênh kênh màu tối đa bằng 0 (chỉ khác mã hoá PNG), và không có file nào đổi kích thước. KHÔNG import chúng (đúng quy ước "chỉ copy PNG cần đổi, không copy cả artifact"); nếu import sẽ tạo 655 thay đổi nhị phân vô nghĩa. Test golden `EventCalendarCard` trên macOS đỏ sẵn ở HEAD (quy ước repo), nên không kiểm được cục bộ: xác nhận cuối cùng là CI trên Linux.

### Chưa làm
- Sửa chip lọc `CollectionAlbumPanel`: tách thành ENH-113.
- Quyết định có chặn semantics cho `LoadingOverlay` hay không: để nguyên (quyết định ENH-37), mở lại nếu muốn.
- Chưa bật TalkBack/VoiceOver thật; mọi kết luận là từ cây semantics trong test.

- Audit / điểm: ~9.0/10. Trừ điểm: `CollectionAlbumPanel` chưa sửa (tách thành ENH-113); không có TalkBack thật; golden `EventCalendarCard` mới chỉ được xác nhận qua workflow tạo lại, chưa qua một lần CI đầy đủ.
- Commit/push: `1c7651f2` (overlay), `ededf8cd` (ExpandablePanel + EventCalendarCard), `e007809b` (golden); đã push.
