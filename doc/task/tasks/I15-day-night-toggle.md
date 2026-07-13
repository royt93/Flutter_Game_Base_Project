# I15 — Day/Night theme toggle

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** none

## Mục tiêu
Settings có switch đổi giữa theme bright-casual hiện tại (mặc định) và theme
neon-dark cũ (`NeonTheme` gốc trước pivot) — đổi tức thì, không tách bản riêng.

## Vì sao
Ý tưởng độc quyền được chọn: giữ cả 2 phong cách hình ảnh làm lựa chọn cá
nhân hoá, không ép chọn 1.

## Acceptance criteria
- [ ] `NeonTheme` thêm bộ token dark bổ sung (không thay thế token bright hiện
      có) — 2 bộ token cùng tồn tại, chọn bằng 1 flag.
- [ ] Settings switch lưu lựa chọn (`StorageKeys` mới), áp dụng ngay không cần
      khởi động lại app.
- [ ] Mọi widget dùng token qua `NeonTheme.of(context)`-kiểu getter hiện có,
      không sửa từng nơi gọi màu cứng.
- [ ] Golden test: 1-2 widget chính (button, app bar) ở cả 2 theme.

## Subtasks (gợi ý file)
1. `lib/core/neon_theme.dart`: thêm bộ token dark, giữ nguyên bộ bright làm
   mặc định.
2. `lib/core/storage_service.dart`: key theme mode.
3. `lib/presentation/screens/settings_screen.dart`: switch.

## Ghi chú kỹ thuật
Rủi ro chính: nơi nào đang dùng màu cứng thay vì token sẽ không đổi theo —
audit trước khi code, liệt kê chỗ cần sửa về dùng token.

DoD chung: `../README.md`.
