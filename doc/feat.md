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

### 🌊 Wave 4 — giữ chân + 2 game mode + obstacles (✅ đã làm song song)
> Theo dõi trạng thái chi tiết: [`tasks/done/`](tasks/done/).
> Quyết định: **giữ nguyên** debug `print('roy93~')` theo yêu cầu người dùng (dễ debug trên máy).

- [x] **Daily Reward** — thưởng xu theo chuỗi 7 ngày (20→110), badge sáng khi có quà, overlay trong cây (route dialog no-op theo [[route-dialogs-noop-fullscreen]])
- [x] **Lives / Energy** — 5 mạng, hồi 1 mạng/15' (mốc thời gian, hồi nhiều chu kỳ), thua trừ mạng, 0 mạng chặn vào màn + đếm ngược; chip ❤ trên Home
- [x] **Mode 5 — Time Attack** — đạt điểm trong giới hạn thời gian (45–75s), timer chạy trong `update()` của Flame, HUD hiện TIME (đỏ ≤10s)
- [x] **Mode 4 — Drop Down** — đưa ingredient xuống đáy bàn (gem không match `_matchColorAt`, rơi theo trọng lực, thu ở đáy `_collectIngredients`)
- [x] **Obstacles Ice/Chain/Stone** — lớp overlay cell-based (như jelly): ice vỡ khi clear trực tiếp, chain/stone gỡ khi ô kề clear, stone loại khỏi match; objective `clearObstacle`; `ObstacleLayer` render băng/xích/đá
- [x] **Guide cập nhật** 3 mode mới + section Chướng ngại
- [x] **Kết quả**: 0 analyzer issue · **89 unit/widget test pass** (+17 test Wave 4) · build APK debug OK

> i18n: key mới thêm proper **en + vi** (merge qua `_extraEn`/`_extraVi`); 20 ngôn ngữ còn lại fallback English cho key mới (giữ parity test). Dịch đầy đủ 20 ngôn ngữ → follow-up.

#### Wave 4.1 — verify máy thật + hoàn thiện chiều sâu + i18n + world (✅ đã làm)
- [x] **Verify máy thật** (Samsung 1080×2340): Time Attack (GIỜ đếm ngược), Drop Down (ingredient + ↓0/2), Obstacle Ice (❄0/16 + băng), Daily overlay, **mua đầy mạng** (lives 2→5, xu 110→50) + countdown hồi mạng
- [x] **Drop Down sâu hơn**: ingredient sinh dần theo dòng chảy (`_replenishIngredients`, tối đa 2 cùng lúc) thay vì cố định lúc mở màn
- [x] **Mua đầy mạng bằng xu** (60 xu): `buyRefillLives` + overlay xác nhận trên Home (chip ❤ bấm được khi chưa đầy) + báo thiếu xu
- [x] **Time Attack thưởng giây**: combo ≥4 → +(combo−2)s, hiện "+Ns" bay lên (`addTime`)
- [x] **Dịch đủ 22 ngôn ngữ** cho key Wave 4 (4 agent dịch song song → `_extraByLang`, giữ `@n`/`@t`, đúng dấu bản địa)
- [x] **World progression**: 100 màn chia **5 thế giới** (`kWorlds`, 20 màn/thế giới, chủ đề neon) + banner tiêu đề khu vực trong Level Select (sao + tiến trình + khoá thế giới chưa tới)
- [x] **Kết quả**: 0 analyzer issue · **98 test pass** · build APK debug OK
- [x] **World-header verify máy thật** (chụp được sau): "THẾ GIỚI 1 ★8 20/20" + "THẾ GIỚI 2 ★0 15/20"

