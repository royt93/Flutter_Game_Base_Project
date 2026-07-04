---
id: w25-3-meta-retention
title: Meta gắn mode phụ — lý do quay lại (không phá cô lập)
wave: 25
phase: 3
status: in-progress
owner: claude
created: 2026-07-02
---

## Tiến độ (2026-07-03) — CODE XONG
- ✅ **Trục điểm side-mode/tuần**: gắn vào `ChallengeCardController` có sẵn (tái dùng hạ tầng weekIdx/
  reset thay vì tạo controller mới) — `sideWeeklyPoints`/`sideMilestoneClaimed`, 3 mốc thưởng xu
  (60/120/220), guard-key ghi TRƯỚC khi cộng xu. Hook `addSideModePoints` gọi cho MỌI side-mode kết
  thúc (kể cả Daily/Versus/Puzzle/Zen không có record) trong `game_screen_controller.dart`.
- ✅ **Quest xoay theo mode — phát hiện đã có sẵn** qua `ChallengeCardController` (W20.3, thẻ playMode
  xoay 7 mode/tuần). **Nâng cấp thêm** (user chốt): thẻ thứ 3 tuần lẻ đổi thành quest kỹ năng
  `ChallengeType.reachRecordTier` — dựa lifetime record (`SideModeRecordController.tierOf`), phủ
  thêm Survival/Labyrinth (2 mode playMode chưa cover), tự "done" nếu người chơi đã đủ trình.
- ✅ **Mốc Platinum + danh hiệu**: `RecordTier.platinum` (enum mới, generic hoá sẵn nên chỉ cần thêm
  ngưỡng/thưởng, không sửa vòng lặp `recordResult`), 3 achievement `platinum_1/4/9` (đeo được qua
  `equipTitle()` có sẵn — danh hiệu = achievement id, không cần hệ UI mới).
- ✅ **Liên kết Progression Tree + Battle Pass**: node `ascendant` (platinumCost:3, hiệu ứng particle
  cosmetic cao nhất) + `BattlePassController.grantBonusXp()` (bonus XP nhỏ khi claim mốc tuần, tách
  biệt hoàn toàn khỏi gate `!isSideMode` của `recordLevelEnd` — không đụng công thức lên cấp).
- ✅ i18n: `_w253ByLang` (20 ngôn ngữ) + bổ sung `_extraEn`/`_extraVi` cho 10 key mới.
- ✅ Test mới `test/w25_3_side_meta_test.dart` (11 case: platinum tier, điểm/tuần, guard-key, tuần cũ
  reset, quest kỹ năng, liên kết PT/BP, resetProgress). Sửa 5 test cũ lỗi thời do đổi số lượng cố định
  (kPtNodes 3→4 node, lock icon count, LinearProgressIndicator count, tierFor/thresholdFor thêm bậc).
- ✅ `flutter analyze` 0 · full suite (exclude slow) **949 passed**, không regression.
- Không đụng win-streak/level-unlock/lives ([[side-mode-isolation]]) — mọi thưởng mới qua trục RIÊNG
  (`ChallengeCardController`), review kỹ tại điểm hook trong `game_screen_controller.dart`.
- Không cần device (thuần data/controller, không đụng engine) — đúng lưu ý gốc của task.
- **W25-3 (Wave 26 Phase 3) HOÀN TẤT** — sẵn sàng để user tự commit.

# Phase 3 — Cho mode phụ một "vì sao chơi lại"

Hướng user (4): "meta/phần thưởng nhạt, lý do quay lại yếu". Hiện side mode **cô lập hoàn toàn**
khỏi progression ([[side-mode-isolation]]) — tốt cho chống-farm nhưng khiến mode phụ **cụt vòng
tiến triển**: chơi xong không "dẫn tới đâu". Task này thêm trục nuôi **RIÊNG cho side mode**, KHÔNG
nối vào win-streak / unlock campaign / lives.

## Việc
- [ ] **Trục thưởng side-mode riêng**: 1 đường "điểm side-mode/tuần" (tách hẳn Mùa giải campaign) →
  mốc thưởng xu/booster. Đọc `todayEpochDay`/`_effectiveDay` (anti-cheat), reset tuần.
- [ ] **Quest xoay theo mode**: "tuần này chơi Survival đạt tầng X" / "ColorRush streak ×3" → thưởng.
  Buộc *luân phiên* mode thay vì chỉ cày 1 mode → khám phá hết bề rộng đã có.
- [ ] **Mốc record sâu hơn**: trên Bronze/Silver/Gold hiện có (`side_mode_records.dart`) thêm mốc
  **Platinum + danh hiệu đeo được** (tái dùng hệ danh hiệu W18.2) — phần thưởng "khoe" không p2w.
- [ ] **Liên kết Progression Tree / Battle Pass**: cho phép 1 nhánh nhỏ tiến bằng thành tích side-mode
  (nếu không phá cân bằng) → side mode "đóng góp" vào meta mà vẫn không đụng campaign progress.

## Acceptance
- [ ] Trục side-mode/tuần hoạt động; thắng side mode KHÔNG đổi win-streak/level-unlock/lives (test).
- [ ] Thưởng 1 lần/mốc (guard-key TRƯỚC — [[currency-persistence-convention]]); không re-claim khi
  restart; mọi key vào `resetProgress` + `resetState()` ([[reset-permanent-controllers]]).
- [ ] Quest xoay đọc thời gian qua `_effectiveDay` (không `DateTime.now()` trực tiếp).
- [ ] `flutter analyze` 0 · unit test (mốc 1 lần + reset + anti-cheat ngày) · suite xanh.

## Lưu ý
- ⚠️ Dễ vô tình phá [[side-mode-isolation]] — mọi hook thưởng phải qua trục RIÊNG, review kỹ.
- Thuần offline + data/controller (không đụng engine) → làm được không cần device.
- Cân bằng faucet theo [[balance-economy-principles]] — thêm sink nếu tăng nguồn xu.
