# 💎 Neon Jewels

Game **match-3** phong cách neon, viết bằng **Flutter + Flame + GetX**.
© Saigon Phantom Labs · Engine match-3 thuần Dart (testable), 22 ngôn ngữ, 150 màn / 8 thế giới.

> Tài liệu chi tiết tính năng & lịch sử phát triển: [`doc/feat.md`](doc/feat.md).
> Trạng thái task: [`doc/tasks/`](doc/tasks/) (done / in-progress / todo).

---

## 🏠 Màn hình Home gồm 3 khối

### ▶️ Nút "CHƠI NGAY" — Chế độ Chiến dịch (Campaign)

Mở **Bản đồ thế giới** (`WorldMapScreen`) — hoặc **lưới màn** (`LevelSelectScreen`) nếu bật chế độ xem dạng grid. Đây là **mạch chơi chính**:

- **150 màn** chia **8 thế giới** (Tinh Vân Lam → Neon Apex).
- Xoay vòng **6 loại mục tiêu**: Điểm số · Thu thập màu · Tính giờ · Dọn jelly · Đưa gem xuống (drop) · Dọn chướng ngại.
- **Tier độ khó** (Wave 16): Normal ~70% · Hard ~25% (⚡) · Super-Hard ~5% (🔥, cuối mỗi thế giới) + nhịp **răng cưa** (màn "nghỉ" relief sau đỉnh).
- Có **cốt truyện** (story intro/mid), **tốn mạng**, **win-streak**, mở khoá tuần tự, **DDA/pity** (trợ giúp ẩn khi thua liên tiếp).

> Các cơ chế bàn: trượt chéo, Gravity Streams (trọng lực theo ô), bàn không-chữ-nhật (tường/lỗ), gem nhốt (cage), băng chuyền, cổng, dispenser, jelly/soda/jam/licorice, dead-zone & bottleneck…

---

### 🎯 Khu THỬ THÁCH — 10 chế độ phụ

Các chế độ **không tốn mạng, không đụng tiến trình campaign** (cô lập qua `isSideMode`). Lưới 2 hàng × 5:

| # | Mode | Hàm khởi động | Mô tả |
|---|------|---------------|-------|
| 1 | **Hằng ngày** | `startDaily()` | Câu đố seed theo ngày, thưởng 1 lần/ngày, có chuỗi streak 🔥 |
| 2 | **Vô tận** | `startEndless()` | Chơi vô hạn, stage tăng theo điểm, lưu high-score |
| 3 | **Trùm Neon** | `startBoss(stage)` | Đấu boss có máu; combo lớn + trúng "điểm yếu màu" gây sát thương ×2; boss phản đòn |
| 4 | **Quét màu** | `startColorRush()` | Color Rush — dồn clear 1 màu trong thời gian |
| 5 | **Trọng lực** | `startGravity()` | Hướng trọng lực thay đổi động |
| 6 | **Nhịp điệu** | `startRhythm()` | Ghép theo nhịp (BPM 100, cửa sổ ±0.14s), thanh groove |
| 7 | **2 người** | `VersusScreen` | Versus/Co-op 1 máy: 2 bàn song song, junk-gem tấn công, mirror seed (công bằng) |
| 8 | **Nước dâng (Soda)** | `startSoda()` | Soda fill-based — clear gem để chai/nước nổi lên |
| 9 | **Sinh tồn** | `startSurvival()` | Đua thời gian, clear để +giây, lưu kỷ lục `survivalHigh` |
| 10 | **Mê cung** | `startLabyrinth()` | Bàn mê cung tường, đưa gem xuống đích qua khe hẹp |

---

### 🎁 Khu PHẦN THƯỞNG — 10 mục meta / tiện ích

Hệ thống "giữ chân" + tiện ích. Lưới 2 hàng × 5:

| # | Mục | Màn | Mô tả |
|---|-----|-----|-------|
| 1 | **Đền Neon** | `TempleScreen` | Meta xây tier bằng **tiêu xu** (chi phí ×10/tier) để nhận thưởng |
| 2 | **Battle Pass** | `BattlePassScreen` | Tích XP qua chơi → claim phần thưởng theo bậc (badge khi có quà) |
| 3 | **Sự kiện mùa** | `SeasonScreen` | Điểm theo mùa (keyed tuyệt đối chống chỉnh giờ), claim mốc |
| 4 | **Cửa hàng** | `ShopScreen` | Mua skin gem / theme bằng xu; trang bị qua `ActiveCosmetics` |
| 5 | **Album** | `CollectionScreen` | Bộ sưu tập — tích điểm thắng, claim mốc |
| 6 | **Heo đất** | `PiggyScreen` | Heo tiết kiệm xu (có cap); đạt min → đập nhận xu |
| 7 | **Giải đấu** | `TournamentScreen` | Bảng xếp hạng theo tuần, claim 1 lần/tuần, đổi tuần reset điểm |
| 8 | **Thành tựu** | `AchievementsScreen` | Achievements + mô tả, badge khi có thưởng chưa nhận |
| 9 | **Hướng dẫn** | `GuideScreen` | User-guide: cơ chế, booster, từng chế độ phụ |
| 10 | **Cài đặt** | `SettingsScreen` | Âm thanh, ngôn ngữ, chế độ xem (map/grid), reset tiến trình… |

> **Top bar** còn có: ❤️ **Mạng** (hồi theo thời gian, mua đầy bằng xu) · 💰 **Xu** · 🎁 **Quà hằng ngày** (chuỗi 7 ngày 20→110) · 🎰 **Vòng quay may mắn**.

---

## 🧱 Kiến trúc & công nghệ

- **Flutter** UI + **Flame** game engine (bàn match-3) + **GetX** (state/DI/route).
- **Engine settle thuần Dart** (`lib/logic/`) — wall + trượt chéo + flow + no-drop, **test được không cần Flame**.
- **i18n** 22 ngôn ngữ qua lớp merge (`_extraEn/_extraVi` + `_w*ByLang`); font **Baloo2** (đủ dấu tiếng Việt).
- **GameController** 1 class tách `part`/`extension` qua 8 file (scoring/modes/progress…).
- **Auto-playtest** bot Monte Carlo (`tool/playtest.dart`) validate đường cong độ khó.
- Render: **Impeller/Vulkan**. Phiên bản đọc từ `pubspec` (`package_info_plus`), không hardcode.
- **Không** quảng cáo / cross-promo / IAP trong code (thuần offline).

## 🚀 Chạy & kiểm thử

```bash
flutter pub get
flutter run                  # chạy trên thiết bị/emulator
flutter test                 # 402 test (unit + widget + integration)
flutter analyze              # 0 issue
dart run tool/playtest.dart  # mô phỏng bot validate độ khó
```

## 📂 Cấu trúc thư mục chính

```
lib/
  core/          # theme, storage, i18n, utils, app_info
  data/          # levels.dart (150 màn, tier, layout), story
  logic/         # engine thuần Dart: settle, match, board, rhythm, versus
  game/          # NeonJewelGame (Flame): render + tương tác bàn
  presentation/
    controllers/ # GameController (+8 part/extension), meta controllers
    screens/     # home, world_map, level_select, game, shop, ...
    widgets/     # neon_bg, neon_dialog, lucky_wheel_view, ...
doc/             # feat.md (tài liệu tính năng) + tasks/ (done/todo)
test/            # *_test.dart theo từng Wave
tool/playtest.dart
```