#### Wave 4.2 — audit & fix (✅ đã làm)
> Tự audit code Wave 4 (chấm 7.5/10) → phát hiện & sửa lỗi nghiêm trọng.
- [x] **FIX winnability obstacle (nghiêm trọng)**: chain dùng `checker` + stone dùng `all` → khoá swap dày đặc làm **bí cứng ~10 màn** (36/42/48/54 + 66/72/78/84/90/96). Sửa: chain & stone luôn dùng `center` (chừa viền tự do); ice giữ tierPattern. Verify máy thật: màn 36 (xích/center) + màn 66 (đá/center) đều ❄0/16, viền tự do, không auto-shuffle.
- [x] **FIX `_findMove` bỏ qua ô khoá**: trước đây phát hiện "còn nước đi" không xét swap-lock → tưởng còn nước nhưng người chơi không đi được → không auto-shuffle. Nay hint + phát hiện hết-nước đều tôn trọng khoá.
- [x] **FIX lives bypass khi retry**: `again()` chặn khi hết mạng (về Level Select); dialog thua ẩn nút CHƠI LẠI + báo "HẾT MẠNG" khi lives=0.
- [x] **Refactor**: tách `patternHas()` thuần (DRY cho jelly/obstacle + test được không cần Flame).
- [x] **Test winnability** (4 test mới): chain/stone không bao giờ dùng all/checker + luôn còn cặp ô tự do kề nhau (regression guard — sẽ fail nếu tái phát).
- [x] **Kết quả**: 0 analyzer issue · **102 test pass** · build APK OK · verify máy thật chain+stone.
- [ ] *Còn nợ nhỏ (đã ghi)*: đếm ngược hồi mạng ở Home chưa tự tick (static tới rebuild); `_doShuffle` kiểm hasMatch trên màu thô gồm ô loại trừ (vô hại).

### 🟡 In progress
*(không có — Wave 5 đã xong 9/9)*

### 🌊 Wave 5 — batch 3.5 (World Map juice) + batch 4 (engine: Polish + Lucky + Spread) — ✅ đã làm
- [x] **World Map nâng cấp** (theo feedback): node nhỏ gọn (46px), zig-zag sin mượt, **sao màu lấp lánh** động (CustomPainter twinkle), **xung năng lượng** chạy dọc path đã đi, node hiện tại **vầng sáng xoay** + pulse, banner thế giới gọn, auto-scroll tới màn hiện tại.
- [x] **Polish & Juice**: **slow-motion** 0.45s khi wombo combo (≥6) làm chậm mọi hiệu ứng Flame (`super.update(dt*timeScale)`); particle gem **special tăng 9→18 hạt** bay xa hơn.
- [x] **Lucky / Mystery Gem**: ~2.8% gem refill là gem may mắn (tia sáng lấp lánh trắng); match → **+điểm +xu** & biến vài gem thường thành special ngẫu nhiên + flash "LUCKY!".
- [x] **Obstacle lan tỏa (chocolate)**: `ObstacleType.spread` mới — phủ ô (khoá swap + loại match như stone), mỗi lượt KHÔNG phá ô kề → **lan 1 ô** (trần 16 ô chống khoá bàn). Hazard trên 3 màn score (55/73/91, +6 lượt), không phải mục tiêu. Render khối chocolate tím. `ObstacleLayer._drawSpread`.
- [x] i18n Guide cập nhật (chocolate + lucky gem). 0 analyzer issue.

### 🌊 Wave 5 — batch 5 (view-mode local + test toàn diện) — ✅ đã làm
- [x] **Lưu kiểu xem (local DB)**: `StorageKeys.viewMode` (0 = World Map, 1 = Grid). Home "CHƠI NGAY" mở đúng kiểu đã chọn (mặc định Map). **Chỉ ghi khi user chủ động đổi** (bấm nút Grid trên Map → lưu 1; nút Map trên Grid → lưu 0).
- [x] **flutter_localizations**: thêm `GlobalMaterialLocalizations`/`Widgets`/`Cupertino` delegates → tooltip + Material widget hoạt động đúng cho cả 22 ngôn ngữ (trước đây thiếu → ném lỗi với locale ≠ en).
- [x] **app(withAudio)**: tách cờ audio để integration test không bị frame-callback của audioplayers giữ sống (gây lỗi teardown).
- [x] **Test toàn diện**:
  - **Unit** (`test/w5_test.dart`): win-streak, achievements (mọi thành tựu mở khoá + claim hết), lucky wheel (mọi ô thưởng), pre-game, view-mode, resetProgress, spread data.
  - **Widget** (`test/widget/w5_screens_test.dart`): AchievementsScreen, WorldMapScreen (+ lưu viewMode), LevelSelect (map toggle + pre-game), Home (nút thành tựu/vòng quay, mở overlay).
  - **Integration** (`integration_test/app_test.dart`): 8 flow end-to-end (World Map↔Grid, Thành tựu, Vòng quay quay thật, Quà ngày, vào game qua pre-game, X→thoát, Settings, Guide) — **chạy thật & PASS trên iQOO Z9 Turbo**.
