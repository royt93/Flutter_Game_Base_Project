# G8 — Glow burst ring + idle shimmer sweep

**Epic:** Neon/Glow · **SP:** 2 (chỉ phần còn lại) · **Pri:** Could · **Deps:** A1

## Đã xong (audit 2026-07)
Burst ring đã implement — `_BurstRing` (`lib/game/pop_star_game.dart:58-96`), spawn
mỗi lần nổ nhóm, cap qua `_rings` list. Không cần làm lại.

## Mục tiêu (phần còn lại)
**Idle shimmer**: bàn rảnh tay quá lâu → 1 lớp gradient sweep quét nhẹ ngang qua
bàn rồi tự gỡ. 60fps, không che UI, không đụng phần ring đã xong.

## Vì sao
Bàn "chết" khi người chơi ngập ngừng lâu — I4 (predictive hint) đã xử lý phần
gợi ý nước đi, shimmer chỉ thêm lớp thị giác "còn sống" trước/song song hint.

## Acceptance criteria
- [x] Rảnh > X giây (dùng lại cơ chế đếm rảnh của I4, ngưỡng riêng) → shimmer
      quét ngang bàn 1 lượt, lặp thưa; dừng ngay khi có tap. — `_shimmerTimer`
      (ngưỡng `_shimmerDelay = 4.0s`, riêng với `_hintDelay` của I4) reset
      trong `clearHint()` (gọi ở mọi tap, kể cả tap sai) → dừng ngay khi tap.
- [x] Không chạy khi `_animating` true (đang diễn hoạt pop/collapse/intro). —
      cùng guard `!_animating && !controller.ended.value` như nhánh I4.
- [x] 60fps; không che tile, không chặn tap. — `_ShimmerSweep` chỉ vẽ dải
      gradient alpha thấp (0 → 0.22 → 0), không tham gia hit test (input qua
      GestureDetector ở `game_screen.dart`, không qua component Flame nào).

## Rà soát checkbox (2026-07-13)
Grep `shimmer`/`sweep`/`MoveEffect` gradient trong `lib/` — không tìm thấy
component nào khớp mô tả "idle shimmer sweep". `_idleTimer`/`_hintDelay`
(`pop_star_game.dart:170-171,595-596`) chỉ đang phục vụ I4 (predictive hint),
chưa có nhánh kích shimmer riêng. Phần ring (`_BurstRing`) vẫn đúng như audit
2026-07 — không đụng tới. Phần shimmer trong file này là gap thật, không
phải bookkeeping — để nguyên chưa tick, không tự viết code (ngoài phạm vi
việc rà soát checkbox).

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: tái dùng `_idleTimer` (đã có cho I4 hint) hoặc
   thêm timer riêng cùng cơ chế — kích 1 lớp gradient sweep (component/painter)
   quét qua vùng bàn rồi `RemoveEffect` tự gỡ.
2. Tôn trọng `_animating`, reset timer khi có tap (giống I4).

## Ghi chú kỹ thuật
Shimmer sweep = 1 dải gradient dịch ngang (`MoveEffect`) clip trong tray. Giữ
hiếm/nhẹ, không cạnh tranh visual với ring/hint đã có.

DoD chung: `../README.md`.
