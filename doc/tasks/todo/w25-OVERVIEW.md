---
id: w25-overview
title: Wave 25 — Chiều sâu mode > Bề rộng (chống cảm giác "sơ sài")
wave: 25
status: todo
owner: claude
created: 2026-07-02
---

# 🌊 Wave 25 — Đào sâu mode, không thêm mode

**Xuất phát**: user nhận xét "các mode chơi game sơ sài quá". Audit code (2026-07-02) kết luận:
game **KHÔNG thiếu bề rộng cơ chế** — engine (`neon_jewel_game.dart` ~2.900 dòng) rẽ nhánh thật
cho Survival (rising tide), Labyrinth (maze-shift + fog), Boss (attack pattern), Rhythm (beat
judge), Gravity (`settleBoardFlow`), weave (conveyor/portal/dispenser). Vấn đề nằm ở **CHIỀU SÂU**:

- Boss chỉ leo thang bằng **HP tuyến tính** (`+700/stage`) + 3 kiểu đòn, `meteor` **chưa wire**
  (`logic/boss_attack.dart` 26 dòng). "Khó hơn" ≠ "khác hơn".
- ~½ số mode phụ là nhãn 🟡 **B** (đổi luật/target cùng vòng lặp) theo chính audit ở `README.md`.
- Không mode phụ nào có **progression nội tại** như campaign → "chơi vài lần là cạn".

> 💡 **Phản biện đã chốt**: có 12+ mode mà vẫn thấy sơ sài ⇒ **thêm mode thứ 13/14 sẽ KHÔNG chữa
> được, chỉ làm loãng** (vẫn là match-3 trên cùng engine). Ưu tiên đào sâu 2-3 mode lõi.

## 4 phase (map tới 4 hướng user xác nhận đều đúng)

| Phase | Task | File | Hướng user | Ưu tiên | Đụng engine? |
|---|---|---|---|---|---|
| 1 | **Chiều sâu mode lõi** | `w25-1-mode-depth.md` | (1) chiều sâu | 🔴 Cao | ✅ Có (Boss/Rhythm) |
| 2 | **Tương phản cảm giác** | `w25-2-mode-contrast.md` | (3) same-y | 🟡 TB | ⚠️ Ít (HUD/audio/palette) |
| 3 | **Meta gắn mode phụ** | `w25-3-meta-retention.md` | (4) meta nhạt | 🟡 TB | ❌ Không (data/controller) |
| 4 | **Spike thể loại mới** | `w25-4-new-genre-spike.md` | (2) bề rộng | 🔵 Thấp / optional | ✅ Có (mới hoàn toàn) |

**Thứ tự đề xuất**: 1 → 2 → 3 → (4 chỉ làm nếu 1-3 xong và vẫn muốn bề rộng).

> ⚠️ **Về Phase 4 (bề rộng)**: giữ lại vì user xác nhận, nhưng đây là hướng **rủi ro loãng nhất**
> và tốn nhất — làm dưới dạng **spike thử nghiệm** (1 mode, throwaway nếu không "đã"), KHÔNG cam kết
> ship. Nếu ngân sách hẹp, cắt phase này trước.

## Nguyên tắc (NHẮC)
- 🚫 **KHÔNG commit** — chỉ code + test, user tự commit (xem [[code-on-main-only]]).
- Mode phụ KHÔNG được đụng win-streak / level-unlock / lives ([[side-mode-isolation]]) — kể cả khi
  thêm meta ở Phase 3 (dùng trục thưởng riêng, không nối vào progression campaign).
- Key persist mới → thêm vào `resetProgress` + `resetState()` ([[reset-permanent-controllers]]).
- Thưởng mới theo [[balance-economy-principles]] + [[currency-persistence-convention]] (guard-key TRƯỚC).
- Key i18n mới → convention `_wXXByLang`, giữ ratio ≥80% khác English.

> Nguồn chân lý tổng thể: [`../feat.md`](../feat.md).