- [x] **Kết quả cuối**: 0 analyzer issue · **128 unit/widget test + 8 integration test = 136 pass** · verify máy thật.

### 🌊 Wave 5 — batch 6 (revamp menu + font tiếng Việt) — ✅ đã làm
- [x] **Font casual hỗ trợ tiếng Việt**: thay **Orbitron** (thiếu glyph tiếng Việt → mất dấu) bằng **Baloo2** (variable, đủ Latin Extended + Vietnamese, bo tròn vui mắt). Bundle `asset/fonts/Baloo2.ttf`, đổi 59 chỗ `fontFamily` ở 12 file. Verify máy thật: CHƠI NGAY / THÀNH TỰU / Thợ Săn Sao… đủ dấu.
- [x] **Revamp menu Home gọn** (sửa lỗi quá nhiều nút): bỏ nút "MÀN 1" trùng; **CHƠI NGAY** là nút chính nổi bật; gom Thành tựu / Hướng dẫn / Cài đặt thành **hàng 3 icon tròn neon** nhỏ (có nhãn + badge thành tựu). Bớt chiều cao → không tràn/đè overlay.
- [x] 0 analyzer issue · 136 test pass.

---

## 4.5 So sánh Candy Crush Saga — GAP ANALYSIS (Wave 5 candidate)

> Đánh giá tính năng còn thiếu so với **Candy Crush Saga** (bản gốc King). Đã có khá đầy đủ core: 5 mode, obstacle, booster, sao, daily, lives, world. Phần còn thiếu chủ yếu là **trải nghiệm hành trình + meta-retention + juice**.

### Đã ngang ngửa CCS ✅
match-3 + cascade · special gem (striped/wrapped/color) + combo 2-special · 5 mode · obstacle (jelly/ice/chain/stone) · booster · sao 1-3 · daily reward · lives/energy · 100 màn · world grouping · i18n.

### Còn THIẾU so với CCS (xếp theo độ "đậm chất Candy Crush")

| # | Tính năng CCS | Hiện trạng | Độ khó | Tác động |
|---|---|---|---|---|
| A | **World Map node-based** (đường đi uốn lượn, node màn, lâu đài, cờ episode) | Chỉ Level Select dạng lưới gom thế giới | 🟡 TB | ⭐⭐⭐ Định danh CCS |
| B | **Tutorial lần đầu** (overlay tay chỉ, dạy swap/special) | Chưa có | 🟢 Thấp | ⭐⭐ Onboarding |
| C | **Obstacle lan tỏa** (chocolate/licorice tự nhân lên mỗi lượt nếu không chặn) | Obstacle tĩnh | 🟡 TB | ⭐⭐⭐ Chiều sâu |
| D | **Pre-game booster panel** (chọn booster trước khi vào màn) | Chỉ dùng booster trong màn | 🟢 Thấp | ⭐⭐ Kinh tế |
| E | **Lucky Wheel / vòng quay may mắn** (spin hàng ngày nhận thưởng) | Chỉ daily streak | 🟢 Thấp | ⭐⭐ Giữ chân |
| F | **Achievement / thành tựu** (mốc combo, số sao, win streak…) | Chưa có | 🟢 Thấp | ⭐⭐ Giữ chân |
| G | **Win streak / Sweet streak** (thắng liên tiếp → thưởng tăng) | Chưa có | 🟢 Thấp | ⭐ Giữ chân |
| H | **Sound/Music revamp + juice** (SFX phong phú, slow-mo combo lớn, trail gem rơi) | Audio cơ bản | 🟢 Thấp | ⭐⭐ Cảm giác |
| I | **Gem hiếm / Lucky candy / Mystery** (gem ngẫu nhiên ra special) | Chưa có | 🟢 Thấp | ⭐ Bất ngờ |
| J | **Leaderboard / Cloud save / Daily challenge online** | Chưa có (cần backend) | 🔴 Cao | ⭐⭐ Social (cần Firebase) |
| K | **Episode/story + nhân vật** (cốt truyện, NPC dẫn dắt) | Chưa có | 🔴 Cao | ⭐ Cốt truyện |

