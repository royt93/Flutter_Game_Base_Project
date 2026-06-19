---
id: w16-4-nearmiss-rng
title: Near-miss + RNG control (tâm lý F2P — bản nhẹ/công bằng)
wave: 16
phase: 4
status: done
owner: claude
---

# Phase 4 — Near-miss + RNG control (BẢN NHẸ, có thể tắt)

Theo infographic: cắt 1-2 lượt màn khó ("suýt thắng") + thiên vị màu cuối lượt để
tăng căng thẳng.

## ⚠️ Quyết định đạo đức
Game ĐANG OFFLINE, CHƯA có IAP → near-miss "thúc mua lượt" tác dụng = 0, lại dễ cảm
giác bất công. Vì vậy làm **bản NHẸ + thiên về THỬ THÁCH công bằng**, KHÔNG lừa:
- **Near-miss = difficulty knob**: CHỈ Super-Hard cắt 1 lượt (tạo độ khó đỉnh), KHÔNG
  cắt để ép mua. Const `kNearMissCut` + cờ tắt được.
- **RNG control**: chỉ dùng theo HƯỚNG PITY (Phase 3) — KHÔNG dùng anti-player (giảm
  màu cần lúc cuối) vì bất công + không có IAP. Ghi rõ chỉ làm chiều "giúp", không "hại".
- Tất cả gate bởi const + cờ → dễ bật chiều "hại" khi có monetization + A/B sau.

## Test
- near-miss chỉ áp Super-Hard, cắt đúng kNearMissCut, winnability vẫn pass (playtest);
  RNG-pity bias đúng chiều (tăng màu cần khi pity), tắt được.

## Lưu ý
Đây là phase NHẠY CẢM nhất — ưu tiên CÔNG BẰNG. Phần "hại" (anti-player RNG, near-miss
ép mua) HOÃN tới khi có monetization + A/B test, KHÔNG bật mặc định.
