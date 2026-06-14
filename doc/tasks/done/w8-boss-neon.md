---
id: w8-boss-neon
title: Boss neon theo lượt (signature)
wave: 8
status: done
owner: claude
---

# Trùm Neon — match-3 đánh boss kiểu RPG

> ĐỘC QUYỀN: thêm chiều "phiêu lưu/RPG" (giống Empires & Puzzles, Puzzle Quest)
> vào match-3 neon. Tạo cao trào cuối mỗi thế giới.

## Cơ chế
- Boss có **thanh máu**. Mỗi match gây sát thương = f(số gem, combo, màu khớp
  điểm yếu boss). Ghép special → đòn mạnh.
- **Boss phản đòn theo lượt/đếm ngược**: đóng băng ô (ice), đổ rác (junk gem),
  khoá 1 cột, giảm số lượt — tái dùng obstacle đã có (ice/chain/stone/spread).
- **Điểm yếu màu**: boss yếu trước 1 màu gem (đổi theo phase) → khuyến khích ghép
  đúng màu → chiều sâu chiến thuật.
- Thắng = hạ HP boss về 0 trước khi hết lượt/thời gian.

## Việc cần làm
- `ObjectiveType.boss` + `BossConfig { hp, weaknessColor, phases, retaliation }`.
- Lớp "damage" map từ match → HP boss (mở rộng `addScore`/resolve match).
- Boss "phản đòn": hook sau mỗi lượt người chơi → spawn obstacle/junk.
- HUD boss: avatar (`CustomPainter` như NPC), thanh máu, icon điểm yếu, cảnh báo đòn.
- Đặt boss ở **màn cuối mỗi world** (level 20/40/60/80/100) → nối với Story.

## Test
- damage theo combo/điểm yếu đúng; phase đổi điểm yếu; phản đòn spawn obstacle
  đúng nhịp; thắng/thua theo HP & lượt.

## Trạng thái — ✅ DONE (chế độ riêng như Endless, không sửa core engine)
`ObjectiveType.boss` + `buildBossLevel()`; GameController: `startBoss(stage)`, máu theo stage,
`_bossDamage` (combo ≥4 gấp đôi, đổi điểm yếu khi <50% máu), phản đòn hút thêm lượt mỗi 3-4 lượt,
`hasWon`/`objectiveProgress`/checkEnd boss (thưởng xu+shard, không đụng streak/level), HUD bar +
badge, result panel riêng (không tốn mạng), nút BOSS Home (stage scale theo unlock), i18n en+vi.
Kết quả: 0 analyzer · test `test/w8_boss_test.dart` (8) pass.
