# X2 — Settings: âm lượng riêng + haptics toggle

**Epic:** Floor/UX · **SP:** 3 · **Pri:** Must · **Deps:** none

## Mục tiêu
Settings hiện tại chỉ có on/off tổng — tách slider riêng nhạc nền (bgm) và
hiệu ứng (sfx), thêm switch bật/tắt haptic feedback.

## Vì sao
Gap floor cơ bản — game thiếu tuỳ chỉnh âm thanh chi tiết, chuẩn kỳ vọng tối
thiểu của thể loại casual puzzle.

## Acceptance criteria
- [ ] `AudioManager` thêm 2 mức volume riêng (bgm/sfx), lưu `StorageKeys` mới.
- [ ] Settings screen: 2 slider riêng (thay hoặc bổ sung switch tổng hiện có)
      + 1 switch haptics.
- [ ] Haptic toggle: khi tắt, mọi chỗ gọi `HapticFeedback.*` trong code phải
      check cờ trước khi gọi (rà soát toàn bộ điểm gọi hiện có).
- [ ] Unit test: lưu/đọc đúng giá trị volume + cờ haptics qua `StorageService`.

## Subtasks (gợi ý file)
1. `lib/core/audio_manager.dart` (hoặc tên tương đương): thêm volume riêng
   bgm/sfx.
2. `lib/core/storage_service.dart`: key volume/haptics.
3. `lib/presentation/screens/settings_screen.dart`: UI slider + switch.
4. Rà soát toàn bộ điểm gọi `HapticFeedback` — bọc qua 1 hàm helper check cờ,
   không sửa từng điểm gọi riêng lẻ.

## Ghi chú kỹ thuật
Haptics: dùng 1 hàm helper trung tâm (`triggerHaptic()`) thay vì gọi
`HapticFeedback` trực tiếp rải rác — chẻ nhỏ việc rà soát nếu số điểm gọi
nhiều.

DoD chung: `../README.md`.
