# Product Backlog — Pop Star Blast

Index đầy đủ story theo epic. Ký hiệu: SP = story point, Pri = MoSCoW.
DoD/DoR chung ở `README.md`. Trạng thái mặc định 📋 To Do.

---

## E1 — Art Revamp: Bright Casual Pivot (Must) — ✅ Done (2026-08-02)

> Audit đối chiếu từng story S1-S12 với code thật (`neon_theme.dart`, `neon_bg.dart`,
> `neon_button.dart`, `block_component.dart`, `game_screen.dart` HUD, `home_screen.dart`,
> `level_select_screen.dart`, `shop/guide/settings_screen.dart`, `neon_dialog.dart`,
> `star_mascot.dart`) xác nhận đủ 12/12 story: palette bright-casual, background gradient
> sáng, nút chunky, block gloss/gradient theo material, HUD progress bar + booster tray,
> home casual + mascot + PLAY lớn, level-select dạng path cong (v/l stretch goal S7 đã
> đạt), shop/guide/settings casual card, dialog celebration, mascot 4 mood state
> (idle/happy/sad/cheer). Không còn dấu vết nền tối "neon-dark" trong flow mặc định
> (dark mode chỉ tồn tại như flag tuỳ chọn, không bật mặc định).

Mục tiêu: chuyển từ neon-dark tĩnh sang bright-casual (Candy-Crush): nền sáng ấm,
palette pastel + accent neon, nút chunky, mascot ngôi sao, cảm giác "kẹo".

| Story | Mô tả | SP | Pri |
|-------|-------|----|----|
| E1-S1 | Design tokens & palette bright-casual | 5 | Must |
| E1-S2 | Background sáng ấm (gradient + decor) | 3 | Must |
| E1-S3 | Nút chunky casual (bevel/gloss/press) | 3 | Must |
| E1-S4 | Re-skin block sang candy trên nền sáng | 3 | Must |
| E1-S5 | HUD casual (score capsule + progress bar target) | 5 | Must |
| E1-S6 | Home redesign (mascot + big play) | 5 | Must |
| E1-S7 | Level select dạng path/map casual | 8 | Should |
| E1-S8 | Shop redesign card casual | 3 | Should |
| E1-S9 | Guide redesign | 2 | Could |
| E1-S10 | Settings redesign | 3 | Could |
| E1-S11 | Dialog win/lose/quit casual + khung celebration | 3 | Must |
| E1-S12 | Mascot ngôi sao: asset + reaction states | 5 | Should |

**E1-S1 Design tokens** — *As a* dev *I want* bộ token màu/typography/spacing/shadow
bright-casual *so that* mọi screen đổi đồng bộ 1 nguồn.
AC: (1) `NeonTheme` (hoặc `AppTheme` mới) có palette nền sáng + block pastel +
accent; (2) đổi token → toàn app đổi, không hardcode màu rời; (3) tương phản chữ
đạt đọc được trên nền sáng.
Tasks: sửa `lib/core/neon_theme.dart` (thêm/đổi bg, panel, text, gemColors pastel;
giữ API `glow()`); bảng token trong doc; rà callsite hardcode `Color(0x…)`.
Dep: chặn E1-S2..S12, E3 màu.

**E1-S2 Background** — nền gradient sáng ấm + decor tĩnh nhẹ (bokeh/ngôi sao mờ)
thay `NeonBg` space-đen. File: `lib/presentation/widgets/neon_bg.dart`. SP3.

**E1-S3 Buttons** — `NeonButton` chunky: bevel top-light, gloss, đổ bóng đáy,
bounce khi nhấn (scale 0.96). File: `neon_button.dart`. SP3. (Anim nhấn giao E3-S2.)

**E1-S4 Block re-skin** — block candy trên nền sáng: outline đậm, gloss, saturation
cao; đảm bảo phân biệt màu cho người mù màu (thêm nhạt/biểu tượng nhỏ tùy chọn).
File: `lib/game/block_component.dart`. SP3.

**E1-S5 HUD** — capsule điểm bo tròn + thanh progress target (fill theo score),
khay booster casual. File: `game_screen.dart` (`_Hud`). SP5.

**E1-S6 Home** — layout casual: logo lớn, nút PLAY khổng lồ, mascot chào, hàng
entry (shop/guide/settings) dạng casual. File: `home_screen.dart`. SP5.

**E1-S7 Level select** — đổi grid phẳng sang đường path uốn (node level nối bằng
đường), tile casual + sao. File: `level_select_screen.dart`. SP8. (Có thể giai đoạn 1
giữ grid, chỉ re-skin; path map là stretch.)

