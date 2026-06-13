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

#### Wave 2.5 — revamp visual mạnh + fix (đã làm)
- [x] **Background động cực mạnh** (NeonBg): nebula trôi + tia sweep xoay + sao lấp lánh — áp mọi màn
- [x] **Revamp Level Select**: tile lớn 2 cột, emblem gem neon, icon mục tiêu, điểm cao, **màn hiện tại pulse + badge ▶**, animation vào màn
- [x] **HUD panel thống nhất** (ĐIỂM | MỤC TIÊU | LƯỢT) — căn giữa, cùng chiều cao, có divider
- [x] **Version + copyright neon glow** ở Home
- [x] Fix **nút X** dễ bấm (thêm padding top, icon to 28) + chặn input sau khi kết thúc ván
- [x] **Fix bug "lượt 0 không có dialog"**: gọi `_finishMove` trong finally (luôn kiểm tra kết thúc kể cả khi lỗi) + cờ `_ended`
- [x] **Fix MỤC TIÊU jelly hiện 0/0** → jellyTotal thành RxInt (reactive)
- [x] **Haptic** theo combo (nhẹ 2-3, vừa 4-5, mạnh ≥6 wombo)
- [x] 58 unit/widget test pass

#### Wave 2.6 — revamp + fix triệt để (đã làm)
- [x] **Fix nút X/back triệt để**: đóng dialog rồi pop màn ở frame kế (hết bị GetX nuốt pop) + PopScope (back hệ thống → dialog thoát)
- [x] **Revamp Level Select**: banner "màn hiện tại" lớn (emblem + ★ + CHƠI NGAY) + lưới 4 cột, focus màn đang chơi
- [x] **NeonBg động** (nebula + sweep + sao) áp toàn bộ màn; version/copyright neon glow
- [x] Đã xác minh trên máy: dialog (reset/quit) hiện đúng, nút CANCEL/CONFIRM gọn trong khung
- [x] 59 unit/widget test pass

### 🌊 Wave 3 — 4 mục song song (đã làm)
- [x] **Hệ thống sao 1-3** + lưu sao tốt nhất/màn + **dialog thắng celebration** (sao bay elastic + thưởng xu)
- [x] **Booster + kinh tế xu**: Hammer (đập 1 gem) + Shuffle; xu thưởng khi thắng (20/30/40 theo sao); hết booster → mua bằng xu; booster bar trong game + chip xu
- [x] **100 màn** (generator scaling, xoay vòng 3 mục tiêu, jelly pattern theo tier); Level Select 4 cột cuộn lazy (CustomScrollView) + sao trên mỗi tile
- [x] **22 ngôn ngữ** (en, vi + 20: es/fr/de/pt/ru/zh/ja/ko/it/id/th/hi/ar/tr/nl/pl/fil/ms/uk/bn) — agent dịch, test parity pass
- [x] **66 unit/widget test pass**, 0 analyzer issue, build release chạy thật (Samsung 1080x2340 + Tecno BG6)

#### Wave 3.1 — fix booster + GetX hoá (đã làm)
- [x] **Bỏ booster Shuffle** (trùng auto-shuffle) → thay bằng **+5 Lượt** (rõ giá trị)
- [x] **Fix nút X triệt để (root cause thật)**: Flame GameWidget vẽ ĐÈ lên dialog route → chuyển quit/win/lose sang **overlay trong cây widget** (NeonDialog.panel + NeonDialog.overlay) render trên GameWidget. Đã verify trên máy: X → "THOÁT MÀN?" → ĐỒNG Ý → về Level Select.
- [x] **Bỏ hoàn toàn setState** → refactor `game_screen` thành StatelessWidget + `GameScreenController` (GetX): game instance, overlay state, vòng đời wakelock đều qua Rx/Obx
- [x] **Booster có animation khi bấm** (InkWell ripple); hết booster → hiện **giá xu** (💰30) ngay trên nút → làm rõ quan hệ xu↔booster
- [x] Icon: 🔨 búa = đập 1 gem bất kỳ; ⏰+5 = thêm 5 lượt; 💰 = xu (mua booster)
- [x] 66 test pass · 0 analyzer issue · verify thật trên Samsung

#### Wave 3.2 — fix booster UX (đã làm)
- [x] **Trace bằng debug print `roy93~`** ở click event booster (giữ lại để dễ debug trên máy)
- [x] **Nguyên nhân "booster không work"**: hết booster (count=0) + thiếu xu (coins<giá) → mua thất bại **im lặng**. Đã verify: khi còn booster, +5 → LƯỢT 26→31; búa → arm → đập gem OK
- [x] **Phản hồi thiếu xu**: rung chip xu (shake) khi mua thất bại
- [x] **Búa có chỉ báo "đã chọn"** (nút sáng rực) + bấm lại để bỏ chọn
- [x] **Giá mua đúng** trên nút (búa 30, +5 lượt 25); icon: 🔨 đập 1 gem, ⏰+5 thêm lượt, 💰 xu
- [x] 68 unit/widget test pass · 0 analyzer issue · verify thật trên máy

#### Wave 3.3 — gem lá bài + 9 booster + StorageService (đã làm)
- [x] **Gem hình lá bài** (♥ cơ, ♦ rô, ♣ chuồn, ♠ bích, ★ sao, ● tròn) vẽ bằng `Path`/`cubicTo` trong `gem_component.dart`
- [x] **9 booster**: Hammer, +10 Lượt, Swap, Bomb, Color Blast + 4 booster **độc quyền**: 🃏 Joker (biến 1 gem thành rainbow), ⚡ Chain Lightning (7 gem cùng màu + tia sét), ♕ Royal Flush (clear cả bàn), 🌀 Gravity Flip (đảo cột). Có user-guide trong màn Hướng dẫn (`guide_boost_title/body`)
- [x] **StorageService + StorageKeys** (GetxService bọc SharedPreferences, key tập trung thành constant) — audit toàn bộ key, bỏ string rời rạc. `GameController`/`LocaleService`/`main.dart` đều dùng service
- [x] 72 unit/widget test pass · 0 analyzer issue · verify gameplay thật trên Samsung (gem lá bài + booster bar hiển thị đúng)

#### Wave 3.4 — fix bug "Xoá tiến độ" không work (đã làm)
- [x] **Trace `roy93~`** ở settings (card tap → show dialog → resetProgress START/DONE)
- [x] **Nguyên nhân gốc**: route-based dialog (`Get.dialog` **và** `showDialog` native) đều **no-op** trong app full-screen này — không push được route, không có exception. Log xác nhận handler chạy mỗi lần tap nhưng dialog không bao giờ chặn được tap kế tiếp
- [x] **Cách fix**: chuyển dialog xác nhận reset sang **overlay trong cây** (`NeonDialog.overlay` + `NeonDialog.panel`) điều khiển bởi `SettingsController` (GetX `RxBool`, không setState) — cùng pattern đã chạy OK ở màn game. Snackbar "đã xoá" đổi sang `ScaffoldMessenger`
- [x] Đã verify thật: tap thẻ → overlay "Xoá tiến độ?" hiện → ĐỒNG Ý → `unlocked 4→1, highScores 3→0, stars 3→0` + snackbar; HUỶ/barrier đóng overlay
- [x] 72 test pass · 0 analyzer issue

### 🟡 In progress
*(không có)*

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

*Cập nhật lần cuối: 2026-06-13 · Trạng thái: Đang phát triển (Wave 3.4 — fix bug Xoá tiến độ, 72 test pass)*
