# F17 — Combo Bank: tiền tệ nối 14 side-mode đang là silo

**Epic:** E9 Tính năng mới · **SP:** 5 · **Pri:** Should
**Deps:** [[X24]] nên làm trước (thêm counter vào hot path)
**Trạng thái:** ✅ Done (2026-08-13)

## Vấn đề nó giải quyết
14 `GameMode` hiện là 14 silo hoàn toàn tách biệt. Mỗi mode có best-score
riêng, không mode nào nuôi mode nào. Chơi Combo Rush giỏi không giúp gì cho
campaign; chơi campaign không mở gì ở Gauntlet.

Hệ quả: người chơi không có lý do rời mode ưa thích, và 13 mode còn lại chết
dần. Đây là điểm yếu #4 trong `ROUND-9.md`.

Đối chiếu: **coin** đã là tiền tệ xuyên mode (mọi mode đều pop ra weekly goal
và clan contribution). Nhưng coin chỉ chảy *ra khỏi* side-mode vào shop —
không có gì chảy *giữa* các mode.

## Pitch
Một tiền tệ thứ ba — **Combo Token** — chỉ kiếm được bằng cách giữ combo cao
ở **bất kỳ** mode nào, tiêu vào những thứ cắt ngang mode.

## Vì sao độc quyền
Không phải cơ chế mới lạ — cái mới là **thứ nó thưởng**: không phải "chơi
nhiều", mà "chơi giỏi ở bất kỳ đâu". Và nó biến 14 silo thành một hệ kinh tế.

## Đề xuất chi tiết
**Kiếm:** mỗi lần chạm mốc combo (`kComboMilestones` = 5/10/15/20, đã có) cho
1 token. Mọi mode. Không phụ thuộc điểm hay thắng thua — người chơi kém vẫn
kiếm được, chỉ chậm hơn.

**Tiêu** (chỉ những thứ **cắt ngang** mode, đó là toàn bộ ý nghĩa):
- Reroll daily quest (`kDailyQuestPool`)
- Mở Weekly Featured level sớm (không chờ hết tuần)
- Thêm 1 lượt Raid Boss trong cuối tuần
- Đổi modifier Gauntlet hôm nay sang cái khác
- Thêm 1 bản đồ Treasure Map

## Vì sao Should
Rẻ (tái dùng `kComboMilestones` + khuôn `_buy`/`_grant` đã có), và nó sửa
một vấn đề cấu trúc thay vì thêm nội dung. Nhưng nó là **tiền tệ thứ ba**
(sau coin và Star Dust) — rủi ro chính là quá tải.

## User story
*As a* người chơi *I want* kỹ năng combo ở mode tôi thích đổi được thành thứ
hữu ích ở mode khác *so that* thời gian chơi của tôi tích luỹ vào một chỗ.

## Acceptance criteria
- [ ] Token cộng ở **mọi** `GameMode` khi chạm mốc combo, kể cả Zen và
      Puzzle Lab (đây là điểm chính — không loại trừ mode nào).
- [ ] Key riêng trong `StorageKeys`; **nằm trong** danh sách `resetProgress`
      (xem [[X19]] — đừng lặp lại lỗi cũ ngay khi thêm hệ mới).
- [ ] Rollback đúng khi Undo (xem [[X17]] — cùng lý do).
- [ ] Ít nhất **3** đường tiêu hoạt động khi giao hàng. Một đường tiêu duy
      nhất thì không đáng có tiền tệ riêng — cứ dùng coin.
- [ ] Mỗi đường tiêu có giá cố định, hiện rõ, và **giới hạn số lần/ngày**
      để không bỏ qua được toàn bộ nhịp hằng ngày/hằng tuần bằng token.
- [ ] Hiện số dư token ở Home và màn chơi, đã i18n 22 ngôn ngữ.
- [ ] Test: cộng token ở mọi mode, mọi đường tiêu, giới hạn/ngày, rollback undo.

## Subtask
1. `game_controller.dart` — `comboTokens` Rx + persist. Cộng tại chỗ đang gọi
   `triggerComboMilestone` (đã có sẵn hook, không cần trigger mới).
2. Ba đường tiêu — mỗi cái nối vào hệ đã tồn tại (`dailyQuests`,
   `featuredLevelId`, `raid_boss_controller`). **Không** viết màn hình mới
   cho từng cái; đặt nút ngay tại chỗ hệ đó đang hiển thị.
3. UI số dư + i18n.
4. Test.

## Rủi ro
- **Tiền tệ thứ ba gây quá tải.** Đây là rủi ro thật. Giảm bằng: chỉ 1 đường
  kiếm (mốc combo), 3 đường tiêu rõ nghĩa, hiển thị ở đúng chỗ dùng. Nếu sau
  khi làm xong thấy người chơi không hiểu nó để làm gì — **xoá và chuyển các
  đường tiêu sang coin**. Ghi sẵn phương án lùi này để không phải tranh cãi
  sau.
- **Bỏ qua nhịp hằng ngày**: nếu token mua được mọi thứ, nhịp daily/weekly
  sụp. Giới hạn số lần/ngày là bắt buộc, không phải tuỳ chọn.

DoD chung: `../README.md`.

---

## Đã làm

**Kiếm:** `comboTokens` cộng trong `triggerComboMilestone` — hook đã có sẵn, đúng
như subtask 1 dự đoán, không cần trigger mới. Ghi đệm vì nằm trên hot path
([[X24]]).

**Tiêu — ba đường, mỗi đường giới hạn 1 lần/ngày:**

