# G4 — Nền reactive glow theo combo

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F1

## Mục tiêu
Nền (NeonBg) phản ứng theo combo: combo càng cao → quầng sáng/bong bóng nền rực &
nhanh hơn; combo hết → dịu về mặc định.

## Vì sao
Cả màn "sống" theo pha chơi, leo thang trực quan cùng combo — thưởng chuỗi hay.

## Acceptance criteria
- [x] `NeonBg` nhận mức "energy" (0..1) từ combo/điểm gần đây.
- [x] Energy cao → tăng độ sáng/tốc độ orb + có thể thêm quầng màu ấm; mượt khi lên/xuống.
- [x] Trên nền sáng casual KHÔNG gây chói/khó đọc UI (giới hạn biên độ).
- [x] 60fps; không leak controller.

## Rà soát checkbox (2026-07-13)
- `lib/presentation/widgets/neon_bg.dart:18-29`: param `energyOf` (callback
  0..1 đọc mỗi frame); `_NeonBgPainter` dùng `energy` để lerp màu ấm
  (`Color.lerp(oc, NeonTheme.orange, energy*0.5)`) — biên độ giới hạn (`*0.5`,
  `*0.7`), không chói.
- `lib/presentation/screens/game_screen.dart:42`: `energyOf: () => gsc.game.heat`
  — tái dùng đúng nguồn `heat` suy từ combo (đã dùng chung với G6, đúng gợi ý
  "một nguồn comboEnergy" trong ghi chú G6) thay vì thêm `comboEnergy` riêng
  trên GameController — tương đương về chức năng.
- `_NeonBgState` dùng `Ticker` riêng, `dispose()` gọi `_ticker.dispose()`
  (`neon_bg.dart:86-88`) — không leak.

## Subtasks (gợi ý file)
1. `lib/presentation/widgets/neon_bg.dart`: thêm param/`ValueListenable` `energy`;
   painter nội suy alpha/tốc độ theo energy.
2. `lib/presentation/controllers/game_controller.dart`: expose `comboEnergy` (RxDouble)
   suy từ combo (F1), decay dần.
3. `game_screen.dart`: truyền energy vào NeonBg.

## Ghi chú kỹ thuật
Ràng biên độ để giữ tương phản chữ trên nền sáng. Decay energy mượt (lerp mỗi frame)
tránh giật.

DoD chung: `../README.md`.
