---
id: FEAT-170
title: TitleChipPicker — Bộ chọn danh hiệu dạng chip với trạng thái khoá và đang dùng
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Người chơi có thể đạt nhiều danh hiệu (ví dụ "Explorer", "Streak Master") và cần chọn một danh hiệu hiển thị cạnh tên. Chưa có UI chọn danh hiệu; không nên tái dùng `SegmentedTabBar` vì số lượng lớn, độ dài chữ khác nhau và có trạng thái khoá.

## Đề xuất phạm vi
Widget `TitleChipPicker` hiển thị:
- Danh sách `TitleOption(id, label, locked, unlockHint?)`, id duy nhất, xếp bằng `Wrap` tự xuống dòng.
- Chip đang dùng (`selectedId`) nhấn mạnh; chip khoá có biểu tượng khoá và mờ.
- Tuỳ chọn "Không dùng danh hiệu" (`noneLabel`) đặt `selectedId == null`.
- `onSelect(id)` cho chip đã mở; `onLockedTap(id)` cho chip khoá (caller hiện `unlockHint`), không tự đổi lựa chọn.
- Nhãn dài hiển thị tối đa 2 dòng rồi cắt; không tràn ngang ở 320dp + textScale 2.0.
- Presentation-only: caller sở hữu danh sách, trạng thái mở khoá và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: id không rỗng và duy nhất, label không rỗng, `selectedId` null hoặc là danh hiệu không khoá, `noneLabel` không rỗng; `ArgumentError` runtime.
- [ ] **Widget test**: không chọn, đang chọn, chip khoá (gọi `onLockedTap`, không gọi `onSelect`), chọn "không dùng", danh sách rỗng, nhãn rất dài, semantics (tên, đang dùng, khoá + gợi ý), target >= 48dp, 320dp + textScale 2.0 gutter 16dp, RTL thật.
- [ ] **Integration test (Device)**: chọn danh hiệu và chạm chip khoá qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground, hỏi nếu đang là app khác; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` không chọn/đang chọn/có khoá/nhãn dài × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1 theo CLAUDE.md.
- [ ] **Interruption test**: đổi `selectedId` liên tục và thay danh sách giữa chừng không crash, giá trị cuối đúng, không phát callback thừa.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: không còn ticker sau unmount và khi reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming với 100 danh hiệu và đổi lựa chọn liên tục (profile thiết bị thật), ghi rõ giới hạn engine timing.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Chip vừa chọn có chuyển màu ngắn; `reducedMotion` đổi tức thì; tái dùng `PressableScale`.
