# F22 — Tile-DNA Lab: người chơi tự phối cơ chế special tile, share QR

**Epic:** E9 Tính năng mới · **SP:** 13 · **Pri:** Won't (đợt này)
**Deps:** [[X25]] · [[T2]] · [[T3]] · [[T4]] — **tất cả**
**Tái dùng:** [[I42]] puzzle code · [[I33]] gauntlet modifier · [[I58]] QR
**Trạng thái:** ⏸️ Deferred — ghi lại, **không** kéo vào Round 9

## Pitch
Puzzle Lab cho người chơi vẽ **bàn**. Tile-DNA Lab cho người chơi phối
**luật**: chọn tổ hợp special tile (chain + ice + magnet + countdown + boss)
với mật độ tuỳ chỉnh, lưu thành một "DNA" và chia sẻ bằng QR.

## Vì sao độc quyền
Crafting ở tầng **cơ chế**, không phải tầng vật phẩm. Người chơi tự thiết kế
*loại thử thách*, không chỉ *một màn cụ thể*. Tôi không biết game pop nào cho
phép điều này.

Hạ tầng có sẵn nhiều: `puzzle_code.dart` (encode board), `gauntlet_modifiers.dart`
(`GauntletModifier` đã được **3** mode tái dùng qua 3 danh sách const khác
nhau — chính là bằng chứng rằng "luật là dữ liệu" đã hoạt động trong codebase
này), `qr_flutter` + `challenge_code.dart` (chia sẻ).

## Vì sao **Won't** trong đợt này
Đây là ý tưởng hay nhất trong danh sách và cũng là ý tưởng sai thời điểm nhất.

1. **Vấn đề board bất khả thi trở nên nghiêm trọng.** Puzzle Lab đã có rủi ro
   này với bàn tự vẽ; cho phép chỉnh cả *luật* nhân nó lên. CLAUDE.md ghi lại
   rằng đã từng có bug làm phần lớn level bất khả thi (`doc/feat.md`) — cần
   một validator thật, và validator đó là task riêng lớn hơn cả tính năng.
2. **Bề mặt input không tin cậy lớn nhất trong game.** Người chơi dán một
   QR/mã lạ vào và nó cấu hình lại engine. [[X25]] là điều kiện tối thiểu,
   không phải điều kiện đủ.
3. **Bốn hệ chưa có test** nằm trên đường đi (xem Deps).
4. **Chưa có bằng chứng có nhu cầu.** Puzzle Lab — tính năng gần nhất — hiện
   không có gì kéo người chơi quay lại ([[F18]] tồn tại chính vì lý do đó).
   Xây thứ phức tạp hơn cho cùng nhóm người dùng chưa được xác nhận là đặt
   cược sai.

**Điều kiện để mở lại:** [[F18]] đã ra và cho thấy có người thật sự dùng
Puzzle Lab; E6 + E7 đã xong; có một validator khả thi hoạt động được.

## Phác thảo (giữ để không mất ý tưởng)
- DNA = một `GauntletModifier` mở rộng + bảng mật độ special tile.
- Encode cùng khuôn `puzzle_code.dart`; chia sẻ bằng QR như [[I58]].
- Chơi qua `startPuzzleLevel`-style: không coin/sao/unlock.
- Validator: mô phỏng N ván ngẫu nhiên, từ chối DNA không đạt target ở
  X% số lần chạy. Đắt nhưng là thứ duy nhất thật sự trả lời được câu hỏi.

## Ghi chú
Nếu có nhu cầu làm sớm, phiên bản rẻ hơn nhiều đạt 70% giá trị: cho người
chơi chọn từ **một danh sách ngắn các DNA dựng sẵn** (5-8 cái, đã kiểm chứng
khả thi bằng tay) thay vì tự phối tự do. Không cần validator, không có bề mặt
input không tin cậy, SP ~3. Cân nhắc đường này trước khi làm bản đầy đủ.

DoD chung: `../README.md`.
