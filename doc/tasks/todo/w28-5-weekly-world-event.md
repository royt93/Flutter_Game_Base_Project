---
id: w28-5-weekly-world-event
title: "Weekly Rotating World Event"
wave: 28
phase: 5
status: todo
owner: claude
---

# Phase 5 — Weekly Rotating World Event

## Concept

Buff/debuff toàn cầu đổi mỗi tuần, hiển thị ở World Map (VD "Tuần Nhân Đôi Xu",
"Tuần Không Đặc Biệt", "Tuần Combo Vàng"). Tái dùng **Daily mutator engine**
(`lib/data/levels.dart` + `game_controller_modes.dart` Wave 17.3) nhưng đổi scope
từ per-level (Daily) sang toàn app/toàn tuần — tạo lý do quay lại thường xuyên hơn
Season League (vốn cũng reset tuần nhưng không có tín hiệu trực quan trên World Map).

## Phạm vi đề xuất

1. Danh sách event tuần (const list, seed theo epoch-week — tất định, không RNG
   client-server lệch).
2. Áp buff/debuff vào công thức thưởng hiện có (coin/score) — **không** đổi cap
   hay công thức gốc, chỉ multiply có kiểm soát.
3. Banner nhỏ trên World Map hiển thị event đang chạy + thời gian còn lại.
4. i18n: thêm key tên/mô tả mỗi event cho 22 ngôn ngữ.

## Rủi ro cần lưu ý

- Buff quá mạnh có thể lệch economy đã cân bằng (coin sink Piggy/Temple, Battle
  Pass XP pace) — cần giới hạn hệ số nhỏ (VD ×1.2-1.5, không ×2 tuỳ tiện).
- Không đụng `_effectiveDay` anti-cheat pattern (event tuần vẫn phải dùng
  epoch-week tất định, không đọc `DateTime.now()` trực tiếp).

## Việc cần làm khi bắt đầu

- [ ] Đọc kỹ Daily mutator pattern (`game_controller_modes.dart`) trước khi tái dùng.
- [ ] Thiết kế bảng hệ số cụ thể, review lại trước khi code.
- [ ] Test anti-cheat: lùi giờ máy không farm được nhiều event hơn 1 lần/tuần.
- [ ] Verify máy thật: banner World Map hiện đúng, hết tuần tự đổi event.
