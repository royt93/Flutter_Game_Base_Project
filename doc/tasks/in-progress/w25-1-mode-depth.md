---
id: w25-1-mode-depth
title: Chiều sâu mode lõi — Boss đa dạng đòn + progression nội tại
wave: 25
phase: 1
status: in-progress
owner: claude
created: 2026-07-02
---

> 🟢 **Đợt 1 (2026-07-02) — Boss depth phần A xong (chờ verify device):**
> Khảo sát phát hiện `_doMeteor`/`_doShuffle` + `bossPhaseUpSignal` + điểm-yếu-đổi-phase **đã wire sẵn**
> (task note W23 cũ lạc hậu). Đợt này làm:
> - **Meteor nâng scramble-màu → XÓA gem thật**: cờ `_clearCells(scoring:false)`; `_doMeteorAt` +
>   `pickMeteorRegion` (pure, `logic/boss_attack.dart`) → tạo lỗ → gravity → refill.
> - **Telegraph cross-turn (chỉ meteor)**: báo lượt N (vùng đỏ `_MeteorWarning` + flash `boss_atk_meteor`)
>   → rơi lượt N+1 (đọc-và-né). shuffle/block giữ tức thì. Reset pending khi ván kết thúc/boss chết.
> - **2 loại boss** `BossType{pulse,voidType}` + `bossAttackPatternFor(phase,type)`; set theo stage
>   (chẵn=voidType hung hãn: shuffle→meteor→meteor); HUD hiện tên loại; i18n 22 ngôn ngữ (`_w25ByLang`).
> - **Test** `test/w25_boss_depth_test.dart` (selector 2 type + `pickMeteorRegion` + bossType theo stage).
>   `flutter analyze` 0 · full suite (exclude slow) **913 pass**.
> **Verify device (Samsung A11, SM-A115F)**: app chạy tốt, không crash; HUD hiện **"Pulse · NEON BOSS 1"**
> → tên loại boss + phase system chạy thật (stage lẻ=Pulse). Telegraph→meteor phase 2 CHƯA nhìn mắt
> (cần cày sâu; logic đã có unit test). ⚠️ Log `[AdManager]` thấy lúc verify là **tàn dư APK cũ** —
> code hiện tại KHÔNG có ad SDK (đã xác minh clear-logcat), tài liệu "offline" vẫn đúng.
> **CHƯA làm (đợt sau)**: nhìn mắt telegraph→meteor; 1B (nâng 1 mode B→A); 1C (progression sau-Gold).
> 🚫 chưa commit — user tự commit ([[code-on-main-only]]).

# Phase 1 — Đào sâu 2-3 mode lõi (KHÔNG thêm mode mới)

Hướng user (1): "mode nào chơi vài lần cũng cạn". Tập trung Boss (mode có tiềm năng sâu nhất)
+ 1 mode phụ nhãn B để nâng lên A.

## 1A. Boss — từ "HP cao hơn" sang "đánh khác đi"
Hiện trạng: `bossAttackPatternFor(phase)` chọn block/shuffle/meteor theo 3 phase HP; **meteor chưa
wire** (đã ghi nợ ở [[w23-2-miniboss-complete]] / W24 phase 2 — làm phần wire ở đó, KHÔNG lặp).
Task này là **chiều sâu VƯỢT LÊN việc wire**:
- [ ] **Telegraph đòn**: boss "báo trước" 1 lượt (HUD warning + gem rung vùng sắp bị đánh) → biến
  đòn từ ngẫu nhiên-khó-chịu thành **quyết định đọc-và-né** (đây là thứ tạo chiều sâu, không phải HP).
- [ ] **≥2 loại boss có bộ đòn khác nhau** (không chỉ 1 boss scale HP): vd Boss "màu" (khoá 1 màu
  mỗi phase) vs Boss "bàn" (co hẹp vùng chơi). Chọn theo `bossStage` hoặc theo thế giới.
- [ ] **Điểm yếu động**: màu yếu đổi theo phase (đã có màu yếu tĩnh) → buộc đổi chiến thuật giữa ván.
- [ ] Giữ **invariant thắng-được** (playtest bot vẫn qua ở HP thấp) + `isSideMode` (thua không trừ mạng).

## 1B. Nâng 1 mode B → A (chọn 1: ColorRush hoặc Soda)
Lấy mode "đổi luật cùng vòng lặp" và cho nó **1 quyết định cơ chế thật**:
- [ ] Ví dụ ColorRush: màu nóng không chỉ +điểm mà **thay đổi cách gem rơi/refill** (bias màu nóng)
  → người chơi *tạo* cơ hội thay vì chờ; hoặc Soda: chai nổi mở **vùng no-drop tạm thời** đổi bố cục.
- [ ] Tiêu chí "thành A": bỏ nhánh cơ chế đó ra thì **ván chơi khác hẳn**, không chỉ khác điểm/HUD.

## 1C. Progression nội tại cho mode phụ
- [ ] Mỗi mode phụ có **đường tiến triển riêng** (vd mở biến thể/độ khó mới sau N lần chơi) — hiện chỉ
  có record + Bronze/Silver/Gold ở [[side-mode-isolation]] (`side_mode_records.dart`). Thêm *lý do
  chơi tiếp sau khi đạt Gold*: unlock modifier tự chọn, seed khó hơn, hay "prestige".
- [ ] KHÔNG nối vào unlock campaign (giữ cô lập).

## Acceptance
- [ ] Boss có telegraph + ≥2 bộ đòn phân biệt được bằng mắt; playtest bot vẫn thắng được.
- [ ] 1 mode B đã lên A (mô tả rõ nhánh engine mới trong PR/notes).
- [ ] ≥1 mode phụ có progression sau-Gold; persist + vào `resetProgress`.
- [ ] `flutter analyze` 0 issue · unit test cho selector đòn mới + progression persist · suite xanh.

## Lưu ý
- Boss/Rhythm đụng game loop Flame → rủi ro cao hơn phase khác; tách sub-phase nếu cần.
- Không trùng phần **wire meteor/shuffle** (đó là [[w23-2-miniboss-complete]]); task này thêm
  telegraph + boss-variety + điểm-yếu-động lên trên.
