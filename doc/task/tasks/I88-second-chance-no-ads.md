# I88 — Second chance khi kẹt — trả bằng coin, **không** quảng cáo

**Epic:** E8 Enhance · **SP:** 5 · **Pri:** Should
**Deps:** — · **Liên quan:** [[I5]] [[F10]]
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
Bàn campaign **không refill** (Zen là ngoại lệ duy nhất). Khi bàn cạn hoặc
kẹt mà chưa đủ target, người chơi chỉ có 2 lựa chọn: chơi lại từ đầu, hoặc
thoát. Không có gì ở giữa.

Chuẩn thể loại giải quyết bằng "xem quảng cáo để có thêm 5 nước đi". **Ta đã
chốt không dùng quảng cáo** (quyết định sản phẩm, xem `ROUND-9.md`). Nên cần
một đường trả bằng tài nguyên trong game.

## Vì sao Should
Đoạn khó của campaign (world 8+ với obstacle/boss/ice) là chỗ người chơi rớt
nhiều nhất, và cảm giác "thua sát nút, mất trắng 3 phút" là lý do bỏ game
kinh điển. Đồng thời đây là **chỗ tiêu coin có ý nghĩa nhất** mà game đang
thiếu — hiện coin chủ yếu để mua booster và cosmetic.

Không Must vì nó đụng cân bằng độ khó, cần tune, và làm sai thì tệ hơn không
làm (xem Rủi ro).

## User story
*As a* người chơi thua sát nút *I want* mua thêm một cơ hội bằng coin đã
kiếm được *so that* 3 phút vừa rồi không mất trắng.

## Acceptance criteria
- [ ] Khi màn campaign kết thúc với **0 sao** và điểm đạt **≥70%** target,
      dialog thua chào một lựa chọn "Cơ hội thứ hai".
- [ ] Ngưỡng 70% là hằng số có tên, có comment, dễ tune. Dưới ngưỡng thì
      **không** chào — thua cách xa quá thì mua thêm nước cũng không cứu
      được, và chào lúc đó chỉ làm người chơi thấy bị moi tiền.
- [ ] Giá theo coin, cố định, hiển thị rõ trước khi bấm. Không đủ coin →
      nút disabled kèm lý do, **không** đẩy sang shop.
- [ ] Chấp nhận → bàn được bồi thêm ô mới (một đợt refill **giới hạn**, dùng
      lại đường `refillEnabled` mà Zen đang dùng, không viết cơ chế mới),
      điểm và combo **giữ nguyên**, chơi tiếp.
- [ ] Tối đa **1 lần mỗi màn**. Thắng nhờ second chance vẫn tính sao/coin/
      unlock bình thường — nhưng **không** tính vào `boardsFullyCleared` nếu
      bàn được bồi (tránh làm hỏng achievement "dọn sạch bàn").
- [ ] Chốt rõ và test: second chance có ảnh hưởng `levelsThreeStarred`,
      Perfect Clear ([[I23]]), và replay ([[I28]]) không. Đề xuất: replay
      **không** tái tạo được ván có second chance → không ghi replay cho ván
      đó.
- [ ] Chỉ áp dụng **campaign**. Mọi side-mode dùng best-score đều loại trừ —
      nếu không, mọi kỷ lục đều mua được.
- [ ] Chuỗi mới đủ 22 ngôn ngữ.
- [ ] Test trong `test/presentation/game_controller_test.dart` +
      `test/widget/game_screen_smoke_test.dart`.

## Subtask
1. `game_controller.dart` — `bool canOfferSecondChance` (thuần, test được) +
   `bool buySecondChance()` theo khuôn `_buy()` đã có.
2. `pop_star_game.dart` — `refillOnce()` bồi ô rỗng bằng gem mới. Tái dùng
   đường refill của Zen; **không** viết generator bàn thứ hai.
3. `game_screen_controller.dart` — chèn vào luồng `GameUi.lose`, quay lại
   `GameUi.playing` khi mua.
4. Xử lý cờ loại trừ (`boardsFullyCleared`, replay, side-mode).
5. i18n + test.

## Rủi ro & cách giảm
- **Phá cảm giác thử thách.** Giảm bằng: 1 lần/màn, ngưỡng 70%, và chỉ ở
  campaign. Không cho mua lần 2 với giá tăng dần — đó là đường trượt.
- **Lạm phát coin.** Đây thực ra là *tính năng*: game đang thiếu chỗ tiêu
  coin. Theo dõi số dư trung bình sau vài tuần.
- **Chào sai lúc.** Chào ngay sau khi thua sát nút thì được đón nhận; chào
  sau khi thua bét thì bị ghét. Ngưỡng 70% chính là để tránh vế sau.

## Ghi chú kỹ thuật
Đừng đưa vào cơ chế "+5 nước đi" — game này không đếm nước đi để thắng/thua
(`movesUsed` chỉ dùng cho sao bonus của `moveLimitBonus`). Thứ hết là **ô
trên bàn**, nên bồi ô mới là cách duy nhất khớp với luật hiện có.

DoD chung: `../README.md`.

## Đã làm

`lib/logic/second_chance.dart` (thuần) + `usedSecondChance`, `boardWasRefilled`,
`canBuySecondChance`, `secondChanceUnaffordable`, `buySecondChance()` trên
`GameController`; `PopStarGame.refillForSecondChance()`; UI ở `game_screen.dart`.

**Trả bằng xu, không quảng cáo, không IAP** — theo quyết định sản phẩm đã chốt
(xem phần ý tưởng bị từ chối trong `IDEAS.md`).

## Kiểm chứng

- `test/logic/second_chance_test.dart` — 15 ca thuần.
- `test/presentation/second_chance_wiring_test.dart` — 11 ca nối controller.
