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

### 🎯 Khu THỬ THÁCH — 9 chế độ phụ + 1 PvP

Các chế độ **không tốn mạng, không đụng tiến trình campaign** (cô lập qua `isSideMode`). Lưới 2 hàng × 5.

> **Ghi chú trung thực (audit code):** toàn game dùng **một engine match-3 duy nhất**. Mức khác biệt thật của mỗi mode được gắn nhãn:
> 🟢 **A** = đổi CƠ CHẾ (engine xử lý khác) · 🟡 **B** = đổi LUẬT/mục tiêu nhưng cùng vòng lặp · 🔴 **C** = gần như reskin (chỉ đổi target/HUD).

| # | Mode | Hàm | Khác biệt thật | Loại |
|---|------|-----|----------------|------|
| 1 | **Trùm Neon** | `startBoss(stage)` | Thanh máu boss; clear gem gây sát thương (màu yếu/combo ×2); boss phản đòn rút lượt | 🟢 A |
| 2 | **Trọng lực** | `startGravity()` | Mỗi 5 lượt engine **lật ngược cả bàn** (gem+obstacle+jelly) | 🟢 A |
| 3 | **Nhịp điệu** | `startRhythm()` | Đồng hồ nhịp BPM; ghép đúng beat → groove → điểm ×1.5–2.5 | 🟢 A |
| 4 | **2 người** | `VersusScreen` | 2 bàn song song; combo ≥3 gửi **gem rác** sang đối thủ; mirror seed | 🟢 A |
| 5 | **Vô tận** | `startEndless()` | Ghép ≥4/≥5 **hoàn lượt** → chơi vô hạn, stage tăng dần | 🟡 B |
| 6 | **Quét màu** | `startColorRush()` | Màu "nóng" xoay mỗi 4 lượt; clear màu đó **+15đ/gem** | 🟡 B |
| 7 | **Nước dâng (Soda)** | `startSoda()` | Mỗi clear +1 fill; đủ 20 fill nổi 1 chai (objective riêng) | 🟡 B |
| 8 | **Sinh tồn** | `startSurvival()` | ⚠️ Hiện = **TimeAttack đổi tên** (target vô cực); engine chưa đọc `isSurvival` | 🔴 C |
| 9 | **Mê cung** | `startLabyrinth()` | ⚠️ Hiện = **DropDown + 1 layout tường** (cơ chế chung với màn campaign 103/127) | 🔴 C |
| 10 | **Hằng ngày** | `startDaily()` | ⚠️ Hiện = **chọn lại 1 objective campaign** + seed bàn theo ngày + thưởng/streak | 🔴 C |

> Đa dạng gameplay LỚN NHẤT thực ra nằm ở **Campaign** (bom đếm ngược, băng chuyền, cổng, dispenser, chocolate lan, jam, cage, tường, gravity-stream — gắn theo chỉ số màn). 3 mode 🔴 C đang chờ nâng cấp cơ chế riêng (xem `doc/tasks/todo/`).

---

### 🎁 Khu MỤC TIÊU & PHẦN THƯỞNG — 8 hệ meta

Hệ thống "giữ chân". **Toàn bộ progression chạy qua `_onGameEnd`**; chế độ phụ bị loại (`isSideMode`), 3 hệ (Album/Heo/Giải đấu) còn yêu cầu `lastFirstClear` (chống farm).

| # | Mục | Màn | Vào (earn) | Ra (reward/sink) |
|---|-----|-----|------------|------------------|
| 1 | **Đền Neon** | `TempleScreen` | — | **Tiêu xu** xây tier (sink dài hạn) |
| 2 | **Cửa hàng** | `ShopScreen` | — | **Tiêu xu** mua skin/theme (sink, không ảnh hưởng chơi) |
| 3 | **Battle Pass** | `BattlePassScreen` | XP từ **quest ngày** | Xu **+ booster độc quyền** (nguồn chính) |
| 4 | **Sự kiện mùa** | `SeasonScreen` | Điểm **mỗi khi thắng** | Xu + booster, reset 7 ngày |
| 5 | **Album** | `CollectionScreen` | Điểm thắng **first-clear** | Xu/booster + sticker vĩnh viễn |
| 6 | **Heo đất** | `PiggyScreen` | Xu tự bỏ ống khi thắng | Đập (≥120) → vào ví (net dương) |
| 7 | **Giải đấu** | `TournamentScreen` | Điểm thắng first-clear | Xu theo hạng (đua 7 bot offline), reset tuần |
| 8 | **Thành tựu** | `AchievementsScreen` | Tự đạt theo chỉ số lifetime | Xu |

> ⚠️ **Chồng chéo đã ghi nhận (audit):** Sự kiện mùa · Giải đấu · Album · Thành tựu trùng ~70% khuôn "thắng → tích điểm → claim mốc"; 1 lần thắng đẩy đồng thời nhiều thanh điểm. Kinh tế lệch về **faucet** (chỉ Đền Neon + Cửa hàng là sink xu). Kế hoạch gộp/khác-biệt-hoá ở `doc/tasks/todo/`.

### 🔧 Tiện ích (KHÔNG phải phần thưởng)
Nằm chung lưới Home nhưng là tiện ích thuần:
- **Hướng dẫn** (`GuideScreen`) — giải thích luật, booster, từng chế độ.
- **Cài đặt** (`SettingsScreen`) — âm thanh, ngôn ngữ, chế độ xem map/grid, reset tiến trình.

> **Top bar:** ❤️ **Mạng** (hồi theo thời gian, mua đầy bằng xu) · 💰 **Xu** · 🎁 **Quà hằng ngày** (7 ngày 20→110) · 🎰 **Vòng quay may mắn**.

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