**E1-S8..S11** — Shop/Guide/Settings/Dialog áp token + layout casual. Files tương ứng.

**E1-S12 Mascot** — nhân vật ngôi sao (asset PNG/vẽ shape), state: idle/cheer/sad,
dùng ở Home + win/lose. Placeholder vẽ bằng canvas nếu chưa có art. SP5.

---

## E2 — Gameplay Animation & Juice (Must) — ✅ Done (2026-08-02)

> Toàn bộ triển khai chi tiết hơn qua `doc/task/tasks/A1..A9-*.md` (đã audit
> checkbox + verify trên device thật, không còn hạng mục nào mở). Bảng dưới
> giữ lại làm lịch sử/tham chiếu, không còn là việc cần làm.

Mục tiêu: pop/rơi/collapse có chuyển động mượt + phản hồi đã tay. Đây là đòn bẩy
"vui" lớn nhất. Hiện block biến mất tức thì (`_rebuildBoard` dựng lại toàn bộ).

| Story | Mô tả | SP | Pri |
|-------|-------|----|----|
| E2-S1 | Pop: scale-up + fade + particle burst | 5 | Must |
| E2-S2 | Rơi (gravity) tween ease/bounce | 5 | Must |
| E2-S3 | Collapse cột: trượt trái mượt | 3 | Must |
| E2-S4 | Preview chọn nhóm: highlight/pulse + điểm dự kiến | 3 | Should |
| E2-S5 | Combo feedback theo cỡ nhóm (to hơn = đã hơn) | 3 | Could |
| E2-S6 | Bomb: hiệu ứng nổ 3x3 | 3 | Should |
| E2-S7 | Shuffle: block bay + xếp lại | 3 | Could |
| E2-S8 | Undo: animation đảo ngược | 2 | Could |
| E2-S9 | Ngân sách perf + tránh input khi đang anim | 2 | Must |

**E2-S1 Pop** — *As a* player *I want* block nổ có hiệu ứng *so that* thao tác đã
tay. AC: nhóm được chọn phóng to nhẹ rồi mờ dần (~150–200ms) + hạt màu bắn ra;
điểm cộng sau khi anim; không kẹt nếu tap nhanh.
Tasks: `BlockComponent` thêm effect (Flame `ScaleEffect`+`OpacityEffect`/`RemoveEffect`);
particle qua Flame `ParticleSystemComponent`; `pop_star_game._tryPop` chờ anim xong mới
`applyGravityAndCollapse`. Dùng `rhythm_clock`? không — dùng Flame effect controller.
Dep: E2-S9 (khoá input khi anim).

**E2-S2 Rơi** — block ở trên hố rơi xuống bằng tween (ease-in + nảy nhẹ) thay vì
snap. AC: vị trí cuối khớp `applyGravityAndCollapse`; nhiều block rơi song song;
thời lượng ~200–300ms. Tasks: thay `_rebuildBoard` bằng cơ chế di chuyển component
hiện có tới vị trí mới (`MoveToEffect`), chỉ tạo/huỷ khi cần.

**E2-S3 Collapse** — khi cột rỗng, các cột phải trượt trái mượt. `MoveToEffect`. SP3.

**E2-S9 Perf & input-lock** — cờ `isAnimating` chặn tap khi đang diễn hoạt; cap
số effect/frame; test 60fps trên device tầm trung. File: `pop_star_game`,
`game_screen_controller.handleBoardTap`.

---

## E3 — Game-wide Animation & Transitions (Should) — ✅ Done (2026-08-02)

> Chi tiết qua `doc/task/tasks/G1..G8-*.md` (audit checkbox + verify device
> thật). Ngoại lệ duy nhất: idle shimmer trong G8 được code xong, test trên
> device, rồi **chủ động xoá** (2026-07-15) vì gây chói mắt — không phải việc
> còn dang dở, xem ghi chú trong `G8-glow-burst-shimmer.md`.

| Story | Mô tả | SP | Pri |
|-------|-------|----|----|
| E3-S1 | Route transition (slide/scale) giữa screen | 3 | Should |
| E3-S2 | Micro-interaction nút (press bounce) toàn cục | 2 | Should |
| E3-S3 | Dialog pop-in bounce enter/exit | 2 | Should |
| E3-S4 | HUD score count-up + progress fill mượt | 3 | Should |
| E3-S5 | Coin bay vào ví khi thưởng | 3 | Could |
| E3-S6 | Win celebration: confetti/sao + mascot cheer | 5 | Must |
| E3-S7 | Lose feedback: rung nhẹ + mascot buồn | 2 | Should |
| E3-S8 | Level unlock reveal ở level-select | 3 | Could |
| E3-S9 | Idle/attract (title pulse, mascot idle) | 2 | Could |

