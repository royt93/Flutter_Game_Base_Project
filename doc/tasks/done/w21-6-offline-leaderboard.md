---
id: w21-6-offline-leaderboard
title: Offline Leaderboard — Bot score tất định cho Campaign + Daily
wave: 21
phase: 6
status: done
owner: claude
---

> ✅ **Implemented 2026-06-26** (verify end-to-end trên Vivo V2352A): engine pure
> `lib/core/leaderboard_engine.dart` + `LeaderboardController`/`LeaderboardScreen` (2 tab
> Chiến dịch/Hằng ngày) + icon Home "BẢNG XẾP HẠNG" + i18n en/vi. 17 test mới, analyze 0,
> full suite 748 pass.
> **Follow-up còn lại:** điểm người chơi tab Daily (cần key `dailyBestScore` + hook finish
> Daily) — hiện Daily chỉ hiện bot + note "hoàn thành Hằng ngày để vào bảng".
---

# Phase 6 — Offline Leaderboard (Bot tất định)

Leaderboard hoàn toàn offline: **bot score tất định** → top 10 đổi mỗi tuần/ngày, không
backend, không tài khoản. Tạo cảm giác "đua hạng" để tăng replay.

## Code grounding (đã verify 2026-06-25)

| Mục | File:line | Ghi chú |
|---|---|---|
| Target score 1 màn | `lib/data/levels.dart:504` `_scorePerMove`, `:507` `_scoreTarget(index, baseMoves)` | base cho bot score; **`_` private** → expose helper public |
| High score người chơi (Campaign) | `core/storage_service.dart:77` `highScore(level)`='hs_$level'; `game_controller.dart:263` `RxMap<int,int> highScores` | nguồn điểm thật người chơi |
| Anti-cheat ngày | `game_controller_economy.dart:48` `_todayEpochDay`, `:56` `_effectiveDay` (maxDay), `:70` `todayEpochDay` (public) | **luôn dùng `todayEpochDay`**, không `DateTime.now` |
| Tuần | `lib/data/tournament.dart:13` `tournamentWeek(epochDay)` | tái dùng |
| **Hạ tầng bot có sẵn** | `tournament.dart:31` `kTournamentBots` (7 bot), `:43` `botScore(week,i,day)` style hash **no-Random** | leaderboard MIRROR style này (KHÁC ngữ cảnh: tournament=điểm-giải, đây=điểm-màn) |
| Mẫu Screen+Controller | `screens/collection_screen.dart:13`, `controllers/collection_controller.dart:11` | StatelessWidget + GetX permanent:false, `Get.isRegistered` guard |
| Icon Home | `screens/home_screen.dart:255-378` (2 row ×5 icon), helper `_circleNav():884` | thêm icon Leaderboard |
| i18n | `core/app_translations.dart:143` `_extraEn`, `:562` `_extraVi`, merge `:96-114` | thêm key, không sửa 22 map |

## Thiết kế (đã sửa theo code thật)

### Engine — `lib/core/leaderboard_engine.dart` (pure Dart, no Random runtime)

⚠️ **Sửa giả định cũ** (`Random(seed)` trong plan gốc): mirror style **hash tất định**
của `tournament.dart:botScore` (không `Random`, tránh khác máy/lệch). Reuse tên bot từ pool
neon mở rộng (tournament chỉ có 7; top-10 cần ≥9 đối thủ).

```dart
// Pool tên neon (proper noun, KHÔNG dịch). Reuse 7 từ kTournamentBots + bổ sung.
const kLeaderboardNames = ['Nova','Zyra','Echo','Lumen','Pyx','Vortex','Glint',
                           'Aster','Quark','Ion','Riff','Myst']; // ≥10

/// Điểm bot hạng [rank] (0-based) cho [baseTarget] màn, seed theo [period]
/// (=epochWeek cho Campaign, =epochDay cho Daily). Tất định, no Random.
int lbBotScore(int baseTarget, int rank, int period) {
  final mix = (period * 2654435761 + rank * 40503) & 0x7fffffff;
  final pct = 0.7 + (mix % 61) / 100.0;          // 0.70..1.30
  final rankFalloff = 1.0 - rank * 0.045;         // hạng thấp điểm giảm dần
  return (baseTarget * pct * rankFalloff).round();
}

String lbBotName(int rank, int period) =>
    kLeaderboardNames[((period * 31 + rank * 7) & 0x7fffffff) % kLeaderboardNames.length];
```

