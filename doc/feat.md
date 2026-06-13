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

### ✅ Implemented (done + build pass Android & iOS + 37 test pass)
- [x] **Setup dự án Flutter** (`com.galaxyjoy.neonjewels`) + deps: get, flame, flame_audio, shared_preferences, google_fonts, flutter_animate
- [x] **Logic board (pure Dart):** match-3 detection ngang/dọc, run 4→striped, run 5→rainbow — `lib/logic/` (unit-tested kỹ)
- [x] **Render board bằng Flame:** `GemComponent` 6 màu neon, glow pulsing, gradient radial, tap-chọn-rồi-swap
- [x] **Hiệu ứng nổ neon:** particle burst + glow, shockwave ring lan tỏa, screen shake
- [x] **Special gem:** Striped (match 4, nổ hàng/cột + tia laser beam) + Rainbow (match 5, xóa cùng màu) + chain reaction + combo rainbow swap
- [x] **Scoring + combo** với hệ số nhân, combo text bay lên ("COMBO x3!")
- [x] **Game mode 1:** Score Target (đạt điểm trong số lượt)
- [x] **Màn hình (GetX):** Home (logo shimmer) → Level Select → Gameplay → Win/Lose dialog
- [x] **Lưu high score + unlock level** bằng shared_preferences
- [x] **5 level demo** độ khó tăng dần
- [x] **Animation "wow":** pop-in xếp tầng đường chéo khi mở màn, bounce khi rơi, nền neon orb trôi động, swap mượt
- [x] **Audio:** nhạc nền (bkg.mp3) + 24 nốt nhạc tăng cao độ theo combo + âm special + nút tắt tiếng
- [x] **Test đầy đủ:** unit + widget + integration — 45 test pass
- [x] **Chất lượng:** 0 issue analyze, try/finally chống kẹt bàn cờ, effect/particle tự huỷ (không leak)

#### Wave 1.1 — phản hồi người dùng (đã làm)
- [x] **Swipe để đổi gem** (DragCallbacks) — giống game gốc, vẫn giữ tap-chọn-tap
- [x] **Bomb gem** (match hình T/L) → nổ vùng 3x3
- [x] **Hình gem đa dạng + neon hơn:** mỗi màu 1 hình riêng (tròn/kim cương/tam giác/lục giác/ngũ giác/sao) + viền neon đôi
- [x] **Booster Shuffle** (xáo bàn, đảm bảo không match sẵn)
- [x] **Đa ngôn ngữ (i18n GetX):** English (default) + Tiếng Việt, kiến trúc sẵn sàng 20+ ngôn ngữ + test toàn vẹn key
- [x] **Màn Settings:** âm thanh, chọn ngôn ngữ, reset tiến độ
- [x] **Launcher icon + Splash screen** neon (kim cương SVG → PNG)
- [x] **Font bundle Orbitron** (offline, bỏ phụ thuộc tải mạng)
- [x] **Tối ưu hiệu năng:** bỏ MaskFilter.blur per-frame (thủ phạm lag), glow dùng ảnh cache, particle blend cộng, nền tối ưu
- [x] **Tên app:** "Neon Jewels" (Android + iOS)
- [x] **Chạy thật trên Tecno BG6 (release)** — không crash trong logcat

#### Wave 2 — chiều sâu gameplay + revamp UI (đã làm)
- [x] **Combo 2-special tổng quát:** striped+striped (chữ thập), striped+bomb (3 hàng+3 cột), bomb+bomb (5x5), rainbow+striped/bomb/rainbow
- [x] **Auto-shuffle khi hết nước đi** (phát hiện no-move + báo "SHUFFLE!"), bỏ booster shuffle thủ công
- [x] **Obstacle Jelly** + **objective đa dạng:** Score / Collect (thu màu) / Clear Jelly — mỗi màn 1 kiểu
- [x] **HUD revamp:** chip SCORE / GOAL (đổi theo mục tiêu, có chấm màu cho collect) / MOVES + thanh tiến độ + NeonIcon
- [x] **Khung bàn (BoardFrame)** + ô lõm checkerboard — gem nằm trong khay
- [x] **NeonDialog dùng chung** (win/lose + xác nhận reset) + **NeonIcon dùng chung**
- [x] **Nền lung linh hơn:** lưới + 64 sao (có sao 4 cánh neon) + orb gradient + vignette
- [x] **Polish hiệu ứng special/combo:** flash màn hình (rainbow/bomb/combo≥4), combo text to dần theo cấp, hiệu ứng "ra đời" khi tạo gem special, beam/shockwave
- [x] **Sửa bug bàn lệch tâm** khi animation (trauma-based shake, không drift)
- [x] **Fix:** tên app Neon Jewels, font bundle, 46 test pass

