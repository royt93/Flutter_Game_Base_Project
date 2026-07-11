# G4 — Nền reactive glow theo combo

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F1

## Mục tiêu
Nền (NeonBg) phản ứng theo combo: combo càng cao → quầng sáng/bong bóng nền rực &
nhanh hơn; combo hết → dịu về mặc định.

## Vì sao
Cả màn "sống" theo pha chơi, leo thang trực quan cùng combo — thưởng chuỗi hay.

## Acceptance criteria
- [ ] `NeonBg` nhận mức "energy" (0..1) từ combo/điểm gần đây.
- [ ] Energy cao → tăng độ sáng/tốc độ orb + có thể thêm quầng màu ấm; mượt khi lên/xuống.
- [ ] Trên nền sáng casual KHÔNG gây chói/khó đọc UI (giới hạn biên độ).
- [ ] 60fps; không leak controller.

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
