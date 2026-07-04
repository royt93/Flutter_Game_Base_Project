---
id: w27-1-device-verify-1abc
title: Device-verify — Boss telegraph (1A) + ColorRush refill-bias (1B) + Thử Thách (1C)
wave: 27
phase: 1
status: todo
owner: claude
created: 2026-07-04
---

# Phase 1 — Device-verify Wave 25.1 (1A/1B/1C)

Theo [[w25-1-mode-depth]]: 1A đã unit-test + device-verify xong; 1B/1C có unit-test xanh (969 passed)
nhưng **chưa nhìn bằng mắt trên device**. Task này verify cả 3 (đủ tài liệu), tập trung 1B/1C.
Theo R3: `adb devices` + chọn target trước; theo R4: dừng nếu gặp ad che UI (app không có ad SDK → ok).

## 1A — Boss telegraph → meteor (đã verify — chỉ xác nhận lại nếu cần)
- [x] Vào Boss mode, đợi phase đổi (HP thấp) → thấy vòng tròn tím cảnh báo (telegraph) ở vùng sắp bị
  meteor đánh trước 1 lượt. **Đã verify 2026-07-04 trên R5CX613VZBR ("Xung Kích · TRÙM NEON 1").**
- [ ] (Tuỳ chọn) Verify thêm 1 stage chẵn (voidType) để thấy chuỗi shuffle→meteor→meteor hung hãn hơn
  Pulse (stage lẻ).

## 1B — ColorRush refill-bias (chưa verify)
- [ ] Vào ColorRush, chơi vài ván (≥10 lượt), quan sát màu "nóng" (hiển thị trên HUD/chip streak) có
  rơi/refill **nhiều hơn rõ rệt bằng mắt** so với 5 màu khác không. Kỳ vọng ~35% + 1/6 ≈ 46% (test
  thống kê 500 trial đã xác nhận > 30%).
- [ ] Đổi màu nóng (mỗi `kColorRushChangeEvery` lượt) → xác nhận màu mới cũng được ưu ái refill (bias
  bám theo `colorRushHot`, không cứng 1 màu).
- [ ] Không thấy giật/lag khác thường khi refill (bias chỉ đổi màu chọn, không đổi tốc độ animation).

## 1C — "Thử Thách" (hard variant, sau Gold)
- [ ] Đạt Gold ở 1 mode phụ (ví dụ ColorRush) → icon toggle 🔥 xuất hiện cạnh badge kỷ lục trên Home
  (trước đó chưa Gold thì KHÔNG thấy icon này).
- [ ] Bật icon 🔥 → vào ván mode đó, xác nhận `movesLeft` ban đầu **ít hơn ~15%** so với bình thường.
- [ ] Thắng ván (bật Thử Thách) → xác nhận xu thưởng **nhiều hơn ~50%** so với ván tắt Thử Thách
  (cùng điểm số/base tương đương).
- [ ] Tắt icon 🔥 → ván tiếp theo trở lại lượt/thưởng bình thường (không dính trạng thái cũ).
- [ ] Vào campaign (level thường) → xác nhận UI không có icon 🔥, lượt/thưởng không bị ảnh hưởng dù
  đã bật Thử Thách ở mode phụ khác (test unit đã xác nhận, verify lại bằng mắt cho chắc).

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Nếu phát hiện ad che UI → dừng ngay theo R4, báo user (loại ad, vị trí), chờ "done".
- Nếu lệch visual (bias không rõ rệt, icon 🔥 sai vị trí...) → tinh chỉnh tham số ngay trong phiên có
  device, không để lại nợ.
- Link: [[w25-1-mode-depth]] (nguồn code+test gốc của cả 1A/1B/1C).
