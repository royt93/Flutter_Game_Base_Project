# I7 — Vòng quay hằng ngày

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Should · **Deps:** none

## Mục tiêu
Vòng quay 1 lần/ngày, random coin/booster theo bảng trọng số cố định — seed
theo ngày để không đổi kết quả khi thoát vào lại.

## Vì sao
Bổ sung cho daily reward (F2, cố định) — spin thêm yếu tố "may mắn" mà vẫn
deterministic/không cần server.

## Acceptance criteria
- [ ] 1 lần/ngày, check giống `claimDaily` (tái dùng `durationToLocalMidnight`).
- [ ] Bảng phần thưởng trọng số cố định; seed = ngày hiện tại (`Random(seed)`,
      không `Random()` mặc định — tránh đổi kết quả khi refresh).
- [ ] UI vòng quay: animation quay + dừng đúng ô đã chọn trước (không tự vẽ
      random riêng ở lớp UI).
- [ ] Unit test: cùng ngày → cùng seed → cùng kết quả; qua ngày mới reset được quay.

## Subtasks (gợi ý file)
1. `lib/presentation/controllers/game_controller.dart`: `spinAvailable`,
   `claimSpin` (tái dùng `durationToLocalMidnight`).
2. UI mới — dialog overlay theo pattern `NeonDialog.overlay`.

## Ghi chú kỹ thuật
Seed theo ngày (`year*10000+month*100+day`) để kết quả tái lập được, dễ test —
không dùng Random không seed.

DoD chung: `../README.md`.
