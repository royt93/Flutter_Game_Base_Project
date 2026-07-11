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
- [ ] Thêm state/animation: `cheer` (combo), `sad` mạnh hơn khi thua, idle biến tấu.
- [ ] Ở Game: mascot nhỏ góc màn react khi combo (tùy chọn) hoặc chỉ ở dialog.
- [ ] Không tốn perf (1 AnimationController, vẽ canvas).
- [ ] Không chặn tương tác.

## Subtasks (gợi ý file)
1. `lib/presentation/widgets/star_mascot.dart`: thêm mood `cheer`; đa dạng idle
   (liếc mắt, nghiêng nhẹ theo thời gian); tham số trigger 1 lần (bounce burst).
2. (Tùy chọn) đặt mascot nhỏ ở HUD Game, lắng nghe combo (F1) để cheer.
3. Đảm bảo dialog win/lose dùng mood mới hợp lý.

## Ghi chú kỹ thuật
Giữ vẽ bằng canvas (không asset). Trigger cheer 1-shot: truyền `Key`/counter đổi để
replay animation. Idle biến tấu bằng nhiễu theo `_c.value`.

DoD chung: `../README.md`.