| Đường | Giá | Nối vào |
|---|---|---|
| Đổi bộ nhiệm vụ hằng ngày | 6 | `dailyQuests` + `questsForDay` |
| Thêm 1 lượt Raid Boss | 10 | `RaidBossController._maxAttemptsToday` |
| Thêm 1 bản đồ Treasure Map | 12 | `treasureMapCount` |

Nút đặt **ngay tại chỗ hệ đó đang hiển thị** (nút đổi quest nằm trong
`daily_quest_dialog`), không dựng màn hình riêng cho từng đường tiêu.

## Bỏ một đường tiêu khỏi danh sách đề xuất

Task đề xuất "mở Weekly Featured level sớm". Đọc `featuredLevelId` thì thấy nó
**vốn đã** tự thay bằng level đã mở khoá thay vì chặn người chơi (X27). Không có
cổng nào để mở, nên bán chìa khoá cho một cánh cửa không khoá là bán hàng giả.
Thay bằng Treasure Map — thứ thật sự bị giới hạn số lượng.

## Lượt Raid mua thêm: nâng TRẦN, không cộng thẳng

`RaidBossController` được dựng lại mỗi lần vào màn. Cộng thẳng vào
`attemptsRemaining` là cộng thêm một lần nữa ở mỗi lần dựng — vòng "vào màn,
thoát, vào lại" thành lượt vô hạn. Nên `_maxAttemptsToday` trả **trần** và
`attemptsRemaining` suy ra từ `trần - đã dùng`, giữ nguyên khuôn sẵn có.

Màn hình cũng phải đổi mẫu số: `x / maxAttemptsToday` chứ không phải hằng số
`maxDailyAttempts`, nếu không mua thêm lượt xong vẫn thấy "4 / 3".

## Kiểm chứng

- `test/presentation/combo_bank_test.dart` — **22 ca**: cộng token ở **mọi**
  `GameMode` (lặp qua `GameMode.values`, không hard-code danh sách), lùi theo
  Undo cả trong bộ nhớ lẫn trên đĩa, vòng nổ-undo lặp không bơm được token, cả
  ba đường tiêu + giới hạn/ngày + mốc ngày cũ, token không âm, và
  **reset tiến độ xoá token** ([[X19]]).
- **Mutation-check 5/5 bị bắt:** undo không lùi token; bỏ giới hạn/ngày (quest);
  đổi quest không reset tiến độ; bỏ giới hạn/ngày (raid); loại trừ mode Zen.
- Toàn bộ suite: **1393 xanh**, `flutter analyze` 0 issue.

## Trả nợ UI (2026-08-13, cùng ngày)

Nợ ghi ở lần đóng đầu đã trả xong:

- `lib/presentation/widgets/token_chip.dart` — chip số dư, đứng cạnh `CoinChip`
  ở **Home**, bản gọn ở **HUD màn chơi**.
- **Mua lượt Raid Boss** — nút ngay dưới ô đếm lượt ở `raid_boss_screen`, chỉ
  hiện khi thật sự mua được (không quảng cáo thứ bấm vào không ăn).
- **Mua bản đồ Treasure Map** — thêm hành động vào đúng dialog "hết bản đồ" ở
  `mode_select_screen`: người chơi đang muốn chơi ngay, đó là chỗ chào bán
  đúng lúc nhất.

### Hai lỗi thật do test UI bắt được

1. **Nhánh "sang tuần mới" của `RaidBossController` bỏ qua lượt đã mua.** Lần
   sửa đầu chỉ đổi nhánh else (`trần − đã dùng`), quên nhánh reset tuần vẫn gán
   hằng số `maxDailyAttempts`. Lượt vừa mua biến mất ngay khi sang tuần mới.
2. **Nạp lại controller sau khi mua KHÔNG cập nhật màn hình.** Bản đầu gọi
   `Get.delete` + `Get.put`, nhưng `raidCtrl` đã bị bắt trong `build` nên `Obx`
   vẫn trỏ instance cũ — trả tiền xong màn hình vẫn hiện "3 / 4". Sửa thành
   cộng thẳng vào `attemptsRemaining` (mẫu số tự đúng vì `_maxAttemptsToday`
   đọc thẳng storage).

   Mutation-check ban đầu **không bắt** được lỗi này vì test chỉ hỏi getter
   `maxAttemptsToday` — mà getter đọc storage nên đúng kể cả khi UI sai. Siết
   test thành kiểm đúng chuỗi hiển thị `"4 / 4"` mới bắt được.

### Kiểm chứng phần UI

- `test/widget/token_ui_test.dart` — 9 ca: chip hiện đúng số/0/cập nhật ngay,
  bản gọn nhỏ hơn bản thường, nút mua chỉ hiện khi đủ token, bấm thì trừ token
  + tăng cả tử lẫn mẫu + nút biến mất, mẫu số theo trần thật.
- **Mutation-check 3/3 bị bắt** sau khi siết: trần bỏ qua lượt đã mua; hiện nút
  cả khi không mua được; không cộng lượt hiển thị.
- Toàn bộ suite: **1402 xanh**.

## Nợ còn lại
1. i18n mới en + vi; 20 ngôn ngữ còn lại rơi về bản en.
2. ~~Chưa verify trên thiết bị thật.~~ Chip số dư đã verify trên Pixel 7 Pro
   (Home + HUD màn chơi). Ba đường tiêu mới verify bằng test, chưa bấm tay.
3. Phương án lùi vẫn giữ nguyên như task ghi: nếu người chơi không hiểu token
   để làm gì, **xoá** và chuyển ba đường tiêu sang coin. Ba đường đó đều đã
   tách hàm riêng nên đổi tiền tệ là sửa một chỗ.