### 📋 Picked — Wave 5 (đã chốt: làm CẢ 4 hướng + 4 tính năng nhỏ, song song, OFFLINE thuần)
> Task chi tiết: [`tasks/todo/`](tasks/todo/) → di chuyển sang `in-progress/` → `done/`.

| Nhóm | Task | File | Trạng thái |
|---|---|---|---|
| Meta giữ chân | Achievement / Thành tựu | `w5-achievements.md` | ✅ done |
| Meta giữ chân | Win Streak | `w5-win-streak.md` | ✅ done |
| Meta giữ chân | Lucky Wheel (vòng quay) | `w5-lucky-wheel.md` | ✅ done |
| Meta giữ chân | Pre-game Booster Panel | `w5-pregame-boosters.md` | ✅ done |
| Hành trình | Tutorial lần đầu | `w5-tutorial.md` | ✅ done |
| Hành trình | World Map node-based | `w5-world-map.md` | ✅ done |
| Chiều sâu | Obstacle lan tỏa | `w5-spreading-obstacle.md` | ✅ done |
| Chiều sâu | Lucky / Mystery Gem | `w5-lucky-gem.md` | ✅ done |
| Cảm giác | Polish & Juice | `w5-polish-juice.md` | ✅ done |

> Quyết định: **không backend** — game offline thuần (không leaderboard/cloud).

### 🌊 Wave 5 — batch 1 (Meta giữ chân: Achievement + Win Streak) — ✅ đã làm
- [x] **Win Streak / Sweet Streak**: thắng liên tiếp → bonus xu tăng dần (từ bậc 2, +5 xu/bậc, trần 6 bậc); thua reset chuỗi. Dialog thắng hiện chip "CHUỖI xN +bonus". Lưu `winStreak`/`bestWinStreak`/`totalWins` qua StorageService.
- [x] **Achievement / Thành tựu** (12 thành tựu offline): tổng thắng / sao / combo cao nhất / chuỗi thắng / mở khoá thế giới / tổng xu kiếm. Mỗi mốc thưởng xu, nhận 1 lần. Màn `AchievementsScreen` (lưới thẻ + thanh tiến trình + nút NHẬN), nút + badge sáng ở Home. `AchievementController` (GetX) đọc thống kê reactive.
- [x] Theo dõi `bestCombo` (qua addScore), `coinsEarnedTotal` (lifetime); reset đầy đủ trong `resetProgress`.
- [x] i18n: thêm key proper **en + vi** (merge `_extraEn`/`_extraVi`, 20 ngôn ngữ fallback English — giữ parity test).
- [x] **Kết quả**: 0 analyzer issue · **108 test pass** (+6 test Wave 5) · build APK debug.

