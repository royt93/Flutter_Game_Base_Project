---
id: w25-3-meta-retention
title: Meta gắn mode phụ — lý do quay lại (không phá cô lập)
wave: 25
phase: 3
status: todo
owner: claude
created: 2026-07-02
---

# Phase 3 — Cho mode phụ một "vì sao chơi lại"

Hướng user (4): "meta/phần thưởng nhạt, lý do quay lại yếu". Hiện side mode **cô lập hoàn toàn**
khỏi progression ([[side-mode-isolation]]) — tốt cho chống-farm nhưng khiến mode phụ **cụt vòng
tiến triển**: chơi xong không "dẫn tới đâu". Task này thêm trục nuôi **RIÊNG cho side mode**, KHÔNG
nối vào win-streak / unlock campaign / lives.

## Việc
- [ ] **Trục thưởng side-mode riêng**: 1 đường "điểm side-mode/tuần" (tách hẳn Mùa giải campaign) →
  mốc thưởng xu/booster. Đọc `todayEpochDay`/`_effectiveDay` (anti-cheat), reset tuần.
- [ ] **Quest xoay theo mode**: "tuần này chơi Survival đạt tầng X" / "ColorRush streak ×3" → thưởng.
  Buộc *luân phiên* mode thay vì chỉ cày 1 mode → khám phá hết bề rộng đã có.
- [ ] **Mốc record sâu hơn**: trên Bronze/Silver/Gold hiện có (`side_mode_records.dart`) thêm mốc
  **Platinum + danh hiệu đeo được** (tái dùng hệ danh hiệu W18.2) — phần thưởng "khoe" không p2w.
- [ ] **Liên kết Progression Tree / Battle Pass**: cho phép 1 nhánh nhỏ tiến bằng thành tích side-mode
  (nếu không phá cân bằng) → side mode "đóng góp" vào meta mà vẫn không đụng campaign progress.

## Acceptance
- [ ] Trục side-mode/tuần hoạt động; thắng side mode KHÔNG đổi win-streak/level-unlock/lives (test).
- [ ] Thưởng 1 lần/mốc (guard-key TRƯỚC — [[currency-persistence-convention]]); không re-claim khi
  restart; mọi key vào `resetProgress` + `resetState()` ([[reset-permanent-controllers]]).
- [ ] Quest xoay đọc thời gian qua `_effectiveDay` (không `DateTime.now()` trực tiếp).
- [ ] `flutter analyze` 0 · unit test (mốc 1 lần + reset + anti-cheat ngày) · suite xanh.

## Lưu ý
- ⚠️ Dễ vô tình phá [[side-mode-isolation]] — mọi hook thưởng phải qua trục RIÊNG, review kỹ.
- Thuần offline + data/controller (không đụng engine) → làm được không cần device.
- Cân bằng faucet theo [[balance-economy-principles]] — thêm sink nếu tăng nguồn xu.
