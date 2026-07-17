# F15 — Photo mode / chia sẻ bàn chơi

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** F1 (win banner), F4 (path map)

## Mục tiêu
Chụp lại bàn chơi hiện tại (hoặc màn thắng) kèm overlay điểm/level, chia sẻ
qua share sheet hệ thống.

## Vì sao
Ý tưởng độc quyền — viral nhẹ, không cần backend, dùng đúng `RepaintBoundary`
+ share plugin đã/sẽ có trong pubspec.

## Acceptance criteria
- [x] Nút "Chia sẻ" ở màn thắng (và/hoặc trong game) chụp `RepaintBoundary` của
      board + overlay text (level, điểm, ngày).
- [x] Gọi share sheet hệ thống (kiểm tra `pubspec.yaml` đã có package share
      chưa trước khi thêm mới — ưu tiên tái dùng).
- [x] Không chặn UI khi đang chụp/export (loading state ngắn nếu cần).
- [x] Manual test: ảnh xuất ra đúng nội dung, không bị cắt/méo tỉ lệ. Verify
      tay trên Samsung SM_S928B (2026-07-17): chơi hết Level 1 tới màn thắng,
      bấm nút share → share sheet native mở với thumbnail ảnh + caption
      "Pop Star Blast — Level 1 — Score 565 — 2026-07-17"; pull file cache
      thật (`run-as ... cat .../cache/share_plus/pop_star_blast.png`) → PNG
      720x1170 đúng nội dung bàn chơi + overlay điểm/level/ngày, không bị
      cắt/méo tỉ lệ.

## Rà soát checkbox (2026-07-13)
- `lib/core/share_helper.dart`: `captureBoardPng` (RepaintBoundary → PNG) +
  `shareBoardImage` (SharePlus.instance.share với file + text level/điểm/ngày).
- Nút share ở màn thắng: `lib/presentation/screens/game_screen.dart:800-806`
  gọi `widget.gsc.shareBoard` (`game_screen_controller.dart:50-55`).
- `pubspec.yaml:49` đã có `share_plus: ^12.0.2` (tái dùng, không thêm package
  mới). Test: `test/core/share_helper_test.dart`. Capture là async, không
  chặn UI thread.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart` hoặc `game_screen.dart`: bọc board bằng
   `RepaintBoundary` + key để capture.
2. Hàm export ảnh (`dart:ui.Image` → bytes) + overlay text bằng `Canvas`.
3. Nút share ở màn thắng (`_WinChoreography` hoặc dialog liên quan), gọi share
   plugin.

## Ghi chú kỹ thuật
Kiểm tra `pubspec.yaml` trước — nếu chưa có package share nào, thêm 1 package
phổ biến, không tự viết intent chia sẻ tay cho từng platform.

DoD chung: `../README.md`.
