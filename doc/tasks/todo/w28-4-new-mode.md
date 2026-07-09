---
id: w28-4-new-mode
title: "Tính năng match-3 hoàn toàn mới"
wave: 28
phase: 4
status: todo
owner: claude
---

# Phase 4 — Tính năng mới hoàn toàn

## Vì sao (audit)

Campaign/Endless/Boss/Rhythm/Survival đã sâu; các mode còn lại đã có hướng enhance
riêng (xem `w28-1`). Đây là hướng **rủi ro cao nhất** nhưng tạo điểm mới thật cho
update log — tái dùng engine đã có để giảm effort xây từ đầu.

## 2 ứng viên (chọn 1, không làm cả 2 cùng wave)

### A. Boss Rush luân chuyển
Tái dùng Boss engine (`game_controller_modes.dart` + boss attack pattern Wave 23.2).
Mỗi tuần xoay 1 trong N boss đã có (thay vì luôn cùng 1 boss), thưởng riêng theo
tuần — tái dùng khung tuần đã có ở Season League/Challenge Card.

### B. Versus PvP async qua Ghost Mode
Ghost Mode (ghi lại replay) đã tồn tại. Cho phép đấu với "ghost" của lần chơi tốt
nhất trước đó (của chính mình) trong Endless/Rush — tạo cảm giác cạnh tranh mà
không cần server thật (đúng kiến trúc offline-first hiện tại).

## Việc cần làm khi bắt đầu

- [ ] Chọn A hoặc B trước khi code (AskUserQuestion nếu cần xác nhận lại).
- [ ] Đọc kỹ ghost replay logic hiện có (`game_controller_modes.dart`) trước khi mở rộng.
- [ ] Playtest kỹ hơn các wave khác — tính năng mới 100% dễ sinh bug lạ.
- [ ] Verify máy thật đầy đủ trước khi đánh dấu done.
