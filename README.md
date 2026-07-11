# ⭐ Pop Star Blast

Game **tap-to-pop** kiểu PopStar!, style **bright-casual** (candy), viết bằng
**Flutter + Flame + GetX**.
© Saigon Phantom Labs · Logic thuần Dart (testable) · 22 ngôn ngữ · 200 màn.

> Fork & viết lại hoàn toàn từ game match-3 "Neon Jewels" cũ.
> Tính năng & lịch sử: [`doc/feat.md`](doc/feat.md) · Kế hoạch Scrum: [`doc/task/`](doc/task).

---

## 🎮 Cách chơi

- Tap 1 nhóm **≥2 ô cùng màu liền kề** → cả nhóm nổ.
- Điểm mỗi lần nổ: **`5 × n × (n−1)`** (n = số ô) — nhóm càng to càng lời.
- Ô phía trên rơi xuống lấp chỗ trống; cột rỗng dồn sang trái. **Không refill** từ trên.
- Màn kết thúc khi bàn **kẹt** (không còn nhóm ≥2) hoặc **sạch** (thưởng lớn).
- Đạt/vượt **target score** để thắng và ăn **1–3 sao**.
- Dọn sạch bàn: bonus **+1000**.

## 🧰 Booster (mua bằng xu)

| Booster | Giá | Tác dụng |
|---------|-----|----------|
| 💣 Bomb | 60 | Nổ vùng 3×3 |
| 🔀 Shuffle | 40 | Xáo lại màu các ô còn lại |
| ↩️ Undo | 30 | Hoàn tác 1 bước |

Xu thưởng theo sao (sao × 20) khi thắng.

## 📱 Màn hình

Home · Level Select (200 màn, mở khoá tuần tự) · Game · Shop · Guide · Settings
(âm thanh + 22 ngôn ngữ + reset tiến trình).

## 🏗️ Kiến trúc (4 lớp, tách bạch)

1. **`lib/logic/`** — Dart thuần, testable: `pop_detector.dart` (flood-fill nhóm),
   `pop_collapse.dart` (gravity + dồn cột).
2. **`lib/data/`** — `levels.dart` (`PopLevel`, `kLevels`, công thức điểm/target).
3. **`lib/game/`** — Flame: `pop_star_game.dart` (tap → pop → animation → collapse),
   `block_component.dart` (ô kẹo bóng).
4. **`lib/presentation/`** — GetX: `game_controller.dart`, `game_screen_controller.dart`,
   6 screen, widget neon/casual dùng chung.

Chi tiết & quy ước: [`CLAUDE.md`](CLAUDE.md).

## 🛠️ Lệnh thường dùng

```bash
flutter test --exclude-tags slow   # unit + widget
flutter analyze                    # phải 0 issue
flutter run -d <device-id>
flutter build apk --debug
```

Package: `com.galaxyjoy.pop_star_blast` (Android) · `com.galaxyjoy.popStarBlast` (iOS).
