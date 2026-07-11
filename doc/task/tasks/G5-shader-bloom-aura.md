# G5 — Shader bloom aura (tái dùng neon_glow.frag)

**Epic:** Neon/Glow · **SP:** 8 · **Pri:** Should · **Deps:** —

## Mục tiêu
Dùng fragment shader `shaders/neon_glow.frag` (ĐÃ khai báo trong pubspec) để vẽ
**aura bloom động** dưới/quanh bàn (và/hoặc quanh combo), hiệu ứng GPU "xịn".

## Vì sao
Shader đã có sẵn trong repo (từ game cũ) nhưng chưa dùng — tận dụng cho glow cao
cấp mượt, rẻ GPU hơn nhiều layer blur.

## Acceptance criteria
- [ ] Load shader qua `FragmentProgram.fromAsset('shaders/neon_glow.frag')`.
- [ ] Vẽ 1 lớp aura động (thời gian + màu) sau bàn hoặc dưới HUD; hoà nền sáng casual.
- [ ] Fallback an toàn nếu load lỗi (không crash — bỏ qua aura).
- [ ] Kiểm perf trên device thật (không tụt <60fps).

## Subtasks (gợi ý file)
1. Kiểm nội dung `shaders/neon_glow.frag` (uniform: time, resolution, color?) — đọc trước.
2. Widget/painter load `FragmentShader`, cập nhật uniform `time` mỗi frame (Ticker).
3. Đặt sau board tray ở `game_screen` (hoặc trong Flame render layer).
4. Try/catch load; log `dlog` nếu fail, ẩn aura.

## Ghi chú kỹ thuật
Shader từ game cũ có thể dùng bảng màu tối — chỉnh uniform/blend cho hợp nền sáng
(hoặc dùng ở chế độ dark/Zen). Cần `flutter` bật shader compilation (đã có trong pubspec).

DoD chung: `../README.md`.
