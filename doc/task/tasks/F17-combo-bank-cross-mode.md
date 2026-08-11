# F17 — Combo Bank: tiền tệ nối 14 side-mode đang là silo

**Epic:** E9 Tính năng mới · **SP:** 5 · **Pri:** Should
**Deps:** [[X24]] nên làm trước (thêm counter vào hot path)
**Trạng thái:** 📋 To Do

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
