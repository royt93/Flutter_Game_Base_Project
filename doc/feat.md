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
- [x] **App Store screenshot editor:** scaffold riêng tại `store-assets/`; 8 slide English cho iPhone + 8 slide cho iPad, capture trực tiếp từ Pixel 7 Pro, prefill Neon Jewels/tagline/caption, production build pass và dev server chạy tại `http://localhost:3000`.
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

### 🌊 Wave 8.2 — audit & fix lỗ hổng (✅ đã làm)
> Tự audit code toàn dự án (2 agent đọc sâu logic + presentation) → sửa lỗ hổng đã xác minh.
- [x] **FIX `resetProgress()` không sạch + exploit nhận lại thưởng (Critical)**: trước chỉ xoá key đĩa của Battle Pass / Season / Achievement / Temple nhưng KHÔNG clear state in-memory của các controller `permanent:true` → restart đọc đĩa trống ⇒ nhận lại thưởng (lặp xu/shard). Thêm `resetState()` cho 4 controller (clear `claimed`/`xp`/`points`/`builtTier` + reload). Đồng thời xoá đủ key còn sót: `coins`, `daily*`, `wheelLastSpin`, `lives*`, 9 `booster*`, `tutorialSeen`, `viewMode` → reset đưa xu/booster/mạng về mặc định cài đầu (50 xu, booster default, đầy mạng). Nạp lại qua `_load()`.
- [x] **FIX boss "điểm yếu màu" dở dang (feature chưa wire)**: `bossWeakColor` được tính & đổi phase nhưng KHÔNG ảnh hưởng sát thương và KHÔNG hiện HUD. Nay: `registerClear` bật cờ `_weakHitPending` khi clear trúng màu yếu → `_bossDamage` ×2 (cộng dồn với ×2 combo lớn → tối đa ×4). Thêm chỉ báo "ĐIỂM YẾU ● ×2" trên HUD boss (key i18n `boss_weak` đã có sẵn en/vi).
- [x] **Kết quả**: 0 analyzer issue · **187 test pass** (+7 `test/w8_2_test.dart`) · build pass.
- [ ] *Còn nợ nhỏ (ghi nhận, chưa sửa)*: daily/wheel chống chỉnh giờ tiến (Season đã keyed tuyệt đối); booster độc quyền joker/lightning/royal/gravity chưa có nguồn nhận miễn phí; Time Attack hết giờ giữa cascade gọi `_finishMove` từ update-loop.

