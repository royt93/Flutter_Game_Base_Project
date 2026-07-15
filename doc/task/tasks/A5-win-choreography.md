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
- [x] Các bước diễn TUẦN TỰ có delay hợp lý (~1.5–2.5s tổng), có thể tap để skip.
- [x] Sao bay vào theo số sao thật (1/2/3); rương/điểm/xu đúng thứ tự.
- [x] Không kẹt nếu người chơi tap sớm (skip → hiện trạng thái cuối).
- [x] Tái dùng ConfettiOverlay/CoinFlyOverlay/StarMascot sẵn có.

## Rà soát checkbox (2026-07-13)
- `_WinChoreographyState` (`lib/presentation/screens/game_screen.dart`): `Timer` tuần tự cho từng sao (`350 + i*260`ms, đúng `starsEarned.value`), rồi điểm (`+150`), rồi nút (`+650`) — tổng ~1.1–1.8s tuỳ số sao, khớp khoảng ~1.5–2.5s.
- `_skip()`: cancel toàn bộ timer, set `_starsShown/_scoreShown/_buttonsShown` về trạng thái cuối ngay — không kẹt. `GestureDetector` bọc toàn overlay để tap bất kỳ đâu đều skip. Nút Retry/Next dùng `IgnorePointer(ignoring: !_buttonsShown)` nên không bấm nhầm khi chưa hiện.
- Grep `ConfettiOverlay`/`CoinFlyOverlay`/`StarMascot` trong `game_screen.dart`: cả 3 đều được tái dùng (confetti + coin fly là overlay có sẵn, mascot dùng `StarMood.cheer` trong `_MascotDialog`).

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
