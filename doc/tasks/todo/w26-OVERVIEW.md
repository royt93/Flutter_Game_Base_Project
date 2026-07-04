---
id: w26-overview
title: Wave 26 — Batch 4 hướng (tương phản HUD/nhạc · World Map identity · meta · boss depth)
wave: 26
status: done
owner: claude
created: 2026-07-03
---

# 🌊 Wave 26 — Batch 4 hướng (user chốt: làm cả 4)

Gom 4 hạng mục feature/enhance thành 1 batch. **2 hạng mục MỚI** có file rã chi tiết trong wave này;
**2 hạng mục ĐÃ rã sẵn** ở Wave 25 — link chéo, KHÔNG tạo trùng.

## Tiến độ (2026-07-03) — 4/4 HOÀN TẤT

| Phase | Hạng mục | File | Loại | Ưu tiên | Đụng engine? | Trạng thái |
|---|---|---|---|---|---|---|
| 1 | **Hoàn tất tương phản: HUD + nhạc per-mode** | `../in-progress/w26-1-mode-contrast-hud-audio.md` | Enhance (W25-2 đợt 2) | 🔴 Cao | ⚠️ Ít | ✅ **DONE** |
| 2 | **World Map — bản sắc thị giác per-world** | `../in-progress/w26-2-world-map-identity.md` | Enhance (polish) | 🟡 TB | ❌ Không | ✅ **DONE** |
| 3 | **Meta/giữ chân** | `../in-progress/w25-3-meta-retention.md` | Feature mới (đã rã) | 🟡 TB | ❌ Không | ✅ **DONE** |
| 4 | **Boss depth 1B + 1C** | ↪ `../in-progress/w25-1-mode-depth.md` | Enhance (đã rã) | 🟢 Thấp | ✅ Có (1B) | ✅ **DONE** |

### Phase 1 — HUD/nhạc per-mode ✅ (chi tiết: `w26-1-mode-contrast-hud-audio.md`)
- 4 mode đồng phục (Gravity/Soda/Labyrinth/Daily) có HUD chủ đạo riêng; ColorRush thêm chip streak
  ×N; nhạc nền đổi theo nhóm mode (3 track). i18n 3 key mới × 22 ngôn ngữ.
- `flutter analyze` 0 · full suite 923 passed · verify thật trên device R5CX613VZBR (5 mode, logcat
  sạch, không giật layout).

### Phase 2 — World Map identity ✅ (chi tiết: `w26-2-world-map-identity.md`)
- Fix `worldAccents` 5→10 màu riêng biệt; thêm `WorldLandmark` enum + 10 glyph vẽ tay/thế giới;
  path/xung năng lượng + dải nền đổi màu theo world (trước đó cứng cyan); banner nâng cấp icon
  landmark.
- `flutter analyze` 0 · full suite 937 passed (test mới `w26_2_world_map_identity_test.dart`) ·
  verify thật trên device R5CX613VZBR (World 1 Nebula/cyan vs World 4 Comet/cam phân biệt rõ, không
  đè node/banner, không crash).

### Phase 3 — Meta gắn side-mode ✅ (chi tiết: `w25-3-meta-retention.md`)
- Trục điểm side-mode/tuần (gắn vào `ChallengeCardController` có sẵn, không tạo controller mới) —
  mọi side-mode thắng đều +điểm, 3 mốc thưởng xu/tuần.
- "Quest xoay theo mode" phát hiện **đã có sẵn** qua W20.3 — chỉ nâng cấp thêm 1 loại quest kỹ năng
  mới (`reachRecordTier`, dựa lifetime record, phủ thêm Survival/Labyrinth).
- Thêm mốc **Platinum** (bậc thứ 4 sau Gold) + 3 danh hiệu đeo được (tái dùng hệ achievement/title
  có sẵn, không cần UI mới); liên kết Progression Tree (node `ascendant`) + Battle Pass (bonus XP nhỏ,
  tách biệt gate campaign-only).
- Không đụng win-streak/level-unlock/lives ([[side-mode-isolation]]).
- `flutter analyze` 0 · full suite 949 passed (test mới `w25_3_side_meta_test.dart`, sửa 5 test cũ lỗi
  thời do đổi số lượng cố định). Không cần device (thuần data/controller).

### Phase 4 — Boss depth 1B + 1C ✅ (chi tiết: `w25-1-mode-depth.md`)
- 1A (boss telegraph + 2 loại boss) đã device-verify từ đợt trước (Samsung A11).
- **1B — ColorRush B→A**: `biasRefillToHotColor()` (`lib/data/levels.dart`) nghiêng 35% refill về
  màu nóng khi ColorRush bật, wire vào `_refillColor()` (`neon_jewel_game.dart`) — nhánh cơ chế
  board thật, không chỉ đổi điểm/HUD. 0 rủi ro lan sang `settle.dart`/`GemComponent`/playtest.
- **1C — "Thử Thách" (hard variant)**: `SideModeRecordController.toggleHardVariant` — mở sau Gold,
  đổi lượt (-15%, `_resetRunState()`) lấy thưởng cao hơn (+50% xu, `discountSideModeReward()`). Icon
  toggle 🔥 cạnh badge kỷ lục trên Home. Không đụng win-streak/level-unlock/lives.
- `flutter analyze` 0 · full suite 969 passed (test mới `w25_1_hard_variant_test.dart` + mở rộng
  `w17_4_deepen_b_modes_test.dart`) · `dart run tool/playtest.dart`: 0 màn quá khó, không lệch
  baseline. **Chưa verify device riêng cho 1B/1C** (thuần logic/economy, rủi ro thấp).

## ⚠️ Ghi chú trung thực về hiện trạng (kiểm code 2026-07-03)

- **World Map KHÔNG phải feature mới** — `world_map_screen.dart` (869 dòng) đã có: node-path uốn
  lượn + glow (Wave 5.3/6), avatar đi bộ (W22.5/W23.3), mini-boss node (W23), chest node (W22).
  Deferred "đường đi node-based" trong `feat.md:448` **đã hoàn thành**. Phase 2 ở đây CHỈ là **bản sắc
  thị giác per-world** (landmark/lâu đài, background riêng) — map hiện "tĩnh, chỉ khác màu accent"
  (w21-5). Đừng rã/làm lại cái đã có.
- **Meta (Phase 3)** = `w25-3-meta-retention.md` (todo, đã rã đầy đủ). Không viết lại.
- **Boss 1B/1C (Phase 4)** = `w25-1-mode-depth.md` (done — cả 1A+1B+1C hoàn tất, code+test xanh;
  chỉ còn thiếu device-verify riêng cho 1B/1C, không chặn "done"). Không viết lại.

## Nguyên tắc (NHẮC)
- 🚫 **KHÔNG commit** — user tự commit ([[code-on-main-only]]).
- Mode phụ KHÔNG đụng win-streak/level-unlock/lives ([[side-mode-isolation]]) — kể cả Phase 3.
- Key persist mới → `resetProgress` + `resetState()` ([[reset-permanent-controllers]]); thưởng guard-key
  TRƯỚC ([[currency-persistence-convention]]); cân bằng faucet ([[balance-economy-principles]]).
- Key i18n mới → convention `_wXXByLang` (20 ngôn ngữ), ratio ≥80% khác English.
- HUD/overlay full-screen Flame → dùng `NeonDialog.overlay`, không `Get.dialog`.

> Nguồn chân lý tổng thể: [`../feat.md`](../feat.md). Liên quan: [[w25-2-mode-contrast]], [[w21-5-world-map-events]].