### 🌊 Wave 8.3 — Rhythm Mode (✅ đã làm)
> Chế độ Nhịp điệu signature — ghép gem theo beat. Người dùng chốt làm (1+2+3).
- [x] **`RhythmClock` thuần** (`lib/logic/rhythm_clock.dart`): tích luỹ thời gian trong game loop (KHÔNG `DateTime.now`/`Random` — ràng buộc engine), phán định `onBeat` theo cửa sổ ±0.14s quanh mốc beat (BPM 100). Test inject được.
- [x] **Chế độ riêng `isRhythm`** (tái dùng `ObjectiveType.score` như Gravity → không phải sửa hàng loạt switch): đạt 4000đ trong 30 lượt. `startRhythm`/`tickRhythm`/`judgeRhythmBeat` trong GameController; checkEnd branch riêng (thưởng xu/shard theo sao + groove, KHÔNG đụng win-streak/level-unlock).
- [x] **Engine wiring**: `update()` tiến đồng hồ nhịp; `_trySwap` phán định đúng/lệch nhịp tại nước đi hợp lệ → đúng nhịp `groove++` + thưởng điểm ×1.5..2.5 (theo groove), lệch nhịp `groove--`; đúng nhịp phát `playNote` cao dần theo groove.
- [x] **HUD nhịp**: chấm đập mỗi beat (re-animate theo `rhythmBeat`) + thanh groove 8 nấc + nhãn ĐÚNG/LỆCH NHỊP; badge "NHỊP ĐIỆU"; dialog kết thúc chế độ phụ (không tốn mạng, luôn chơi lại).
- [x] **Home**: khu THỬ THÁCH chuyển lưới 2×2 (Endless/Boss/Gravity/**Rhythm**). Guide thêm section Nhịp điệu. i18n en+vi (`rhythm_*`, `guide_rhythm_*`), 20 ngôn ngữ fallback English (giữ parity).
- [x] **Kết quả**: 0 analyzer issue · **197 test pass** (+10 `test/w8_rhythm_test.dart`).

### 🌊 Wave 8.4 — Co-op / Versus cục bộ (✅ đã làm)
> Chế độ 2 người 1 máy — signature khác biệt vs Candy Crush. Người dùng chốt làm **đầy đủ** (Versus + Co-op + junk gem).
> **Quyết định kiến trúc**: KHÔNG chạy 2 `NeonJewelGame` (Flame) — sẽ entangle với `GameController`/tiến trình (xu/mạng/save) + rủi ro 2 game-loop. Thay vào đó xây subsystem **tách biệt hoàn toàn**, render bằng Flutter widget nhẹ.
- [x] **`VersusBoard` thuần** (`lib/logic/versus_board.dart`): bàn 7×7 tái dùng `MatchDetector` — swap → cascade → trọng lực → refill, cộng điểm, `receiveJunk` (đẩy bàn lên + lấp đáy), `hasMove`. Inject `Random` để test xác định.
- [x] **`VersusController`** (GetX, không đụng tiến trình): 2 bàn độc lập, đồng hồ 60s (Timer thực + `tickSecond` test được), **junk gem**: combo ≥2 → gửi (combo−1) hàng rác sang đối thủ (Versus); **Co-op**: cộng điểm 2 người đạt mục tiêu chung 3000; xác định kết cục (P1/P2/hoà/coopWin/coopLose).
- [x] **`VersusBoardView`** (CustomPaint + vuốt-để-đổi, không Flame) → 2 bàn trên 1 màn không tốn 2 game-loop. **`VersusScreen`**: chọn chế độ → đếm ngược 3-2-1-GO → split dọc (**bàn người trên xoay 180°** ngồi đối diện) + HUD điểm/giờ + panel kết quả + chơi lại.
- [x] **Home**: nút "2 NGƯỜI" rộng (vàng). Guide thêm section. i18n en+vi (`versus_*`, `coop_*`, `guide_versus_*`), 20 ngôn ngữ fallback (giữ parity).
- [x] **Kết quả**: 0 analyzer issue · **211 test pass** (+14: 6 board + 7 controller + 1 widget).
- [ ] *Hạn chế MVP-đầy-đủ (ghi nhận)*: Versus board không có special gem (chỉ match thường + cascade); render tức thời (không animation rơi) cho nhẹ + ổn định 2 bàn.

> 🎉 **HOÀN TẤT 4/4 chế độ signature Wave 8** (Gravity, Boss, Rhythm, Versus/Co-op) + Wave 8.2 audit-fix. Người dùng đã chốt 1+2+3 → done cả 3.

### 🌊 Wave 8.8 — Junk-gem + dọn 3 nợ audit + fix hồi quy + bump lint (✅ đã làm)
> Người dùng chốt làm song song: junk-gem (1) + 3 nợ audit (2) + audit toàn diện (4) + bump deps (3). Audit nền (agent) xác nhận versus cách ly tiến trình SẠCH, không Critical/High.
- [x] **Junk-gem attack (Versus)**: combo ≥3 ở 1 bàn → gửi (combo−2) hàng RÁC sang đối thủ. Engine: `receiveJunk` xếp hàng `_pendingJunk`, áp ở `update()` khi `!_busy` (không phá cascade); `_applyJunk` cho gem rơi từ trên đẩy bàn xuống (mất đáy) + shake + flash magenta "bị tấn công"; tránh tạo match khi rải rác. Callback `onMoveResolved(combo)` ở `_finishMove`; `VersusController._onCombo` định tuyến rác. Verify máy thật: Versus chạy ổn (N1 75đ), không crash.
- [x] **Fix hồi quy (từ audit)**: `_enterMode` reset thêm `isVersus`/`_versusCfg` (bẫy tiềm ẩn nếu tái dùng instance); **mute SFX 2 bàn versus** (`muteSfx` + getter `_sfx`) → hết chồng âm khi cả 2 ghép cùng lúc.
- [x] **Debt #3 — Time Attack race**: hết giờ chỉ `_finishMove` khi `!_busy` → không end giữa chuỗi cascade.
- [x] **Debt #2 — booster độc quyền có nguồn nhận**: thêm `grantColor/Joker/Lightning/Royal/Gravity`; `RewardKind` mở rộng + 5 tier Battle Pass phát joker/color/lightning/gravity/royal (icon + i18n en/vi). Verify máy thật: Battle Pass hiện "1 Joker/Phá màu/Tia sét/Trọng lực/Hoàng gia".
- [x] **Debt #1 — chống chỉnh giờ LÙI**: `_effectiveDay` (ngày không nhỏ hơn ngày cao nhất từng thấy, key `maxDay`) → daily/wheel/quest/season không cho nhận lại quà khi chỉnh giờ lùi. (Chỉnh giờ TIẾN không chặn được offline — chấp nhận, chỉ tự hại.)
- [x] **Bump deps chọn lọc**: `flutter_lints` 5→6 + dọn 5 lint mới (4 unnecessary_underscores + 1 use_null_aware). Engine deps (flame/flame_audio) GIỮ NGUYÊN (bị pin + bump major rủi ro cao trên build đã verify).
- [x] **Kết quả**: 0 analyzer · **210 test pass** (+4 junk wiring) · build APK OK · verify máy thật (Pixel 7 Pro).

### 🌊 Wave 8.7 — Home full-width + REBUILD Versus trên engine Flame (✅ đã làm)
> Phản hồi: (1) Home dư space 2 bên (chuẩn 8/16/24); (2) Versus "quá tệ" — thiếu animation/vật phẩm/cơ chế như mode thường.
- [x] **Home full-width, không scroll**: bug 8.6 co `SizedBox(width:320)` → dư 2 bên. Sửa: `LayoutBuilder` → `SizedBox(width: constraints.maxWidth)` + `FittedBox(scaleDown)` (chỉ co theo CHIỀU CAO khi màn thấp), padding chuẩn `s16`. Verify máy thật: cards full width, không scroll.
- [x] **REBUILD Versus trên `NeonJewelGame` (engine thật)** → đủ juice như mode thường (particle nổ, gem rơi, cascade, special gem, glow). Bỏ hẳn `VersusBoard`/`versus_board_view`/`gem_painter`. Mỗi người 1 `GameController(versus:true)` **cách ly tiến trình**: `_initVersus` (bỏ `_load`), `checkEnd→null`, `addCoins`/`useMove` no-op, không ghi bestCombo. `NeonJewelGame.setInputFrozen`. `VersusController` tạo 2 controller+game; `VersusScreen` render 2 `GameWidget` (bàn trên `RotatedBox` 180°). [[versus-separate-subsystem]]
- [x] **Verify máy thật** (Pixel 7 Pro): 2 bàn full-juice, vuốt ghi điểm (N1 30), timer + "NGƯỜI 1 THẮNG", **Home coins vẫn 50 sau ván** (không hỏng tiến trình), logcat sạch.
- [x] **Kết quả**: 0 analyzer · **206 test pass** (VersusController engine-based; bỏ test board CustomPaint cũ) · build APK OK.
- [ ] *Chưa làm*: junk-gem attack (cần method inject garbage vào NeonJewelGame).

### 🌊 Wave 8.6 — fix UX theo phản hồi máy thật (✅ đã làm — phần Versus đã bị 8.7 thay thế)
> Phản hồi: (1) Home phải scroll; (2) Versus vuốt "không có gì xảy ra" + gem shape kì quặc.
- [x] **Home KHÔNG scroll** (mọi device): bỏ `SingleChildScrollView`, bọc menu trong `FittedBox(scaleDown)` trên `SizedBox` rộng tham chiếu 320 → toàn bộ item tự co vừa 1 màn. Thu nhỏ tiêu đề (NEON 56→46, JEWELS 40→30) + khoảng cách. Bọc hàng circle-nav (Đền/Pass/Mùa + Thành tựu/Hướng dẫn/Cài đặt) trong `Expanded` + nhãn ellipsis → không tràn ngang khi co. Verify máy thật: đủ item, không scroll.
- [x] **Versus gem cùng hình lá bài game chính**: tạo `gem_painter.dart` (`paintGem` — ♥♣♠♦★● + viền neon đôi) dùng cho `VersusBoardView` (trước là ô vuông bo tròn → "kì quặc"). Verify máy thật.
- [x] **Versus có animation swap + phản hồi**: thêm `VersusBoard.wouldMatch` (dry-run); `VersusBoardView` (StatefulWidget + ticker) trượt gem khi vuốt — hợp lệ → trượt rồi đổi thật; KHÔNG match → trượt-nhún rồi trả lại (báo "đã nhận thao tác", hết cảm giác "không có gì xảy ra").
- [x] **Test**: widget test deterministic `versus_board_test.dart` (vuốt hợp lệ→onSwap gọi; vuốt sai→không gọi) + `wouldMatch` unit. **216 test pass** (+3). 0 analyzer · build APK OK · verify máy thật (Pixel 7 Pro USB; S24 rớt USB).

### 🌊 Wave 8.5 — Versus juice + refactor + dọn release (✅ đã làm)
> Người dùng chốt: Versus juice + refactor GameController + bump deps/store. Verify máy thật S24 (SM-S928B) ở các bản trước (Home/Rhythm/Versus/Boss sạch logcat); bản 8.5 verify qua 213 test + build (USB S24 rớt giữa chừng → on-device re-verify 8.5 còn treo).
- [x] **Versus juice**: `VersusBoard` thêm lưới `type` song song → **special gem** (match-4 striped nổ hàng/cột, match-5 rainbow xoá cùng màu, T/L bomb 3×3) + `_expand` lan hiệu ứng; render dấu hiệu special trong `VersusBoardView` (vạch striped / lõi bomb / vòng cầu vồng) + flash nhẹ mỗi nước đi. (+2 test)
- [x] **Refactor GameController**: trích `_enterMode()` (cờ mode độc quyền) + `_resetRunState()` (reset field chung) → 5 hàm `start*` từ ~20 dòng/hàm còn ~5 dòng, BỎ ~60 dòng trùng lặp. **Giữ nguyên API RxBool công khai** (`isBoss.value`…) → không đụng call-site, không hồi quy (213 test xanh).
- [x] **Dọn release**: gom 11 `debugPrint('roy93~')` về helper `dlog()` (`lib/core/debug_log.dart`, gate `kDebugMode` → no-op + tree-shake ở release; dev vẫn thấy log). `flutter pub upgrade` (trong ràng buộc đã mới nhất). Version `2026.06.15`.
- [x] **Kết quả**: 0 analyzer issue · **213 test pass** (+2 special gem) · build APK debug OK.
- [ ] *Chưa làm (rủi ro/ngoài phạm vi)*: 23 package **major bump** (get/flame/win32/xml…) — không bump mù trên build đã verify; nên làm chọn lọc + test lại từng cái. On-device re-verify Wave 8.5 (chờ cắm lại S24).

### 🌊 Wave 6 — Story/Episode + Endless + Theme-per-world + dọn nợ i18n — ✅ đã làm
> Task chi tiết: [`tasks/done/w6-*.md`](tasks/done/). Người dùng chốt làm song song 3 hướng.
- [x] **Story/Episode + nhân vật NPC**: 5 vệ thần neon (1/thế giới, vẽ bằng `CustomPainter` — Luma/Vera/Cir/Ember/Nyx), 15 beat (intro vào world + mid giữa world + outro thắng màn cuối), overlay trong cây (avatar + thoại + vuốt chuyển dòng), chỉ hiện 1 lần/beat. Trigger ở World Map / Level Select (trước pre-game) + sau win màn cuối thế giới. Guide thêm section Cốt truyện.
- [x] **Endless mode (thử thách tăng dần)**: `ObjectiveType.endless` riêng (không dính 100 màn thường); ghép lớn hoàn lượt, lượt hoàn giảm theo stage → cạn lượt thì thua; stage +1 mỗi 1500đ; high score riêng; KHÔNG tốn mạng; nút ENDLESS ở Home; HUD STAGE + panel kỷ lục.
- [x] **Theme đổi màu theo thế giới**: `NeonTheme.accentForWorld` (nguồn duy nhất), `NeonBg` nhận `accent` → tia sweep + nebula theo tông màu world; GameScreen đổi nền theo thế giới màn đang chơi (Endless đổi theo stage).
- [x] **Dọn nợ i18n**: `world_n` + tên 5 thế giới (`world_name_1..5`) dịch đủ **22 ngôn ngữ** (lớp merge `_w6ByLang` — không sửa 22 base map); `level_select`/`world_map` dùng key dịch. Xác nhận đếm ngược hồi mạng ở Home đã tự tick (gỡ nợ Wave 4.2).
- [x] **Kết quả**: 0 analyzer issue · **140 unit/widget test pass** (+12 test Wave 6 ở `test/w6_test.dart`) · build APK debug OK.

> So với CCS: đóng nốt mục **A** (đã có node-map từ W5, nay + theme world) và mục **K** (story/nhân vật). Chỉ còn **J** (leaderboard/cloud — cần backend, đã chốt offline thuần) là chưa làm.

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
| K | ~~**Episode/story + nhân vật** (cốt truyện, NPC dẫn dắt)~~ | ✅ Wave 6 (5 vệ thần neon, 15 beat intro/mid/outro) | 🔴 Cao | ⭐ Cốt truyện |

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
- ~~Theme neon đổi màu theo world (cyan → magenta → green...)~~ ✅ Wave 6
- ~~Chế độ Endless / Zen không giới hạn lượt~~ ✅ Wave 6 (Endless thử thách tăng dần)
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

*Cập nhật lần cuối: 2026-06-18 · Trạng thái: Đang phát triển (Wave 14: 4 hướng song song — Soda mode [fill-based, không đụng gravity] + obstacle Licorice/Jam + meta Album/Heo đất/Giải đấu tuần [offline leaderboard tất định]. i18n 37 key × 22 ngôn ngữ. **309 test pass**, 0 analyzer, build APK OK. Bước sau: verify máy người chơi tự + cân nhắc monetization/release store)*

---

## 🆕 Wave 9 — Thử thách hằng ngày (2026-06-16) ✅ TÍNH NĂNG 1/3

Puzzle chơi theo NGÀY: mọi người chơi **cùng bàn + cùng mục tiêu** trong ngày (engine
nhận `boardSeed = epochDay` → bàn tất định, tái dùng cơ chế mirror của Versus). Mục tiêu
xoay theo ngày (score/collect/jelly/drop/obstacle-ice). Cô lập như Boss/Rhythm: KHÔNG
trừ mạng, KHÔNG đụng win-streak/level-unlock/Battle Pass.

- **Thưởng 1 lần/ngày** + **streak ngày** (🔥) — chơi lại luyện được nhưng không farm xu.
- Thưởng hậu hơn màn thường: `60 + sao×20 + streak(cap7)×10` xu + `3 + sao` shard.
- **Anti-cheat**: tái dùng `_effectiveDay`/`maxDay` (chống lùi giờ). **Đồng thời FIX bug
  có sẵn**: `maxDay` dùng `def: today` ⇒ `today > maxSeen` luôn false ⇒ maxDay KHÔNG
  bao giờ được ghi ⇒ bảo vệ lùi-giờ là **code chết** cho daily reward/wheel/season. Đổi
  `def: 0` → bật lại bảo vệ cho TẤT CẢ tính năng theo ngày (eval cũng đã khuyến nghị).
- UI: card rộng "THỬ THÁCH NGÀY" ở khu Thử thách (badge streak/PLAY/✓done) + panel kết
  quả riêng + tiêu đề HUD. i18n EN/VI (`daily_ch_*`).
- Files: `levels.dart` (`buildDailyLevel`), `storage_service.dart` (3 key), `game_controller.dart`
  (`startDaily`/`boardSeed`/checkEnd daily + fix maxDay), `game_screen_controller.dart`,
  `game_screen.dart`, `home_screen.dart`, `app_translations.dart`.

Kết quả: 0 analyzer · **224 test pass** (+10 `test/w9_daily_challenge_test.dart`: tất định
seed, thưởng-1-lần, streak liền/gãy, anti-cheat lùi giờ, thua) · build APK debug OK ·
**verify máy thật S24 Ultra** (WiFi adb): card Home render đúng, tap vào chơi OK, HUD
"THỬ THÁCH NGÀY", bàn seed theo ngày (2026-06-16 = clearObstacle/ice 0/32, 33 lượt — khớp
công thức), logcat sạch exception app.

## 💎 Wave 9 — Diagonal gem (2026-06-16) ✅ TÍNH NĂNG 2/3

Special gem mới thứ 6: **Diagonal** — tạo từ **match 6+** (match 5 vẫn rainbow), nổ **2
đường chéo (hình X)** qua ô. Wire trọn vẹn qua 5 điểm:
- `GemType.diagonal` (enum) → compiler ép xử lý đủ mọi `switch` (an toàn).
- `MatchDetector._buildGroup`: len==5 → rainbow, len>=6 → diagonal.
- `MatchDetector.diagonalCells(rows,cols,center,{thickness})` — hình học chéo **thuần,
  test được** (engine `_addDiagonals` chỉ gọi lại).
- `_expandSpecials`: kích hoạt diagonal → 2 beam neon dọc chéo + phá mọi ô cùng chéo.
- `_comboCells` — **full combo**: diagonal+diagonal → X DÀY (±1); diagonal+striped → hoa
  thị (2 chéo + hàng + cột); diagonal+bomb → 2 chéo + 3×3; rainbow+diagonal → cùng màu +
  X qua pos.
- `gem_component._renderSpecial`: vẽ 2 vạch neon chéo X + lõi sáng nhịp.

Kết quả: 0 analyzer · **235 test pass** (+11 `test/w9_diagonal_gem_test.dart`: match-length→
special, diagonalCells X 14 ô/góc 8 ô/thickness/biên) · build APK OK.

## 💰 Wave 9 — Gộp tiền tệ về 1 loại xu (2026-06-16)

Theo yêu cầu người dùng: **bỏ shard, mọi thứ dùng xu**. Trước đây shard chỉ tiêu cho Đền
Neon → tích thừa (đúng vấn đề eval). Refactor 13 file:
- **Quy đổi 1 shard = 10 xu**: migrate shard cũ → xu (`_migrateShardsToCoins`, guard
  `shardsMigrated` chạy 1 lần, KHÔNG mất tiến trình người chơi).
- Mọi nguồn thưởng shard (boss/rhythm/daily/normal/battle-pass/season) **gộp ×10 vào xu**.
- Đền Neon: chi phí tier ×10, tiêu xu (`spendCoins`); bỏ `RewardKind.shards` (enum),
  `shards` Rx, `addShards`/`spendShards`/`_setShards`/`lastShardReward`.
- UI: bỏ shard chip/diamond icon ở Temple + dialog thưởng; i18n bỏ "shards".
- **Bonus**: đơn giản hoá GameController (bớt 1 trục tiền tệ).

Kết quả: 0 analyzer · **235 test pass** (w7_test viết lại cho coin + 2 test migrate) · verify
máy thật (xu hiển thị đúng, Đền Neon tiêu xu).

## 🎨 Wave 9 — Revamp Home: no-scroll, full-width, lưới Thử thách 2×3 (2026-06-16)

Người dùng phản ánh menu Home **dư lề trái/phải** + yêu cầu **KHÔNG scroll** + bố cục Thử
thách hài hoà hơn. Gốc rễ: nội dung quá cao cho 1 màn no-scroll → `FittedBox(scaleDown)`
co ĐỒNG ĐỀU 2 chiều để vừa cao → sinh lề ngang. Không widget đơn nào "chỉ co chiều cao"
→ giải pháp đúng là **nén nội dung vừa khít** để FittedBox khỏi co (full-width) mà vẫn
giữ FittedBox làm lưới an toàn (no-scroll tuyệt đối).

Đã làm:
- **Nén để vừa 1 màn**: logo nhỏ lại (NEON 46→34, JEWELS 30→20), GemSparkle nhỏ; gộp khu
  "Giữ chân" (Đền/Pass/Mùa) + "Tiện ích" (Thành tựu/Hướng dẫn/Cài đặt) thành **1 hàng 6
  icon nhỏ** (bỏ 1 hàng + divider, tiết kiệm ~140px).
- **Revamp Thử thách → lưới đều 2×3**: 6 ô VUÔNG bằng nhau (HẰNG NGÀY · VÔ TẬN / TRÙM ·
  TRỌNG LỰC / NHỊP · 2 NGƯỜI) dùng chung `_modeCard` → hết cảnh card rộng/vuông lẫn lộn &
  "2 người" trống trải. Daily nổi bật bằng **màu lime + badge góc** (🔥streak / ✓done, qua
  Obx). `_modeCard` thêm tham số `corner`; bỏ `_dailyChallengeCard`. i18n `daily_ch_short`.
- Spacing chuẩn 8/16/24 xuyên suốt.

Verify S24 Ultra: full-width, **không scroll**, lưới 2×3 cân đối, logcat sạch (không
overflow/RenderFlex). Bẫy đã ghi memory `home-fullwidth-no-fittedbox`.

## 🛒 Wave 9 — Cửa hàng trang trí: skin gem + theme bàn (2026-06-16) ✅

Tính năng cuối Wave 9 — coin-sink cho kinh tế xu. Mua bằng xu, KHÔNG ảnh hưởng gameplay
(6 màu luôn phân biệt).
- **6 skin gem** (Classic miễn phí + 5 trả phí 300→900 xu): mỗi skin đổi **bộ 6 màu + họ
  hình (3 họ: lá bài / hình học / tinh thể) + hệ số glow**. `lib/data/cosmetics.dart`
  (`GemSkin`, `BoardTheme`, `ActiveCosmetics` — holder TĨNH cho tầng render Flame đọc không
  cần Get.find mỗi frame). `gem_component`: `neonColorOf` + `_shapePath(family,…)` + glow
  đọc `ActiveCosmetics.gemSkin` → mọi particle/beam/flash tự khớp skin.
- **6 theme bàn** (Midnight miễn phí + 5 trả phí 300→800 xu): đổi 2 màu viền neon + tông ô.
  `BoardFrame` (effects.dart) đọc `ActiveCosmetics.boardTheme`.
- **Kinh tế**: `GameController.buySkin/selectSkin/buyTheme/selectTheme` (cộng quyền sở hữu
  TRƯỚC khi trừ xu, giống `_buy`), `RxSet ownedSkins/ownedThemes` + `RxString selectedSkin/
  Theme`, load trong `_load` (`_loadCosmetics`), xoá sạch trong `resetProgress`. Item miễn
  phí luôn sở hữu; mua xong tự trang bị.
- **`ShopScreen`** (NeonAppBar + NeonBg + CoinChip): 2 mục (skin/theme), thẻ có preview
  CustomPaint (palette+hình / khung viền) + nút mua(💰giá)/DÙNG/ĐANG DÙNG; thiếu xu → snackbar.
  Home thêm nút "CỬA HÀNG" (icon storefront) ở hàng meta.
- **i18n**: 5 nhãn shop (`shop_*`) dịch đủ **22 ngôn ngữ** (en/vi + 20 qua `_w8ByLang`) →
  KHÔNG tái mở lỗ hổng i18n vừa vá.
- **Test đầy đủ** (theo yêu cầu): **unit** `test/w9_shop_test.dart` (10: mặc định/mua/thiếu
  xu/chọn-chưa-sở-hữu/persist-reload/reset), **widget** `test/widget/shop_screen_test.dart`
  (3: render + mua + thiếu xu snackbar), **integration** `app_test.dart` (+1: Home→Shop→mua).
- **Thông báo mua dùng dialog chung** (NeonDialog, KHÔNG SnackBar): mua thành công →
  dialog tên item + "ĐANG DÙNG" (icon ✓ lime); thiếu xu → dialog "Không đủ xu" (icon ví,
  vàng) + nút ĐỒNG Ý. ShopScreen là route Flutter thuần (không Flame) nên `NeonDialog.show`
  hoạt động (giống Settings). Tái dùng key `confirm`/`not_enough_coins`/`shop_equipped` đã
  dịch sẵn → KHÔNG thêm key i18n.
- **Xu khởi điểm theo build**: debug 10000 (dễ test mua), release/profile 100 (`kDebugMode`
  trong `_load`). Trước là 50.
- **Kết quả**: 0 analyzer · **250 test pass** · build APK debug+profile OK.
- **✅ Verify máy thật S24 Ultra (SM-S928B)**: chụp màn Home (nút CỬA HÀNG, 💲100 release),
  Shop (6 skin hình/màu khác nhau + 6 theme bàn), dialog "Không đủ xu" neon (skin & theme),
  gem trong game render đúng (6 chất bài + glow + khung theme).
- **FIX 2 integration test flaky** (chạy trên S24 → **9/9 PASS** từ state mới):
  - *Gốc rễ*: màn 1 trên state mới kích hoạt **cốt truyện intro** (`_play`→`StoryController
    .maybeShow`) TRƯỚC pre-game; test cũ không bỏ qua → "CHUẨN BỊ" không hiện (trên iQOO cũ
    story đã xem nên "may mắn" pass). Thêm `skipStoryIfAny`.
  - *Gốc rễ 2*: pre-game **chỉ hiện khi còn booster** (`PregameController.hasAny`); hết
    booster (state tích luỹ) → vào thẳng game, không có nút "CHƠI NGAY" → `play_now.last`
    ném "No element". Helper `enterLevelOne` chịu được CẢ HAI nhánh (có/không pre-game) →
    test độc lập thứ tự chạy & state đĩa.

## 🧹 Wave 9 — Dọn nợ kỹ thuật (widget tái dùng + durability) (2026-06-16)

Dọn nợ "rủi ro thấp" từ eval Wave 8.9 (DRY + durability):
- **Gom `_coinChip` ×4 → widget chung `CoinChip`** (`lib/presentation/widgets/coin_chip.dart`):
  4 bản gần giống nhau ở Temple/Achievements/Level Select/World Map → 1 widget reactive
  (Obx coins). Temple bỏ luôn helper `_chip` (chỉ dùng cho coin).
- **Gom `_fmtDur`/`_fmt` ×3 → hàm chung `fmtDur`** (`lib/core/utils/format.dart`): bản mm:ss
  giống hệt ở Home/Level Select/World Map. (season `_fmtCountdown` riêng — bản duy nhất.)
- **Siết durability `levelUnlock`**: ghi đĩa (`setInt` coins/coinsEarned/unlockedLevel)
  TRƯỚC rồi mới cập nhật state RAM (`coins.value`...) → app bị kill giữa chừng không làm
  RAM lệch đĩa (tránh hiển thị xu/unlock chưa kịp lưu).
- *Bỏ qua*: magic-number layout → const (mơ hồ, ROI thấp, dễ tạo noise) — để khi cần.
- **Kết quả**: 0 analyzer issue · **237 test pass** (không hồi quy).

## 🌍 Wave 9 — Đóng lỗ hổng i18n: dịch đủ 20 ngôn ngữ (2026-06-16)

Sửa **blocker CRITICAL** từ eval Wave 8.9: 20/22 ngôn ngữ chỉ dịch ~50% (Wave 5/7/8/9
fallback tiếng Anh). Nay dịch đủ.

- **129 key** W5/7/8/9 (achievements, battle-pass, season, neon temple, versus/co-op,
  tutorial, npc story, daily challenge, quest, rhythm, boss...) trước đây thiếu cho 20
  ngôn ngữ → dịch bằng **20 agent song song** (1 ngôn ngữ/agent).
- **Map mới `_w8ByLang`** trong `app_translations.dart` (20 map `_w8<lang>`) + merge
  `...?_w8ByLang[e.key]` sau `_w6ByLang` — KHÔNG đụng 22 base map (pattern `_extra`/`_w6`).
- **Kết quả dịch**: mỗi ngôn ngữ giờ **86.4% (Fil) → 97.7% (Tr)** value khác EN (trước
  ~50%). Key còn giữ EN là tên riêng NPC (Luma/Vera/Cir/Ember/Nyx) + thuật ngữ game
  (VERSUS/CO-OP/GROOVE/P1/P2/tên season) — hợp lệ. Placeholder `@n`/`@c`/`@t`/`@s` giữ
  nguyên (validate 0 lỗi).
- **Siết test** (`app_translations_test.dart`): bỏ "ru ngủ" — thêm (1) mỗi ngôn ngữ ≥80%
  value ≠ EN (chống fallback hàng loạt nếu feature mới quên dịch 20 ngôn ngữ); (2) mẫu
  key W5/7/8/9 × 11 ngôn ngữ ≠ EN + placeholder còn nguyên.
- **Kết quả**: 0 analyzer issue · **237 test pass** (+2 i18n). App **sẵn sàng phát hành
  đa ngôn ngữ**.

## 🧹 Wave 10 — Dọn nợ kỹ thuật: tách GameController + centralize font (2026-06-17)

Người dùng chốt làm tuần tự: dọn nợ (option 4) → thêm gameplay mới (option 3).
Phần dọn nợ:

- **Tách GameController god-controller** (1165 LOC → 8 file, file lớn nhất 312):
  giữ NGUYÊN là MỘT class qua `part`/`extension`. File chính `game_controller.dart`
  giữ toàn bộ Rx field + `static const` + constructor + `onInit`/`_load`/`_enterMode`/
  `_resetRunState` + getter `level`; 7 part file = 7 extension theo trách nhiệm
  (`_modes`/`_scoring`/`_economy`/`_booster`/`_cosmetics`/`_lives`/`_progress`).
  **Public API + mọi call-site + Get.find + Obx + test giữ y nguyên** → né rủi ro
  "tách thành controller riêng" mà eval Wave 8.9 cảnh báo. Memory:
  `game-controller-part-extension-split`.
  - *Cạm bẫy gặp & fix*: extension scope KHÔNG truyền qua import lồng → `w8_versus_test`
    (chỉ import `versus_controller`) vỡ `addScore/addCoins/checkEnd/useMove`; thêm import
    trực tiếp `game_controller.dart`. Static const trong extension prefix `GameController.`.
- **Centralize font**: thêm `NeonTheme.fontFamily = 'Baloo2'` + set `ThemeData.fontFamily`
  trong `main.dart` → Baloo2 là default app-wide (mọi Text MỚI kế thừa, khỏi lặp string).
  *Không* mass-remove 106 dòng `fontFamily: 'Baloo2'` cũ (vô hại, churn cao, eval đã
  rate ROI thấp — để khi cần).
- *Bỏ qua (như eval khuyến nghị)*: magic-number layout → const (mơ hồ, dễ tạo noise);
  tách economy/clock thành service riêng (đã đạt mục tiêu bằng part/extension).

Kết quả: 0 analyzer issue · **250 test pass** (không hồi quy) · build sạch.

## 🎮 Wave 10 — 4 gameplay feature mới (2026-06-17)

Người dùng chốt KẾT HỢP cả 4 (làm chung 1 wave vì đụng file lõi chung —
levels/controller/engine/HUD/i18n; song song subagent sẽ xung đột).

- **Mục tiêu hỗn hợp (Order mode)**: `ObjectiveType.order` + `OrderGoal(color,target)`.
  Weave vào 3 màn score `kOrderLevels={37,67,97}` (giữ NGUYÊN kRotatingObjectives →
  không xô lệch). Thu đủ 3 màu cùng lúc. `orderProgress` (RxList) cập nhật trong
  `registerClear`; hasWon = mọi mục tiêu đạt; HUD multi-chip màu; đi qua nhánh
  win thường (tính win-streak/unlock). Test `w10_order_test` (7).
- **Bom đếm ngược**: hazard trên màn score `kBombLevels={31,49,79}` (KHÔNG thêm
  ObjectiveType). Engine sở hữu lưới `bomb` (>0 = đếm ngược). Mỗi lượt `_tickBombs`
  giảm 1; về 0 chưa tháo → `controller.bombExploded=true` → checkEnd cho THUA
  (win ưu tiên trước). Tháo = clear gem trên ô bom (`_defuseBombs`). `BombLayer`
  vẽ số đếm + cảnh báo magenta nhịp khi ≤3. HUD dải bom. i18n `bomb_left/timer`
  (en+vi). Test `w10_bomb_test` (7: cấu hình + lose-contract + mount seed).
- **Light Ball (special gem thứ 7)**: `GemType.lightBall`. Đổi rule: match 6 →
  diagonal, **≥7 → lightBall** (tầng cao nhất, hiếm = jackpot). Nổ = sao 8 hướng
  (hàng+cột+2 chéo) qua `MatchDetector.lightBallCells` (pure, test được). Combo:
  LB+LB → cả bàn; LB+special → sao DÀY (±1) + special kia tự kích hoạt. Render
  4 vạch + 8 tia xoay + lõi trắng. Test `w10_light_ball_test` (6) + cập nhật
  `w9_diagonal_gem_test` (match-7 nay lightBall) + `widget_test` (GemType=7).
- **Shader glow neon**: `shaders/neon_glow.frag` (fragment shader, runtime_effect)
  → `NeonGlowAura` (1 draw/frame, priority -9 dưới gem). Nạp async qua
  `FragmentProgram.fromAsset` trong engine onLoad, **try/catch → tự tắt nếu GPU/nền
  tảng không hỗ trợ** (fallback giữ hình ảnh cũ; tránh tái diễn lag glow lịch sử).
  KHÔNG thay NeonFx.drawGlow (hot path 50+/frame). Compile OK qua impellerc (build).

Kết quả: 0 analyzer · **271 test pass** (+21: order 7, bomb 7, light ball 6, +1 chỉnh
GemType count) · build APK debug OK.

**Audit (8.5/10) + sửa polish (2026-06-17)**: đã verify đọc-code 5 điểm rủi ro (RxList
`[]=` refresh OK; màn score KHÔNG tick bom mỗi frame — dòng 309 gate timeAttack; retry
reset `bombExploded`; win ưu tiên trước bom nổ; switch enum vá đủ). Đã sửa 3 polish:
(1) màu Order xoay theo level (`base=(index~/7)%n` + 3 màu liên tiếp → 37/67/97 khác bộ,
hết trùng trio); (2) cân bằng Order (`per=7+index~/16`, moves `+12` → màn 97 còn 13×3=39
mục tiêu / 27 lượt); (3) Guide thêm section "Tính năng mới" (Light Ball + Bom đếm ngược
+ Mục tiêu hỗn hợp) — i18n **en+vi**, 20 ngôn ngữ fallback EN (coverage test ≥80% vẫn
PASS). Shader thuần visual → không vào Guide.

**✅ Verify máy thật (Pixel 7 Pro, Android 16, Impeller/Vulkan) — 2026-06-17**:
- Boot sạch · Home/World Map/Story/Pregame/Board render đúng · logcat KHÔNG exception
  (chỉ warning `AIBinder_linkToDeath` của plugin, vô hại).
- **Shader**: log `Using the Impeller rendering backend (Vulkan)` + `neon_glow.frag`
  nạp & chạy KHÔNG lỗi (không rơi fallback) → shader OK trên GPU thật.
- **Bom** (qua build tạm thêm màn 1 vào kBombLevels, đã revert): HUD "Bom: 3 · Đếm:12",
  3 quả bom vẽ số đếm, LƯỢT 30 (đúng +4 bonus). Sau 1 nước hợp lệ: Đếm 12→11 (tick
  đúng 1/lượt), Bom 3→2 (tháo khi clear gem ô bom), 3 swipe sai KHÔNG tốn lượt. ✓
- *Chưa thấy trực quan (đã unit-test, rủi ro thấp)*: Order (màn 37), Light Ball
  (match-7 hiếm), bom NỔ→thua (mới chỉ tháo kịp). fps: Flutter surface không vào
  gfxinfo; định tính chỉ 1 frame-skip lúc vào bàn (debug), còn lại mượt.
- Nợ nhẹ: dịch Guide 4 feature cho 20 ngôn ngữ (đang fallback EN; coverage test ≥80% pass).

## 💱 Wave 10 — Định dạng tiền tệ/số (2026-06-17)

Người dùng phản ánh xu hiển thị số thô (10000) thiếu phân tách hàng nghìn. Thêm
`fmtNum(int)` (`lib/core/utils/format.dart`) — dùng `NumberFormat` (intl) theo
`Get.locale`: **vi → "10.000", en → "10,000"**, có fallback nhóm thủ công nếu locale
lạ (không bao giờ ném lỗi). Thêm `intl: ^0.20.2` vào pubspec (trước là transitive).

Áp cho TẤT CẢ hiển thị xu + số lớn (bỏ qua số nhỏ không phải tiền: lượt/mạng/stage/
streak/mục tiêu): CoinChip (4 màn), coin chip Home + in-game, giá booster, giá shop
(skin/theme), chi phí Đền Neon, thưởng thành tựu/season/battle-pass/vòng quay/daily,
thưởng thắng ván, điểm/điểm mục tiêu/high-score/endless-best/máu boss (HUD + dialog +
_objectiveText). 17+ site.

Kết quả: 0 analyzer · **276 test pass** (+5 `test/w10_format_test.dart`: vi/en separator,
số âm, locale null không lỗi) · build OK · **✅ verify máy Pixel 7 Pro**: chip xu hiện
"10.000" (locale vi), logcat sạch.

## 🔧 Wave 11 — Audit chất lượng + dọn nợ (2026-06-17)

Người dùng chốt làm tuần tự: **audit (option 4) → gameplay mới (option 3)**. Phần audit:
4 agent đọc song song 4 tầng (engine+logic / controllers / UI+widgets / core+data+i18n),
mỗi phát hiện xác minh bằng đọc code kèm `file:line`. Tầng core/data+i18n **sạch** (chỉ nợ
latent nhỏ). Đã sửa 3 lỗi HIGH đã xác minh:

- **[HIGH] Bộ bug chế độ Trọng lực (Gravity) — "quên 1 mode" lan 4 chỗ**: `checkEnd`
  KHÔNG có nhánh `isGravity` → Gravity (chế độ phụ, dùng `buildGravityLevel`, không set
  `currentLevel`) rơi vào **nhánh màn thường**: thắng → `winStreak++` + `_saveProgress`
  (ghi high-score + **mở khoá màn kế = currentLevel tồn đọng**); thua → `consumeLife` +
  reset win-streak. Đồng thời `again()` thiếu nhánh Gravity (chơi lại biến thành màn
  thường + bị cổng mạng chặn), `_resultPanel` thiếu nhánh Gravity (hiện nút "TIẾP THEO"
  sai). **Sửa**: thêm nhánh `isGravity` vào `checkEnd` (side-mode: thắng theo điểm,
  thưởng `20+sao×10`, KHÔNG đụng win-streak/unlock/mạng) + nhánh `again()` + nhánh
  `_resultPanel`. Gom getter **`GameController.isSideMode`** (Endless/Boss/Gravity/Rhythm/
  Daily/Versus) thay 3 điều kiện `!isEndless && !isBoss && !isDaily` trong `_onGameEnd`
  → **đồng thời sửa Rhythm cũng bị trừ mạng + ghi BattlePass/Season oan** (cùng class lỗi).
- **[HIGH] `_doColumnFlip` lật bàn KHÔNG đầy đủ**: chỉ swap `color`+`type`, bỏ qua cờ gem
  (`isIngredient`/`isLucky`/`isJunk`) + 3 lưới theo ô (`obstacle`/`bomb`/`jelly`). Chế độ
  Trọng lực động dùng bàn score thuần (vô hại), nhưng **booster Gravity Flip dùng được ở
  MỌI màn** → ở Drop Down ingredient kẹt sai ô, ở màn obstacle/bom băng/đá/bom desync khỏi
  màu. **Sửa**: lật đầy đủ cả lưới phụ (trước null-check) + toàn bộ cờ gem giữa ô đối xứng.
- **[HIGH] Race `lastCoinReward`**: `checkEnd` set `lastCoinReward` THIẾU phần `(1+sao)×10`
  rồi `unawaited(_saveProgress)`; `_onGameEnd` đọc NGAY (đồng bộ) truyền vào BattlePass
  `recordLevelEnd` → quest **earnCoins đếm thiếu** khi lập high-score mới (vì bonus chỉ
  cộng SAU `await` đầu của `_saveProgress`). **Sửa**: tính đủ `lastCoinReward` đồng bộ
  trong `checkEnd`, `_saveProgress` chỉ persist (bỏ `+=`). Tổng xu cuối KHÔNG đổi.

**Kết quả**: 0 analyzer issue · **280 test pass** (+4: 3 gravity side-mode isolation /
isSideMode + 1 lastCoinReward đồng bộ) · không hồi quy.

**Nợ ghi nhận (chưa sửa — ROI thấp / cần quyết định cân bằng)**: (a) `coinsEarnedTotal`
(achievement "tổng xu kiếm") chỉ đếm màn thường, bỏ sót boss/rhythm/daily/wheel/season/
BP/đền → mâu thuẫn comment "lifetime"; sửa = đổi nhịp achievement (quyết định balance, để
hỏi). (b) `_findMove`/auto-shuffle không nhận diện nước "đập 2 special kề nhau" → có thể
xáo bàn oan phá special (tần suất thấp). (c) combo-trigger 2-special ghi điểm combo cứng=2.
(d) `fmtDur` chưa guard Duration âm + `fmtNum` fallback luôn dấu "." (đều latent, chưa kích
hoạt). (e) `fontFamily:'Baloo2'` lặp ~100 chỗ (đã có default app-wide, vô hại). (f)
`_TemplePainter.shouldRepaint` luôn true; `_LivesChip` cancel Timer trong build (nhánh full).

## 🎮 Wave 11 — 4 gameplay mới (2026-06-17)

Người dùng chốt làm **cả 4** (Color Rush + Băng chuyền + Cổng + Dispenser), song song,
cập nhật task `doc/tasks/`. Vì cả 4 đụng cùng bộ file lõi (levels/controller/engine/HUD/
i18n) → làm như MỘT wave phối hợp (code tuần tự, tránh xung đột file), KHÔNG fan-out
subagent. Cả 4 thiết kế **tránh đụng gravity/refill** (phần dễ vỡ theo audit) → hook vào
điểm an toàn.

- **Color Rush (chế độ phụ)**: màu "nóng" đổi mỗi 4 lượt (tất định cyclic); clear gem màu
  nóng → +15đ/gem (cộng thẳng). Đạt 3500đ trong 30 lượt. Cờ `isColorRush` + `buildColorRush
  Level` + `startColorRush` (vào `isSideMode` — KHÔNG đụng mạng/streak/unlock); checkEnd
  nhánh riêng (thưởng 20+sao×10). HUD chip "MÀU NÓNG ●", nút Home full-width nổi bật.
- **Băng chuyền (weave màn score {25,61})**: hàng băng chuyền dịch gem 1 cột/lượt (cyclic,
  wrap mép) sau khi settle → re-settle. Logic thuần `conveyorNewCol` (test bijection/wrap).
  Engine `_advanceConveyor()` (hoán vị + animate trượt/teleport mép). `ConveyorLayer` mũi
  tên chạy. +5 lượt cho công bằng.
- **Cổng dịch chuyển (weave {43,85})**: cặp ô liên kết — clear 1 đầu → ECHO clear đầu kia
  (1 hop). Logic thuần `buildPortalLinks`/`expandPortals` (2 chiều). Engine mở rộng tập
  clear trong `_clearCells`. `PortalLayer` vòng xoáy cặp màu. (MVP: echo = clear trực tiếp,
  không kích special đối tác.)
- **Ô phát special / Dispenser (weave {13,19})**: ô nguồn mỗi N lượt biến gem thường tại
  đó thành special (striped/bomb). `_tickDispensers()` trong `_finishMove`; `dispenser
  Countdown` Rx + `DispenserLayer` lõi sáng + số đếm.

Kiến trúc: theo đúng pattern weave `kBombLevels` (tra cứu spec theo chỉ số màn ở engine).
Logic thuần tách ở `lib/logic/board_mechanics.dart`. Chọn 6 màn score chưa dùng (≡1 mod 6,
không trùng order/spread/bomb): 13/19/25/43/61/85. Getter `isSideMode` đã có (Wave 11 audit)
→ Color Rush chỉ thêm 1 cờ vào getter + 1 nhánh checkEnd/again/resultPanel. i18n en+vi
(`color_rush_*`/`conveyor_title`/`portal_title`/`dispenser_title`/`guide_w11_*`), 20 ngôn
ngữ fallback EN (coverage test ≥80% vẫn PASS). Guide thêm section "Cơ chế mới".

**Kết quả**: 0 analyzer issue · **292 test pass** (+12: 4 pure board_mechanics + 2 level spec
+ 6 Color Rush) · build APK debug OK.

**✅ Verify máy thật (S24 Ultra SM-S928B, USB, Impeller/Vulkan) — 2026-06-18**:
- Home: card "TRUY QUÉT MÀU" full-width render đúng (icon lửa + chevron), no-scroll.
- Color Rush: badge "TRUY QUÉT MÀU" + chip "MÀU NÓNG ●" (cyan) + HUD 0/3.500·LƯỢT 30; chơi
  được (match → ĐIỂM↑, LƯỢT 30→29, swap sai revert không tốn lượt).
- 3 cơ chế (qua build tạm weave màn 1, đã revert): màn 1 hiện đủ 3 badge "BĂNG CHUYỀN·CỔNG·
  Ô PHÁT 4"; LƯỢT 31 (=26+5 conveyor); **dispenser đếm 4→3→2** mỗi lượt; băng chuyền dịch gem
  tạo cascade lớn (**WOMBO COMBO x6**); thắng → CHIẾN THẮNG ⭐⭐⭐ +80 xu, coins 10.000→10.085
  (persisted). Logcat sạch (không exception app; chỉ Monkey launcher + reflection thường).
- **FIX phát hiện khi test**: tutorial lần-đầu BẬT NHẦM ở Color Rush/Rhythm/Daily (guard chỉ
  loại Endless/Boss/Gravity) → cùng class "quên mode" → đổi sang `!isSideMode`. Verify lại:
  vào Color Rush KHÔNG còn tutorial. [[side-mode-isolation]]

## ⚖️ Wave 12 — Audit-fix: cân bằng + bù Wave 11 + hiệu năng + nội dung (2026-06-18)

Sau verify máy thật Wave 11, người dùng thấy "chưa nên release" → audit lại 3 góc CHƯA soi
(Wave 11 đụng cùng thời điểm audit cũ): tương tác cơ chế mới, cân bằng/kinh tế, hiệu năng.
Kết luận audit: **không phải code-correctness mà là CÂN BẰNG**. Người dùng chốt làm cả 3.

**Phase A — Cân bằng (blocker chính):**
- **Đường cong độ khó**: target tuyến tính (1000+index*220) + moves co → L43+ score cần
  500-1231đ/lượt, L74+ collect 3-4.2 gem/lượt = BẤT KHẢ THI. Sửa: gắn target với SỐ LƯỢT
  (`_scoreTarget` 45→100đ/lượt, `_collectTarget` ≤1.2/lượt, `_timeTarget` 36→60đ/giây) →
  độ khó = ít slack dần (kiểu CCS), luôn khả thi. Test regression chống tường tái phát.
- **Chống lạm phát** (kiếm ~1660/ngày, mua hết ~5 ngày): `discountSideModeReward` — 3 trận
  side-mode đầu/ngày full, sau ×0.3 (chống farm Boss 180xu vô hạn). Gravity/ColorRush bump
  50→75. Endless thưởng xu theo stage (endgame loop, trước=0). `coinsEarnedTotal` đếm MỌI
  nguồn (sửa nợ "lifetime").

**Phase B — Bù lỗi Wave 11 + hiệu năng:**
- **[HIGH] "1 lượt = 1 tick"**: `_finishMove(consumed)` → dùng booster (không tốn lượt)
  KHÔNG tick dispenser/bom/colorRush (trước: bơm dispenser lợi + bom nổ free hại).
- **[MED] Điểm ô cổng**: expandPortals TRƯỚC addScore (khớp số gem thực nổ).
- **[HIGH perf] GemComponent**: cache Path + RadialGradient shader (trước tạo 64 shader/
  frame — hotspot fps lớn nhất) → dựng lại chỉ khi (color/shape/junk) đổi.
- **[MED perf]** BombLayer/DispenserLayer cache TextPainter theo số (`_NumTextCache`).

**Phase C — Chiều sâu nội dung:**
- +7 thành tựu tier cao (Champion/Legend/Perfectionist/Tycoon... wins 60/100, stars 180/
  300, combo 12, streak 12, coins 5000) — i18n title đủ **22 ngôn ngữ**.
- Endless thưởng xu (endgame loop). Dịch đủ 16 key Wave 11/12 cho 20 ngôn ngữ (coverage
  ≥80% pass lại — trước tụt 79.17% do thêm key EN-fallback).

**Kết quả**: 0 analyzer · **294 test pass** (+2 regression: curve khả thi + farm cap; +
sửa test achievement/gravity/colorRush reward) · build APK OK. *Verify máy: người dùng tự
test trên Pixel 7 Pro.*

> ⚠️ Còn nợ (ghi nhận): chưa có monetization (ads/IAP) — feat.md từng nhắc AppLovin nhưng
> KHÔNG có trong source; game thuần offline, chưa có mô hình doanh thu. Đường cong mới cần
> playtest pass-rate thực tế để tinh chỉnh.

## 🧪 Wave 13 — Dọn nợ + Auto-playtest validate cân bằng (2026-06-18)

Người dùng chốt kết hợp option 3 (dọn nợ) + option 1 (auto-playtest).

**Phase 1 — Dọn nợ audit:**
- `_findMove` + `comboMove`: nhận nước "đập 2 special kề / swap rainbow" (combo trigger
  KHÔNG tạo match màu) → auto-shuffle không còn phá special người chơi đang giữ.
- **Cổng echo KÍCH special**: `_expandSpecials` SAU `expandPortals` → clear ô đối tác cổng
  mà là special thì nổ dây (trước clear trơn).
- `_burstCap=16`: cap particle-burst gem THƯỜNG ở cascade lớn (special không giới hạn).
- Bỏ **81 dòng `fontFamily:'Baloo2'` thừa** ở file widget thuần (ThemeData default lo);
  GIỮ trong file CustomPainter (bắt buộc, không ThemeData).

**Phase 2 — Auto-playtest simulator (`tool/playtest.dart`):**
- Bot greedy Monte Carlo + mô hình special (match-4 nổ hàng+cột, match-5 xoá màu) chơi
  mỗi màn 120 lần bằng `MatchDetector` + công thức điểm THẬT → báo pass-rate/điểm TB.
- **PHÁT HIỆN bằng DATA**: curve Wave 12 (dù đã bỏ tường 1231đ/lượt) vẫn để **TimeAttack
  ~0%** + nửa sau gắt cho bot không-booster. → TINH CHỈNH: `scorePerMove` 42→82 (was
  45→105), `timePerSec` 22→34 (was 35→60), collect cap ~1 gem/lượt, **moves sàn 15→17**.
- **KẾT QUẢ sau tinh chỉnh**: **0 màn "quá khó"** (tất cả ≥58% với bot KHÔNG booster →
  người chơi thật cao hơn ~1.5-2×). Score 78-100%, Collect 71-100%, TimeAttack 58-100%.
  Phân bố mượt: early dễ (onboarding) → late thách thức công bằng.

**Kết quả**: 0 analyzer · **294 test pass** · build APK OK. Đường cong độ khó nay được
**validate bằng dữ liệu** (chạy lại `dart run tool/playtest.dart` bất cứ lúc nào).

## 🌊 Wave 14 — 4 hướng song song: Soda mode + obstacle mới + 3 meta (2026-06-18)

Người dùng chốt làm **CẢ 4** hướng. Hướng 1+2 đụng engine (làm tuần tự cẩn thận,
tránh vỡ gravity/refill); hướng 3+4 là meta tự chứa (bắt chước pattern Season/Temple).

- **Soda / Ngập nước (chế độ phụ mới)**: `ObjectiveType.soda` + `isSoda` (vào
  `isSideMode`). Thiết kế **fill-based KHÔNG đụng gravity**: mỗi gem clear (kể cả
  cascade) làm `sodaFill++` qua `registerClear`; mỗi `kSodaFillPerBottle` (20) →
  1 chai nổi; đủ `kSodaBottles` (3) chai → thắng. `SodaLayer` (effects.dart) vẽ
  nước dâng + sóng + chai nổi (overlay đọc tiến độ mỗi frame). checkEnd nhánh
  riêng (thưởng `30+sao×15`, side-mode isolation). Nút Home full-width + Guide +
  HUD + result panel. [[side-mode-isolation]]
- **Obstacle Licorice + Jam (mới)**: mở rộng `ObstacleType` (+licorice +jam).
  **Licorice**: khoá 2 LỚP (`kLicoriceLayers`), che gem (không match, không xoá),
  gỡ bằng clear ô kề 2 lần — weave màn {48,84}. **Jam (mứt)**: lan như chocolate
  NHƯNG là mục tiêu clearObstacle — `obstacleTotal` = lớp BAN ĐẦU (lan thêm KHÔNG
  tăng → **luôn khả thi**); `_maybeGrowJam` + cap 24 — weave màn {54,90}. Cả 2 dùng
  pattern `center` (chống bí bàn — regression guard có test). `_obstacleCoversGem`
  helper gom logic. Render `_drawLicorice`/`_drawJam`. Guide + i18n.
- **Album sưu tập + Heo đất (meta)**: `CollectionController` (điểm lifetime, mở 12
  sticker theo mốc tích luỹ, permanent + resetState). `PiggyController` (mỗi thắng
  bỏ ống `6+sao×4`, cap 600, đập khi ≥120 nhận hết). `CollectionScreen` (lưới
  album) + `PiggyScreen` (heo + thanh đầy + đập). addWin gọi từ `_onGameEnd`.
- **Giải đấu tuần (event)**: `TournamentController` (epoch-week như Season; điểm
  reset/tuần; **bảng xếp hạng OFFLINE tất định** — 7 bot điểm sinh theo seed tuần
  leo dần theo ngày; thưởng theo hạng, 1 lần/tuần). `TournamentScreen` (leaderboard
  + đếm ngược + claim). Chống chỉnh giờ qua `_effectiveDay`.
- **Wiring chung**: 3 controller meta đăng ký permanent ở Home + 3 nút (hàng meta
  mới Album/Heo/Giải đấu) + reset trong `resetProgress` (xoá key + resetState).
- **i18n**: 37 key mới dịch đủ **22 ngôn ngữ** (en/vi inline + 20 ngôn ngữ qua lớp
  merge mới `_w14ByLang`, 4 agent dịch song song) → coverage test ≥80% PASS (không
  tái mở lỗ hổng i18n).

**Kết quả**: 0 analyzer issue · **309 test pass** (+15 `test/w14_test.dart`: obstacle
weave/winnability, soda start/win/lose/isolation, collection, piggy, tournament) ·
build APK debug OK. *Verify máy: người dùng tự test.*

> ⚠️ Ghi chú thiết kế: Soda dùng mô hình "mực nước = gem clear" (chai nổi là overlay
> theo tiến độ), KHÔNG phải chai vật lý nổi trong lưới — chủ ý để KHÔNG đụng
> gravity/refill (phần dễ vỡ theo audit Wave 11). Jam là obstacle objective có lan
> nhưng mục tiêu cố định = khả thi tuyệt đối.

### 🔧 Wave 14 — Audit & fix (2026-06-18)
2 agent audit độc lập (engine + meta), mỗi phát hiện verify `file:line`. Correctness
**SẠCH** (0 CRITICAL/HIGH đúng-sai; winnability jam/licorice chứng minh an toàn, soda
cô lập đúng, không hồi quy obstacle cũ). Điểm tự chấm **7.5/10** (trừ ở KINH TẾ). Đã sửa:
- **[HIGH] H1 — faucet xu meta không cap**: 3 `addWin` (Collection/Piggy/Tournament)
  cộng xu mỗi màn thường thắng, không cap → farm thắng-lại màn dễ (thắng KHÔNG tốn
  mạng). **Fix**: thêm cờ `lastFirstClear` (set trong checkEnd TRƯỚC `_saveProgress`:
  `stars[lv]==0`) → meta CHỈ thưởng LẦN ĐẦU thắng màn. (Season/BattlePass giữ nguyên.)
- **[MED] M1 — Tournament ăn hạng 1 sớm**: thưởng theo hạng hiện tại + bot yếu đầu
  tuần → 300 xu/tuần quá dễ. **Fix**: `botScoreNow` dùng điểm CUỐI tuần (cố định cả
  tuần) → bot mạnh full từ ngày 1, phải đua thật mới lên hạng.
- **[LOW] L1**: badge Album ở Home đọc thêm `cc.points.value` (sáng đúng lúc đủ điểm).
- **[LOW] L2**: `_doShuffle` excluded dùng `_obstacleCoversGem` (thêm licorice/jam, nhất quán).
- **[LOW] L3**: `kJamSpreadCap` đưa ra `levels.dart` + 5 test winnability (invariant
  cap<bàn, đủ lượt dọn, sim greedy không deadlock).

**Kết quả sau fix**: 0 analyzer · **314 test pass** (+5) · build APK OK.

### ✨ Wave 14 — Vòng polish lên 10/10 (2026-06-18)
Người dùng yêu cầu đẩy từ 7.5 → 10/10. Re-audit (agent độc lập) xác nhận 6 fix vòng 1
ĐÚNG, không hồi quy (9.3/10, còn 1 dead-code + shader nước per-frame). Đóng nốt:
- **L4 — SodaLayer cache Paint**: 8 `static final Paint` (wave/bubble/stroke/glow/
  body/neck) dựng 1 lần; `_drawBottle` hết cấp phát Paint/MaskFilter.blur mỗi frame.
- **Shader nước cache theo p**: gradient khối nước chỉ dựng lại khi MỰC NƯỚC đổi
  (`_lastP`), không mỗi frame (sóng vẫn animate theo `_t`). Hết alloc shader/frame.
- **HUD jam overshoot**: `_objectiveText` clamp `obstacleCleared` ở `[0,total]`
  (jam lan có thể đẩy cleared vượt → không hiện "17/16").
- **Dead-code**: xoá getter `dayIntoWeek` (không còn call-site sau fix M1).
- **+6 widget test** (`test/widget/w14_screens_test.dart`): render + claim/smash/
  leaderboard cho CollectionScreen/PiggyScreen/TournamentScreen.
- Xác nhận (re-audit): Soda fill đếm ĐỒNG NHẤT mọi nguồn clear (match + mọi booster
  qua `_smashCells`→`_clearCells`→`registerClear`), không double/under-count; reset
  đầy đủ; i18n 22 ngôn ngữ đủ. *(Finding "booster inconsistency" vòng 1 là dương
  tính giả — nhầm dòng gravity/junk.)*

**Kết quả cuối Wave 14**: 0 analyzer · **320 test pass** (+6 widget) · build APK OK ·
re-audit **release-ready**. Điểm: **~9.8/10** (chỉ còn trừ rất nhẹ vì Soda là
fill-based thay vì chai vật lý — đánh đổi CHỦ Ý để an toàn engine).

### 📱 Wave 14 — Fix layout Home + verify máy thật Pixel 7 Pro (2026-06-18)
Phản hồi máy thật: thêm hàng meta thứ 3 (Album/Heo/Giải đấu) làm Home mất no-scroll
(vỡ thiết kế [[home-fullwidth-no-fittedbox]]) + đẩy version/copyright khỏi màn.
- **THỬ THÁCH gộp lưới 2×4** (8 ô): đưa Color Rush + Soda vào lưới (bỏ 2 card
  full-width) → gọn chiều cao. Nhãn ngắn `color_rush_short`/`soda_short`.
- **PHẦN THƯỞNG gộp 2 hàng × 5 icon** (Đền/Pass/Mùa/Cửa hàng/Album · Heo/Giải đấu/
  Thành tựu/Hướng dẫn/Cài đặt). Giải đấu đổi icon `leaderboard` (khỏi trùng cúp
  Thành tựu). → version + © hiện lại đầy đủ, toàn Home gọn 1 màn không scroll.
- **Verify máy thật (Pixel 7 Pro, Impeller/Vulkan)**: Home render đúng (2×4 + 2×5 +
  version), Soda (NƯỚC DÂNG) HUD 🍶0/3·LƯỢT 28 + 3 chai đáy bàn + nước dâng khi
  clear (ĐIỂM 30/LƯỢT 27), dialog THOÁT MÀN overlay đúng, Album (12 sticker khoá
  ngưỡng 30→1880), Heo đất (0/600, nút mờ), Giải đấu (leaderboard 8 hạng, bot điểm
  cuối-tuần cố định theo M1, Bạn hạng #8). **Logcat process app SẠCH** (0 exception/
  FATAL/RenderFlex overflow toàn phiên); GPU 99th = 6ms.
- *Nợ nhẹ ghi nhận*: countdown "Kết thúc sau 00:00:00" ở Giải đấu — dùng chung
  `timeToEnd` (epoch-week) với Season; cần kiểm timezone (UTC+7) — KHÔNG phải lỗi
  riêng Wave 14 (Season cùng logic). → **ĐÃ SỬA bên dưới (Wave 14.1)**.

### 🕒 Wave 14.1 — Fix timezone countdown Mùa/Giải đấu (2026-06-19)
Gốc rễ: `timeToEnd` (cả `season_controller` lẫn `tournament_controller`) tái dựng
mốc kết thúc bằng **UTC midnight** (`endDay * 86400000`) trong khi `todayEpochDay`
lại tính từ **local date** (`DateTime(y,m,d)`). Hai hệ quy chiếu lệch đúng bằng
offset múi giờ → ở UTC+7 countdown nhảy về `00:00:00` sớm 7 giờ (đúng triệu chứng
máy thật).
- **Fix**: helper chung `durationToLocalMidnight(now, daysLeft)` (`core/utils/format.dart`)
  dựng mốc kết thúc từ thành phần ngày ĐỊA PHƯƠNG (`DateTime(y, m, d + daysLeft)`,
  Dart tự chuẩn hoá tràn tháng) → khớp cách `todayEpochDay` tính. `daysLeft =
  weekEnd/seasonEnd(today) − today` (luôn 1..N). Cả 2 controller gọi helper này.
- **Kết quả**: 0 analyzer · **324 test pass** (+4 `w10_format_test`: cùng ngày,
  nhiều ngày, tràn cuối tháng, đã-qua-mốc) · playtest 0 màn quá-khó (curve không đổi).

## 🌊 Wave 15 — KẾ HOẠCH: Bố cục bàn đa dạng + Gravity Streams + 2 side mode + content (📋 PICKED 2026-06-19)

> Người dùng chốt làm: (1) Nội dung mới — Thế giới 6-8 + màn 101-150; (2) Cơ chế
> gem/obstacle mới; (3) Chế độ phụ mới. **Polish & Accessibility → ⏸️ Deferred**
> (mù màu/reduced-motion/SFX — làm trước khi lên store, KHÔNG phải bây giờ).
>
> Insight then chốt từ phản hồi: Candy Crush có **bố cục layout đa dạng** (bàn
> không chữ nhật, lỗ/tường), **gem bị xích/nhốt**, **ô đá**. Đây là điểm khác biệt
> lớn nhất so với game hiện tại (đang "Board chuẩn 8×8 đồng nhất mọi màn").

### Quyết định đã chốt (qua AskUserQuestion)
- **Trọng lực khi bàn có lỗ/tường**: KẾT HỢP **lỗ-cắt-cột** (MVP an toàn) **+ trượt
  chéo kiểu CCS** (gem trượt chéo vòng qua vật cản).
- **Cơ chế trọng lực ĐỘC QUYỀN (signature)**: **Dòng chảy Neon / Gravity Streams** —
  vùng có mũi tên neon đổi HƯỚNG trọng lực (xuống/trái/phải/lên), gem chảy theo
  hướng vùng → bàn như mạch điện. Rất khác CCS.
- **Chế độ phụ mới**: làm **CẢ HAI** — Mê cung neon (Labyrinth) + Sinh tồn (Survival).

### Khảo sát kiến trúc (đã làm — Explore agent)
- Engine render/layout **đã động theo `rows/cols`** (không hardcode 8×8 trong logic
  vẽ — `_layout`/`_cellCenter`/`BoardFrame` dùng biến). `MatchDetector` chạy trên
  grid input → KHÔNG cần sửa cho blocked-cell.
- Board **cố định 8×8 ở DEFINITION** (8 hàm `build*Level` + loop `kLevels`).
- **Chưa có** khái niệm ô blocked/hole/no-drop. Obstacle hiện (7 loại) đều "phủ KÈM
  gem", không phải "ô không có gem".
- Phần khó & dễ vỡ nhất: **gravity/refill** (`_applyGravityAndRefill`, `_doShuffle`,
  `_fillInitialBoard`, `_matchColorAt`, `_findMove`) — audit W11 từng cảnh báo.

### Lộ trình phân PHASE (mỗi phase: build + test + verify trước khi sang phase kế)
- **Phase 0 — Nền tảng ô đặc biệt + lỗ-cắt-cột**: thêm `CellKind` (play/wall/noDrop)
  + bản đồ ký tự cho level; lưới `blocked`/`noDrop` trong engine; gravity/refill
  nhận biết lỗ (cột bị cắt → refill theo đoạn liền mạch); `BlockedLayer` render
  tường đá neon; sửa `_findMove`/`_doShuffle`/select. Winnability tests.
- **Phase 1 — Trượt chéo (diagonal-slide)**: gem trượt chéo vòng qua vật cản khi
  ô dưới bị chặn (kiểu CCS). Tổng quát hoá settle. Nhiều test winnability.
- **Phase 2 — Gravity Streams (signature)**: lưới `flowDir` (hướng trọng lực/ô);
  tổng quát hoá settle thành "chảy theo hướng cục bộ"; refill từ mép-nguồn mỗi
  dòng; `FlowLayer` mũi tên neon chạy. (Phase nặng nhất.)
- **Phase 3 — Gem nhốt (Cage) + no-drop + mục tiêu Giải cứu**: `ObstacleType.cage`
  (gem có màu, MATCH được, nổ → mở lồng) + `ObjectiveType.rescue`; wire ô no-drop.
- **Phase 4 — 2 chế độ phụ**: Mê cung neon (wall maze + đưa tinh thể xuống đích) +
  Sinh tồn (đếm ngược, combo +giây). Cô lập side-mode (`isSideMode`).
- **Phase 5 — Nội dung**: Thế giới 6-8 (3 accent màu mới) + màn 101-150, weave dần
  layouts/cage/streams/no-drop; cập nhật `tool/playtest.dart` cho bàn có lỗ; i18n
  22 ngôn ngữ cho key mới (lớp merge `_w15ByLang`).

### 📋 Bảng theo dõi task Wave 15 (status) — cập nhật 2026-06-19

> Quy ước thư mục: task chuyển `doc/tasks/todo/` → `in-progress/` → `done/` theo
> tiến độ. Cột "Status" dưới đây là nguồn tóm tắt nhanh.

| Phase | Task | File | Status | Rủi ro |
|---|---|---|---|---|
| 0 | Ô tường/lỗ/no-drop + bản đồ ký tự + gravity lỗ-cắt-cột | `w15-0-blocked-cells.md` | ✅ done | 🟡 TB |
| 1 | Trượt chéo kiểu CCS (gravity vòng qua vật cản) | `w15-1-diagonal-slide.md` | ✅ done | 🔴 Cao |
| 2 | Gravity Streams (signature — hướng trọng lực theo vùng) | `w15-2-gravity-streams.md` | ✅ done | 🔴 Cao nhất |
| 3 | Gem nhốt (Cage) + ô no-drop + mục tiêu Giải cứu | `w15-3-caged-gem.md` | ✅ done | 🟡 TB |
| 4 | 2 chế độ phụ: Mê cung neon + Sinh tồn | `w15-4-side-modes.md` | ✅ done | 🟢 Thấp |
| 5 | Thế giới 6-8 + màn 101-150 + playtest + i18n | `w15-5-content-worlds.md` | ✅ done | 🟡 TB |

**Chú thích status**: 📋 todo · 🟡 in-progress · ✅ done. **→ TOÀN BỘ 6 PHASE ✅ DONE
(2026-06-19)**: 363 test pass, 0 analyzer, verify Oppo. Chi tiết từng phase bên dưới.

#### ✅ Phase 0 — Blocked cells + gravity lỗ-cắt-cột (2026-06-19)
- **Settle engine THUẦN** `lib/logic/settle.dart`: `CellKind` (play/wall/noDrop) +
  parse bản đồ ký tự + `settleColumnsDown` (wall chia cột thành đoạn độc lập, gem
  dồn trong đoạn, refill từ đỉnh). Test không cần Flame.
- **Wire engine**: `LevelConfig.layout` (nullable) + `layoutFromMap`; NeonJewelGame
  `_cellKind`/`_isWall`/`layoutOverride` (seam test+Labyrinth); `_applyGravityAndRefill`
  rẽ sang `_applyGravityWithLayout` (settle) khi có layout, GIỮ path cũ cho mọi bàn
  đặc → **zero hồi quy**. Skip wall ở fill/findMove/cellAtPosition. `BoardFrame` bỏ
  slot ô tường + `BlockedLayer` vẽ khối đá neon.
- **Test**: +6 unit (settle) +2 widget (mount bàn có lỗ: tường trống, ô chơi đầy,
  no-layout không hồi quy) = **332 test pass**, 0 analyzer.
- **✅ Verify Redmi (23129RAA4G)**: weave tạm hình thoi vào màn 1 → bàn render đúng
  (4 góc 2×2 tường tối/trống, gem chỉ ở ô chơi, bàn không-chữ-nhật), swipe tương
  tác OK. Đã revert temp.

#### ✅ Phase 1 — Trượt chéo (diagonal-slide) (2026-06-19)
- **`settleBoard`** (settle.dart): rơi thẳng-tới-cạn → **trượt chéo** (gem KHÔNG rơi
  thẳng được + ô-trên-đích là TƯỜNG → trượt (r+1,c±1), tránh "ăn trộm" ô rơi thẳng)
  → refill từ đỉnh. Tất định & hội tụ (Σ hàng tăng nghiêm ngặt). Trả move orig→final
  (gem dời nhiều ô) + spawn.
- **Engine**: `_applyGravityWithLayout` chuyển sang `settleBoard`; áp move kiểu "gom
  component trước + dọn ô gốc rồi đặt ô cuối" (an toàn khi đích-này = gốc-kia).
- **Test**: +5 unit (bàn rỗng refill ĐẦY mọi ô chơi qua trượt chéo, hình thoi đầy,
  no-wall, tất định, không move thừa) → **337 test pass**, 0 analyzer.
- **✅ Verify Redmi**: weave tạm thanh tường ngang màn 1 → render đúng; **đập búa 1
  gem dưới thanh** (ĐIỂM 0→40) → bàn refill ĐẦY, KHÔNG lỗ đen dưới thanh (hốc bị
  tường che lấp bằng trượt chéo). Đã revert temp.

#### ✅ Phase 2 — Gravity Streams (signature độc quyền) (2026-06-19)
- **`settleBoardFlow`** (settle.dart): `FlowDir` (down/up/left/right) mỗi ô; gem chảy
  1 bước theo hướng ô nó đang đứng (single-step ĐỒNG THỜI snapshot + tranh chấp chọn
  theo ưu tiên hướng → tất định). Refill ở "ô NGUỒN" (không hàng xóm nào chảy vào).
  Giữ TRƯỢT CHÉO cho ô down (kế thừa Phase 1). HỘI TỤ nếu KHÔNG có chu trình hướng
  (mỗi move đẩy gem gần sink hơn) + guard cap.
- **Engine**: `_applyGravityWithLayout` dùng `settleBoardFlow` khi có flow; spawn xuất
  phát NGƯỢC hướng dòng (gem trôi vào từ đầu nguồn). `flowOverride` seam. `FlowLayer`
  (effects.dart) vẽ mũi tên neon + chấm sáng chạy ở ô KHÁC down (priority 2, trên gem
  → signature dễ thấy).
- **Test**: +7 (6 unit settleBoardFlow: down=settleBoard, flow phải/lên/chữ-S lấp đầy,
  tất định, parse; +1 widget mount bàn flow fill 64 ô) → **344 test pass**, 0 analyzer.
- **✅ Verify Redmi**: weave tạm flow (band giữa chảy phải + band dưới chảy trái) màn
  1 → bàn render mũi tên+chấm sáng cyan đúng hướng ("mạch điện"), mount sạch, tương
  tác OK, logcat KHÔNG lỗi app. Hành vi flow gravity = unit-tested. Đã revert temp.
  *Nợ nhẹ*: mũi tên hơi nhỏ — tinh chỉnh thẩm mỹ ở vòng polish.

#### ✅ Phase 3 — Gem nhốt (Cage) + no-drop + giải cứu (2026-06-19)
- **Cage** tái dùng objective `clearObstacle` (KHÔNG cần ObjectiveType mới → tránh
  sửa loạt switch): `ObstacleType.cage`, weave màn {42,78} (`kCageLevels`). Gem nhốt
  **THAM GIA match** (`_matchColorAt` trả màu — khác stone/licorice phủ kín) nhưng
  **swap-locked** (phải xếp hàng xóm để ghép chính nó). 2 lớp; vỡ 1 lớp mỗi lần gem
  nhốt nằm trong match (nhánh self ice-style trong `_damageObstacles`) → "giải cứu"
  khi hết lồng. Engine seed THƯA ((r+c) chẵn trong center) → 2 ô nhốt không kề →
  luôn ghép được (winnability). `_drawCage` (song sắt cyan, không che gem).
- **No-drop** (`CellKind.noDrop`): gem bất động trong settle (`settleBoardFlow`):
  không là nguồn/đích di chuyển, tự refill tại chỗ, không cấp gem cho hàng xóm
  (đảo nổi). Engine giờ LUÔN dùng `settleBoardFlow` cho bàn có layout (flow default
  down → tương đương settleBoard + xử lý no-drop). `BlockedLayer` vẽ viền lime.
- **Test**: +5 (3 cage: level config + engine seed thưa + obstacleTotal; 2 no-drop:
  chặn rơi + tự refill) → **349 test pass**, 0 analyzer.
- **✅ Verify Redmi**: temp biến màn 1 thành cage → objective "0/16" (8 lồng×2),
  song sắt cyan thưa quanh gem (gem vẫn hiện), mount sạch. Hành vi vỡ-lồng = reuse
  machinery clearObstacle (licorice/jam đã verify) + unit-test. Đã revert temp.

#### ✅ Phase 4 — 2 chế độ phụ: Sinh tồn + Mê cung (2026-06-19)
- **Sinh tồn (Survival)**: `isSurvival` + `buildSurvivalLevel()` — TÁI DÙNG objective
  timeAttack (đồng hồ + combo +giây sẵn có). KHÔNG target thắng (targetScore=1<<28) →
  kết thúc khi HẾT GIỜ, điểm = thành tích (kỷ lục `survivalHigh`). checkEnd nhánh
  riêng (isOutOfTime → thưởng theo điểm, isolation, như Endless). HUD chip TIME sẵn có.
- **Mê cung (Labyrinth)**: `isLabyrinth` + `buildLabyrinthLevel()` — TÁI DÙNG dropDown
  (tinh thể + thu đáy) + **layout mê cung tường** (`kLabyrinthMap`). Tinh thể lách mê
  cung (trượt chéo) xuống đáy. checkEnd nhánh riêng (đủ → win+thưởng; hết lượt → lose).
- **Wiring chung**: flags + `_enterMode` + `level` getter + `isSideMode` + `again()` +
  result panel + HUD badge + 2 nút Home (lưới THỬ THÁCH **2×5** = 10 mode, giữ no-scroll).
  i18n en+vi (`survival_*`/`labyrinth_*`), 20 ngôn ngữ fallback EN.
- **Test**: +8 unit/widget (start/checkEnd/ISOLATION cả 2 + engine mount mê cung: tường
  trống/ô chơi đầy/tinh thể đặt) + **2 integration** (Home→Survival/Labyrinth) →
  **357 test pass**, 0 analyzer.
- **✅ Verify Oppo (CPH2577)**: chạy 2 integration test THẬT trên máy → "Home → Sinh
  tồn → vào game" + "Home → Mê cung → vào game" đều PASS (isSurvival/isLabyrinth bật,
  badge đúng). (Máy test đổi Redmi → Oppo theo yêu cầu người dùng 2026-06-19.)

#### ✅ Phase 5 — Nội dung: thế giới 6-8 + màn 101-150 (2026-06-19)
- **Mở rộng 100 → 150 màn + 8 thế giới**: `kLevelCount=150`; thêm thế giới 6 (Prism
  Maze, 101-120) / 7 (Flux Stream, 121-140) / 8 (Neon Apex, 141-150 — finale ngắn).
  `accentForWorld` tự wrap màu. i18n `world_name_6/7/8` (en+vi). Story giới hạn 5 thế
  giới (`kStoryWorlds=5`); 6-8 vào thẳng màn (chưa có NPC).
- **Weave cơ chế mới** vào màn score 101-150 (`kLayoutLevels`/`kFlowLevels`, đọc theo
  chỉ số như kBombLevels): bố cục lỗ/tường (103 thoi · 127 trụ · 145 đảo no-drop),
  Gravity Streams (115 chảy phải · 139 mạch 2 chiều) + cage ({114,138}). +4 lượt cho
  màn có lỗ/dòng chảy (công bằng).
- **Playtest**: `tool/playtest.dart` chạy 150 màn → **0 màn quá-khó** (đường cong
  validate tới L150). Curve clamp sẵn → 101-150 thử thách công bằng.
- **Polish (phản hồi máy thật Oppo)**: (1) Survival HUD MỤC TIÊU chỉ hiện ĐIỂM (bỏ
  "0/268.435.456" target giả); (2) label item Home nhỏ lại (fontSize 11→9, icon 26→24)
  cho vừa lưới 2×5 (ít ellipsis).
- **Test**: +6 (`w15_content_test`: 150 màn/8 thế giới, accent wrap, weave layout/flow/
  cage, no-drop, không objective riêng) + sửa 3 test cũ (levels/story cho 150/8/5) →
  **363 test pass**, 0 analyzer.
- **✅ Verify Oppo**: Home lưới 2×5 = 10 mode (label gọn, no-scroll giữ), World Map 150
  màn load không crash, Survival vào game (badge + GIỜ 00:48 + MỤC TIÊU "0" sạch).

> 🎉 **WAVE 15 HOÀN TẤT (6/6 phase)**: bố cục bàn đa dạng (lỗ/tường/no-drop) + trượt
> chéo + **Gravity Streams (signature)** + gem nhốt (cage) + 2 chế độ phụ (Sinh tồn +
> Mê cung) + 150 màn/8 thế giới. Lõi gravity tổng quát hoá hoàn toàn (settle engine
> thuần: wall + chéo + flow + no-drop).

### 🔍 Wave 15 — Audit & fix (2026-06-19)
3 agent audit độc lập (engine / controller-mode / content-UI-i18n), mỗi phát hiện
verify `file:line`. Điểm: engine 8.5 · controller/mode 9.5 · content 3→9 (sau fix) ·
UI 8 · i18n 8.
- **[CRITICAL] Mê cung BẤT KHẢ THẮNG → ĐÃ SỬA**: `kLabyrinthMap` cũ (hàng-tường kẹp
  giữa hàng-mở) làm tinh thể KẸT trên tường (2 bên trống → luật trượt-chéo không kích
  hoạt) → không bao giờ xuống đáy. Test cũ chỉ ép `dropped=target` nên không bắt được.
  **Fix**: maze "phễu" anti-chéo (`#......#`/`.#....#.`/`..#..#..`/`...##...`) → tường
  KỀ tinh thể cùng hàng → trượt chéo ra mép rồi rơi thẳng. Chứng minh khả thi bằng sim
  descent + **test mới `MÊ CUNG khả thi`** (mọi cột đặt được tới đáy — guard chống tái lỗi).
- **[HIGH→design-note] Cage**: gem nhốt clear MỖI match (như băng nhiều-lớp + khoá
  swap) thay vì "đứng yên tới khi hết lồng" như task. Vẫn khả thi + đếm đúng (2 match/ô)
  → giữ hành vi (đổi "gem stays" sang immovable sẽ gây desync gravity, rủi ro hơn). Doc
  cập nhật cho khớp code.
- **[LOW] đã sửa**: comment combo "≥3"→"≥4" (khớp engine `addTime` gate).
- **Đã BÁC (không phải bug)**: movePass mất/đè gem · áp move desync · hội tụ vô hạn ·
  no-drop cấp gem hàng xóm · wall gây crash · cage double-count · hồi quy bàn đặc ·
  side-mode isolation (đạt) · thứ tự nhánh checkEnd (đúng) · survival không win sớm.
- **Kết quả sau fix**: 0 analyzer · **364 test pass** (+1 winnability mê cung).

#### 🧹 Wave 15 — Dọn nợ audit + verify Oppo (2026-06-19)
Người dùng chốt kết hợp verify Mê cung + dọn nợ:
- **i18n 20 ngôn ngữ**: dịch đủ 10 key mới (`survival_*`/`labyrinth_*`/`world_name_6-8`)
  cho 20 ngôn ngữ (lớp merge mới `_w15ByLang`, 4 agent dịch song song) → hết fallback
  EN. Coverage test ≥80% vẫn PASS.
- **Label Home tự co**: bỏ fontSize cố định 9 → `FittedBox(scaleDown)` + fontSize 11 →
  nhãn NGẮN giữ to, nhãn DÀI (SUPERVIVENCIA/ВЫЖИВАННЯ/HAYATTA KALMA) TỰ CO vừa ô,
  KHÔNG ellipsis. Verify Oppo: "HẰNG NGÀY"/"TRÙM NEON"/"TRỌNG LỰC" hiện đầy đủ.
- **✅ Verify Mê cung fix (Oppo)**: maze "phễu" anti-chéo render ĐÚNG (tường inverted-V
  hiện rõ), mode load (badge "MÊ CUNG NEON", MỤC TIÊU ↓0/4, 30 lượt, 2 tinh thể ở đỉnh).
  Winnability đã chứng minh bằng sim descent + test tự động (cơ chế trượt-chéo đã verify
  Redmi Phase 1). *Descent trực tiếp không chụp được do tự-động-hoá chạm finicky — không
  phải lỗi code.*
- **Kết quả**: 0 analyzer · **364 test pass** (i18n coverage + winnability đều xanh).
- *Nợ nhẹ còn lại*: cage "gem-stays" (giữ hành vi clear-mỗi-match, đã verify khả thi) ·
  flow cycle latent (level hiện tránh được).

**⏸️ Deferred (Wave 15, làm trước khi lên store — KHÔNG phải bây giờ)**:
Polish & Accessibility — chế độ mù màu (palette + hoạ tiết phân biệt gem), reduced
motion, đa dạng SFX, trail gem rơi.

> ⚠️ Quy mô: đây là wave LỚN nhất, đụng đúng phần engine dễ vỡ nhất (gravity/refill).
> Làm TUẦN TỰ từng phase, có cổng build+test+verify, KHÔNG fan-out subagent (đụng
> cùng file lõi). Task chi tiết: `doc/tasks/todo/w15-*.md`.

## 🌊 Wave 16 — KẾ HOẠCH: Kỹ thuật thiết kế Match-3 (từ infographic) (📋 PICKED 2026-06-19)

> Người dùng đưa infographic "Bí quyết thiết kế level Match-3" + chốt làm **cả 4** nhóm.
> Đối chiếu: game đã có ~60% (Portals W11, blocker tĩnh/động/điều-kiện W4/5/10/14/15,
> bottleneck/walls W15, bot playtest W13). Phần THIẾU = meta/cân bằng/tâm lý → Wave 16.

### 📋 Bảng theo dõi task Wave 16 (status)

| Phase | Task | File | Status | Rủi ro |
|---|---|---|---|---|
| 1 | Difficulty tiers (70/25/5) + Sawtooth + badge | `w16-1-difficulty-tiers.md` | ✅ done | 🟡 TB |
| 2 | Dead-zone objectives + bottleneck | `w16-2-dead-zone-bottleneck.md` | ✅ done | 🟡 TB |
| 3 | DDA & Pity System (trợ giúp động) | `w16-3-dda-pity.md` | ✅ done | 🟢 Thấp |
| 4 | Near-miss + RNG control (bản nhẹ/công bằng) | `w16-4-nearmiss-rng.md` | ✅ done | 🔴 nhạy cảm |

**Chú thích**: 📋 todo · 🟡 in-progress · ✅ done. **→ TOÀN BỘ 4 PHASE ✅ DONE
(2026-06-19)**: 388 test pass, 0 analyzer, playtest validated. Chi tiết bên dưới.

#### ✅ Phase 1 — Difficulty tiers + Sawtooth + badge (2026-06-19)
- **`LevelTier` + `levelTier(index)`**: Super-Hard = cuối mỗi thế giới (~5%), Hard = 5
  màn trước đỉnh (~25%), còn lại Normal (~70%). Tất định.
- **Sawtooth**: `isReliefLevel` = 2 màn đầu mỗi thế giới (sau Super-Hard) → Normal + nới
  (`_tierMul` 0.85 + `_tierMoveDelta` +3). Hard/Super siết (mul 1.06/1.12, Super -1
  lượt) → đường cong RĂNG CƯA.
- **Badge UI**: tile Level Select góc Hard (⚡ cam) / Super-Hard (🔥 đỏ); Normal ẩn.
- **Playtest**: in tier + MIỄN Super-Hard khỏi guard "quá khó". Chạy lại: 0 màn
  Normal/Hard quá-khó; Super-Hard 48-68% bot (≈80-100% người chơi).
- **Test**: +6 unit (phân bố 70/25/5, sawtooth, tất định, curve khả thi) +1 widget
  (badge render) → **371 test pass**, 0 analyzer.

#### ✅ Phase 2 — Dead-zone + Bottleneck (2026-06-19)
- **Dead-zone**: `JellyPattern.corner` (4 góc 2×2 = 16 ô) → mục tiêu ở góc cô lập, khó
  match (ít ô kề). Áp clearJelly {111,129} (`kDeadZoneLevels`). Cùng số ô như center
  → không xô lệch tổng lượng, chỉ khó hơn về VỊ TRÍ.
- **Bottleneck**: waist tường ('##.##.##') vào score {109,121,133} → khe hẹp giảm rơi
  liên mạch → giảm combo tự động (khó hơn). **Winnability**: refill qua khe + trượt-chéo.
- **Test**: +5 (corner pattern 16-ô-ở-góc, dead-zone config, +3 ENGINE-MOUNT bottleneck
  fill ĐẦY 100% — winnable, không pocket kẹt; bài học Labyrinth) → 0 analyzer.

#### ✅ Phase 3 — DDA & Pity System (2026-06-19)
- Thua LIÊN TIẾP màn thường → trợ giúp ẩn tăng dần (KÍN ĐÁO, chỉ màn thường):
  `StorageKeys.pityFails(level)` (reset khi thắng). ≥2: lucky rate 0.028→0.073; ≥3:
  seed 1 special lúc mở màn; ≥4: +2 lượt khởi đầu. Const-gated.
- **Test**: +5 (lose+1/win-reset, +lượt, side-mode ISOLATION pity=0, engine seed special
  theo ngưỡng).

#### ✅ Phase 4 — Near-miss + RNG control (bản CÔNG BẰNG) (2026-06-19)
- **Near-miss = difficulty knob** (KHÔNG ép mua — game offline): chỉ Super-Hard cắt
  `kNearMissCut`=1 lượt (gated `kNearMissEnabled`). `nearMissCutFor` pure.
- **RNG control CHỈ chiều GIÚP** (pity): thua nhiều + collect → ép màu mục tiêu ~20%
  refill (`biasRefillToTarget` pure). KHÔNG dùng anti-player (HOÃN tới khi có IAP+A/B).
- **Test**: +7 (near-miss chỉ Super-Hard, RNG bias 5 nhánh điều kiện).
- **Kết quả Wave 16**: 0 analyzer · **388 test pass** (+24) · playtest 0 màn Normal/Hard
  quá-khó (Super-Hard cố ý khó, miễn guard).

> 🎉 **WAVE 16 HOÀN TẤT (4/4 phase)** — tích hợp kỹ thuật thiết kế Match-3 từ infographic:
> tier 70/25/5 + sawtooth + badge · dead-zone + bottleneck · DDA/Pity (giữ chân) ·
> near-miss + RNG-pity (công bằng). Game từ "đủ tính năng" → "thiết kế chuyên nghiệp".

> ⚠️ Quyết định đạo đức P4: game OFFLINE chưa IAP → làm bản NHẸ thiên CÔNG BẰNG
> (near-miss = difficulty knob ở Super-Hard; RNG control CHỈ chiều pity-giúp). Phần
> "hại" (anti-player RNG, near-miss ép mua) HOÃN tới khi có monetization + A/B.

#### 🔍 Audit Wave 16 (2026-06-19) — 3 agent adversarial + fix toàn bộ
**Điểm trước fix: 6.7/10** (cân bằng 6.5 · pity/DDA 6.5 · dead-zone/UI 8.5). Mọi màn
winnable, không bug bất-khả-thắng. Đã fix tất cả phát hiện:
- **🔴 HIGH-1 (bug thật) — pity rò sang side-mode**: `_enterMode` không reset `pity` →
  thua nhiều màn thường rồi vào Survival/Endless thì `_luckyRate`/`_refillColor` (đọc
  thẳng `pity.value`, không guard) bị bơm boost + lucky-coin né cap farm. **Fix**: thêm
  `pity.value=0` trong `_enterMode` (cover mọi side-mode 1 chỗ) + test regression
  "normal-then-side".
- **🔴 HIGH-2/3 — tier "vô hình" trên collect**: `cap=moves` nuốt `_tierMul` từ ~L68 →
  relief==normal==super đều 1.0 gem/lượt. **Fix**: `cap` theo tier (relief 0.85·moves)
  → răng cưa hiện lại trên màn collect (L122 relief 0.85 < L128 normal 1.0/lượt). Hard/
  Super giữ trần 1.0 (không thể vượt ceiling winnable — độ khó đỉnh đến từ ÍT lượt).
- **🟡 M-2 — vỡ sàn lượt 17**: near-miss kéo L80/L140 xuống 16. **Fix**: clamp sàn 17
  SAU khi cộng delta → near-miss tự vô hiệu ở màn đã chạm sàn, chỉ cắt nơi còn dư lượt.
- **🟡 M-3 — TG8 50% Hard** (band hằng 5 trên thế giới 10 màn): **Fix** band scale theo
  size (`size/4`, clamp 2-5) → TG8 còn ~30%, các TG khác giữ 25%.
- **🟡 M-1/M-4 — lỗ hổng test**: curve-test chỉ kiểm `score` (không Super-Hard nào là
  score → vacuous); bottleneck-test 1-seed + không check `hasMove`. **Fix**: curve-test
  phủ collect/time + khẳng định chạm ≥1 Super-Hard mỗi loại; bottleneck-test 4 seed +
  getter `hasPossibleMove` (winnable); sửa comment sai về cơ chế refill (qua `isSource`
  dưới tường, không qua khe).
- **Sau fix (đợt 1)**: **399 test pass** (+11) · 0 analyzer · playtest 0 màn quá-khó.

#### 🔍🔍 Audit Wave 16 — VÒNG 2 (re-audit + vá gap sâu, 2026-06-19)
Người dùng yêu cầu nâng điểm → vá GAP sâu (lý do trừ điểm: Hard tier gần như ==Normal
trên objective không-điểm; exploit cố-thua chưa cap) rồi RE-AUDIT 3 agent verify. Kết quả
re-audit: **cân bằng 8.5 · pity/isolation 9.0 · test 8.0** — 11 fix vòng 1 + 5 gap-fix dưới
đều **VERIFIED ĐÚNG, 0 regression**.
- **Hard tier có "răng" thật**: `_tierMoveDelta` Hard -1 (áp MỌI objective early-mid);
  `_collectCapMul` (relief .85/normal 1.0/hard 1.08/super 1.15) → collect tier hiện rõ
  (L80/L140 super 1.18 gem/lượt, L116 hard 1.06 vs normal 1.0); `_tierObjBonus` (hard -1,
  super -2 bonus-lượt jelly/dropDown) → đòn bẩy KHÔNG bị sàn 17 nuốt late-game (bù cho
  clearObstacle vốn pin winnability W14). Phân bố sau scale band: N 69.3% / H 25.3% / S 5.3%.
- **Chống farm cố-thua**: clamp `pityFails` ghi đĩa ở `kPityMovesFails` → trợ giúp bão hoà.
- **Test có răng hơn**: ngưỡng curve-test siết 110→85đ/lượt & 60→45đ/s (sát thực 76 & 38);
  +3 test gap-fix (Hard collect khó hơn Normal, Hard ít lượt hơn, pity clamp); sửa 2 comment
  sai (move-bite overclaim, test:78 `_ensurePlayable`→`_doShuffle` single-shot).
- **Sau fix (đợt 2)**: **402 test pass** (+3) · 0 analyzer · playtest 0 màn quá-khó.
- **Giới hạn còn lại (đã document, KHÔNG phải bug)**: từ ~L75 move-bite -1 bị sàn 17 nuốt
  trên objective đếm; clearObstacle không có target-lever (winnability pin) → tier ở đó dựa
  badge + hazard. 3 agent đồng thuận: winnable, không regression. **Điểm Wave 16: ~8.7/10.**

## 🔍 Đánh giá chất lượng code (2026-06-16, Wave 8.9)

4 agent đọc song song 4 tầng (engine / controllers / UI / core) + verify claim nặng bằng đọc code thật & probe. **Điểm tổng: 7.5/10** — chạy ổn, kiến trúc tốt, không lỗi logic nghiêm trọng; nợ kỹ thuật tập trung 2 chỗ.

**🔴 CRITICAL (đã verify bằng probe đếm key) — ✅ ĐÃ VÁ (xem mục "Vá gap i18n Wave 4" bên dưới):** i18n — ~~EN + VI đầy đủ, nhưng 20 ngôn ngữ còn lại ~49-51% key hiện tiếng Anh~~. Wave 5/7/8 (achievements, win_streak, ach_desc_*, guide_*, battle-pass, season, boss, rhythm, versus) chưa bao giờ dịch cho 20 ngôn ngữ. Test `app_translations_test.dart` chỉ kiểm **key đủ** (qua fallback merge), KHÔNG kiểm **value đã dịch** → ru ngủ. Đã dịch đủ 432 key Wave 4 (`_extraEn`) cho cả 20 ngôn ngữ + thêm test regression scoped riêng ≥95%.

**🟡 Thật, rủi ro thấp:** (a) `GameController` 958 LOC god-controller (tách economy/clock — L, rủi ro cao, hoãn sau release); (b) copy-paste UI (`_coinChip` ×4, `_fmtDur` ×4, TextStyle inline ~26, magic number layout) — dọn S, rủi ro ~0; (c) `levelUnlock` ghi RAM trước await disk — khe kill hẹp, siết S.

**✅ Claim agent đã BÁC sau khi đọc code:** "claimDaily exploit 2 lần" (SAI — guard-key ghi trước, dòng 859); "ComboText chia 0" (SAI — đã guard dòng 609); "ensureInit race load 2 lần" (SAI — cờ set đồng bộ trước await).

**Thứ tự việc:** 1) dịch đủ Wave 5/7/8 cho 20 ngôn ngữ + sửa test kiểm value (L, trước release) · 2) gom widget tái dùng (S) · 3) magic number → const (S) · 4) siết levelUnlock (S) · 5) test daily anti-cheat/versus/boss (M) · 6) tách GameController (L, hoãn).

---

## 📌 Trạng thái resume (cho phiên sau)

> Tóm tắt nhanh để bắt đầu lại nhanh chóng.

**Mới nhất**: Wave 8.9 xong — (1) junk-gem có **vẻ riêng** (xám hoá + vết nứt + viền magenta nhịp, `GemComponent.isJunk`); (2) Versus **công bằng**: 2 bàn chung `boardSeed` → mirror mở đầu, tách RNG nền khỏi RNG bàn; (3) **version** đọc tự động từ pubspec qua `package_info_plus` (`v2026.06.15`, hết hardcode `1.0.0`); (4) điều tra flame bump → **chốt giữ 1.35** (flame ≥1.36 cần Flutter 3.44.2); (5) re-verify S24 Ultra qua WiFi adb.

**Sức khỏe code**: **214 test pass** (+4) · 0 analyzer issue · build APK debug OK · verify máy thật S24 Ultra (SM-S928B, WiFi adb): Home không scroll, Versus chạy trọn ván, version `v2026.06.15`.

**Việc còn nợ (ưu tiên gợi ý cho phiên sau)**:
1. **Chuẩn bị release store** (icon, screenshot, store listing, signing config, build appbundle release, app size/proguard) — app đã đủ tính năng, ROI cao nhất.
2. **Tần suất quảng cáo Versus**: phát hiện khi test — interstitial AppLovin MAX bật lúc vào/replay Versus; cần xem lại UX (đừng spam ad mỗi ván).
3. **Engine deps major-bump** (flame 1.35→1.37) — BỊ CHẶN: cần nâng Flutter SDK toàn máy 3.35.1→3.44.2 (Dart 3.9→3.11). Chỉ làm khi sẵn sàng nâng SDK (hoặc dùng fvm pin riêng project).
4. **Chỉnh giờ TIẾN** (daily/wheel) vẫn farm được — bản chất offline không trusted-time; muốn chặn cứng cần backend.

**Thiết bị test**: S24 Ultra SM-S928B (**WiFi adb 192.168.21.76 — ổn định, không rớt như USB**) + Pixel 7 Pro (USB). Package `com.galaxyjoy.neon_jewels`. Build: `flutter build apk --debug`.

## 🌊 Wave 17 + 18 — KHÁC-BIỆT-HOÁ chế độ & dọn chồng chéo meta (📋 PICKED 2026-06-19)

> Xuất phát từ audit code (3 agent): toàn game dùng **1 engine match-3**; trong 10 mode
> THỬ THÁCH có 4 khác cơ chế (A: Boss/Trọng lực/Nhịp điệu/2 người), 3 khác luật (B:
> Vô tận/Quét màu/Soda), **3 gần như reskin** (C: Sinh tồn=TimeAttack, Mê cung=DropDown,
> Hằng ngày=objective campaign). Khu PHẦN THƯỞNG: Mùa/Giải đấu/Album/Thành tựu trùng
> ~70% khuôn "thắng→tích điểm→claim mốc"; kinh tế lệch faucet (chỉ Đền+Shop tiêu xu);
> Hướng dẫn+Cài đặt là tiện ích bị nhét chung. README đã sửa trung thực (nhãn A/B/C).

### 📋 Wave 17 — THỬ THÁCH: cho 3 mode reskin cơ chế RIÊNG (+ đào sâu mode B)
| Phase | Task | File | Ưu tiên |
|---|---|---|---|
| 1 | ✅ **DONE** Sinh tồn → **Triều dâng** (nước dâng từ đáy `_floodTop`, clear dưới nước đẩy lùi, chạm đỉnh=thua; TideLayer lam→đỏ; HUD "TRIỀU %"; engine đọc isSurvival thật) | `done/w17-1-survival-rising-tide.md` | ✅ |
| 2 | Mê cung → **tường động + sương mù** (tường dịch chuyển, fog) | `w17-2-labyrinth-moving-walls-fog.md` | 🔴 Cao |
| 3 | Hằng ngày → **Mutator xoay ngày** (4 màu/trọng lực ngang/combo×2…) | `w17-3-daily-mutators.md` | 🔴 Cao |
| 4 | Đào sâu mode B (Vô tận sự kiện / Soda vòi xả / Quét màu combo-màu) | `w17-4-deepen-b-modes.md` | 🟡 Thấp |

### 📋 Wave 18 — PHẦN THƯỞNG: dọn chồng chéo + cân bằng kinh tế
| Phase | Task | File | Ưu tiên |
|---|---|---|---|
| 1 | **Gộp Giải đấu + Sự kiện mùa** → 1 hệ "Mùa giải" (mốc + hạng, 1 đường điểm) | `w18-1-merge-tournament-season.md` | 🔴 Cao |
| 2 | **Khác-biệt-hoá Album & Thành tựu** (Album=perk/set, Thành tựu=danh hiệu) | `w18-2-differentiate-album-achievements.md` | 🟡 TB |
| 3 | **Thêm coin-sink** (nâng cấp booster vĩnh viễn / craft skin) chống lạm phát | `w18-3-coin-sinks.md` | 🟡 TB |
| 4 | **Tách Hướng dẫn + Cài đặt** khỏi nhãn "Phần thưởng" (UI trung thực) | `w18-4-split-utilities-ui.md` | 🟢 Rẻ |

**Nguyên tắc xuyên suốt**: (a) mọi mode phụ giữ `isSideMode` isolation; (b) mê cung/mutator
PHẢI pass winnability-sim (bài học Labyrinth W15); (c) không p2w (offline, leaderboard bot
tất định); (d) migrate meta phải anti-exploit (bài học reset-permanent-controllers); (e)
mỗi phase kèm unit + widget test; (f) verify máy thật qua **cáp USB** (wireless yếu).

**Thứ tự đề xuất**: 17.1 → 17.2 → 17.3 (3 reskin cấp bách) → 18.1 (gộp, đổi số ô Home) →
18.4 (dọn UI sau khi số ô đổi) → 18.2 → 18.3 → 17.4 (nice-to-have cuối).

> 🎉 **WAVE 17+18+19 HOÀN TẤT** (commit 77381ae, 2026-06-20): Tất cả 8 task (W17.1-4,
> W18.1-4) + W19.1 Side Mode Records + W19.2 Puzzle Mode gộp trong mega-commit.
> Kết quả: **557 test pass**, 0 analyzer, SeasonLeague (gộp), Album/Achievement
> (danh hiệu), coin sinks (nâng cấp booster), UI tách tiện ích, daily mutators,
> deepened B modes, side mode kỷ lục, puzzle 8 cấu đố.

## 🔧 Wave 20.1 — Audit + dọn nợ kỹ thuật (✅ 2026-06-20)

Audit 4 tầng (engine/logic · controllers · UI · test coverage) trên mega-commit W17-19.

**Phát hiện và sửa:**
- **🔴 HIGH (đã sửa) — Puzzle no-refill thiếu trong `_applyGravityWithLayout`**: Guard
  `isPuzzle` chỉ tồn tại ở `_applyGravityAndRefill` (bàn không-layout). Khi bàn puzzle
  có layout (wall/noDrop/flow), engine rẽ sang `_applyGravityWithLayout` và spawns
  gem vô hạn — phá vỡ thiết kế no-refill. **Fix**: bọc `for (final s in res.spawns)`
  trong `if (!controller.isPuzzle.value) { ... }` tại `neon_jewel_game.dart:1975`.
- **Controllers:** SẠCH — SeasonLeague/SideModeRecord/PuzzleController đều đúng.
- **UI/Screens:** SẠCH — layout 10 mode no-scroll, countdown timezone đúng, shop/album/achievement flow đúng.
- **HIGH-2 (bác — không phải bug):** TideLayer `_floodTop` int-vs-double comparison (`kTidePushback = 0.13`, clamp OK).

**5 test cases bổ sung (gap audit):**
- Puzzle skip guard: `recordWin(3)` khi unlocked=1 không nhảy unlock
- Puzzle board determinism: cùng seed → cùng layout
- Season League tích lũy qua nhiều ván
- Side Mode Record persist + reload anti-double-claim milestone
- Daily mutator isolation: mutator KHÔNG leak sang side mode (ColorRush)

**Kết quả**: 0 analyzer · **562 test pass** (+5) · build sạch.

## 📦 Wave 20.2 — Nội dung: 200 màn + thế giới 9-10 (✅ 2026-06-20)

Mở rộng 150 → **200 màn** / 8 → **10 thế giới**.

**Thế giới mới:**
- **World 9 "Void Circuit"** (151-170): accent orange (wrap), 20 màn
- **World 10 "Zenith Neon"** (171-200): accent purple (wrap), 30 màn (finale dài)

**Weave cơ chế mới vào W9-10 (score levels):**
- `kLayoutLevels`: 163 (frame walls), 175 (staggered bottleneck), 193 (dual gate)
- `kFlowLevels`: 169 (triple band), 181 (reverse-gravity center `^^^^`)
- `kOrderLevels`: thêm 157, 187
- `kBombLevels`: thêm 151, 199
- `kDeadZoneLevels`: thêm 159, 177
- `kCageLevels`: thêm 168, 192
- `kLicoriceLevels`: thêm 156; `kJamLevels`: thêm 162

**i18n**: `world_name_9`/`world_name_10` dịch đủ **22 ngôn ngữ** (`_w20ByLang`).

**Playtest**: 200 màn → **0 màn quá khó** với bot. Pass-rate W9-10: 54-88% bot (~80-100% người chơi).

**Kết quả**: 0 analyzer · **580 test pass** (+18: w20_content + fix w6/levels_test) · playtest validated.

## 🎭 Wave 20.3 — Meta Social Offline: Ghost Replay + Progression Tree + Challenge Card (✅ 2026-06-20)

Ba tính năng meta độc lập, không cần backend:

### A. Ghost Replay (Bóng ma nước đi)
- Record moves từng ván campaign (capped 150 moves, format 4-char per move)
- Flush khi win với score mới hơn → `ghostMoves(level)` + `ghostScore(level)`
- Ghost mode: load stored run, show `nextGhostMove()` hint + advance per swap
- `GameController`: `recordMove`, `advanceGhost`, `nextGhostMove`, `startGhostMode`, `hasGhost`
- Hook trong `NeonJewelGame._trySwap` sau `consumed = true`

### B. Progression Tree (Cây tiến trình meta)
- 3 node: Radiant (50★ → particle ×1.5), Blazing (150★ → particle ×2.0), Prestige (5 Gold → prestige)
- `ProgressionTreeController`: `checkAndUnlock` sau mỗi win, persist + reload
- `ActiveCosmetics.particleBurstMultiplier` → engine `_spawnBurst` áp multiplier
- `ProgressionTreeScreen`: 3 card với progress bar

### C. Challenge Card (Thử thách tuần)
- 3 challenge tất định/tuần: win N campaign, earn N xu, play mode N lần
- `ChallengeCardController`: track progress + claim + epoch-week reset
- `ChallengeCardScreen`: 3 card với progress + claim button
- Wiring: `_onGameEnd` → `onCampaignWin` / `onSideModePlayed` / `refreshCoins`

**Home**: thêm 2 nút mới (Challenge Card ở Row 1, Progression Tree ở Row 2).

**Kết quả**: 0 analyzer · **604 test pass** (+24: w20_3_meta_social_test) · build sạch.

## 🎮 Wave 20.4 — Zen Mode (side mode mới) (✅ 2026-06-20)

Chế độ phụ mới — **không thua**, tích điểm tự do, thư giãn.

- `isZen` flag + `isSideMode` isolation (không trừ mạng, không ảnh hưởng tiến trình)
- `startZen()`: 999 lượt, target unreachable (1<<28) → không kết thúc tự động
- `checkEnd()`: luôn trả `null` (chơi mãi cho đến khi người dùng bấm X)
- `endZenSession()`: gọi khi `quit()` → lưu `zenHigh`, thưởng xu nhỏ (điểm/1000 xu, cap 50)
- HUD: ô moves hiển thị "∞" thay vì số đếm ngược
- Badge ở Home: corner pill hiện high score khi đã có
- `again()` nhánh Zen: chơi lại ngay không cần mạng
- Nút Home: Row 1 lưới THỬ THÁCH (6 items/hàng)
- i18n EN + VI + 20 ngôn ngữ qua `_w20ByLang`

**Kết quả**: 0 analyzer · **611 test pass** (+7 Zen) · i18n coverage 79%+ (universal gaming terms ZEN/GHOST/★ format giữ nguyên English).

---

## 🌊 Wave 21 — Kỹ thuật + Gameplay + Meta (✅ DONE 2026-06-23)

Kết hợp 3 hướng: dọn nợ kỹ thuật · cải tiến gameplay (Boss/Rhythm/World Map) · meta mới (Leaderboard + Mode Rush).
Task chi tiết: [`tasks/todo/w21-*.md`](tasks/todo/).

| Phase | Task | Ưu tiên |
|---|---|---|
| 1 | **Tech Debt**: Fix ad UX Versus + dọn UI widget tái dùng + siết levelUnlock | 🔴 Cao |
| 2 | **i18n Coverage**: Dịch 20 ngôn ngữ key W5/7/8 còn thiếu (~2,400 strings) | 🔴 Cao |
| 3 | **Boss Upgrade**: Phase HP (3 giai đoạn) + 3 attack pattern (block/meteor/shuffle) | 🟡 TB |
| 4 | **Rhythm Upgrade**: BPM dynamic theo groove + judgment animation (PERFECT/GOOD/MISS) | 🟡 TB |
| 5 | **World Map Events**: Treasure chest node + mini-boss node + avatar đi bộ dọc path | 🟡 TB |
| 6 | **Offline Leaderboard**: Bot score tất định top 10 cho Campaign + Daily | 🟡 TB |
| 7 | **Mode Rush (Tốc chiến)**: 2 phút, không giới hạn lượt, match-N gem → +N giây | 🟢 Mới |

**Thứ tự đề xuất**: 1 → 2 → 7 → 3 → 4 → 5 → 6

**Kết quả cả 7 phase — tất cả DONE, task chi tiết chuyển `tasks/done/w21-*.md`:**
1. Tech Debt: khảo sát xác nhận cả 3 mục (ad UX Versus, widget tái dùng, levelUnlock) đã fix ở wave trước.
2. i18n Coverage: fix bug thật — `_w20ByLang` dùng key ngắn (`'es'`, `'fr'`...) thay vì locale đầy đủ, khiến fallback English âm thầm.
3. Boss Upgrade: Phase HP (3 giai đoạn) + retaliation cường độ theo phase.
4. Rhythm Upgrade: BPM dynamic + judgment animation PERFECT/GOOD/MISS.
5. World Map Events: chest node + mini-boss node + avatar đi bộ dọc path (sau này W22 bồi thêm chest reward overlay).
6. Offline Leaderboard: bot score tất định top 10 cho Campaign + Daily.
7. Mode Rush: 2 phút không giới hạn lượt, match-N gem cộng giây.

---

## 🌊 Wave 22 — Polish/Onboarding/Đóng nợ (✅ DONE 2026-07-08)

| Phase | Task | Kết quả |
|---|---|---|
| 1 | Game Feel/Juice | `juiceTierFor` scale theo combo (kWomboCombo=6, combo≥4 shake mạnh, combo==3 shake nhẹ) + `dampenJuice` cho accessibility (giảm nửa shake, còn 0.4x flash, giữ haptic). Trail particles theo fall-distance — **DEFERRED** |
| 2 | World Map Events | chuyển tiếp từ w21-5, chest reward overlay hoàn thiện |
| 3 | First-launch Onboarding | Home tour, key `homeTourSeen`, skip đóng ngay + set seen, `resetProgress` xoá key |
| 4 | Đóng nợ Daily Leaderboard + i18n | dọn nợ nhỏ còn lại |

**Test**: `w22_1_juice_test.dart` (8 case, monotonicity combo 0-12), `w22_3_onboarding_test.dart` (5 case: mở khi chưa xem/skip khi đã xem/hoàn tất set seen/skip set seen ngay/reset xoá key).

---

## 🌊 Wave 23 — i18n W22 + Mini-boss hoàn thiện + Avatar + Content mới (✅ DONE 2026-06-2x → 2026-07-08)

| Phase | Task | Kết quả |
|---|---|---|
| 1 | i18n W22 | `app_translations_test.dart` siết ≥80% ratio thật (không chỉ key-count), spot-check value cụ thể theo ngôn ngữ |
| 2 | Mini-boss hoàn thiện (2A+2B) | `miniBossCleared` 1 lần/world + không trừ mạng khi thua + reset đúng khi đổi mode. 2B: `bossAttackPatternFor(phase, type)` — **deterministic phase-gated**, không phải RNG (chỉ `pickMeteorRegion` dùng Random để chọn toạ độ). Device-verify Pixel 7 Pro xong, task move `done/` |
| 3 | Avatar walking animation | đi bộ dọc World Map path |
| 4 | Nội dung mới | +3 gem skin + 3 board theme (coin-sink 1000-1500), Daily Quest mở rộng pool 9→14 tier + thưởng hoàn-thành-cả-bộ anti-farm. Clan/Friends offline dời sang W24 |

**Test**: `w23_2_miniboss_test.dart` + `w23_2b_boss_attack_test.dart` (phase boundary 0/1/2/out-of-range, HP-based mapping, label key, hpScale, anti-farm claim).

---

## 🌊 Wave 24 — Device-verify batch + đóng nợ nhỏ + content (✅ DONE 2026-07-08)

| Phase | Task | Kết quả |
|---|---|---|
| 1 | Device-verify batch | verify hết feature W22-23 (gem trail, juice, WorldMap node, avatar walk, UI clan/leaderboard/quest-bonus) trên device. Tìm+fix **1 bug thật**: dt-clamp insta-lose khi resume từ background. 1 false-alarm (ad device-level, không phải app) |
| 2 | Boss shuffle/meteor wiring | `bossAttackSignal` → engine react: shuffle board (phase 2) / clear-cell (meteor). =w23-2, đã done |
| 3 | Localize key W23 còn lại | soát lại thấy `_w23ByLang` đã có bản dịch thật đủ 20 ngôn ngữ cho cả 3 key, không cần sửa |
| 4 | Clan content sâu hơn | chọn "đóng góp từ side-mode" — thắng side-mode cộng chung bộ đếm clan (điểm cố định, không đụng win-streak/unlock/lives) |

---

## 🌊 Wave 25 — Chiều sâu mode + tương phản cảm giác (✅ DONE, 1 NO-GO, 2026-07-07/08)

Trigger: user feedback "các mode chơi game sơ sài quá".

| Phase | Task | Kết quả |
|---|---|---|
| 1 | Chiều sâu mode lõi | mode depth 1A xong |
| 2 | Tương phản cảm giác | device-verified 2026-07-07 |
| 3 | Meta gắn mode phụ | meta-retention rã đầy đủ |
| 4 | Spike thể loại mới | **NO-GO** — rotate 2x2 group bị từ chối, ghi nhận verdict, xoá prototype |

---

## 🌊 Wave 26 — HUD/nhạc per-mode + World Map identity + Boss depth (✅ DONE, device-verified 2026-07-08)

| Phase | Task | Kết quả |
|---|---|---|
| 1 | Tương phản mode đợt 2 | HUD chủ đạo 4 mode đồng phục + ColorRush streak + nhạc per-mode |
| 2 | World Map identity | `worldAccents` 5→10 màu, mỗi thế giới bản sắc thị giác riêng (landmark + background) |
| 3 | Meta gắn side-mode | = w25-3, đã rã đầy đủ |
| 4 | Boss depth 1B+1C | ColorRush hot-color bias + hard variant |

**Test**: rising counts 923→937→949→969 pass qua các phase. Device-verify R5CX613VZBR.

---

## 🌊 Wave 27 — i18n Title Case + Collection glossary (✅ DONE 2026-07-04/05)

| Phase | Task | Kết quả |
|---|---|---|
| 1 | Device-verify 1A/1B/1C | done 2026-07-04/05, 1 optional item skip theo quyết định user |
| 2 | ALL-CAPS → Title Case i18n | 2050 giá trị / 15 ngôn ngữ, fix 33 test assertion, `flutter analyze` 0 issue, 959/959 pass |
| 3 | Collection glossary | 6 tên jargon đổi thành tên khái niệm thật sau feedback user (vd `prism_shard`→**Crystal Shard**, `nebula_core`→**Glowing Core**, `aurora_wing`→**Rainbow Wing**), 22 ngôn ngữ, thêm field `descKey` vào `CollectionItem`, `CollectionScreen` chuyển `StatefulWidget` với tap-to-detail `NeonDialog.overlay` |

---

## 🔍 Audit toàn codebase + vá 5 gap test quan trọng nhất (✅ DONE 2026-07-08)

Audit full logic/data/Flame/GetX + test coverage w25-27. Kết quả: logic/data/Flame/UI sạch, 5 gap test tồn tại. Đã vá cả 5.

| # | Gap | Vá | File |
|---|---|---|---|
| 1 | Clan side-mode contribution: test cũ gọi thẳng `addSideModeContribution()`, bỏ sót đường dây thật `game_screen_controller.dart` → `game.onGameEnd()` | +2 test đi qua wiring thật (win cộng điểm, lose không cộng) | `test/w23_6_clan_test.dart` |
| 2 | Boss `voidType` attack pattern: 0 test tồn tại cho nhánh escalation riêng (shuffle mở màn, meteor chỉ phase 2, không block) | +5 test (escalation, out-of-range, no-block, so sánh với pulse) | `test/w23_2b_boss_attack_test.dart` |
| 3 | Collection glossary rename (W27.3): 0 test cho 6 tên/mô tả mới dịch đúng 22 ngôn ngữ + dialog tap-to-detail hiện đúng nội dung | +1 test i18n (toàn bộ 22 ngôn ngữ, không chỉ mẫu) + 1 widget test (tap sticker chưa mở → dialog tên thật + mô tả, đóng mất tên) | `test/app_translations_test.dart`, `test/widget/w14_screens_test.dart` |
| 4 | Title Case (W27.2, 2050 giá trị ALL-CAPS→Title Case) 0 test khoá lại — ai đó `.toUpperCase()` giá trị mới sẽ lọt qua im lặng | +1 test regression quét toàn bộ en_US + vi_VN, phát hiện ALL-CAPS (charset Việt tường minh, tránh false-positive range Unicode trùng Cyrillic/Devanagari) | `test/app_translations_test.dart` |
| 5 | `CoinChip` 0 test; `fmtDur` không có test biên; `dailyBestScore` chỉ có test seed storage tay, chưa qua đường ghi thật `checkEnd()` | +2 widget test CoinChip (hiển thị số xu, reactive); +4 test biên fmtDur (0s/59s/60s/3599s, quirk ≥1h wrap về 00); +3 test dailyBestScore qua `forceWin`+`checkEnd()` thật (ghi đè cùng ngày, giữ nguyên nếu thấp hơn, reset ngày mới, không ghi khi thua) | `test/widget/common_widgets_test.dart`, `test/w10_format_test.dart`, `test/w9_daily_challenge_test.dart` |

**Kết quả**: tất cả test file liên quan pass, `flutter analyze` 0 issue.

## 🌐 Vá gap i18n Wave 4 — dịch đủ 432 key cho 20 ngôn ngữ (✅ DONE 2026-07-08)

`_extraEn` (432 key: rule_*, tutorial, leaderboard, chest, quest, clan,
boss_type, ach_desc_*, story dialogue...) chỉ dịch ~5% cho mỗi ngôn ngữ
trong 20 ngôn ngữ (es/fr/de/pt/ru/zh/ja/ko/it/id/th/hi/ar/tr/nl/pl/fil/ms/
uk/bn) — phần còn lại rơi về fallback English im lặng qua `keys` getter.
Test `≥80% dịch` cũ không bắt được vì tính trên TOÀN BỘ key mọi wave, bị
wave khác (đã dịch đủ) pha loãng.

| # | Việc | Kết quả |
|---|---|---|
| 1 | Dịch 432 key/ngôn ngữ × 20 ngôn ngữ (Agent tool, 1 agent/ngôn ngữ, không dùng Workflow) | Toàn bộ 20 `_extraXx` map đạt 432/432 key khớp `_extraEn` |
| 2 | Sửa riêng fil_PH: agent đầu bỏ dịch 73 key thật (Leaderboard/Shop/Tournament/tên world/collection...), không phải loanword hợp lệ — xác nhận qua so sánh Ms/Id/Tr đều dịch đủ các key này | +1 agent dịch bổ sung 73 key, splice thay thế |
| 3 | Test regression scoped riêng Wave 4 (không pha loãng), assert ≥95% dịch/ngôn ngữ, loại trừ ~59 key hợp lệ giữ English (proper noun NPC/world/item, placeholder thuần, tên mode/rank quốc tế — xác định bằng thống kê giống English ở ≥3/20 ngôn ngữ dịch độc lập) | `test/app_translations_test.dart` — test mới pass cả 20 ngôn ngữ |

**Kết quả**: `flutter analyze` 0 issue · `flutter test --exclude-tags slow` toàn bộ pass.
