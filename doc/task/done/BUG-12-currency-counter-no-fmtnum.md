---
id: BUG-12
title: CurrencyCounter không dùng fmtNum, hiển thị số thô không dấu phân cách
type: bug
priority: P1
effort: S
verified: true
source: Claude, verify lại code thật (lib/presentation/widgets/common/currency_counter.dart:59-60)
---

## Vị trí
`lib/presentation/widgets/common/currency_counter.dart:59-60` —
`TweenAnimationBuilder<int>` builder render `Text('$n', ...)` — số nguyên thô,
không qua `fmtNum` (`lib/core/utils/format.dart`) vốn đã có sẵn để format
đúng ngôn ngữ hiện tại (vd `10.000` cho `vi`, `10,000` cho `en`).

## Hậu quả
Số tiền/điểm lớn hiển thị dính liền không dấu phân cách (`1234567` thay vì
`1.234.567`), khó đọc — đặc biệt với casual/idle game nơi số dư tăng nhanh.

## Đề xuất fix
Đổi `'$n'` thành `fmtNum(n)` trong builder. Xem thêm ENH-11 (fmtNum cần thêm
chế độ rút gọn K/M/B cho số cực lớn của idle game).

## Acceptance criteria
- [ ] `CurrencyCounter` hiển thị số có dấu phân cách đúng theo locale hiện tại.
- [ ] Test widget verify text hiển thị khớp `fmtNum(value)` thay vì số thô.
