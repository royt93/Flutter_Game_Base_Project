---
id: w13-debt-polish
title: Dọn nợ nhỏ + polish (audit)
wave: 13
status: done
owner: claude
---
# Đóng nợ audit còn lại
- _findMove nhận nước "đập 2 special kề / swap rainbow" → không xáo bàn phá special oan.
- Cổng echo KÍCH special đối tác (không clear trơn).
- Bỏ fontFamily lặp (an toàn: chỉ widget TextStyle, GIỮ trong CustomPainter).
- Cap particle cascade lớn (_spawnBurst).
## Trạng thái — 🟡 in-progress

## ✅ DONE
- _findMove + comboMove: nhận nước "2 special kề / swap rainbow" → không xáo phá special.
- Cổng echo: _expandSpecials sau expandPortals → kích special đối tác (chain qua cổng).
- _burstCap=16: cap particle gem thường cascade lớn (special không giới hạn).
- Bỏ 81 dòng fontFamily thừa ở file widget thuần (GIỮ trong file painter).