### Campaign Leaderboard
- Chọn level (spinner/slider) → top 10 = 9 bot (`lbBotScore(target(level), rank, epochWeek)`)
  + người chơi (điểm = `highScores[level]`, nếu chưa chơi = 0 → hạng chót).
- `baseTarget = scoreTargetOf(level)` (helper public mới wrap `_scoreTarget`).
- `epochWeek = tournamentWeek(todayEpochDay)` → đổi mỗi tuần.
- Hạng người chơi = số bot mình vượt + 1; tô sáng dòng "BẠN".

### Daily Leaderboard
- Top 10 cho Daily Challenge hôm nay, seed `period = todayEpochDay`.
- `baseTarget` = target của daily seed (daily dùng level theo seed — lấy target tương ứng).
- ⚠️ **Nguồn điểm người chơi daily**: hiện chưa có key. **Thêm** `StorageKeys.dailyBestScore`
  (lưu `epochDay|score`) — ghi khi finish Daily Challenge. Trước khi có điểm → ẩn dòng người
  chơi (chỉ hiện bot) + nhãn "Hoàn thành Daily để xem hạng".

### UI — `LeaderboardScreen` + `LeaderboardController`
- Mirror `CollectionScreen`/`CollectionController` (StatelessWidget + GetX, permanent:false,
  `Get.isRegistered` guard cho test mount độc lập).
- 2 tab: "Chiến dịch" | "Hằng ngày". Campaign tab có level selector.
- Dòng: hạng + tên + điểm; dòng người chơi highlight neon.
- `NeonBg` + `NeonAppBar` (như collection).
- **Không persist gì cho bot** — compute on-the-fly mỗi lần mở.

### Điểm vào (entry)
- Thêm `_circleNav(Icons.leaderboard_rounded, NeonTheme.gold, 'leaderboard_title'.tr, …)`
  vào Home. ⚠️ 2 row icon đang đầy (5+5) → **3 lựa chọn**: (a) thêm row 3; (b) thay 1 icon ít
  dùng; (c) đặt icon nhỏ cạnh level selector trong WorldMap/LevelSelect. → chọn (a) hoặc (c).

## Thứ tự triển khai

1. `leaderboard_engine.dart` (pure) + expose `scoreTargetOf(level)` public trong levels.dart.
2. `storage_service.dart`: `dailyBestScore` key.
3. Ghi `dailyBestScore` khi finish Daily (trong `checkEnd`/daily flow — `game_controller_scoring.dart`).
4. `LeaderboardController` + `LeaderboardScreen` (2 tab).
5. Entry icon ở Home (hoặc WorldMap).
6. i18n keys `_extraEn`+`_extraVi`.
7. Test + `flutter analyze` 0 issue.

## Acceptance criteria

- [ ] `lbBotScore` / `lbBotName` **tất định**: cùng input → cùng output (no Random).
- [ ] `lbBotScore` trong dải hợp lý: ~0.6×–1.3× target của level.
- [ ] Top 10 đổi khi `epochWeek` (Campaign) / `epochDay` (Daily) đổi.
- [ ] Hạng người chơi = số bot vượt + 1; điểm 0 → hạng chót.
- [ ] **Anti-exploit**: bot score KHÔNG ghi disk, KHÔNG ảnh hưởng `highScore` thật.
- [ ] Daily: chưa hoàn thành → ẩn dòng người chơi, không crash.
- [ ] `dailyBestScore` chỉ cập nhật khi điểm cao hơn; dùng `todayEpochDay` (anti-cheat).
- [ ] Widget test: `LeaderboardScreen` mount cả 2 tab (`Get.isRegistered` guard).
- [ ] `flutter analyze` 0 issue.

## Lưu ý
- `epochWeek = tournamentWeek(todayEpochDay)` — nhất quán anti-cheat `_effectiveDay`.
- KHÔNG persist bot — pure compute.
- Liên quan: [[balance-economy-principles]], [[daily-challenge-subsystem]], [[season-league-merge-w18]].
