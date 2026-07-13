# X6 — Mời bạn bè (share invite)

**Epic:** Floor/UX · **SP:** 3 · **Pri:** Should · **Deps:** F15 (tái dùng hạ tầng share)

## Mục tiêu
Nút "Mời bạn" ở Settings/Home, mở share sheet hệ thống với text mời chơi +
link store (placeholder nếu chưa có link thật).

## Vì sao
Viral rẻ tiền, tái dùng share sheet đã dựng ở F15 — không cần code chia sẻ
mới.

## Acceptance criteria
- [ ] Nút mời bạn dùng chung hàm share hệ thống đã có ở F15 (text-only, không
      cần ảnh).
- [ ] Text mời có placeholder link store, dễ thay khi có link thật.
- [ ] Manual test: share sheet mở đúng, nội dung text đúng.

## Subtasks (gợi ý file)
1. Tái dùng hàm share ở F15 (tham số text-only, không kèm ảnh).
2. `lib/presentation/screens/settings_screen.dart` hoặc `home_screen.dart`:
   nút mời bạn.

## Ghi chú kỹ thuật
Không tạo pipeline share riêng — gọi lại đúng hàm/plugin đã thêm ở F15.

DoD chung: `../README.md`.
