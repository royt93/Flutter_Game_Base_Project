---
id: w24-1-device-verify
title: Device-verify batch — kiểm mắt các feature W22-23 (test-only)
wave: 24
phase: 1
status: todo
owner: claude
---

# Phase 1 — Device-verify batch

Các feature dưới đây đã **pass unit/widget test** nhưng **CHƯA nhìn bằng mắt trên device**
(phiên W22-23 không build device). Verify + tinh chỉnh visual/feel 1 mẻ. Theo R3: list
`adb devices` + chọn target trước; theo R4: dừng nếu gặp ad che UI (app không có ad SDK → ok).

## Cần verify (mỗi mục: thao tác → tiêu chí pass)

### Game Feel (W22.1)
- [ ] **Thang combo 3/4-5/≥6**: combo 3 (shake nhẹ), 4-5 (vừa), ≥6 (wombo slow-mo) — leo thang mượt, không nhảy bậc.
- [ ] **Gem hiếm (lucky)**: pulse cầu vồng + sparkle — nhận ra ngay giữa gem thường.
- [ ] **Gem fall trail (W22.1.1)**: gem rơi nhanh có đuôi mờ; **FPS không tụt** khi cascade dài (cap hoạt động); băng chuyền wrap KHÔNG lóe trail giả (đã fix VỪA-3).
- [ ] **Cờ "Giảm hiệu ứng động"** (Settings): bật → tắt slow-mo + giảm shake/flash + tắt trail.

### World Map (W22.5 / W23.3)
- [ ] **Chest node**: ở màn trung điểm mỗi TG; khoá tới 80% → mở (glow vàng) → tap nhận overlay (xu/Búa/+Lượt) → thành check.
- [ ] **Mini-boss node**: TG chẵn, cạnh màn cuối; tap vào Boss HP thấp; thắng → node thành `verified`; thua không trừ mạng.
- [ ] **Avatar walk (W23.3)**: mở map → avatar "đi" từ node trước → node hiện tại + nhún; không giật.

### Leaderboard / Clan / Quest (W21.6 / W23)
- [ ] **Leaderboard**: tab Chiến dịch (chọn màn, BẠN highlight), Daily (sau khi hoàn thành Daily hiện điểm).
- [ ] **Clan**: roster 10 (BẠN highlight), thanh mục tiêu tuần, nút CLAIM khi đạt `kClanWeeklyGoal`.
- [ ] **Quest bonus**: hoàn thành cả 3 daily quest → thẻ "THƯỞNG TRỌN BỘ" + CLAIM (1 lần/ngày).
- [ ] **Skin/theme mới (W23.4)**: Shop hiện Galaxy/Neon Pop/Gold Lux + Nebula/Lava/Cyberpunk; mua + trang bị đổi render đúng.

### Onboarding (W22.3)
- [ ] **Home tour**: lần đầu (xoá data) → carousel 4 bước → đóng + không hiện lại.

### RELEASE_CHECKLIST còn treo
- [ ] **B3 split-screen**: vào split-screen — không vỡ/crash (game khoá portrait).
- [ ] **B4 perf 10' low-end**: không ANR, FPS ổn.
- [ ] **B4 background↔resume**: Campaign/Rush/Survival nền 30s → mở lại state đúng, timer/audio không lỗi.

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Phiên W22-23 từng đổi device 3 lần (Redmi/Vivo/Samsung) + gesture-nav Samsung kích app khác khi swipe → thao tác cẩn thận, tránh swipe từ mép.
- Nếu phát hiện lệch visual → tinh chỉnh tham số (shake/trail/màu) ngay trong phiên có device.
