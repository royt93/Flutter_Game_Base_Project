---
id: FEAT-168
title: AvatarFrameSelector — Bộ chọn khung avatar kèm trạng thái khoá và đang dùng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
`AvatarFrame` chỉ là vòng viền quanh một avatar, chưa có UI để người chơi duyệt và đổi khung. Cần một bộ chọn gọn cho màn hồ sơ, hiển thị khung nào đang dùng, khung nào còn khoá, mà không sở hữu kho đồ hay logic mở khoá.

## Đề xuất phạm vi
Widget `AvatarFrameSelector` hiển thị:
- Danh sách `AvatarFrameOption(id, label, color, locked, lockHint?)`, id duy nhất.
- Mỗi ô là một `AvatarFrame` xem trước với avatar của caller (`previewChild`), nhãn dưới ô, dấu "đang dùng" cho `selectedId`.
- `onSelect(id)` cho khung đã mở; `onLockedTap(id)` cho khung còn khoá (caller mở cửa hàng hoặc hiện gợi ý), không tự đổi lựa chọn.
- Lưới cuộn lazy, số cột thích ứng theo chiều rộng và textScale; không bị cắt nhãn ở textScale 2.0.
- Presentation-only: caller sở hữu danh sách khung, trạng thái mở khoá và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: id không rỗng và duy nhất, label không rỗng, `selectedId` null hoặc thuộc danh sách và không khoá; `ArgumentError` bằng kiểm tra runtime, không chỉ assert.
- [ ] **Widget test**: chưa chọn, đang chọn, khung khoá (chạm gọi `onLockedTap`, không gọi `onSelect`), danh sách rỗng, nhiều khung dựng lazy, semantics từng ô (tên, đang dùng, khoá), target >= 48dp, 320dp + textScale 2.0 gutter 16dp, RTL thật (kiểm tra `Directionality`).
- [ ] **Integration test (Device)**: chọn khung và chạm khung khoá qua caller seam trên thiết bị thật; kiểm tra lại serial và app foreground trước khi chạy, hỏi người dùng nếu đang là app khác; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` chưa chọn/đang chọn/có khoá/rỗng × 7 biến thể, viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1) theo CLAUDE.md, không dùng ảnh macOS.
- [ ] **Interruption test**: đổi `selectedId` hoặc danh sách giữa lúc cuộn không mất vị trí cuộn và không phát callback sai.
- [ ] **Network conditioning test**: N/A — caller sở hữu dữ liệu.
- [ ] **Memory leak & profiling test**: `ScrollController` nội bộ (nếu có) được dispose, `transientCallbackCount == 0` sau unmount và khi reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi cuộn 100 khung (profile, thiết bị thật); ghi rõ đây là engine timing, không chứng minh 60 FPS bền vững.
- [ ] **IAP & Ad mediation test**: N/A — chỉ phát `onLockedTap`, không biết nguồn mở khoá.

## Hiệu năng & Animation
- [ ] Ô được chọn có nhịp nhấn nhẹ một lần khi đổi lựa chọn (không khi mount); `reducedMotion` tắt hiệu ứng; dùng `GridView.builder` lazy.
