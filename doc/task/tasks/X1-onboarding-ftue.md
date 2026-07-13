# X1 — Onboarding / FTUE tap-to-pop

**Epic:** Floor/UX · **SP:** 5 · **Pri:** Must · **Deps:** none

## Mục tiêu
Lần mở app đầu tiên: overlay hướng dẫn "chạm để nổ" trên chính level 1 (không
màn riêng), tự ẩn sau lần tap đầu tiên đúng.

## Vì sao
Game hiện chưa có onboarding thật — người chơi mới không có chỉ dẫn nào ngoài
UI ngầm hiểu. Đây là gap floor/UX, ưu tiên Must vì ảnh hưởng người chơi mới
trực tiếp.

## Acceptance criteria
- [ ] Cờ `hasSeenFtue` (`StorageKeys` mới) — chỉ hiện overlay 1 lần duy nhất
      trong đời cài đặt app.
- [ ] Overlay trỏ vào 1 nhóm màu cụ thể trên board level 1, có text ngắn +
      tay chỉ (animation đơn giản, tái dùng effect có sẵn nếu có).
- [ ] Tap đúng vào nhóm được chỉ → overlay biến mất, level tiếp tục bình
      thường; tap sai chỗ không crash, không kẹt overlay.
- [ ] Rà soát `AppTranslations`: xoá key onboarding cũ không dùng nếu có (theo
      audit trong `doc/feat.md`), thêm key mới cho toàn bộ 22 locale.

## Subtasks (gợi ý file)
1. `lib/presentation/screens/game_screen.dart` hoặc controller: state
   `showFtue`.
2. Overlay widget mới (tái dùng `NeonDialog`-style layering, không phải dialog
   chặn tap toàn màn).
3. `lib/core/app_translations.dart`: key mới/dọn key cũ.

## Ghi chú kỹ thuật
Overlay không được chặn tap vào đúng nhóm được chỉ — chỉ chặn tap sai vị trí
hoặc không chặn gì, để không tạo cảm giác "kẹt".

DoD chung: `../README.md`.