AC chung: 60fps, tôn trọng reduce-motion nếu bật; không chặn thao tác quá lâu
(skip được bằng tap). Files: `game_screen.dart`, `neon_dialog.dart`, `main.dart`
(GetX `defaultTransition`), `coin_chip.dart`.

---

## E4 — Test Coverage đầy đủ (Must)

Mục tiêu: phủ mọi case unit + widget + integration. Hiện có: pop_detector,
pop_collapse, levels, 2 widget smoke + win-flow, 1 integration lifecycle.

| Story | Mô tả | SP | Pri |
|-------|-------|----|----|
| E4-S1 | Hạ tầng test + helper (pump, mock storage, golden) | 3 | Must |
| E4-S2 | Unit pop_detector đủ case (biên, ragged, full, đơn lẻ) | 3 | Must |
| E4-S3 | Unit pop_collapse đủ case (đa cột, dồn, no-refill, cao) | 3 | Must |
| E4-S4 | Unit GameController: score/star/coin/unlock/reset | 5 | Must |
| E4-S5 | Unit booster: bomb biên, shuffle giữ multiset, undo stack | 5 | Must |
| E4-S6 | Unit levels: invariant + achievability (greedy sim) | 3 | Should |
| E4-S7 | Widget mọi screen render + tương tác chính | 8 | Must |
| E4-S8 | Widget dialog win/lose/quit flow | 3 | Must |
| E4-S9 | Widget i18n: không lộ key, đổi ngôn ngữ | 2 | Should |
| E4-S10 | Integration: lifecycle đầy đủ + booster + resume | 5 | Must |
| E4-S11 | Golden test screen chính (regression sau revamp) | 5 | Should |
| E4-S12 | Coverage report + ngưỡng tối thiểu | 3 | Could |

Ghi chú: E4-S6 chuyển greedy-bot sim (đang ở scratchpad) thành test chính thức
`test/data/levels_achievability_test.dart`. E4-S11 golden CHỜ E1 xong (chốt visual).
Anim (E2/E3) test bằng pump theo mốc thời gian + kiểm trạng thái cuối, không so pixel.

**E4-S5** ✅ Done (2026-08-05) — `test/game/booster_test.dart` (151 dòng, dựng
`PopStarGame` thật qua `GameWidget` theo pattern `cell_at_test.dart`, gọi thẳng
trigger method cho bomb/shuffle/undo, xác nhận biên + giữ multiset + stack undo).
Commit `e64f991`.

**E4-S6** ✅ Done (2026-08-05) — `test/data/levels_achievability_test.dart` (168
dòng, có assertion thật — mô phỏng greedy bot theo đúng `_blastCellsFor` của
`pop_star_game.dart` line/bomb/rainbow, không phải file stub). Commit `e64f991`.

**E4-S1, S2, S3, S4, S7, S8, S9, S10, S11** — re-verify lại nguồn thay vì tin
ước lượng cũ: đã **thoả mãn từ trước Round-7**, không cần việc mới.
- S1: 46 file test dùng chung pattern `SharedPreferences.setMockInitialValues` +
  `Get.put(StorageService(...))` nhất quán (helper "de facto" qua convention, không
  phải hàm `pumpApp()` tách riêng — chấp nhận được, không phải gap thật).
- S2/S3/S4: `test/logic/pop_detector_test.dart`, `pop_collapse_test.dart`,
  `test/presentation/game_controller_test.dart` đã tồn tại và chạy trong suite
  chính (`flutter test --exclude-tags slow`).
- S7: `test/widget/` có 45+ file, phủ gần như mọi screen/widget (achievements,
  boss_rush, guide, home, settings, shop, trophy_room, star_road, mascot_wardrobe...).
- S8: `neon_dialog_test.dart` + `game_screen_smoke_test.dart` phủ flow dialog.
- S9: `test/core/locale_service_test.dart` + `app_translations_test.dart` (parity
  key 22 ngôn ngữ).
- S10: `integration_test/lifecycle_test.dart` + `backup_restore_test.dart`.
- S11: `test/widget/goldens/` có 7 golden test (neon_icon, stroke_text, coin_chip,
  neon_button, neon_app_bar, block_component_material, theme_dark_toggle).

