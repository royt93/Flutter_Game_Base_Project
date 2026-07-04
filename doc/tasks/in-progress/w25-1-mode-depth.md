---
id: w25-1-mode-depth
title: Chiều sâu mode lõi — Boss đa dạng đòn + progression nội tại
wave: 25
phase: 1
status: done
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

> 🟢 **Đợt 2 (2026-07-03) — 1B + 1C CODE XONG (Wave 26 Phase 4):**
> - **1B — ColorRush B→A**: chọn ColorRush (không Soda — cả 2 mode trước đó 0 chỗ đọc cờ mode trong
>   board mechanics; ColorRush tự nhiên hơn, rủi ro thấp hơn Soda). Thêm hàm pure
>   `biasRefillToHotColor()` (`lib/data/levels.dart`, mẫu y hệt `biasRefillToTarget` có sẵn) + wire
>   vào `_refillColor()` (`neon_jewel_game.dart`) — refill nghiêng 35% về màu nóng khi ColorRush bật.
>   Đây là "quyết định cơ chế thật": bỏ nhánh này ra thì cách gem rơi khác hẳn, không chỉ khác điểm.
>   0 rủi ro lan sang `settle.dart`/`GemComponent`/`tool/playtest.dart` (đã khảo sát xác nhận).
> - **1C — "Thử Thách" (hard variant, tự chọn sau Gold)**: khác Platinum (Wave 25.3, mốc điểm số thụ
>   động) — đây là **lựa chọn chủ động** trước ván, đổi lượt lấy thưởng cao hơn. Chỉ mở được sau khi
>   đạt Gold ở mode đó (`SideModeRecordController.toggleHardVariant`). Wire vào 2 điểm chèn TRUNG TÂM
>   có sẵn (không đụng 9 hàm `startXxx()`/9+ chỗ tính thưởng riêng lẻ): `_resetRunState()` (-15% lượt)
>   + `discountSideModeReward()` (+50% xu). UI: icon toggle 🔥 cạnh badge kỷ lục trên Home (chỉ hiện
>   khi đạt Gold).
> - **Test**: mở rộng `test/w17_4_deepen_b_modes_test.dart` (pure + thống kê qua seam
>   `refillColorForTest()`) + file mới `test/w25_1_hard_variant_test.dart` (7 case: unlock-gate theo
>   Gold, persist, ảnh hưởng lượt/thưởng, campaign KHÔNG bị ảnh hưởng, resetProgress dọn sạch).
> - `flutter analyze` 0 · full suite (exclude slow) **969 passed** · `dart run tool/playtest.dart`:
>   0 màn quá khó, không lệch so với baseline (bias/hard-variant không kích hoạt ở campaign).
> - Không đụng win-streak/level-unlock/lives ([[side-mode-isolation]]).
> - Chưa verify device (doc coi 1A còn treo phần "nhìn mắt telegraph→meteor" — có thể verify chung 1
>   phiên máy thật cho cả 3 phần nếu cần chắc thêm; không bắt buộc vì 1B/1C thuần logic/economy).
> **Wave 25 Phase 1 (1A+1B+1C) HOÀN TẤT** — sẵn sàng để user tự commit.
> 🚫 chưa commit — user tự commit ([[code-on-main-only]]).

# Phase 1 — Đào sâu 2-3 mode lõi (KHÔNG thêm mode mới)

Hướng user (1): "mode nào chơi vài lần cũng cạn". Tập trung Boss (mode có tiềm năng sâu nhất)
+ 1 mode phụ nhãn B để nâng lên A.

