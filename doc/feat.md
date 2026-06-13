# 💎 NEON JEWELS — Game Kim Cương Match-3 Style Neon

> Tài liệu kế hoạch & theo dõi tính năng (single source of truth).
> Tham khảo: [Jewels Legend - Match 3 Puzzle](https://play.google.com/store/apps/details?id=com.linkdesks.jewellegend)
> Stack: **Flutter** + **GetX** ([get](https://pub.dev/packages/get)) + **Flame** ([flame](https://pub.dev/packages/flame))
> Target: Android + iOS

---

## 0. Đánh giá khả thi (Feasibility) — ✅ KHẢ THI

| Tiêu chí | Đánh giá | Ghi chú |
|---|---|---|
| Flutter build Android + iOS | ✅ Rất khả thi | Flutter là cross-platform gốc, 1 codebase ra 2 nền tảng |
| Match-3 engine | ✅ Khả thi | Logic lưới (grid) + match detection là bài toán đã được giải kỹ, không cần Flame cho phần logic |
| Style neon, hiệu ứng rực rỡ | ✅ Khả thi | Flame hỗ trợ particle, shader, sprite animation, glow; Flutter hỗ trợ `BackdropFilter`, `Glow`, gradient |
| Dùng GetX | ✅ Phù hợp | Quản lý state, routing, DI, dialog — gọn nhẹ cho game casual |
| Dùng Flame | ✅ Phù hợp (có lưu ý) | Dùng cho render board + particle effects; phần UI menu nên dùng Flutter widget thuần |
| Hiệu năng 60fps trên mobile | ✅ Đạt được | Cần tối ưu particle pool + object pooling |
| Thời gian dev (1 dev) | 🟡 Trung bình | MVP chơi được: ~2-3 tuần; bản hoàn chỉnh nhiều mode: ~2-3 tháng |

**Kết luận:** Hoàn toàn khả thi. Rủi ro chính KHÔNG nằm ở kỹ thuật mà ở **content** (thiết kế 100+ level cân bằng độ khó) và **asset đồ họa neon** (sprite, particle, âm thanh). Khuyến nghị: làm MVP 1 mode + 20 level trước, rồi mở rộng.

### ⚠️ Lưu ý kiến trúc quan trọng
- **Flame KHÔNG bắt buộc cho match-3.** Nhiều game match-3 Flutter dùng widget thuần. Nhưng vì yêu cầu "hiệu ứng sinh động, neon rực rỡ", Flame giúp render particle/explosion mượt hơn nhiều.
- **Phân tách rõ:** Logic game (pure Dart, testable) ⟷ Render (Flame) ⟷ UI/State (GetX). Tránh nhét logic vào Flame component.
- **Decision:** Dùng **hybrid** — Flame `GameWidget` cho board + hiệu ứng; Flutter widget + GetX cho menu/HUD/dialog/map.

---

## 1. Tech Stack & Dependencies

```yaml
# pubspec.yaml (dự kiến)
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.6              # state management, routing, DI, snackbar/dialog
  flame: ^1.18.0          # game engine: render board, particle, animation
  flame_audio: ^2.10.0    # SFX & nhạc nền
  audioplayers: ^6.0.0    # fallback audio (nếu cần)
  shared_preferences: ^2.2.0  # lưu progress, settings, high score
  google_fonts: ^6.2.0    # font neon (Orbitron, Audiowide...)
  flutter_animate: ^4.5.0 # animation UI menu (glow, shimmer)
```

> Phiên bản sẽ chốt chính xác khi `flutter pub add`. Flutter SDK hiện tại: **3.35.1 / Dart 3.9.0** (đã verify trên máy).

---

## 2. Kiến trúc thư mục (dự kiến)

```
lib/
├── main.dart
├── app/
│   ├── routes/              # GetX pages & routing
│   ├── bindings/            # GetX dependency injection
│   └── theme/               # màu neon, gradient, text style
├── core/
│   ├── constants/           # config, colors, sizes
│   └── utils/
├── data/
│   ├── models/              # Gem, Level, Booster, GameState
│   ├── levels/              # định nghĩa level (JSON/Dart)
│   └── repositories/        # save/load progress (shared_prefs)
├── logic/                   # PURE DART — testable, không phụ thuộc Flame
│   ├── board.dart           # lưới, swap, gravity
│   ├── match_detector.dart  # phát hiện match 3/4/5/T/L
│   └── special_gem_factory.dart
├── game/                    # FLAME
│   ├── neon_jewel_game.dart # FlameGame chính
│   ├── components/          # GemComponent, BoardComponent, EffectComponent
│   └── effects/             # particle, glow, explosion neon
└── presentation/            # FLUTTER WIDGET + GETX
    ├── controllers/         # GameController, LevelController...
    ├── screens/             # splash, home, map, gameplay, win/lose
    └── widgets/             # neon button, HUD, star rating
```

---

## 3. Cơ chế gameplay cốt lõi (từ game gốc)

### Match cơ bản
- Match **3** gem cùng màu (ngang/dọc) → nổ.
- Gem rơi xuống (gravity) → fill gem mới từ trên.
- Cascade/combo: chuỗi match liên tiếp → điểm thưởng tăng dần.

### Special Gems (gem đặc biệt)
| Cách tạo | Gem đặc biệt | Hiệu ứng |
|---|---|---|
| Match 4 thẳng hàng | ⚡ Lightning/Striped | Nổ cả 1 hàng hoặc 1 cột |
| Match 5 hình T / L | 💣 Bomb | Nổ vùng 3x3 xung quanh |
| Match 5 thẳng hàng | 🌈 Rainbow/Color | Xóa toàn bộ gem cùng 1 màu |

### Kết hợp 2 special gems (combo)
- Striped + Striped → nổ chữ thập (1 hàng + 1 cột).
- Striped + Bomb → nổ 3 hàng + 3 cột.
- Rainbow + Striped → biến toàn bộ gem 1 màu thành striped rồi nổ hết.
- Rainbow + Rainbow → xóa sạch cả bàn.
- Rainbow + Bomb → biến gem 1 màu thành bomb.

---

## 4. Roadmap tính năng

### ✅ Implemented (done + build pass)
*(chưa có — sẽ cập nhật sau mỗi wave)*

### 🟡 In progress
*(chưa bắt đầu code)*

### 📋 Picked (đã chốt, chờ implement) — MVP Wave 1
- [ ] **Setup dự án Flutter** + cấu hình Android/iOS + thêm deps (get, flame...)
- [ ] **Logic board (pure Dart):** grid NxN, swap, match-3 detection, gravity, refill
- [ ] **Render board bằng Flame:** GemComponent với 6 màu neon, tap/swipe để swap
- [ ] **Hiệu ứng nổ neon cơ bản:** particle khi match (glow + burst)
- [ ] **Special gem cơ bản:** Striped (match 4) + Rainbow (match 5)
- [ ] **Scoring + combo counter** hiển thị HUD
- [ ] **1 game mode:** Score Target (đạt X điểm trong Y lượt)
- [ ] **Màn hình:** Home → Gameplay → Win/Lose dialog (GetX)
- [ ] **Lưu high score** bằng shared_preferences
- [ ] **5 level demo** để chơi thử

### ⏸️ Deferred (lớn, để session sau)
- [ ] **Bomb gem (match T/L)** + tất cả combo 2-special-gem
- [ ] **5 game modes** (xem mục 5)
- [ ] **Obstacles:** băng (ice), xích (chain), đá (stone), jelly
- [ ] **Level objectives đa dạng:** collect gems, clear jelly, drop items xuống đáy
- [ ] **Map/World progression** (lâu đài, mở khóa khu vực) — 100+ levels
- [ ] **Booster system** (hammer, shuffle, bomb pre-game)
- [ ] **Hệ thống sao (1-3 sao/level)** + reward
- [ ] **Daily reward, lives/energy system**
- [ ] **Âm thanh:** nhạc nền neon synthwave + SFX
- [ ] **Settings:** âm lượng, ngôn ngữ, haptic feedback
- [ ] **Tutorial level đầu game**

### 💭 Ideas (brainstorm pool)
- Theme neon đổi màu theo world (cyan → magenta → green...)
- Chế độ Endless / Zen không giới hạn lượt
- Daily challenge với leaderboard (cần backend — Firebase?)
- Hiệu ứng "screen shake" + slow-motion khi combo lớn
- Gem hiếm phát sáng pulsing, trail khi rơi
- Achievement system
- Chế độ 2 người chơi (versus)
- Shader glow chuẩn neon (fragment shader)

### ❌ Skipped
*(chưa có)*

---

## 5. Năm Game Modes (đa dạng lối chơi — từ game gốc "5 modes")

| Mode | Mục tiêu | Cơ chế đặc trưng |
|---|---|---|
| **1. Score Target** | Đạt điểm mục tiêu trong số lượt giới hạn | Cơ bản nhất, dễ làm MVP |
| **2. Collect Gems** | Thu thập đủ N gem màu chỉ định | Hiện badge đếm trên HUD |
| **3. Clear Jelly** | Xóa hết lớp jelly dưới gem | Jelly cần match đè lên 1-2 lần |
| **4. Drop Down** | Đưa item đặc biệt rơi xuống đáy bàn | Item kẹt cần match xung quanh |
| **5. Time Attack** | Ghi điểm cao nhất trong thời gian giới hạn | Thêm áp lực thời gian, combo nhanh |

---

## 6. Design ngôn ngữ Neon

- **Bảng màu:** nền tối (#0A0A1A / #12122A) làm nổi gem phát sáng.
  - Gems neon: Cyan `#00FFFF`, Magenta `#FF00FF`, Lime `#39FF14`, Yellow `#FFFF00`, Orange `#FF6B00`, Purple `#BC13FE`.
- **Glow:** mỗi gem có outer glow (BoxShadow/blur), pulsing nhẹ.
- **Particle khi nổ:** burst tia sáng + spark theo màu gem.
- **Font:** Orbitron / Audiowide (futuristic neon).
- **Background:** grid neon mờ + particle trôi nổi (ambient).
- **Combo feedback:** flash màn hình + text neon "COMBO x3!" với shimmer.
- **Transition:** glow fade + scale, không dùng cut cứng.

---

## 7. Các bước triển khai MVP (thứ tự code)

1. `flutter create` + cấu hình package name, icon, splash.
2. `flutter pub add get flame flame_audio shared_preferences google_fonts flutter_animate`.
3. Viết `logic/board.dart` + `match_detector.dart` (pure Dart) + **unit test**.
4. Dựng `NeonJewelGame` (FlameGame) render grid tĩnh với màu neon.
5. Thêm tap/swipe swap → gọi logic → animate kết quả.
6. Match → xóa gem → gravity → refill (animation rơi).
7. Particle nổ neon + combo counter.
8. Special gem Striped + Rainbow.
9. GetX: Home screen, GameController, Win/Lose dialog, save score.
10. 5 level demo + build thử Android (`flutter build apk`) và iOS (`flutter build ios`).

---

## 8. Rủi ro & giảm thiểu

| Rủi ro | Mức độ | Giảm thiểu |
|---|---|---|
| Asset đồ họa neon tốn công | 🟡 Cao | Bắt đầu bằng shape vẽ bằng code (Canvas/gradient), thêm sprite sau |
| Cân bằng độ khó 100+ level | 🟡 Cao | Dùng config JSON, tách content khỏi code, test dần |
| Particle nhiều gây tụt fps | 🟢 TB | Object pooling, giới hạn particle, profile bằng DevTools |
| iOS build cần Mac + cert | 🟢 Thấp | Máy đang dùng macOS ✅, simulator OK; cần Apple Dev account để release |
| Audio license | 🟢 Thấp | Dùng nhạc/SFX royalty-free (freesound, opengameart) |

---

## Sources
- [Jewels Legend - Match 3 Puzzle (Google Play)](https://play.google.com/store/apps/details?id=com.linkdesks.jewellegend)
- [Jewels Legend gameplay (games.lol)](https://games.lol/jewels-legend-match-3-puzzle/)
- [get package](https://pub.dev/packages/get) · [flame package](https://pub.dev/packages/flame)

---

*Cập nhật lần cuối: 2026-06-13 · Trạng thái: Kế hoạch (chưa code)*
