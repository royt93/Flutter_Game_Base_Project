---
id: FEAT-174
title: HapticPatternPicker — Chọn và nghe thử pattern rung có kiểm soát preference
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
Kit đã có `HapticChoreographer`, `HapticPattern`, `HapticLevel` và Settings lưu haptic enabled/soft mode, nhưng chưa có control để người chơi nghe thử các pattern ngắn theo ngữ cảnh (soft/standard/strong). UI phải tôn trọng tắt haptics và soft mode, đồng thời không phát rung liên tục khi preview.

## Đề xuất phạm vi
Widget `HapticPatternPicker` hiển thị:
- Các lựa chọn 1–3 `HapticPatternOption(id, label, pattern)`; một lựa chọn đang dùng do caller truyền.
- Nút chọn gọi `onSelect(id)`; nút preview chỉ phát một lần pattern qua caller-supplied `HapticChoreographer`/callback seam.
- Nút preview disabled khi `hapticsEnabled == false`, và disable mọi thao tác khi `busy` (pattern đang phát).
- `onPreview(pattern)` là seam; widget không tự ghi settings hoặc tạo choreographer trong build.
- Semantics có label, selected/busy/disabled; không hiển thị thông tin kỹ thuật pulse/delay cho người chơi.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: option id/label không rỗng, ID duy nhất, ít nhất 1 và tối đa 3 option, selectedId hợp lệ/null; `ArgumentError` runtime.
- [ ] **Widget test**: chọn option, preview seam gọi đúng một lần với pattern, haptics disabled chặn preview, busy chặn preview và select, semantics trạng thái, 320dp + textScale 2.0 + RTL, 48dp targets.
- [ ] **Haptics platform test**: `SystemChannels.platform` mock ghi nhận đúng `HapticFeedback.*`; không rung khi preference tắt hoặc `StorageService` chưa đăng ký; soft mode chỉ phát haptic level đã downgrade theo helper hiện hữu.
- [ ] **Integration test (Device)**: mở control, chọn và preview một lần trên thiết bị thật; kiểm tra serial/foreground và hỏi nếu app khác đang dùng; không chạy pattern lặp dài.
- [ ] **Golden test**: lựa chọn thường/selected/busy/disabled × 7 biến thể, viewport 390×844, baselines Linux + Flutter 3.35.1.
- [ ] **Interruption test**: chạm preview nhanh nhiều lần chỉ một lần khi busy, sau busy có thể nghe lại.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: widget không sở hữu timer/choreographer, unmount khi busy không phát thêm callback.
- [ ] **Frame rate / Jank test**: không animation bắt buộc; kiểm tra UI không block khi preview chạy bất đồng bộ, không tuyên bố jank budget nếu chưa đo.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Touch feedback theo `PressableScale`/`reducedMotion`; không tự phát haptic khi chọn nếu preview đã có, tránh rung kép.