#### Wave 2.1 — tinh chỉnh UI/UX (đã làm)
- [x] **Board cách mép 16px** (không còn khít màn hình)
- [x] **Hệ spacing chuẩn 8/16/24** (`NeonTheme.s8/s16/s24`) áp cho game + home + level select + settings
- [x] **Hint nhấp nháy khi stuck:** đứng yên >4s → gem gợi ý nước đi phát sáng nhấp nháy
- [x] **HUD gọn lại:** chip inline (nhãn + giá trị 1 hàng), icon nhỏ, vẫn đủ SCORE/GOAL/MOVES
- [x] **Thanh progress animate mượt** (TweenAnimation + gradient + glow), chip giá trị nảy khi đổi (AnimatedSwitcher)
- [x] **Dialog xác nhận thoát màn** (NeonDialog) khi bấm X giữa lúc chơi
- [x] Tăng cường animation tổng thể (flash, combo scale, special birth — từ Wave 2)

#### Wave 2.2 — audit UI/UX theo phản hồi (đã làm)
- [x] Home: bỏ tagline "5 màn", thay bằng **version (v1.0.0) + © SAIGON PHANTOM LABS**
- [x] **NeonBackButton** dùng chung (back neon ở mọi màn phụ); xác nhận nút X màn chơi mở dialog OK
- [x] Fix **HUD tràn width** (chip co giãn, NeonButton label FittedBox)
- [x] **Xoá lưới ô vuông** nền game
- [x] **Nền lung linh hơn:** thêm nebula màu lớn (chiều sâu) + sao
- [x] **Gem special nổi bật hơn:** glow mạnh/nhịp nhanh, vạch neon đậm, lõi sáng nhịp, vòng cầu vồng xoay
- [x] **Màn Hướng dẫn (Guide):** cách chơi, gem đặc biệt, combo/wombo combo, các chế độ, mẹo khi stuck
- [x] Fix **COMBO text tràn màn** (giới hạn maxWidth) + nhãn **WOMBO COMBO** khi combo ≥ 6
- [x] Fix **dialog button tràn** (Expanded + FittedBox) — áp cho mọi NeonDialog
- [x] Home **cuộn được** khi màn thấp (chống overflow)

#### Wave 2.3 — fix layout & background chung (đã làm)
- [x] **Fix Home lệch:** bỏ IntrinsicHeight/Spacer, dùng Center + SingleChildScrollView (căn giữa chuẩn, cuộn an toàn)
- [x] **NeonBg — background common** (gradient + quầng sáng mềm + vignette) áp cho Home & Guide
- [x] **Revamp Guide:** dùng NeonBg, tăng padding + giảm glow → card không bị cắt
- [x] **Fix HUD tràn:** chip SCORE/GOAL/MOVES bọc Flexible + FittedBox, chữ nhỏ lại (không wrap)
- [x] **Special gem nổi bật hơn:** thêm **vòng cung sáng xoay** quanh gem special để gây chú ý

#### Wave 2.4 — full screen, board chuẩn, action bar chung (đã làm)
- [x] **Full screen** (immersive: ẩn status bar + navigation bar)
- [x] **Slot bo tròn 0px**, chỉ 4 ô góc board bo theo panel
- [x] **Board chuẩn 8×8** đồng nhất mọi màn (tham chiếu Candy Crush)
- [x] **NeonAppBar — action bar chung** áp cho Guide / Settings / Level Select
- [x] Fix **Settings scroll cắt glow** card + **reset card bấm cả thẻ** (HitTestBehavior.opaque)
- [x] Fix **Guide cuộn đè action bar** (bỏ clip none, padding hợp lý)
- [x] **NeonBg** áp cho tất cả màn phụ (đồng bộ)
- [x] **WOMBO COMBO epic animation:** đổi màu cầu vồng + lắc xoay + flash/shake mạnh khi combo ≥ 6
- [x] **Giữ màn hình luôn sáng khi chơi** (wakelock_plus)
- [x] **Test bổ sung:** objective collect/jelly, board 8×8, NeonAppBar/NeonBg/NeonIcon, Guide screen, integration (guide + dialog thoát) — 58 unit/widget test pass

### 🟡 In progress
*(không có — Wave 2.4 đã xong)*

### 📋 Picked (đã chốt, chờ implement)
*(trống — chờ chọn Wave 2 từ Deferred)*

### ⏸️ Deferred (lớn, để session sau)
- [ ] **Combo 2-special-gem** (striped+striped, striped+bomb, rainbow+bomb...) — hiện mới có rainbow-swap
- [ ] **5 game modes** (xem mục 5) — hiện mới có Score Target
- [ ] **Obstacles:** băng (ice), xích (chain), đá (stone), jelly
- [ ] **Level objectives đa dạng:** collect gems, clear jelly, drop items xuống đáy
- [ ] **Map/World progression** (lâu đài, mở khóa khu vực) — 100+ levels
- [ ] **Booster đầy đủ:** hammer (đập 1 gem), swap (đổi 2 gem bất kỳ), bomb pre-game (mới có Shuffle)
- [ ] **Hệ thống sao (1-3 sao/level)** + reward
- [ ] **Daily reward, lives/energy system**
- [ ] **Thêm 20 ngôn ngữ** (kiến trúc i18n đã sẵn sàng — chỉ thêm map)
- [ ] **Haptic feedback**, tutorial màn đầu
- [ ] **Phát hiện hết nước đi → tự xáo bàn**

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
