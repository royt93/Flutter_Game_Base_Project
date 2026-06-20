---
id: w18-4-split-utilities-ui
title: Tách Hướng dẫn + Cài đặt khỏi "Phần thưởng" (UI)
wave: 18
phase: 4
status: todo
owner: claude
---

# Phase 4 — Tách tiện ích khỏi khu "Phần thưởng" (UI trung thực)

## Vấn đề hiện tại (audit)
Lưới `meta_section` ("Phần thưởng") ở Home gồm 10 ô, nhưng **Hướng dẫn** và **Cài đặt**
là TIỆN ÍCH thuần (không kinh tế) — bị nhét chung → người chơi tưởng cũng là "phần
thưởng" → cảm giác "10 item không rõ chức năng". (Xem `home_screen.dart` khu meta.)

## Thiết kế mới
- Đổi nhãn khu thưởng → ví dụ "MỤC TIÊU & PHẦN THƯỞNG", chỉ chứa hệ kinh tế.
- Đưa **Hướng dẫn** + **Cài đặt** ra:
  - phương án A (rẻ): 1 hàng "TIỆN ÍCH" riêng phía dưới, hoặc
  - phương án B: 2 icon nhỏ ở top-bar (cạnh xu/quà) — gọn, đỡ tốn slot lưới.
- Nếu W18.1 gộp Giải đấu+Mùa (bớt 1 ô) → lưới thưởng còn cân đối; cân nhắc bố cục mới.

## Triển khai
- `home_screen.dart`: tách 2 `_circleNav` (guide/settings) ra section/top-bar riêng;
  cập nhật `_sectionLabel`. Giữ no-scroll (bài học layout Home — [[home-fullwidth-no-fittedbox]]).
- i18n: nhãn section mới ("utilities"/"tiện ích").

## Test (widget)
- Home render đủ item, KHÔNG scroll trên nhiều kích thước (small/large).
- Hướng dẫn + Cài đặt mở đúng từ vị trí mới.
- Khu thưởng chỉ còn hệ kinh tế.

## Lưu ý
- Rẻ nhất trong 8 task — chỉ dọn UI. Làm SAU 18.1 (số ô thay đổi) để khỏi bố cục 2 lần.
- Verify máy thật (Pixel 7 Pro qua CÁP USB — wireless yếu) để chắc không tràn/scroll.
- Liên quan: [[home-fullwidth-no-fittedbox]].
