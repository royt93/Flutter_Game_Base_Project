---
id: FEAT-09
title: Offline Progression / Idle Earnings Calculator
type: feature
priority: P1
effort: M
source: agy + claude-CLI (đề xuất trùng, gộp 1 task)
---

## Vì sao cần
Riêng cho thể loại Idle/Tycoon: tính thu nhập tích luỹ khi người chơi vắng
mặt, hiện popup "Welcome Back" cho claim. `ClampedClock` đã có sẵn làm nguồn
thời gian chống gian lận — đây là bài toán khó nhất của idle game (chống tua
giờ) mà kit hiện tại đã có nửa lời giải, chỉ thiếu phần nghiệp vụ.

## Đề xuất phạm vi
1 helper tính `thu nhập = min(thời gian vắng mặt, maxOfflineCap) * tốc độ
sản xuất/giây`, dùng `nowMsClamped()` làm mốc thời gian. Không cần UI popup
sẵn (tuỳ game), chỉ cần phần tính toán + API `claim()`/`claimDouble()` (xem
quảng cáo x2, tích hợp với FEAT-02 nếu có).

## Acceptance criteria
- [ ] Thời gian vắng mặt vượt `maxOfflineCap` → thu nhập bị giới hạn đúng cap, không tính vượt.
- [ ] Test round-trip: set tốc độ sản xuất, giả lập thời gian trôi qua, verify số tiền tính đúng.
