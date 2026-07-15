# A4 — Mascot reaction động

**Epic:** Animation · **SP:** 5 · **Pri:** Should · **Deps:** StarMascot (đã có), F1 (combo để trigger cheer)

## Mục tiêu
Mascot ngôi sao phản ứng theo sự kiện, không chỉ idle/happy/sad tĩnh:
- Combo lớn → nhảy/xoay phấn khích.
- Thua → che mặt / xịu rõ.
- Idle nâng cao: thỉnh thoảng liếc/nháy, nghiêng đầu.

## Vì sao
Nhân cách hoá vui, tạo gắn kết cảm xúc — điểm nhấn casual.

## Acceptance criteria
- [x] Thêm state/animation: `cheer` (combo), `sad` mạnh hơn khi thua, idle biến tấu.
- [x] Ở Game: mascot nhỏ góc màn react khi combo (tùy chọn) hoặc chỉ ở dialog.
- [x] Không tốn perf (1 AnimationController, vẽ canvas).
- [x] Không chặn tương tác.

## Rà soát checkbox (2026-07-13)
- `lib/presentation/widgets/star_mascot.dart`: `enum StarMood { idle, happy, sad, cheer }`; `cheer` = nhảy dồn dập + xoay lắc, `sad` = rũ xuống rõ + cúi đầu, `idle` = bồng bềnh + nghiêng đầu + chớp mắt — 1 `AnimationController _c` duy nhất, vẽ bằng `CustomPaint`/`_StarPainter` (không asset).
- `lib/presentation/screens/game_screen.dart` dòng ~320: mascot 40px ở HUD Game, bọc `IgnorePointer`, `Obx` đổi mood theo `gameCtrl.comboMultiplier.value > 1.4` → `StarMood.cheer`.
- Dialog thắng dùng `StarMood.cheer` (win choreography), dialog thua dùng `StarMood.sad` — khớp yêu cầu mood hợp lý.

## Subtasks (gợi ý file)
1. `lib/presentation/widgets/star_mascot.dart`: thêm mood `cheer`; đa dạng idle
   (liếc mắt, nghiêng nhẹ theo thời gian); tham số trigger 1 lần (bounce burst).
2. (Tùy chọn) đặt mascot nhỏ ở HUD Game, lắng nghe combo (F1) để cheer.
3. Đảm bảo dialog win/lose dùng mood mới hợp lý.

## Ghi chú kỹ thuật
Giữ vẽ bằng canvas (không asset). Trigger cheer 1-shot: truyền `Key`/counter đổi để
replay animation. Idle biến tấu bằng nhiễu theo `_c.value`.

DoD chung: `../README.md`.