### 🌊 Wave 5 — batch 2 (Lucky Wheel + Tutorial + Pre-game Booster) — ✅ đã làm
- [x] **Lucky Wheel / Vòng quay**: 8 ô (xu + booster), quay miễn phí 1 lần/ngày (`wheelLastSpin` epoch-day), bánh xe `CustomPainter` xoay 5 vòng dừng đúng ô trúng, trao thưởng ngay. Nút 🎰 + badge ở Home (cạnh nút quà). `LuckyWheelController` (GetX, inject `Random` để test).
- [x] **Tutorial lần đầu**: overlay 3 bước (swap → striped → rainbow) chỉ hiện ở **màn 1, lần đầu** (`tutorialSeen`), có chấm tiến trình + nút TIẾP/BỎ QUA. Quản lý bởi `GameScreenController`.
- [x] **Pre-game Booster Panel**: overlay "CHUẨN BỊ" trước khi vào màn (chỉ khi sở hữu booster) — chọn **+10 lượt khởi đầu** (tiêu 1 booster moves) và/hoặc **Búa sẵn sàng** (pre-arm). Cờ pending đọc 1 lần ở `GameScreenController._applyPregameBoosters`. `PregameController` (GetX).
- [x] i18n proper **en + vi** (20 ngôn ngữ fallback English, giữ parity).
- [x] **Kết quả**: 0 analyzer issue · **110 test pass** (+2 test wheel) · build APK debug.
- [x] **Tutorial vuốt**: bổ sung vuốt trái→tiếp / phải→lùi (GestureDetector onHorizontalDragEnd) + gợi ý "Vuốt để chuyển bước"; fix Obx overlay observe thêm `tutorialStep`. Verify máy thật (bước 1→2). **113 test pass** (+3 pre-game).

### 🌊 Wave 5 — batch 3 (World Map node-based) — ✅ đã làm
- [x] **WorldMapScreen**: bản đồ hành trình kiểu Candy Crush — đường path uốn lượn (`CustomPaint` quadratic bezier, sáng tới màn đã đi/mờ tới màn khoá) nối **100 node** zig-zag 4 nhịp; node = màn (số + 3 sao + khoá/hiện-tại-pulse), banner thế giới xen giữa (tên + tổng sao). Cuộn dọc toàn bộ.
- [x] **Tích hợp**: Home "CHƠI NGAY" → World Map; nút chuyển **Grid view ↔ Map** (Get.off) ở cả 2 màn; tái dùng pre-game flow + cổng mạng.
- [x] i18n `world_map`/`grid_view` (en + vi). 0 analyzer issue · verify máy thật (path + node pulse). Giữ Level Select cũ làm chế độ lưới.

### ⏸️ Deferred (lớn, để session sau)
- [x] ~~Combo 2-special-gem~~ (Wave 2)
- [x] ~~5 game modes~~ — **đủ 5/5**: Score, Collect, Clear Jelly, Time Attack, Drop Down (Wave 4)
- [x] ~~Obstacles ice/chain/stone~~ (Wave 4) — jelly đã có từ Wave 2
- [x] ~~Level objectives đa dạng~~ (collect/jelly/drop/obstacle)
- [x] ~~Booster đầy đủ~~ (9 booster — Wave 3)
- [x] ~~Hệ thống sao 1-3 + reward~~ (Wave 3)
- [x] ~~Daily reward, lives/energy system~~ (Wave 4)
- [x] ~~Phát hiện hết nước đi → tự xáo bàn~~ (Wave 2)
- [x] ~~Haptic feedback~~ (Wave 2.5)
- [x] ~~Dịch đầy đủ 20 ngôn ngữ cho key Wave 4~~ (Wave 4.1 — đủ 22 ngôn ngữ)
- [x] ~~Drop Down sinh thêm ingredient theo thời gian~~ (Wave 4.1)
- [x] ~~Mua đầy mạng bằng xu~~ (Wave 4.1)
- [x] ~~Time Attack bonus thời gian khi combo lớn~~ (Wave 4.1)
- [x] ~~Map/World progression~~ — đã chia 5 thế giới + banner khu vực (Wave 4.1); *màn map riêng (lâu đài/đường đi) vẫn để sau*
- [ ] **Màn World Map riêng** (đường đi node-based, lâu đài) — hiện là Level Select gom theo thế giới
- [ ] **Tutorial màn đầu** (overlay hướng dẫn lần chơi đầu)
- [ ] **word_n + tên thế giới dịch 20 ngôn ngữ** (hiện fallback English cho `world_n`; tên thế giới là proper noun)

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