**E4-S12** ❌ Còn mở (Could, ưu tiên thấp) — không tìm thấy config coverage
threshold/gate trong CI hay `pubspec.yaml`. Chưa có việc nào enforce ngưỡng
coverage tối thiểu; để lại cho vòng sau nếu cần.

---

## E5 — Docs & Markdown Audit (Should)

Mục tiêu: xoá sạch dấu vết Neon Jewels / match-3 khỏi tài liệu.

| Story | Mô tả | SP | Pri |
|-------|-------|----|----|
| E5-S1 | Viết lại `CLAUDE.md` cho kiến trúc Pop Star Blast | 5 | Must |
| E5-S2 | Viết lại `README.md` | 3 | Should |
| E5-S3 | Xác nhận `doc/RELEASE_CHECKLIST.md` | 1 | Should |
| E5-S4 | Xác nhận `doc/feat.md` + link plan | 1 | Could |
| E5-S5 | Audit `store-assets/` (ref Neon Jewels) | 3 | Could |
| E5-S6 | Sweep repo `.md` tìm ref cũ (neon_jewels/match-3/side-mode) | 2 | Should |
| E5-S7 | Chốt cấu trúc `doc/` + index | 2 | Could |

**E5-S1** ✅ Done (2026-08-02) — `CLAUDE.md` viết lại đúng quy mô hiện tại: 4 layer +
220-level campaign + `GameMode` enum (10 mode) + side-mode ID-isolation pattern +
toàn bộ meta-progression (prestige, achievements, weekly goal, daily reward/spin,
login streak, season pass, cosmetics, social-lite), có ghi chú rõ clan là UI stub
không backend. File inventory (`lib/logic/` 18, `lib/data/` 18, `lib/game/` 2,
`lib/presentation/controllers/` 4, `screens/` 18, `widgets/` 24) đã verify bằng `ls`
trực tiếp, không chỉ dựa vào agent report.

**E5-S5** ✅ Done (2026-08-05) — `grep -rn "neon_jewels\|Neon Jewels\|match-3" store-assets/`
không còn match nào (Round-7 đã sửa `app-store-screenshots.json`).

**E5-S7** ✅ Done (2026-08-05) — `doc/README.md` tồn tại, hoạt động đúng vai trò
index (bảng liên kết `feat.md` / `RELEASE_CHECKLIST.md` / `task/README.md`).

**E5-S2, S3, S4, S6** — re-verify lại nguồn: **thoả mãn từ trước Round-7**.
- S2: `README.md` gốc đã viết lại đúng cho Pop Star Blast (không còn mô tả
  match-3 cũ), có link `feat.md` + `task/`.
- S3: `doc/RELEASE_CHECKLIST.md` tồn tại và có checklist tự động + thủ công.
  Sweep lần này phát hiện 1 số liệu cũ ("200 màn" từ thời MVP) — đã sửa thành
  "240 màn" trong cùng lần audit này (không phải việc mới, chỉ đồng bộ số liệu).
  Cập nhật (Item 1, World 13): dòng này của `RELEASE_CHECKLIST.md` được sweep
  tiếp sang "260 màn" — số liệu hiện tại của file là "260 màn", không còn là
  "240 màn" như câu trên mô tả tại thời điểm viết.
