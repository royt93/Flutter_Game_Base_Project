# A5 — Win choreography dàn cảnh

**Epic:** Animation · **SP:** 5 · **Pri:** Should · **Deps:** confetti + coin fly + mascot (đã có), A2

## Mục tiêu
Khoảnh khắc thắng được dàn cảnh theo nhịp thay vì hiện tất cả cùng lúc:
1. Mascot bật lên + confetti.
2. Sao 1→2→3 bay vào từng cái (có nhấn/âm).
3. Điểm count-up.
4. Xu bay vào ví (coin fly).
5. Nút Retry/Next hiện sau cùng.

## Vì sao
Thắng là đỉnh cảm xúc — dàn cảnh tốt tăng thoả mãn & retention rõ rệt.

## Acceptance criteria
- [ ] Các bước diễn TUẦN TỰ có delay hợp lý (~1.5–2.5s tổng), có thể tap để skip.
- [ ] Sao bay vào theo số sao thật (1/2/3); rương/điểm/xu đúng thứ tự.
- [ ] Không kẹt nếu người chơi tap sớm (skip → hiện trạng thái cuối).
- [ ] Tái dùng ConfettiOverlay/CoinFlyOverlay/StarMascot sẵn có.

## Subtasks (gợi ý file)
1. `lib/presentation/screens/game_screen.dart` `_Overlay`/`_MascotDialog`: dựng
   sequence controller (staggered) cho win; hiện sao lần lượt (AnimatedScale/slide).
2. Skip: tap bất kỳ → set tất cả về trạng thái cuối.
3. Đồng bộ coin fly (đã có) vào bước 4 của chuỗi.
4. (Nếu có F7) chèn bước rương.

## Ghi chú kỹ thuật
Dùng 1 `AnimationController` + interval cho từng phần, hoặc chuỗi `Future.delayed`
có cờ skip. Giữ tái dùng overlay đã có, chỉ điều phối thứ tự.

DoD chung: `../README.md`.
