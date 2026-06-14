---
id: w7-meta-build
title: Meta build/trang trí — "Đền Neon"
wave: 7
status: done
owner: claude
---

# Meta-progression ngoài lưới: xây & trang trí "Đền Neon"

> Lý do chọn: match-3 top hiện nay (Royal Match, Gardenscapes, Homescapes) giữ
> chân bằng MỤC TIÊU NGOÀI LƯỚI — "chơi level để có tài nguyên xây dựng". Neon
> Jewels đang thiếu hẳn lớp này. Đây là đòn bẩy retention mạnh nhất còn trống.

## Ý tưởng cốt lõi
- Người chơi tích **Shard (mảnh neon)** mỗi khi thắng level (≈ theo số sao).
- Dùng Shard để **xây / nâng cấp các hạng mục** của "Đền Neon" (công trình neon
  trừu tượng — KHÔNG cần asset ảnh phức tạp, vẽ bằng `CustomPainter` để bám
  phong cách neon hiện có, giống cách `npc_avatar.dart` đang làm).
- Mỗi hạng mục có nhiều **tier** (cấp độ) → xây xong tier mở hiệu ứng đẹp hơn +
  có thể tặng thưởng nhỏ (xu/booster) → vòng lặp "chơi → có shard → xây → khoe".

## Tài nguyên mới: Shard
- `StorageKeys.shards = 'shards'` (RxInt, mặc định 0).
- Kiếm: thắng level → `+ (1 + stars)` shard (1 sao = 2, 3 sao = 4). Endless KHÔNG cho shard (tránh farm).
- Có thể bổ sung: daily/achievement thưởng thêm shard.
- Đi qua helper `_setShards()` (clamp [0, maxCoins], persist) — học từ bug currency Wave-trước.

## Mô hình dữ liệu (`lib/data/temple.dart`)
- `TempleNode { id, nameKey, descKey, tiers: List<TempleTier> }`
- `TempleTier { cost(shard), rewardCoins, accent }`
- Danh sách ~6 hạng mục: Cổng (Gate), Trụ (Pillar), Đài (Altar), Vườn sao
  (StarGarden), Tháp (Spire), Lõi (Core). Mỗi cái 3 tier.

## Controller (`temple_controller.dart`)
- `RxMap<String,int> builtTier` (id → tier hiện tại, 0 = chưa xây).
- `bool build(TempleNode n)`: đủ shard → trừ shard, tier++, thưởng rewardCoins, persist.
- Persist: `StorageKeys.templeTier(id)`.

## UI (`temple_screen.dart`)
- Vào từ Home (nút "ĐỀN NEON" cạnh ENDLESS).
- `CustomPainter` vẽ toàn cảnh đền: mỗi node sáng dần theo tier (glow mạnh hơn).
- Panel chọn node → hiện cost tier kế + nút XÂY (disable nếu thiếu shard).
- HUD shard ở góc (giống chip xu/tim).

## i18n
- Thêm key qua `_extraEn/_extraVi` merge (theo memory [[i18n-extra-merge]]).
- Key: `temple_title`, `shards`, `temple_build`, `temple_node_*`, ...

## Test
- temple_controller: build trừ shard đúng, chặn khi thiếu, tier không vượt max,
  thưởng coins đúng, persist/restore.

## Trạng thái — ✅ DONE (MVP)
Đã làm: `data/temple.dart` (6 hạng mục × 3 tier), `temple_controller.dart`
(build/spend/persist/progress), `temple_screen.dart` (CustomPainter nối node +
node bấm chọn + panel xây), Shard vào `GameController` (`_setShards`/`addShards`/
`spendShards`, clamp overflow, thưởng `1 + sao` khi thắng — Endless không cho),
hiển thị shard ở dialog thắng, nút "Đền Neon" ở Home, i18n en+vi (22 ngôn ngữ
fallback qua `_extraEn`), reset trong `resetProgress`.

Kết quả: 0 analyzer issue · **149 test pass** (+9 `test/w7_test.dart`) · build APK debug OK.

Còn lại của Wave 7 (sự kiện mùa, battle pass) ở `todo/`.
