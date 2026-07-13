# F15 — Photo mode / chia sẻ bàn chơi

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** F1 (win banner), F4 (path map)

## Mục tiêu
Chụp lại bàn chơi hiện tại (hoặc màn thắng) kèm overlay điểm/level, chia sẻ
qua share sheet hệ thống.

## Vì sao
Ý tưởng độc quyền — viral nhẹ, không cần backend, dùng đúng `RepaintBoundary`
+ share plugin đã/sẽ có trong pubspec.

## Acceptance criteria
- [ ] Nút "Chia sẻ" ở màn thắng (và/hoặc trong game) chụp `RepaintBoundary` của
      board + overlay text (level, điểm, ngày).
- [ ] Gọi share sheet hệ thống (kiểm tra `pubspec.yaml` đã có package share
      chưa trước khi thêm mới — ưu tiên tái dùng).
- [ ] Không chặn UI khi đang chụp/export (loading state ngắn nếu cần).
- [ ] Manual test: ảnh xuất ra đúng nội dung, không bị cắt/méo tỉ lệ.

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