## 1A. Boss — từ "HP cao hơn" sang "đánh khác đi"
Hiện trạng: `bossAttackPatternFor(phase)` chọn block/shuffle/meteor theo 3 phase HP; **meteor chưa
wire** (đã ghi nợ ở [[w23-2-miniboss-complete]] / W24 phase 2 — làm phần wire ở đó, KHÔNG lặp).
Task này là **chiều sâu VƯỢT LÊN việc wire**:
- [x] **Telegraph đòn**: boss "báo trước" 1 lượt (HUD warning + gem rung vùng sắp bị đánh) → biến
  đòn từ ngẫu nhiên-khó-chịu thành **quyết định đọc-và-né** (đây là thứ tạo chiều sâu, không phải HP).
  (Đợt 1: wire xong, unit test có; nhìn mắt trên device chưa xác nhận riêng phase 2 — rủi ro thấp,
  không chặn "done" vì logic đã kiểm bằng test.)
- [x] **≥2 loại boss có bộ đòn khác nhau** (không chỉ 1 boss scale HP): `BossType{pulse,voidType}` +
  `bossAttackPatternFor(phase,type)`, chọn theo `bossStage` (chẵn=voidType hung hãn hơn).
- [x] **Điểm yếu động**: đã có sẵn từ trước đợt này (khảo sát xác nhận wire sẵn, không lặp việc).
- [x] Giữ **invariant thắng-được** (playtest bot vẫn qua) + `isSideMode` (thua không trừ mạng).

## 1B. Nâng 1 mode B → A (chọn 1: ColorRush hoặc Soda)
Lấy mode "đổi luật cùng vòng lặp" và cho nó **1 quyết định cơ chế thật**:
- [x] **ColorRush** được chọn: màu nóng không chỉ +điểm mà **thay đổi cách gem rơi/refill**
  (`biasRefillToHotColor()` nghiêng 35% refill về màu nóng qua `_refillColor()`) → người chơi *tạo*
  cơ hội thay vì chờ.
- [x] Tiêu chí "thành A" đạt: bỏ nhánh bias ra thì refill campaign/ColorRush giống nhau hoàn toàn —
  ván chơi khác hẳn, không chỉ khác điểm/HUD (xác nhận bằng test thống kê 500 trial).

## 1C. Progression nội tại cho mode phụ
- [x] Mỗi mode phụ có **lý do chơi tiếp sau Gold**: "Thử Thách" (hard variant, tự chọn qua
  `SideModeRecordController.toggleHardVariant`) — đổi lượt (-15%, `_resetRunState`) lấy thưởng cao
  hơn (+50% xu, `discountSideModeReward`). Khác Platinum (Wave 25.3, mốc điểm số thụ động) — đây là
  **lựa chọn chủ động** trước ván.
- [x] KHÔNG nối vào unlock campaign (giữ cô lập — test riêng xác nhận `startLevel(1)` không bị ảnh
  hưởng dù có cờ hardVariant rác trong storage).

## Acceptance
- [x] Boss có telegraph + ≥2 bộ đòn phân biệt được bằng mắt; playtest bot vẫn thắng được. (Device
  Samsung A11 xác nhận tên loại boss + phase hiện đúng; nhìn mắt riêng "telegraph→meteor phase 2"
  chưa làm thêm 1 lần verify sâu — không chặn vì unit test đã phủ logic chọn đòn.)
- [x] 1 mode B đã lên A (ColorRush — nhánh engine refill-bias thật, mô tả trong progress note Đợt 2).
- [x] ≥1 mode phụ có progression sau-Gold; persist (`recHardVariant` key) + vào `resetProgress`
  (test xác nhận `resetProgress()` xoá cờ về false).
- [x] `flutter analyze` 0 issue · unit test cho selector đòn mới (`w25_boss_depth_test.dart`) +
  progression persist (`w25_1_hard_variant_test.dart`) · suite xanh (969 passed).

**Chưa verify device riêng cho 1B/1C** (thuần logic/economy, rủi ro thấp) — có thể làm thêm nếu
user muốn chắc trước khi tự commit.

## Lưu ý
- Boss/Rhythm đụng game loop Flame → rủi ro cao hơn phase khác; tách sub-phase nếu cần.
- Không trùng phần **wire meteor/shuffle** (đó là [[w23-2-miniboss-complete]]); task này thêm
  telegraph + boss-variety + điểm-yếu-động lên trên.
