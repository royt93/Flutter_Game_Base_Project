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

### 🎯 Khu THỬ THÁCH — 10 chế độ phụ + 1 PvP

Các chế độ **không tốn mạng, không đụng tiến trình campaign** (cô lập qua `isSideMode`). Lưới 2 hàng (5 + 6 ô).

> **Ghi chú trung thực (audit code):** toàn game dùng **một engine match-3 duy nhất**. Mức khác biệt thật của mỗi mode được gắn nhãn:
> 🟢 **A** = đổi CƠ CHẾ (engine xử lý khác) · 🟡 **B** = đổi LUẬT/mục tiêu nhưng cùng vòng lặp · 🔴 **C** = gần như reskin (chỉ đổi target/HUD).

| # | Mode | Hàm | Khác biệt thật | Loại |
|---|------|-----|----------------|------|
| 1 | **Trùm Neon** | `startBoss(stage)` | Thanh máu boss; clear gem gây sát thương (màu yếu/combo ×2); boss phản đòn rút lượt | 🟢 A |
| 2 | **Trọng lực** | `startGravity()` | Mỗi 5 lượt engine **lật ngược cả bàn** (gem+obstacle+jelly) | 🟢 A |
| 3 | **Nhịp điệu** | `startRhythm()` | Đồng hồ nhịp BPM; ghép đúng beat → groove → điểm ×1.5–2.5 | 🟢 A |
| 4 | **2 người** | `VersusScreen` | 2 bàn song song; combo ≥3 gửi **gem rác** sang đối thủ; mirror seed | 🟢 A |
| 5 | **Cấu đố** | `startPuzzle(def)` | **KHÔNG refill** (bàn hữu hạn) + bàn seed cố định + ngân sách lượt chặt; 8 cấu đố mở khoá dần, sao theo hiệu suất. Đảm bảo giải được (test greedy) | 🟢 A |
| 6 | **Vô tận** | `startEndless()` | Ghép ≥4/≥5 **hoàn lượt** → chơi vô hạn; **sự kiện mỗi 5 stage** (+lượt / ×2 điểm / mưa gem) | 🟡 B |
| 7 | **Quét màu** | `startColorRush()` | Màu "nóng" xoay mỗi 4 lượt; clear màu đó +15đ/gem × **streak ×1→×3** | 🟡 B |
| 8 | **Nước dâng (Soda)** | `startSoda()` | Mỗi clear +1 fill; đủ 20 fill nổi 1 chai; **vòi phun +5 fill mỗi 5 lượt** | 🟡 B |
| 9 | **Sinh tồn** | `startSurvival()` | Mực nước **Rising Tide** dâng mỗi N lượt; clear gem đẩy lùi nước; thua khi nước phủ toàn bàn; HUD tide-indicator riêng | 🟢 A |
| 10 | **Mê cung** | `startLabyrinth()` | **Tường di động** thay đổi hình dạng bàn mỗi lượt + **fog-of-war** ẩn vùng tường; lưới không cố định | 🟢 A |
| 11 | **Hằng ngày** | `startDaily()` | Bàn seed theo ngày + **mutator xoay ngày** (4 màu / ít lượt / ×2 combo / vô special / +lượt) + thưởng/streak 1 lần/ngày | 🟡 B |

> 🏅 **Kỷ lục & cột mốc (W19.1):** 8 mode (trừ Daily/Versus) có kỷ lục cá nhân (best-stage / best-score / số lần thắng) + 3 mốc **Bronze/Silver/Gold** (badge trên card Home + thưởng nhỏ xu, nhận 1 lần). Tạo lý do chơi lại — `lib/data/side_mode_records.dart`.
> Đa dạng gameplay LỚN NHẤT vẫn nằm ở **Campaign** (bom đếm ngược, băng chuyền, cổng, dispenser, chocolate lan, jam, cage, tường, gravity-stream). **Hết mode 🔴 C** — Daily đã thành Mutator mode (🟡 B), thêm Cấu đố (🟢 A). Còn lại là refactor PHẦN THƯỞNG (xem `doc/tasks/todo/w18-*.md`).

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

> ✅ **W18.1 đã xong — gộp Giải đấu + Sự kiện mùa thành "Mùa giải":** 1 đường điểm/tuần nuôi **2 trục thưởng KHÔNG trùng** — trục **MỐC** (6 ngưỡng → xu/booster) + trục **HẠNG** (đua 7 bot tất định → thưởng hạng). Hết cảnh "1 thắng đẩy 2 thanh điểm". Migrate an toàn (reuse key cũ → cờ đã-nhận được tôn trọng, chống nhận-lại-thưởng). 1 màn `SeasonLeagueScreen` thay 2 màn cũ.
> ✅ **W18.4 đã xong:** khu thưởng chỉ còn ô kinh tế, Hướng dẫn + Cài đặt tách ra hàng **"Tiện ích"** riêng.
> ✅ **W18.2 đã xong — khác-biệt-hoá Album & Thành tựu:** Album = **vật sưu tập** (sticker KHÔNG còn thưởng xu lặp) + hoàn tất bộ → **skin gem độc quyền + xu 1 lần**; Thành tựu = giữ xu + thêm **DANH HIỆU đeo được** (hiện dưới logo Home). Hết cảnh "2 hệ claim-mốc-xu na ná".
> ✅ **W18.3 đã xong — coin-sink:** thêm **nâng cấp booster vĩnh viễn** ở Cửa hàng (Búa → phá 3×3 · +Lượt 10→15), mua 1 lần bằng xu (đắt, hút xu dư) — non-p2w, cân bằng faucet. **🎉 Hết toàn bộ kế hoạch W18 (4/4) + W17/W19.**

### 🔧 Tiện ích (KHÔNG phải phần thưởng)
Hàng **"Tiện ích"** riêng dưới khu Phần thưởng (W18.4 — hết bị nhầm là thưởng):
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
