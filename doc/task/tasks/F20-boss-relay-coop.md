# F20 — Boss Relay: 2 người thay phiên đánh chung 1 boss HP pool

**Epic:** E9 Tính năng mới · **SP:** 13 · **Pri:** Could
**Deps:** [[T2]] bắt buộc trước (cả 2 controller liên quan đều chưa có test)
**Ghép:** [[I59]] pass & play · [[I61]] raid boss · [[I43]] boss rush
**Trạng thái:** 📋 To Do — **cần chẻ nhỏ trước khi kéo vào sprint (SP 13)**

## Pitch
Hai người trên cùng một máy thay phiên nhau đánh **chung một boss**, chia sẻ
một thanh HP. Cùng thắng hoặc cùng thua.

## Vì sao độc quyền
Pass-and-play hiện có (I59) là **so tài**: hai người chơi cùng bàn, so điểm,
một người thắng. Đây là **co-op thật**: chung mục tiêu, chung kết quả. Game
pop hầu như không có co-op cùng máy thật sự.

## Vì sao Could + tại sao SP 13
Ghép hai controller đang **độc lập hoàn toàn**:
- `pass_and_play_controller.dart` — vòng đời lượt, deep copy bàn mỗi lượt
- `raid_boss_controller.dart` — HP boss, cửa sổ cuối tuần, bậc thưởng damage

Cả hai đều theo khuôn "quan sát `ever(gameCtrl.ended, …)`", nhưng mỗi cái sở
hữu state của một *loại* lượt chơi khác nhau. Gộp nghĩa là phải quyết định
ai sở hữu HP boss, ai quyết định lượt kết thúc, và điều gì xảy ra nếu một
controller bị huỷ giữa chừng.

**Và cả hai đều chưa có một dòng test nào** ([[T2]]).

Đây là task duy nhất trong Round 9 mà tôi khuyên **không** làm trong đợt này.
Ghi lại để không mất ý tưởng, kéo ra khi E6/E7 đã xong và [[T2]] đã cho lưới
an toàn.

## User story
*As a* hai người chơi ngồi cạnh nhau *I want* cùng hạ một boss *so that*
chúng tôi hợp tác thay vì cạnh tranh.

## Acceptance criteria (phác thảo — cần chẻ nhỏ)
- [ ] HP boss dùng chung, giảm theo damage của **cả hai** người chơi.
- [ ] Lượt luân phiên; mỗi lượt là một ván trên bàn được sinh lại, HP boss
      **giữ nguyên** xuyên lượt.
- [ ] Kết thúc: HP về 0 → **cả hai** thắng; hết số lượt → **cả hai** thua.
- [ ] Người chơi thoát/app bị kill giữa chừng → trạng thái được khôi phục hoặc
      huỷ sạch. **Không được** để lại run treo lơ lửng.
- [ ] Một chủ sở hữu **duy nhất** cho state run (một controller mới, hoặc mở
      rộng một trong hai cái đã có — **chốt trước khi code**, ghi vào file này).
- [ ] Không đụng progress campaign; thưởng riêng, key riêng.
- [ ] Test cho toàn bộ vòng đời run, kể cả huỷ giữa chừng.

## Subtask — **chẻ nhỏ trước**
Task này SP 13, vượt trần DoR ("≤8 điểm"). Đề xuất chẻ:
1. **F20a (SP 3)** — quyết định kiến trúc: ai sở hữu state run. Viết ra dạng
   ADR ngắn trong chính file này. Không code.
2. **F20b (SP 5)** — controller run + logic thuần (HP dùng chung, luân phiên
   lượt, phân định kết quả), có test đầy đủ, **chưa có UI**.
3. **F20c (SP 5)** — UI, chuyển lượt, xử lý huỷ/khôi phục, i18n.

Không kéo F20b vào sprint trước khi F20a xong.

## Rủi ro
- **Hai controller phân kỳ giữa lượt** → state hỏng. Đây là rủi ro chính và
  là lý do F20a tồn tại.
- **Phiên chơi dài**: nhiều lượt × 2 người trên một máy có thể thành 20 phút.
  Chốt giới hạn số lượt sớm và tune HP boss theo đó.
- Nếu F20a kết luận rằng phải refactor sâu một trong hai controller: **dừng
  lại và báo cáo**, đừng tự đi tiếp. Chi phí lúc đó vượt xa giá trị của một
  tính năng Could.

DoD chung: `../README.md`.
