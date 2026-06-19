---
id: w16-3-dda-pity
title: DDA & Pity System (trợ giúp động)
wave: 16
phase: 3
status: done
owner: claude
---

# Phase 3 — DDA & Pity System (giữ chân, chống bỏ cuộc)

Theo infographic: nếu người chơi kẹt lâu / thua liên tiếp → hệ thống "ngầm" tăng
trợ giúp (combo/booster/gợi ý mạnh) để vượt ải + tạo dopamine.

## Thiết kế
- **Pity counter**: đếm số lần THUA LIÊN TIẾP cùng 1 màn (`StorageKeys.pityFails`,
  reset khi thắng màn đó). Lưu theo màn.
- **Mức trợ giúp tăng dần**:
  - fail ≥2: tăng tỉ lệ gem may mắn (Lucky) + bias refill cho 1 special nhẹ.
  - fail ≥3: seed 1 special gem (striped) lúc mở màn + hint mạnh hơn (sớm hơn).
  - fail ≥4: +2 lượt khởi đầu ẩn (relief) HOẶC tặng 1 booster miễn phí.
- **CHỈ màn thường** (không side-mode — side-mode đã isolation). KÍN ĐÁO (không báo
  "đang được giúp" → giữ cảm giác tự thắng).
- Cờ bật/tắt + ngưỡng đưa ra const (dễ tune).

## Test
- pity tăng/giảm đúng (fail++/win reset); mức trợ giúp kích hoạt đúng ngưỡng;
  KHÔNG áp ở side-mode; persist/reset.

## Lưu ý
Cẩn thận KHÔNG gả quá lộ liễu (mất thử thách). Mức nhẹ, tăng dần. KHÔNG đụng
side-mode/daily (công bằng leaderboard offline).
