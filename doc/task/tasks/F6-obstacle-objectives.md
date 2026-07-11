# F6 — Obstacle tiles + objective đa dạng

**Epic:** Features · **SP:** 13 (chẻ nhỏ) · **Pri:** Could · **Deps:** F5 (làm sau, cùng đụng grid)

## Mục tiêu
Thêm ô chướng ngại + mục tiêu màn ngoài "đạt điểm":
- **Ice/Crate**: không nổ trực tiếp; nổ nhóm CẠNH nó 1–2 lần thì vỡ.
- **Objective**: "dọn hết N ô băng", "nổ hết M ô màu X", ngoài mục tiêu điểm.

## Vì sao
200 màn chỉ-đạt-điểm dễ nhàm. Objective đa dạng + obstacle tạo puzzle, kéo dài
tuổi thọ nội dung mà không cần thêm mode.

## Acceptance criteria
- [ ] Ô obstacle không thuộc nhóm màu (không nổ khi tap trực tiếp).
- [ ] Nổ nhóm liền kề obstacle → giảm 1 "độ bền"; hết bền → vỡ (thành trống, rơi).
- [ ] Level định nghĩa được objective (điểm / clear-color / clear-obstacle) + đếm tiến độ.
- [ ] HUD hiện objective + tiến độ; thắng khi đạt objective (không chỉ điểm).
- [ ] Unit test: obstacle vỡ đúng khi nổ cạnh; điều kiện thắng theo objective.

## Subtasks (gợi ý file)
1. `lib/logic/`: mở rộng cell model (obstacle kind + độ bền). Hàm "giảm bền ô cạnh nhóm nổ".
2. `lib/data/levels.dart`: `PopLevel` thêm `objective` (enum + tham số) + rải obstacle.
3. `lib/game/pop_star_game.dart`: sau nổ, xử lý obstacle cạnh; cập nhật đếm objective.
4. `lib/presentation/`: `game_controller` theo dõi objective; HUD hiện mục tiêu.
5. Test: `test/logic/obstacle_test.dart`, level objective test.

## Ghi chú kỹ thuật
CHẺ: (6a) obstacle ice/crate + vỡ; (6b) objective clear-color; (6c) objective clear-obstacle
+ HUD. Đụng cùng vùng core với F5 → làm tuần tự.

DoD chung: `../README.md`.