- S4: `doc/feat.md` tồn tại, có link tới `doc/task/` plan.
- S6: sweep `grep -rln "neon_jewels\|match-3" --include=*.md .` — các match còn
  lại (ví dụ dòng mở đầu `README.md`/`RELEASE_CHECKLIST.md` "Fork mới từ Neon
  Jewels") là tham chiếu lịch sử fork **cố ý giữ lại** theo đúng phần "History"
  của `CLAUDE.md`, không phải dấu vết code cũ còn sót — không cần xoá.

---

## E6–E9 — Round 9: audit toàn source (2026-08-11)

> Chi tiết đầy đủ + sprint plan: [`ROUND-9.md`](ROUND-9.md).
> Nguồn: đọc toàn bộ `lib/` + đối chiếu 2 AI agent độc lập (`codex exec`,
> `claude -p`). Mọi bug đã verify lại với source thật trước khi ghi.
>
> **Phạm vi đã chốt với PO:** hardening + retention + content. **KHÔNG**
> đưa quảng cáo hay IAP vào backlog — game giữ hướng miễn phí hoàn toàn.
> Mọi cơ chế "cơ hội thứ hai" trả bằng coin/booster có sẵn.

### E6 — Hardening: đúng đắn, chống gian lận, hiệu năng (Must, 34 SP)

| ID | Mô tả | SP | Pri | Mức |
|----|-------|----|----|-----|
| X16 | Test suite **đang đỏ** — `RELEASE_CHECKLIST.md` chưa sweep "260 màn" | 1 | Must | P0 |
| X17 | Undo không rollback counter đời → farm achievement/quest/weekly/clan | 5 | Must | P1 |
| X18 | `star_owned_pets` JSON hỏng → `onInit` throw → **app không boot** | 2 | Must | P1 |
| X19 | `resetProgress()` bỏ sót 8 key + `remixBest` → progress ma sau reset | 3 | Must | P1 |
| X20 | Undo xoá mất `powerKind` của power tile đã có trên bàn | 3 | Must | P1 |
| X21 | Undo không khôi phục `freezeTurnsLeft` | 2 | Should | P2 |
| X22 | Idle pet trả thưởng cho thời gian trước khi ấp + farm bằng chỉnh đồng hồ | 3 | Must | P1 |
| X23 | Swap cùng-ô / Shuffle no-op vẫn tiêu booster | 2 | Should | P2 |
| X24 | ~6 lần ghi `SharedPreferences` **mỗi cú tap** trên hot path | 5 | Must | P1 |
| X25 | `decodeReplay`/challenge code không giới hạn payload → treo/OOM UI | 3 | Should | P2 |
| X26 | Khoá AES-GCM backup hard-code trong binary | 3 | Should | P2 |
| X27 | Guard phòng thủ: crate trừ coin trước khi roll, `featuredLevelId` chia 0 | 2 | Could | P2 |

Thứ tự bắt buộc: **X16 trước tiên** (unblock CI) → X17/X20/X21 gộp 1 nhánh
(cùng đụng `_saveUndo`) → còn lại song song.

### E7 — Test coverage cho vùng chưa cover (Must, 16 SP)

| ID | Mô tả | SP | Pri |
|----|-------|----|----|
| T2 | 5 controller không có test nào (`game_screen`, `home_screen`, `pass_and_play`, `treasure_map`, `raid_boss`) | 8 | Must |
| T3 | `wildcard_tile`, `pigments`, `mascot_skins`, 4 bảng bot leaderboard | 3 | Should |
| T4 | Fuzz save hỏng + test whitelist `resetProgress` — lưới an toàn cho X18/X19 | 5 | Must |

### E8 — Enhance: biến hệ vanity thành hệ có ý nghĩa (Should, 39 SP)

| ID | Mô tả | SP | Pri |
|----|-------|----|----|
| I81 | `WeatherKind` gắn luật gameplay thật (đang chỉ là skin) | 5 | Should |
| I82 | Star Pet có passive nhẹ (đang thuần cosmetic) | 5 | Should |
| I83 | Sky Shrine thành skill tree cho Prestige — NG+ có chiều sâu | 8 | Should |
| I84 | Home gợi ý "làm gì tiếp theo" thay vì liệt kê 14 mode | 5 | **Must** |
| I85 | FTUE dạy target/sao/combo/không-refill, không chỉ 1 hint | 5 | **Must** |
| I86 | Comeback bonus kèm digest "bạn đã bỏ lỡ gì" | 3 | Could |
| I87 | Milestone Journal xuất share card "hành trình của bạn" | 3 | Could |
| I88 | Second chance khi kẹt — trả bằng coin, **không** quảng cáo | 5 | Should |

I84 + I85 là 2 việc tác động retention lớn nhất đợt này.

### E9 — Tính năng mới / độc quyền (Could, 55 SP)

| ID | Mô tả | SP | Pri |
|----|-------|----|----|
| F16 | Ghost Duel bất đồng bộ — xem ghost đối thủ chạy trên bàn mình | 8 | Should |
| F17 | Combo Bank — tiền tệ nối 14 side-mode đang là silo | 5 | Should |
| F18 | Puzzle Lab Daily — board tự vẽ thành thử thách hằng ngày | 3 | Could |
| F19 | Pigment Fusion — pha 2 pigment ra pigment hiếm | 5 | Could |
| F20 | Boss Relay — 2 người thay phiên đánh chung 1 boss HP pool | 13 | Could |
| F21 | Mirror Draft — tap nổ đối xứng ở nửa bàn đối thủ | 8 | Could |
| F22 | Tile-DNA Lab — người chơi tự phối cơ chế special tile | 13 | **Won't** (đợt này) |

**Đề xuất: chỉ lấy F16 + F17.** Game đã có 14 mode; mode thứ 15 không ai
chơi là rủi ro chính của epic này. F20 và F21 trùng mục đích (co-op 2 người
cùng máy) — chỉ làm một. F22 đã ghi rõ điều kiện mở lại trong file của nó.
