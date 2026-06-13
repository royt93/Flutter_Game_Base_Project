---
id: w4-lives-energy
title: Lives / Energy
wave: 4
status: done
owner: claude
---

# Lives / Energy (hệ thống mạng)

## Mục tiêu
Tạo nhịp chơi + sink mềm. Thua 1 màn mất 1 mạng; mạng hồi theo thời gian.

## Thiết kế
- Hằng số: `maxLives = 5`, `regenMinutes = 15`.
- **Storage**: `lives` (int), `livesRegenAt` (epoch ms — mốc hồi mạng kế tiếp).
- **GameController**:
  - `RxInt lives`.
  - `void _refillLives()` — gọi lúc load + khi mở màn chọn: tính số mạng hồi theo thời gian trôi qua, cập nhật.
  - `bool consumeLife()` — trừ 1 mạng (khi thua), set mốc regen nếu vừa rời max.
  - `Duration get timeToNextLife`.
- **Flow**: vào màn chơi yêu cầu lives > 0. Thua → `consumeLife()`. Hết mạng → chặn vào màn + hiện thời gian hồi (mua đầy bằng xu? -> để sau, scope: chỉ hồi theo thời gian).
- **UI**: hiện ❤×N trên Home + Level Select header; khi 0 mạng hiện đếm ngược.

## Acceptance
- [x] consumeLife trừ đúng, không âm
- [x] hồi 1 mạng mỗi 15' (mô phỏng bằng mốc thời gian), cap maxLives
- [x] thua màn trừ 1 mạng
- [x] 0 mạng chặn vào màn + báo thời gian hồi
- [x] unit test (regen theo mốc thời gian inject được)
- [x] analyze 0 issue · test pass

## ✅ Kết quả
Hoàn thành Wave 4 — analyze 0 issue · 89 test pass · build APK debug OK.
