---
id: w8-rhythm-mode
title: Chế độ Nhịp điệu (Rhythm match-3) (signature)
wave: 8
status: todo
owner: claude
---

# Chế độ Nhịp điệu — ghép gem theo beat nhạc

> ĐỘC QUYỀN MẠNH NHẤT: match-3 + âm nhạc gần như chưa ai làm tốt. Game ĐÃ CÓ
> sẵn 24 nốt nhạc leo thang (`audio_manager.dart` playNote 1..24) + combo escalation
> → hạ tầng audio đã sẵn, chỉ thiếu lớp "nhịp".

## Cơ chế
- Có **beat** đều đặn (BPM cố định/ theo track). Vạch nhịp đập trên HUD.
- Ghép gem **đúng cửa sổ nhịp** (on-beat) → bonus: combo ×2, điểm cao hơn, nốt
  nhạc "khớp" nghe đã tai; ghép lệch nhịp → điểm thường.
- Chuỗi on-beat liên tiếp → "groove meter" tăng → mở hiệu ứng + nốt cao dần.
- Gem có thể **nảy/sáng theo beat** (pulse) để gợi ý thời điểm.

## Việc cần làm
- `RhythmClock`: phát tick theo BPM (Ticker/`update` của Flame), KHÔNG dùng
  `Date.now()`/random (theo ràng buộc engine) — đếm thời gian tích luỹ trong game loop.
- Cửa sổ phán định on-beat (vd ±120ms) → đánh giá lúc swap hợp lệ.
- `ObjectiveType.rhythm` + HUD vạch nhịp + groove meter.
- Tận dụng `playNote(step)` map theo vị trí trong nhịp/groove.

## Lưu ý
- Phải tách nhạc nền có BPM rõ (hoặc click track ẩn) để on-beat chuẩn.
- Test khó vì liên quan thời gian thực → trừu tượng hoá clock nhịp để inject.

## Test
- on-beat window phán định đúng quanh mốc; groove tăng/giảm đúng; bonus điểm đúng.
