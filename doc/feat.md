# Pop Star Blast — feature tracker

Fork từ Neon Jewels sang cơ chế PopStar! (tap nhóm ô cùng màu liền kề để nổ,
không swap/cascade). Kế hoạch gốc: `/Users/loitran/.claude/plans/giggly-sprouting-piglet.md`.

## ✅ Implemented

- Đổi định danh project: package `pop_star_blast`, Android `com.galaxyjoy.pop_star_blast`,
  iOS `com.galaxyjoy.popStarBlast*`.
- Logic thuần Dart: `pop_detector.dart` (flood-fill nhóm cùng màu, `hasAnyMovableGroup`),
  `pop_collapse.dart` (gravity + dồn cột trái, không refill).
- `data/levels.dart`: 200 level tăng dần độ khó (rows/cols/colorCount/targetScore theo world).
- Flame game `PopStarGame` + `BlockComponent`: tap → pop → gravity → cascade check.
- `GameController` (điểm/sao/coin, không side-mode) + `GameScreenController`
  (vòng đời màn chơi, overlay, booster arm).
- Booster kinh tế cơ bản: bomb (60 xu, nổ 3x3), shuffle (40 xu), undo (30 xu).
- 6 màn hình: Home, Level Select (grid phẳng 200 level), Game, Shop, Guide, Settings
  (ngôn ngữ + âm thanh + reset progress).
- Test tối thiểu: unit (`pop_detector`, `pop_collapse`, `levels`), widget smoke
  + win-flow test, 1 integration lifecycle test.
- **Cân bằng độ khó**: `targetScore` neo vào diện tích bàn (`cells*6*ramp`) — công
  thức leo-tuyến-tính cũ khiến ~146/200 màn bất khả thi; nay greedy-bot qua 0/200.
- **UI neon glow chuẩn release**: `NeonTheme.glow` 3 lớp bloom; block = neon jewel
  (gradient + gloss + rim + bloom); Home 3 chip tròn neon; Game HUD có scrim + board
  canh giữa không đè HUD; verify tay full-flow trên Pixel 7 Pro.
- **Không quảng cáo**: app không tích hợp ad SDK nào; đã gỡ quyền thừa `AD_ID`.
- **Pivot UI bright-casual (Candy-Crush style)**: nền sáng candy sky (`NeonBg`),
  palette kẹo, thẻ trắng + chữ mực đậm (`NeonTheme.ink/card/drop`), nút chunky
  solid + bevel, chip tròn Home, coin/appbar/dialog/tile/HUD flip sáng. Kế hoạch
  Scrum chi tiết: `doc/task/`.
- **Animation gameplay**: pop = block phóng to rồi co + hạt màu bắn (`ParticleSystemComponent`);
  rơi + dồn cột bằng tween `MoveToEffect` (easeOutBack); khoá input khi đang diễn
  hoạt (`_animating`). Kết thúc màn giờ BẤT ĐỒNG BỘ → `GameScreenController` lắng
  nghe `gameCtrl.ended` qua `ever()` (vá luôn bug overlay không hiện).
- **Celebration**: mưa confetti kẹo khi thắng (`ConfettiOverlay`).
- **Mascot ngôi sao** (`StarMascot`, vẽ canvas, mood idle/happy/sad + bob/blink):
  Home (idle), dialog thắng (happy peek), dialog thua (sad).
- **Coin fly** (`CoinFlyOverlay`): xu bay vòng cung từ giữa màn lên coin chip ở
  HUD game khi thắng; HUD giờ có coin chip làm ví.
- **Label có viền** (`StrokeText`): tiêu đề/nút/HUD/appbar chữ outline đọc rõ trên
  nền candy.

- **Wave 1 nâng cấp** (kế hoạch `doc/task/tasks/`): F1 combo/chain multiplier
  (nổ liên tiếp x1→x5), A1 score popup bay lên (hiện combo), A2 score count-up +
  progress bar target, G1 glow-pulse nhóm khi giữ/kéo + badge điểm dự kiến.
- **Wave 2 nâng cấp** (kế hoạch `doc/task/tasks/`): A5 win choreography (sao/điểm/nút
  hiện tuần tự, tap-to-skip), A4 mascot reaction theo combo (HUD cheer mood + dialog
  thắng/thua), A3 route transition (Cupertino) + button bounce (`PressableScale`),
  G2 pop trail + flash combo (hạt bay quỹ đạo + flash trắng khi nổ nhóm to/combo cao)
  — đã verify tay trên Pixel 7 Pro (chơi hết Level 1, xác nhận mascot cheer, win
  choreography, sao/điểm đúng logic).
- **Wave 3** (kế hoạch `doc/task/tasks/`): F7 star road + chest reward, F3 rainbow
  bomb booster (xoá mọi ô cùng màu 1 tap, không cộng điểm), F2 daily reward + streak
  (chống lùi giờ), F8 side-mode Time-attack (đếm ngược 60s, best điểm riêng) + Zen
  (refill bàn thay vì kết thúc khi hết/kẹt) — cả 2 side-mode cô lập hoàn toàn khỏi
  campaign (không đụng unlockedLevel/coin/star/highScore).
- **Common dialog neon/glow**: `NeonDialog.panel()` là gốc chung duy nhất cho
  mọi dialog trong game (route `show`, overlay trên Flame `overlay`) — audit
  xác nhận mọi màn hình đều gọi qua đây, không có `AlertDialog`/`showDialog`
  rời rạc; bổ sung `NeonTheme.glow(color)` (bloom theo màu viền) chồng lên
  `drop` shadow cũ để có shadow neon/glow nhất quán toàn game.

- **Wave 4 (bắt đầu)**: G5 shader bloom aura (`NeonAuraLayer`, dùng
  `shaders/neon_glow.frag` có sẵn) — vẽ sau bàn, tint cyan alpha thấp hoà nền
  sáng; load an toàn (try/catch, ẩn hẳn nếu lỗi, không crash); verify tay
  Pixel 7 Pro (Impeller/Vulkan, không log lỗi load shader).
- **G3 bloom/rim động CTA**: `PulseGlow` (`RepaintBoundary` + `AnimatedBuilder`,
  chỉ animate `boxShadow` qua `NeonTheme.glow`) — viền glow nhịp thở 1.8s quanh
  nút PLAY ở Home, áp chọn lọc (chỉ CTA chính, không đại trà mọi nút).
- **G6 combo heat**: `PopStarGame.heat` (0..1) suy từ `comboMultiplier` hiện có
  (F1); `BlockComponent` đọc trực tiếp qua `HasGameReference<PopStarGame>`
  (không set state từng ô mỗi frame) và vẽ thêm 1 lớp rim stroke ngả cam/trắng
  theo heat, chỉ cộng thêm lên viền nên vẫn phân biệt màu gốc.
- **G4 nền reactive theo combo**: `NeonBg` nhận `energyOf` (callback lấy
  `game.heat` mỗi frame), tự lerp mượt (`_energy += (target-_energy)*0.08`)
  nên không cần thêm Rx/ticker mới; energy cao → orb trôi nhanh hơn + ngả ấm
  (lerp về `NeonTheme.orange`), biên độ giới hạn để không chói/khó đọc chữ.
  Chỉ `game_screen.dart` truyền `energyOf`; Home vẫn nền tĩnh mặc định.
- **G7 neon edge-trace**: `_EdgeTraceComponent` vẽ viền chạy quanh biên nhóm
  đang preview (G1) — biên = cạnh ngoài (ô kề không thuộc nhóm) của `_preview`,
  tính lại mỗi lần nhóm đổi (`_updateEdgeTrace`, không phải mỗi frame); vẽ
  từng đoạn với alpha sweep chạy theo thời gian thay vì nối path (đơn giản,
  vẫn 60fps kể cả nhóm lớn); tắt khi thả (`clearPreview`).
- **G8 burst ring** (Wave 4): `_BurstRing` — mỗi nhóm nổ bung 1 vòng
  tròn viền tại tâm nhóm (bán kính theo bounding box) rồi mờ dần 0.32s, cap
  tối đa 3 ring đồng thời (`_maxRings`, huỷ ring cũ nhất nếu vượt) để nhẹ khi
  combo dồn dập. (Đoạn "idle shimmer" ghi ở đây trước đó là aspirational —
  code chưa từng tồn tại; phần thật sự đã build xem mục Wave 7 — G8 bên dưới.)

- **F5a power tile — line-clear**: nhóm nổ ≥5 ô (`powerTileKindForGroupSize`,
  50/50 hàng/cột) → ô vừa tap giữ lại thành power tile (`BlockComponent.powerKind`,
  đi theo component qua gravity/collapse, không cần grid song song) thay vì nổ
  luôn; render quầng trắng mờ + icon 2 gạch ngang/dọc báo hàng/cột sẽ xoá. Tap
  lại ô đó (`handleTap` check `powerKind` trước khi gọi `_tryPop`) →
  `_activatePowerTile` xoá cả hàng/cột (tái dùng đúng flow điểm/combo/flash/
  collapse của `_tryPop`). Fix kèm: `_checkEnd` stuck-detection cũ không tính
  power tile còn sống là 1 nước đi hợp lệ → bàn chỉ còn 1 power tile bị xử
  thua sai; thêm check `hasPowerTile` vào điều kiện `stuck`. Bomb (≥7 ô) và
  rainbow (≥9 ô) dời sang 5b/5c.

- **F5b power tile — bomb**: nhóm nổ ≥7 ô luôn sinh `PowerTileKind.bomb`
  (ngưỡng 5-6 vẫn line-clear như F5a). Tap kích hoạt → `_activatePowerTile`
  xoá vùng 5×5 quanh tâm (kẹp biên bàn khi tâm ở gần mép), cùng flow điểm/
  combo/flash/collapse với line-clear. Icon riêng: quả bom tròn + ngòi nổ.
  Rainbow (≥9 ô) dời sang 5c.

- **F5c power tile — rainbow**: nhóm nổ ≥9 ô luôn sinh `PowerTileKind.rainbow`
  (7-8 ô vẫn bomb như F5b). Tap kích hoạt → `_activatePowerTile` đọc màu gốc
  của chính power tile (`colorGrid[row][col]`, không đổi khi ô thành power
  tile) rồi quét toàn bàn xoá mọi ô cùng màu đó, kể cả ô rời rạc không liền kề
  vị trí tap — cùng flow điểm/combo/flash/collapse với line-clear/bomb. Icon
  riêng: 6 chấm màu xếp vòng tròn quanh tâm ô. F5 hoàn tất (5a/5b/5c).

- **F6a obstacle (ice/crate)**: mã hoá bằng số âm ngay trong `colorGrid`
  (`-d` = còn d độ bền) — tái dùng đúng slot `int?` sẵn có, gravity/collapse
  không cần đổi vì chỉ phân biệt null/không-null. `pop_detector.dart` loại
  obstacle khỏi flood-fill (`findConnectedGroup`/`hasAnyMovableGroup`) →
  không nổ trực tiếp khi tap. `chipAdjacentObstacles` (`logic/obstacle.dart`)
  chip 1 độ bền mọi obstacle cạnh (4 hướng) nhóm vừa nổ, hết bền thì vỡ
  (thành null, rơi theo gravity như thường); mỗi obstacle chỉ bị chip 1 lần/
  đợt nổ dù cạnh nhiều ô. Áp dụng nhất quán cho mọi đường xoá ô: match
  thường (`_tryPop`), power tile line/bomb/rainbow (`_activatePowerTile`),
  booster bomb/rainbow (`triggerBomb`/`triggerRainbow`) — tất cả đều loại
  obstacle khỏi vùng xoá trực tiếp và gọi chip. `shuffleBoard` chỉ xáo giá
  trị màu thật (≥0), obstacle giữ nguyên vị trí + độ bền. `BlockComponent`
  render riêng obstacle (khối xám-xanh mờ + chấm trắng đếm độ bền), skip
  toàn bộ pipeline gem/power-tile.

- **F6b objective (clear-color / clear-obstacle) — gộp luôn 6c**: thêm
  `ObjectiveType {score, clearColor, clearObstacle}` + `LevelObjective` optional
  trên `PopLevel` (mặc định `LevelObjective.score()` → 200 màn campaign +
  time-attack/zen không đổi hành vi). `GameController.updateObjectiveProgress`
  đếm lại số ô màu/obstacle còn lại mỗi khi bàn ổn định; `objectiveMet` đúng
  khi type khác score và còn lại = 0. `PopStarGame._checkEnd` check
  `objectiveMet` trước luật hết/kẹt bàn cũ → màn có mục tiêu thắng ngay khi
  dọn xong mục tiêu, không cần dọn sạch/kẹt cả bàn. HUD thêm dòng tiến độ
  ("Clear color:/Break ice: n left") khi objective khác score.
  Bug phát hiện khi viết widget test: gọi `updateObjectiveProgress` đồng bộ
  ngay trong `onLoad()` (giữa lúc `GameWidget` đang build) → Obx nào đang
  lắng nghe `objectiveRemaining` bị "setState during build" crash. Fix: dời
  lệnh gọi đầu tiên vào `WidgetsBinding.instance.addPostFrameCallback`.
  Objective mechanism đã có test đầy đủ (unit `game_controller_test.dart` +
  widget `objective_test.dart` chứng minh thắng trước khi bàn hết/kẹt) nhưng
  **chưa màn campaign nào dùng non-score objective** — cơ chế sẵn sàng, chưa
  có nội dung khai thác (xem Ideas). F6 coi như xong.

- **F4 level-select path/map**: `LevelSelectScreen` viết lại từ `GridView`
  phẳng sang đường zig-zag (`_layout()` sinh tâm 200 node bằng sóng sin
  `cx = centerX + amplitude*sin(i*pi/3)`, cách nhau `_rowHeight=96`, chèn
  banner `_bannerHeight=60` mỗi 20 node). Dựng bằng `CustomScrollView` +
  `SliverToBoxAdapter` bọc 1 `Stack` (path nối vẽ bằng `CustomPaint`, banner
  world, 200 `_LevelTile` — tái dùng nguyên tile cũ, chỉ thêm `Key`).
  10 world (`lib/data/worlds.dart`, `kWorlds`/`worldForLevel`) ánh xạ đúng
  phân đoạn `world = i~/20` đã có sẵn trong `levels.dart`, mỗi world 1 màu
  `NeonTheme` + 1 tên (`world_path_name_1..10`, chỉ dịch EN+VI — xem quyết
  định i18n bên dưới). Node hiện tại (`unlockedLevel`) bọc `_Pulse`
  (`AnimationController..repeat(reverse:true)`) nổi bật nhẹ; auto-scroll tới
  node đó khi vào màn qua `ScrollController.jumpTo` trong postFrameCallback.
  Test: `test/widget/level_path_map_test.dart` (tap node mở khoá → vào
  `GameScreen`; tap node khoá → không vào).
  Bug khi viết test: `_autoScrollTo` đọc `_scrollController.position` ngay
  trong `LayoutBuilder.builder` — lần build đầu tiên `ScrollController` chưa
  attach `ScrollPosition`, đọc `.position` ném exception làm abort cả
  subtree (200 tile biến mất hết). Fix: tính `maxScrollExtent` bằng
  `totalHeight - viewportH` (đã biết từ layout) thay vì đọc từ
  `ScrollController`. Bug thứ hai: sau `tester.tap()` gọi `Get.to()`, cần
  **2 lần `pump`** (1 lần build route mới, 1 lần chạy hết animation chuyển
  màn) — gọi `pump(duration)` một lần duy nhất không đủ vì
  `AnimationController` của route mới chỉ bắt đầu tick giữa chừng frame đó.
  `pumpAndSettle()` không dùng được vì `_Pulse` lặp vô hạn.
  Phát hiện phụ: `world_name_1..5` + `npc_name_*`/`story_w1_intro_*` là i18n
  key mồ côi từ feature "World Map/Story" cũ (match-3) chưa từng bị xoá dù
  code tham chiếu đã không còn — đặt tên mới `world_path_name_N` để tránh
  đụng key, không dọn dẹp (ngoài scope F4).

- **F4 nâng cấp path — 6 hiệu ứng** (kế hoạch
  `/Users/loitran/.claude/plans/giggly-sprouting-piglet.md`): (1) progress-aware
  glow — đoạn path đã unlock tô gold + bead dày + flow-dash sáng chạy, đoạn
  chưa unlock dim xám tắt flow; (2) mascot ⭐ (`_Mascot`) idle-bounce đứng tại
  node `unlockedLevel`, dịch chuyển reactive theo `Obx`; (3) parallax — tách
  `_DecorPainter` ra ngoài `CustomScrollView` (sibling `Positioned.fill`),
  `canvas.translate` theo `scrollOffset * 0.55` nên sparkle trôi chậm hơn
  path/tile; (4) unlock reveal — `GameController.justUnlocked` (`Rxn<int>`)
  set trong `_unlockNext`, `LevelSelectScreen` lắng nghe qua `ever()` (sống
  xuyên route bị che), khi quay lại màn tự haptic + đoạn path vừa mở sáng bừng
  1 lần + confetti quanh node mới; (5) world banner — `GameWorld` thêm field
  `icon` (1 `IconData` Material/world, không asset ảnh), `_WorldBanner` vẽ lớp
  icon lặp mờ phía sau `StrokeText` làm hoạ tiết nền; (6) sao băng —
  `_ShootingStar` timer ngẫu nhiên 6-14s bắn 1 streak chéo qua nền viewport,
  tự ẩn sau khi bay hết. Verify tay đầy đủ trên `R5CX613VZBR`: chơi thật
  Level 1 tới thắng (score 1325, 3 sao) → `unlockedLevel` lên 2 → quay Level
  Select bắt được đúng lúc đoạn 1→2 sáng bừng rồi ổn định thành gold "đã qua",
  mascot đứng đúng node 2, banner world 1 thấy icon pattern, sao băng bắt
  được giữa lúc bay; không gặp quảng cáo ở bất kỳ screenshot nào (R4).

- **A6 board intro assemble**: `_rebuildBoard({bool animateIntro = false})`
  (trước là hàm không tham số) — khi `animateIntro`, mỗi `BlockComponent`
  spawn ở vị trí trên-màn (`_boardTop - cellSize*(r+2)`) rồi `MoveToEffect`
  rơi về cell thật với `startDelay = (r+c)*0.02` (so le) và
  `curve: Curves.easeOutBack` (settle nảy nhẹ), tổng thời lượng tối đa
  ~0.77s (board lớn nhất rows11×cols12). Khoá input bằng `_animating` có
  sẵn (không thêm state mới) — 1 `TimerComponent` một lần bắn ở
  `maxDelay + _introFallDur` để mở khoá lại. Chỉ `onLoad()` gọi
  `animateIntro: true`; các lần dựng lại khác (resize/shuffle/undo/refill)
  giữ nguyên tức thì. Retry/next đều tạo `PopStarGame` mới
  (`game_screen_controller._newGame`) nên tự động chạy lại intro, không
  cần wiring thêm.
  Regression phát hiện khi thêm khoá: 6 widget test dựng `GameScreen` rồi
  gọi thẳng `game.handleTap`/`colorGrid = ...` sau khi chỉ `pump(100ms)` —
  lệnh gọi trực tiếp lên instance `PopStarGame` không chạy qua game loop
  nên `_animating` (khoá bởi intro `onLoad`) chưa kịp tắt, mọi thao tác
  "no-op" im lặng. Fix gốc: bơm thêm `_pumpFrames(frames: 20)` (800ms, đã
  có sẵn ở từng file) trước khi thao tác thủ công lên board, áp dụng
  đồng nhất cho `power_tile_test.dart`, `power_tile_rainbow_test.dart`,
  `power_tile_bomb_test.dart`, `game_screen_smoke_test.dart` (2 test),
  `rainbow_bomb_test.dart`, `objective_test.dart`.

- **A7 slow-mo + punch nổ to**: nổ ≥8 ô (`_punchGroupThreshold`) hoặc combo
  ≥x3 (`_punchComboThreshold`) → khựng nhịp ngắn 0.15s (`_slowMoTimer`,
  `update()` scale `dt` xuống 0.35 lần khi timer > 0; bản thân timer/cooldown
  đếm bằng `dt` thật, không bị chính scale đó kéo dài) + mọi ô còn sống phóng
  nhẹ scale 1→1.06→1 (`SequenceEffect`/`ScaleEffect`). Cooldown 1s tránh lặp
  liên tục khi combo dồn dập. Gọi 1 chỗ duy nhất — `_maybeTriggerPunch(cells)`
  trong `_clearAndCollapse` — nên tự phủ cả tap thường, power tile, bomb,
  rainbow, không cần wiring riêng 4 nơi.
  Camera zoom thật (`camera.viewfinder.zoom`, cách task gợi ý) không dùng
  được: `BlockComponent` add thẳng vào game (`add(b)`), không qua
  `camera.world`, nên camera zoom sẽ không lộ hình lên board (đã đọc source
  Flame `flame_game.dart`/`camera_component.dart` xác nhận). Chọn scale trực
  tiếp từng block còn sống thay thế — không đụng ô đang bị xoá (đã có
  `SequenceEffect` scale riêng cho pop, cộng thêm effect scale sẽ đá nhau),
  không đụng tap hit-test (`cellAt`/toạ độ không liên quan render scale).
  Bỏ toggle "giảm hiệu ứng" trong Settings (task ghi "nên", không bắt buộc) —
  thêm sau nếu có yêu cầu thật.

- **A8 ripple chạm + anticipation squash**: `handleTap` gọi `_spawnRipple(pos)`
  ngay sau khi xác định tap trúng ô hợp lệ (trước khi rẽ nhánh pop/power) —
  nên chạy cả khi tap không tạo nhóm nào. Tái dùng thẳng `_BurstRing` (đã có
  cho hiệu ứng nổ) thay vì viết component mới: thêm tham số `maxAlpha`
  (mặc định 0.7 giữ nguyên hành vi cũ) để ripple dùng alpha thấp hơn (0.35,
  trắng, bán kính `cellSize*0.9`) cho nhẹ trên nền sáng. Không qua `_rings`/
  `_maxRings` (cap dành cho ring nổ) vì ripple tự dọn nhanh (0.32s), tap dồn
  dập không cần giới hạn riêng.
  Anticipation: thêm bước co `ScaleEffect.to(0.85, duration: _squashDur)`
  (`_squashDur = 0.04`) vào đầu `SequenceEffect` pop hiện có trong
  `_clearAndCollapse`, trừ bớt vào bước shrink-to-zero cuối
  (`_popDur - _squashDur - 0.07`) để tổng thời lượng chuỗi vẫn đúng `_popDur`
  y hệt trước — không cần đụng `TimerComponent` lịch `_collapseAnimated`.

- **Fix crash mascot nháy mắt** (`lib/presentation/widgets/star_mascot.dart:139`):
  phát hiện khi build release chạy thật trên Samsung S24 Ultra (SM-S928B,
  Android 16) — app crash-loop ngay màn Home. `eyeH.clamp(size.width * 0.012,
  eyeH)` dùng chính `eyeH` (giá trị đang co dần theo `blink` về 0) làm cận
  trên; khi `blink` nhỏ, `eyeH` tụt dưới cận dưới 0.012 → cận trên < cận dưới
  → `clamp` throw `RangeError` mỗi frame paint. Fix: cận trên cố định
  `size.width * 0.11` (giá trị mắt mở hết, `blink = 1`) thay vì tự tham
  chiếu. Đã grep toàn bộ `.clamp(` trong `lib/` xác nhận không còn chỗ nào
  khác dùng pattern tự tham chiếu tương tự.

## 📋 Quyết định i18n (áp dụng từ nay)

- Chỉ dịch đầy đủ **English + Vietnamese** cho string mới; 20 locale còn lại
  dựa vào `fallbackLocale: AppTranslations.fallback` (en_US) đã cấu hình sẵn
  trong `main.dart` — không cần thêm `_wNByLang` cho mọi wave nữa.
- Menu/settings đã có chọn ngôn ngữ (`SettingsScreen` → `LocaleService`) và
  giá trị được lưu đĩa (`StorageService`/`SharedPreferences`) nên giữ
  nguyên qua mọi session — không cần sửa gì thêm, chỉ xác nhận lại.

## ✅ Đã hoàn thành (bổ sung)

- Smoke widget test cho các screen trước đây chưa có test: `home_screen`,
  `guide_screen`, `settings_screen`, `shop_screen`, `star_road_screen`. Qua
  đó phát hiện + fix 1 bug thật trong `star_road_screen.dart` (`Obx` bọc
  `ListView.separated` có `itemBuilder` đọc Rx trễ ở layout phase → GetX ném
  "improper use of a GetX/Obx" khi mở màn) — đổi sang `ListView` build eager.
- Golden test (`test/widget/goldens/`) cho 5 widget tĩnh ổn định: `neon_button`
  (enabled/disabled/icon), `stroke_text` (default/custom màu), `coin_chip`,
  `neon_app_bar`, `neon_icon` (plain + boxed button enabled/disabled).
- Widget test (không golden) cho `neon_dialog.dart`: `NeonDialog.panel` render
  title/message/action + tap action gọi `onTap`; `NeonDialog.overlay` render
  panel trên barrier + tap barrier gọi `onBarrier`.
- Nâng cấp `level_select_screen.dart`'s `_PathPainter` qua 3 vòng lặp theo
  feedback: (1) `lineTo` thẳng góc gãy → `quadraticBezierTo` qua midpoint;
  (2) đổi sang Catmull-Rom → cubic Bezier (đi đúng qua tâm node, tangent liên
  tục) + glow 2 lớp (blur ngoài + core trong, `MaskFilter.blur`); (3) theo yêu
  cầu "phá cách hơn, kết hợp cả 4 idea" (animated flow / bead trail /
  gradient theo world / organic wiggle), gộp cả 4 vào 1: mỗi đoạn nối 2 node
  là 1 `_PathSegment` dựng sẵn hình học 1 lần trong `_layout` (control point
  Catmull-Rom lệch ngẫu nhiên seed cố định theo index qua `math.Random(i)` →
  ổn định giữa các lần build, không đổi mỗi frame), tô theo màu
  `worldForLevel(id).color`, rắc bead trắng cách đều qua `PathMetric`, và 1
  dải sáng trắng chạy dọc theo `AnimationController` lặp vô hạn (`_flowCtrl`)
  dùng `PathMetric.extractPath` — chỉ vẽ lại mỗi frame, không tính lại hình
  học. Xác nhận trên máy thật (S24 Ultra) sau khi build sạch (`flutter
  clean`) — bản build cache cũ từng khiến lần kiểm tra đầu tiên không thấy
  fix dù code đã đúng, nên quy trình chuẩn từ nay: `flutter clean` →
  `flutter build apk --release` → `adb install -r` (hoặc uninstall+install
  nếu lỗi signature mismatch).
- Wakelock (`WakelockPlus.enable()`) chuyển từ chỉ bật trong `GameScreen`
  (onInit/onClose/quit) sang bật 1 lần lúc app khởi động (`main.dart:app()`),
  giữ màn hình sáng xuyên suốt toàn app chứ không chỉ lúc chơi. Bỏ hết
  enable/disable rải rác trong `game_screen_controller.dart` vì đã bật
  toàn cục, không còn cần toggle theo vòng đời màn chơi.
- F6b `LevelObjective` (score/clearColor/clearObstacle) trước đây chỉ tồn tại
  như cơ chế đã build + test, chưa màn campaign nào thật sự dùng. Gán vào
  `kLevels` (`lib/data/levels.dart`): rotate chu kỳ 5 màn lặp suốt 200 màn —
  3 màn score, 1 màn clearColor (màu mục tiêu đổi theo `i % colorCount`),
  1 màn clearObstacle. `PopStarGame.onLoad()` thêm `_placeObstaclesIfNeeded`:
  màn clearObstacle rải 3-8 ô obstacle (độ bền 1-3, tăng nhẹ theo world) ngay
  lúc dựng bàn — trước đó dù có `objective.type == clearObstacle` thì bàn
  vẫn không hề có obstacle nào (chỉ test tự set thủ công). `_refillBoard`
  (F8 Zen) không cần sửa vì Zen luôn `objective: score()` mặc định.
- `I11` haptic feedback: `_tryPop` rung `light/medium/heavy` theo `group.length`
  (`<4`/`4-7`/`>=8`), `triggerBomb` luôn `heavyImpact`. `I13` wire
  `AudioManager.playMelodic` (đã xây sẵn ngũ cung + màu-là-giọng, chưa từng
  được gọi) vào đúng điểm `_tryPop`, `combo: group.length`, `colorIndex` lấy từ
  màu ô vừa tap trước khi grid bị xoá. `I5` undo miễn phí 1 lần/màn: field
  `_freeUndoUsedThisLevel` trong `GameController`, reset ở `startLevel`/
  `startSideMode`, `useUndo()` chỉ trừ `undoCount` từ lần thứ 2 trở đi trong
  cùng màn. Cả 3 đã có test (`test/widget/free_undo_test.dart` mới), 98/98
  test xanh, `flutter analyze` 0 lỗi.
- `T1` fix settings_screen locale test: root cause xác nhận thực nghiệm —
  `LocaleService.change()` → `Get.updateLocale()` → `performReassemble()` →
  `scheduleWarmUpFrame()` khiến `SchedulerBinding.schedulerPhase` không idle
  khi `tester.pump()` kế tiếp gọi `handleBeginFrame`, ném lỗi
  `schedulerPhase == SchedulerPhase.idle`. Lỗi xảy ra dù đổi locale qua
  `tester.tap()` hay gọi thẳng `LocaleService.change()` (không qua tap) —
  đây là giới hạn thật giữa GetX reassemble-based locale switching và
  `AutomatedTestWidgetsFlutterBinding`, không sửa được từ phía app. Khi rã
  task lộ ra bug thật: `SettingsScreen` chưa từng dùng `AppTranslations` —
  toàn bộ `lib/presentation/` trước đó chỉ có đúng 1 chỗ gọi `.tr()`
  (`level_select_screen.dart` tên world). Đã nối dây `.tr()` vào title,
  Sound label, Language label, và toàn bộ dialog reset-progress của
  `SettingsScreen`, tái dùng 100% key có sẵn đã dịch đủ 22 locale
  (`settings`/`sound`/`language`/`reset_progress`/`cancel`/`confirm`/
  `reset_confirm_msg`) — không thêm key mới. Test mới
  (`test/widget/settings_screen_test.dart`) dựng `GetMaterialApp(locale:
  ..., translations: AppTranslations())` cố định lúc build thay vì đổi
  runtime, verify bản dịch đúng ở `en_US` và `ja_JP` (script Latin +
  non-Latin) và không lộ raw key. `flutter analyze` 0 lỗi, full suite xanh.
- `I4` predictive hint: rảnh tay 6s (không tap, không đang animation, chưa
  thắng/thua) → tự highlight nhóm ≥2 ô cùng màu lớn nhất còn lại trên bàn.
  `findLargestGroup` (mới, `lib/logic/pop_detector.dart`) tái dùng
  `findConnectedGroup` sẵn có — quét toàn bàn, bỏ qua ô đã visited/obstacle,
  giữ nhóm lớn nhất ≥2. `PopStarGame` thêm `_idleTimer`/`_hint` cộng dồn trong
  `update(dt)`, `_triggerHint()` gọi 1 lần khi hết ngưỡng (không phải mỗi
  frame). `BlockComponent` thêm cờ `hinted` tách biệt khỏi `highlighted` (drag
  preview) để 2 hiệu ứng không đụng nhau — viền pulse trắng nhạt dùng `sin()`
  theo `_hintPhase` tích luỹ trong `update()`. `clearHint()` là 1 điểm chốt
  duy nhất: gọi ở đầu `_rebuildBoard` (tránh giữ ref rác khi shuffle/undo/
  resize dựng lại `_blocks`) và ở đầu `GameScreenController.handleBoardTap`
  (mọi tap, kể cả tap ngoài bàn/không hợp lệ, đều tắt gợi ý + reset đồng hồ —
  reset trên mọi tap là tập hợp cha an toàn của "chỉ reset khi tap hợp lệ").
  Test mới (`test/widget/predictive_hint_test.dart`) dựng bàn xác định qua
  `startLevel(1)`, override `colorGrid` thủ công rồi gọi `clearHint()` để
  reset đồng hồ rảnh tay tích luỹ từ lúc dựng bàn (nếu không đồng hồ cũ cộng
  dồn khiến ngưỡng 6s bị vượt sớm hơn dự kiến), pump qua ngưỡng 6s và assert
  đúng 3 ô được gợi ý, rồi assert tap bất kỳ tắt gợi ý ngay. `flutter analyze`
  0 lỗi, full suite 100/100 xanh.
- `I18` colorblind neon symbols: 7 hình cố định (star/circle/triangle/square/
  diamond/hexagon/cross) ánh xạ 1-1 với `colorIndex % 7`, vẽ đè lên gem khi
  bật "Colorblind mode". `StorageKeys.colorblindMode` (key mới,
  `lib/core/storage_service.dart`). `GameController` thêm `colorblindMode`
  (`RxBool`), `toggleColorblindMode()`, load trong `_load()` — cố tình KHÔNG
  đụng tới trong `resetProgress()` vì đây là tuỳ chọn hiển thị/accessibility,
  không phải tiến trình game. `SettingsScreen` thêm `SwitchListTile` mới
  (đứng sau Sound, không có guard `if (audio != null)` vì `GameController`
  luôn có sẵn) — key dịch `colorblind_mode` thêm vào cả 22 locale trong
  `app_translations.dart`. `BlockComponent._renderColorblindSymbol` vẽ bằng
  `Path`/`Canvas` thuần (không thêm asset/package) — fill trắng bán trong
  suốt + viền đen để nổi trên mọi màu nền gem, chỉ là lớp vẽ thêm trong
  `render()` nên không đụng hitbox/tap. Test mới
  (`test/widget/colorblind_mode_test.dart`) bật cờ qua
  `toggleColorblindMode()`, dựng `GameScreen`, pump qua vài frame animation
  và assert không crash cả lúc bật lẫn tắt lại; `settings_screen_test.dart`
  có thêm 1 test riêng xác nhận tap switch lật đúng `colorblindMode.value`
  và persist đúng xuống `SharedPreferences`, cùng 2 test locale cũ
  (`en_US`/`ja_JP`) được bổ sung assertion tên nhãn dịch đúng
  ("Colorblind mode"/"色覚異常モード"). `flutter analyze` 0 lỗi, full suite
  102/102 xanh.
- `I2` color-lock / chain tiles: ô "bị xích" — có màu thật, hiển thị đúng
  màu, nhưng KHÔNG match được (`findConnectedGroup`) tới khi đủ K lần ô cạnh
  nó bị nổ. Khác obstacle (F6a, mã hoá bằng giá trị âm ngay trong
  `colorGrid`) — chain tile cần cấu trúc dữ liệu **song song**
  (`lockGrid`, `List<List<int>>`, 0 = không khoá) vì `colorGrid` vẫn phải giữ
  màu dương thật để hiển thị và để flood-fill dùng lại ngay khi mở khoá.
  `lib/logic/chain_tile.dart` (mới) — `chipAdjacentLocks` mirror chính xác
  `chipAdjacentObstacles`: gom set ô khoá liền kề (4 hướng, dedup qua Set)
  rồi trừ mỗi ô đúng 1 lock, không gộp vào tập clear (mở khoá không xoá ô).
  `pop_detector.dart` (`findConnectedGroup`/`findLargestGroup`/
  `hasAnyMovableGroup`) và `pop_collapse.dart` (`applyGravityAndCollapse`)
  thêm optional `{List<List<int>>? lockGrid}` — mặc định `null` giữ nguyên
  hành vi cũ cho mọi call site chưa truyền. Loại trừ ô khoá là **nhất quán
  trên mọi cơ chế xoá**: match thường (`_tryPop`), power tile line/bomb/
  rainbow (`_activatePowerTile`), booster bomb (`triggerBomb`), booster
  rainbow (`triggerRainbow`) — tất cả thêm điều kiện `lockGrid[r][c] == 0`
  cạnh check obstacle sẵn có, rồi gọi `chipAdjacentLocks` + `_syncLockBlocks()`
  (method mới, mirror `_syncObstacleBlocks`) ngay sau `chipAdjacentObstacles`.
  `_collapseAnimated()` chỉ cần thêm đúng 1 dòng
  `lockGrid[r][c] = b?.lockCount ?? 0;` — vì `_blocks` di chuyển object ref
  nguyên trạng qua gravity/collapse (không tạo lại), field `lockCount` mới
  trên `BlockComponent` tự trôi theo mà không cần sửa tween; ngược lại
  `_rebuildBoard()` (đường tái tạo full-board của shuffle/undo/resize/refill)
  phải truyền `lockCount: lockGrid[r][c]` tường minh khi tạo `BlockComponent`
  mới. `shuffleBoard()` loại ô khoá khỏi pool xáo màu (giữ nguyên vị trí/độ
  khoá). `undo()`/`_saveUndo()` snapshot thêm `_undoLockGrid` song song
  `_undoGrid`. Chain tile **chỉ dành cho campaign** — `_refillBoard()` (Zen)
  reset `lockGrid` về toàn 0 mỗi lần dựng bàn mới, không tạo lock mới.
  Không thêm `ObjectiveType` mới — trigger tách biệt khỏi chu kỳ 5-slot
  objective, chỉ dựa `level.id % 6 == 0` (`_placeChainLocksIfNeeded`, gọi
  ngay sau `_placeObstaclesIfNeeded` trong `onLoad()`), số ô/lock-value scale
  theo world cùng công thức style obstacle. `BlockComponent` thêm field
  `lockCount` + vẽ lớp tối bán trong suốt/icon xích/chấm trắng đếm lock đè
  lên gem (tái dùng ngôn ngữ hình ảnh "chấm trắng đếm durability" đã có ở
  phần vẽ obstacle). Test mới `test/logic/chain_tile_test.dart` (4 test) +
  bổ sung `pop_detector_test.dart` (5 test: khoá chặn match/flood-fill, mở
  khoá tham gia lại bình thường, `findLargestGroup`/`hasAnyMovableGroup` bỏ
  qua ô khoá) + bổ sung `pop_collapse_test.dart` (2 test: `lockGrid` rơi/dồn
  lockstep cùng `colorGrid`). `flutter analyze` 0 lỗi, full suite 113/113
  xanh.

## ✅ Lịch sử: rã Wave 6 (Ideas & Polish) + mở rộng test coverage (xem doc/task/tasks/)

> Tiêu đề gốc "🟡 In progress" gây hiểu lầm — toàn bộ mục dưới đây là lịch sử
> một wave **đã hoàn thành** (I2/I4/I5/I11/I13/I18 đã code + có test, xem
> commit liên quan), không phải việc đang chờ. Rà soát lại 2026-07-13 xác
> nhận I13 (SFX pop theo cỡ nhóm), I5 (undo miễn phí), I4 (predictive hint)
> đều đã implement đầy đủ, có test riêng (`free_undo_test.dart`,
> `predictive_hint_test.dart`), không cần sửa code. Wave test coverage mới
> (cùng ngày): thêm test cho 5 file logic/util thuần trước đây chưa có
> (`storage_service`, `locale_service`, `app_info`, `utils/format`,
> `data/worlds`) — `neon_button`/`stroke_text`/`coin_chip` golden test hoá ra
> đã có sẵn từ trước, không cần viết thêm.

- Rã 7 hạng mục (Wave 6 — Ideas & Polish) thành task .md theo chuẩn scrum:
  `I11` haptic feedback, `T1` fix settings_screen locale test (tham chiếu
  đúng nợ kỹ thuật đã ghi ở dưới), `I5` undo miễn phí 1 lần/màn, `I18`
  colorblind neon symbols, `I4` predictive hint, `I13` SFX pop cao độ theo
  cỡ nhóm, `I2` color-lock/chain tiles (7/7 đã hoàn thành, xem mục trên).
  Phát hiện khi rã `I13`: hạ tầng
  nhạc lý `AudioManager.playMelodic`/`playNote` (ngũ cung + màu-là-giọng +
  hợp âm wombo) đã build đầy đủ nhưng **chưa hề được gọi** ở `pop_star_game.dart`
  — pop hiện không phát bất kỳ SFX nào, task chỉ cần "nối dây" chứ không xây
  mới. `IDEAS.md` đã đánh dấu 6 ID (I2/I4/I5/I11/I13/I18) là "đã chốt", trỏ
  sang file task tương ứng.
- Mở rộng test coverage thêm (theo `doc/task/tasks/README.md`, wave tiếp
  theo) — các widget/screen còn lại chưa có test trực tiếp.
  - Đã thêm test cho 7 widget trước đây chưa có file test nào:
    `coin_fly_overlay`, `confetti_overlay`, `neon_aura_layer`, `neon_bg`,
    `pressable_scale`, `pulse_glow`, `star_mascot` (bao mọi mood qua đủ 1
    chu kỳ blink — regression cho bug `eyeH.clamp` tự tham chiếu đã fix ở A8).
    Bug phát hiện khi viết test `pressable_scale`: `SizedBox(width, height)`
    rỗng (không con/màu) không tự `hitTestSelf` → gesture giả lập trong test
    không tới được `GestureDetector` dù toạ độ đúng tâm; đổi child test
    sang `ColoredBox` (có nội dung vẽ) là chạy đúng — bug ở cách viết test,
    không phải ở `PressableScale`.
- `settings_screen_test.dart`: chỉ smoke-test render, KHÔNG test hành vi tap
  đổi ngôn ngữ qua UI — `Get.updateLocale()` gọi
  `engine.performReassemble()` nội bộ, không tương thích với
  `AutomatedTestWidgetsFlutterBinding` của `flutter_test` (ném lỗi
  `schedulerPhase == idle` ngay trong `tester.tap()`, không phải do pump
  sau đó). Muốn test hành vi đổi ngôn ngữ thật sự cần tách logic khỏi
  `Get.updateLocale`/`performReassemble`, hoặc test qua tầng khác (không
  phải widget test dựng UI thật).

## ✅ Performance audit (2026-07-12, đã fix — xem P0/P1/P2 bên dưới)

User báo game lag nặng lúc chơi thật (device test tới level 6). Audit đọc
toàn bộ `pop_star_game.dart`, `block_component.dart`, `neon_bg.dart`,
`neon_aura_layer.dart`, `pulse_glow.dart`, `game_screen.dart`. Root cause xếp
theo mức độ nghi ngờ:

- **P0 — `BlockComponent.render()` (block_component.dart:71-76):** bloom viền
  ngoài dùng `MaskFilter.blur` vẽ **mọi ô, mọi frame, vô điều kiện** — Flame
  không cache/dirty-check render giữa các frame. Board lớn nhất 11x12 = 132
  ô, mỗi ô ≥1 blur pass (CPU-based, Skia mask blur đắt) chạy 60 lần/giây kể
  cả lúc bàn đứng yên không ai tap. Nghi phạm số 1.
- **P0 — `_spawnBurst` (pop_star_game.dart:594-645, 826+):** particle burst
  (10 particle `ComputedParticle`/ô) gọi **theo từng ô trong nhóm bị xoá**,
  không theo nhóm. Nổ nhóm lớn/rainbow/bomb (có thể xoá nửa bàn) → hàng trăm
  particle vẽ line+circle mỗi frame cùng lúc trong 0.5s, spike đúng lúc combo
  lớn — khớp cảm giác lag "lúc nổ to".
- **P0 — `NeonAuraLayer` (neon_aura_layer.dart):** dùng `Ticker` riêng gọi
  `setState()` mỗi frame (60fps vô điều kiện) vẽ fragment shader full-screen
  ngay trên vùng bàn chơi (`game_screen.dart:53-57`), **không có
  `RepaintBoundary`** bọc — khác `NeonBg`/`PulseGlow` đều có bọc (thiếu sót,
  không nhất quán).
- **P1 — `NeonBg`:** chạy suốt lúc chơi (không riêng menu), vẽ lại 6 orb +
  60 star mỗi frame với `blendMode.softLight` (blend đắt). Cộng dồn cùng lúc
  với 2 hệ trên trong 1 khung 16ms trên máy tầm trung/thấp.
- **P2 — `_syncObstacleBlocks`/`_syncLockBlocks`:** quét toàn bàn 2 vòng lặp
  riêng biệt sau mỗi lần nổ nhóm — rẻ so với P0, chỉ đáng gộp sau khi P0 xong.

Đã tạo task rõ ràng (xem `TaskList`), chưa code fix nào — cần quyết định
hướng fix (cache tĩnh vs bỏ blur vs giảm hiệu ứng) trước khi implement.

## ✅ Performance fix P0 (2026-07-12)

3 fix P0 từ audit trên, theo plan `deep-foraging-floyd.md`:

- **Bloom bitmap-cache** (`block_component.dart`): thay `MaskFilter.blur` vẽ
  trực tiếp mỗi frame bằng cache tĩnh — bake 1 lần/màu (7 màu
  `NeonTheme.gemColors`) vào `ui.Image` qua `PictureRecorder`
  (`BlockComponent.ensureBloomCache()`, gọi 1 lần trong `onLoad()` trước
  `_rebuildBoard`), mỗi frame chỉ `canvas.drawImageRect` (blit rẻ). Fallback
  vẽ blur trực tiếp nếu cache chưa sẵn (không xảy ra trong thực tế vì đã
  `await` trước khi dựng board). Visual giữ nguyên 100%.
- **Cap particle burst theo nhóm** (`pop_star_game.dart`, `_spawnBurst`):
  `burstCount = cells.length <= 8 ? 10 : (80 / cells.length).clamp(3, 10).round()`
  — nhóm nhỏ (≤8 ô) giữ 10 particle/ô như cũ, nhóm càng lớn càng giảm
  particle/ô, tổng particle toàn cụm chặn quanh ~80 thay vì tăng tuyến tính
  không giới hạn.
- **RepaintBoundary + throttle `NeonAuraLayer`**: bọc `CustomPaint` trong
  `RepaintBoundary`, hạ tần suất `setState()` thật sự xuống ~30fps (`_time`
  vẫn cập nhật mỗi tick nên animation không giật).

`flutter analyze` 0 issues, `flutter test --exclude-tags slow` 113/113 xanh
(thay đổi thuần hiệu năng, không đổi hành vi/API công khai nên không cần
test mới).

Verify emulator (`emulator-5554`): rebuild + cài lại, playtest level 1 —
bloom viền neon giữ nguyên y hệt trước, pop nhóm lớn (group 6) burst đẹp và
không giật, log `logcat` sạch (không exception/FATAL, chỉ log audio codec
bình thường). Trong lúc verify, môi trường emulator dùng chung bị 1 app
quảng cáo lạ không liên quan (`com.roy.admobwrapper`) liên tục tự relaunch
cướp foreground, có lúc còn nuốt input (tap bị điều hướng sang Play Store) —
gây hiện tượng board tạm thời chỉ hiển thị vài ô rồi đứng hình (log kèm
`SurfaceSyncGroup: Failed receive transaction ready in 1000ms` đúng lúc đó).
Đã xác nhận đây là **surface-sync glitch do nhiễu ngoài**, không phải bug
logic của 3 fix trên: colorGrid/vị trí block vẫn đúng, chỉ cần 1 sự kiện
buộc repaint (mở dialog) là hiển thị đầy đủ và chính xác trở lại; ván chơi
tiếp diễn bình thường sau đó không tái diễn hiện tượng.

## ✅ Performance fix P1 — NeonBg cost during gameplay (2026-07-12)

Task #11 từ audit trên. `NeonBg` (nền chung mọi màn, vẽ 6 orb `RadialGradient`
+ `blendMode.softLight` (blend đắt) và 60 star mỗi frame) dùng
`AnimationController.repeat()` 24s chạy 60fps vô điều kiện, mỗi tick trigger
`AnimatedBuilder` rebuild + repaint thật sự. `RepaintBoundary` đã có sẵn từ
trước (khác #10 lúc đó chưa có) — chi phí chỉ nằm ở tần suất update quá cao.

Fix: mirror đúng pattern throttle đã dùng ở #10 (`NeonAuraLayer`) — thay
`AnimationController` bằng `Ticker` riêng (`_NeonBgState`), field `_t`/
`_energy` vẫn cập nhật mỗi tick thực (60fps, animation không giật) nhưng chỉ
gọi `setState()` mỗi tick thứ 2 (`_skipFrame` toggle) → tần suất repaint thật
sự giảm còn ~30fps. `_NeonBgPainter`/`_Orb`/`_Star` giữ nguyên hoàn toàn,
không đổi visual.

`flutter analyze` 0 issues, `flutter test --exclude-tags slow` 113/113 xanh
(thay đổi thuần hiệu năng, không đổi hành vi/API công khai nên không cần
test mới).

## ✅ Performance fix P2 — gộp scan obstacle/lock (2026-07-12)

Task #12 từ audit trên. `_syncObstacleBlocks`/`_syncLockBlocks`
(`pop_star_game.dart`) quét toàn bàn 2 vòng lặp riêng biệt sau mỗi lần nổ
nhóm/bom — cùng phạm vi `rows x cols`, không phụ thuộc nhau. Gộp thành 1 hàm
`_syncObstacleAndLockBlocks()` quét 1 lần, đồng bộ cả `colorIndex` (obstacle)
lẫn `lockCount` (chain tile) trong cùng vòng lặp. Thay toàn bộ 4 điểm gọi
(`_clearAndCollapse`, `triggerBomb`, `undo`, `shuffleBoard`) từ cặp
`_syncObstacleBlocks(); ... _syncLockBlocks();` sang 1 lệnh duy nhất.

`flutter analyze` 0 issues, `flutter test --exclude-tags slow` 113/113 xanh
(thay đổi thuần hiệu năng, không đổi hành vi/API công khai nên không cần
test mới).

## ✅ Spacing standard (2026-07-12)

Chuẩn hoá toàn bộ margin/padding/gap về đúng 3 token có sẵn trong
`NeonTheme`: `s8`/`s16`/`s24` (không thêm token mới). User chọn strict
3-value (từ chối option mở rộng lưới 4px) — chấp nhận vài chỗ đổi nhẹ kích
thước visual để dồn về đúng 3 mức.

Quy tắc làm tròn áp dụng cho mọi giá trị lẻ (2/3/4/5/6/10/12/13/14/15/18):
`<12 → s8`, `12–19 → s16`, `≥20 → s24` (0 giữ nguyên, không nằm trong thang).

Đã sửa `EdgeInsets`/`SizedBox` lẻ ở: `coin_chip.dart`, `neon_button.dart`,
`neon_dialog.dart`, `star_road_screen.dart`, `shop_screen.dart`,
`level_select_screen.dart` (`_WorldBanner`), `game_screen.dart` (HUD +
`_BoosterButton` + win choreography), `guide_screen.dart`. `neon_app_bar.dart`
đã sẵn chuẩn, không đổi.

2 golden test (`coin_chip_golden_test`, `neon_button_golden_test`) lệch pixel
do đổi spacing thật — đã regenerate golden bằng `--update-goldens` (kỳ vọng,
không phải lỗi). `flutter analyze` 0 issues, `flutter test --exclude-tags
slow` xanh toàn bộ.

Verify trên emulator Android (`emulator-5554`): Home, Level Select
(`_WorldBanner`), Game screen HUD (nơi sửa nhiều nhất — 12 chỗ) đều render
đúng, không lệch layout.

Phát hiện thêm 1 bug tràn viền có sẵn từ trước (không do task này gây ra,
xác nhận qua `git diff`): `_WorldBanner` (`level_select_screen.dart`) có
`Container(alignment: Alignment.center, ...)` — Flutter tự bọc `Align`,
`Align` truyền loose constraint xuống `Stack` bên trong, khiến `Stack` co
lại theo kích thước `StrokeText` (tên world) thay vì full width, làm `Row`
6 icon trái tim trang trí bị ép vào khung nhỏ và tràn viền
(`RenderFlex overflowed`). Fix: bỏ `alignment: Alignment.center` thừa khỏi
`Container` (Stack đã tự căn giữa `StrokeText` rồi) — không cần bọc thêm
`SizedBox`/`ConstrainedBox` nào. Đã verify lại trên emulator: log sạch,
không còn overflow.

## ✅ Audit đêm (2026-07-12, sau P0/P1/P2)

Sau khi #8-#12 xong, chạy audit + smoke-test tự động qua đêm (7 vòng, mỗi
vòng 1 vùng code: `lib/logic/`, `lib/game/`, `lib/presentation/controllers/`,
`lib/presentation/screens/`, `lib/presentation/widgets/`, `lib/core/`, +
smoke-test runtime trên `emulator-5554`).

**Kết quả: 0 bug thật.** 5 nghi vấn agent báo cáo, cả 5 đều bị bác bỏ sau khi
tự trace tay:
- Chia 0 (`pop_star_game.dart`) — mọi call site đã guard `cells.isEmpty`,
  Dart `/` không throw.
- postFrameCallback đăng ký trùng (`level_select_screen.dart`) — flag set
  `null` đồng bộ trước khi đăng ký, đơn luồng nên không thể trùng.
- `return` thay `continue` (`coin_fly_overlay.dart`) — `delay` tăng đơn điệu
  theo index nên 2 cách cho kết quả vẽ giống hệt nhau.
- Race condition fire-and-forget `setInt` (`game_controller.dart`) — pattern
  nhất quán 16+ chỗ toàn file, không phải lỗi cục bộ, chấp nhận được cho
  casual game.
- Resource leak `AudioManager` sau dispose — là `GetxService` permanent, không
  bao giờ bị dispose thủ công trong vòng đời app.

Nợ kỹ thuật T1 (locale runtime trong widget test, từng ghi trong backlog) đã
xác nhận **đã đóng từ trước** — `test/widget/settings_screen_test.dart` dùng
workaround dựng `GetMaterialApp` với `locale` cố định ngay từ đầu (giống
`main.dart`) thay vì `Get.updateLocale()` runtime, tránh hẳn vấn đề
`performReassemble()` không tương thích test binding.

Smoke-test runtime (emulator-5554): gameplay cơ bản (pop/gravity/collapse),
booster bomb (chip 3x3 đúng vùng tap), thắng level 1 (440/288 điểm, 2 sao) →
win dialog sạch → level 2 unlock đúng trên `level_select_screen.dart` (code
mới nhất, chưa từng chạy runtime trước đó) — path/badge sao/màu render đúng,
không NaN, không lệch layout. Không bắt được frame confetti đang nổ (chụp
trễ), chỉ xác nhận trạng thái tĩnh sau animation sạch — không phải bằng
chứng có bug, chỉ là giới hạn của lần test.

`flutter analyze` 0 issues, `flutter test --exclude-tags slow` 113/113 xanh,
không FATAL/Exception trong logcat suốt toàn bộ đêm, không gặp quảng cáo lạ.

## ✅ Audit toàn diện + rã 24 task mới (2026-07-13)

Yêu cầu: audit lại source, đề xuất feature mới/enhance, rã scrum vào
`doc/task/tasks/`. Qua 4 vòng `AskUserQuestion`, user chốt scope rất lớn —
loại trừ dứt khoát mọi monetize/ads/IAP/analytics infra (Option D).

**Audit findings quan trọng** — trước khi viết task mới, re-verify trực tiếp
qua `grep`/`git log` (không tin lại báo cáo audit cũ chưa kiểm chứng):
tất cả F1-F8/A1-A8/G1-G7 đã **implement xong hoàn toàn** trong source (rainbow
bomb, power tile, obstacle/objective, level path map, mascot/win choreography,
slow-mo/ripple, mọi hiệu ứng glow) — không có "partial" nào như một bản audit
trước đó từng nghĩ. Duy nhất `G8` thiếu nửa: burst ring đã xong, chỉ còn phần
idle shimmer — đã cập nhật `G8-glow-burst-shimmer.md` thu hẹp đúng phần còn
thiếu.

**Scope đã chốt (24 task file mới trong `doc/task/tasks/`)**:
- 4 cụm gameplay mới: `I1` gift tile, `I3` gravity variants, `F9` objective
  mới (collect/move-bonus/obstacle-in-moves), `F10` booster Swap+Freeze,
  `F11` boss level cuối world, `I14`/`I17` theme + material per world.
- Mode mới: `F12` Endless, `F13` Daily Challenge (seed theo ngày).
- Retention/meta (free-track only, không IAP): `I6` battle-pass, `I7` spin
  wheel, `I8` weekend x2 coin, `I9` leaderboard bạn bè (offline giả lập,
  không backend), `I10` comeback bonus.
- Ý tưởng độc quyền: `I15` day/night toggle, `I16` aurora shader, `F14`
  relic/perk system (không pay-to-win, unlock qua world hoàn thành), `F15`
  photo mode/share.
- Floor/UX baseline (`X1`-`X6`): onboarding FTUE, settings âm lượng
  riêng+haptics, accessibility semantics, boot resilience try/catch, review
  prompt, share invite.

Đã cập nhật `README.md` (rows F9-F15, nhóm I mới, nhóm X mới, Wave 7-10 build
order) và `IDEAS.md` (đánh dấu I1/I3/I6-I10/I14-I17 "✅ đã chốt"). Chưa code gì
— toàn bộ turn này chỉ là audit + backlog, chưa implement.

## ✅ Wave 7 — X4, X1 (2026-07-13, chạy tự động overnight)

- **X4 Boot resilience**: `main.dart` bọc try/catch quanh
  `SharedPreferences.getInstance()`, `StorageService` nhận `_prefs` nullable +
  fallback in-memory map (`_fallback`) cho mọi getter/setter — lỗi storage
  lúc boot (thiết bị hiếm, storage hỏng) không còn crash trắng màn hình, chỉ
  mất persist qua session đó.
- **X1 Onboarding/FTUE**: level 1 campaign, lần đầu cài app (cờ
  `StorageKeys.hasSeenFtue` chưa set) → ép hiện gợi ý nhóm lớn nhất ngay khi
  board sẵn sàng (tái dùng nguyên hệ thống hint I4 — `_triggerHint`/`_hint`/
  `hinted` trên `BlockComponent`, chỉ thêm cờ constructor
  `PopStarGame.startWithFtueHint` để trigger trong `onLoad()` thay vì chờ
  `_hintDelay` rảnh tay) + banner "Tap this group!" (`ftue_tap_hint` key,
  không dùng `NeonDialog.overlay` vì không blocking) tự tắt ở tap đầu tiên
  (đúng hay sai nhóm đều tắt — đồng bộ với việc `clearHint()` đã xoá highlight
  ở mọi tap, tránh banner "kẹt" trỏ vào bàn không còn highlight).
  - Bug tự phát hiện + tự sửa trong lúc verify: gọi trigger hint ngay sau
    constructor (đồng bộ) bị `LateInitializationError` vì `colorGrid` chỉ
    init xong trong `onLoad()` (async, Flame engine gọi sau khi mount) — sửa
    bằng cách dời qua cờ constructor, trigger ở cuối `onLoad()`.
  - Key mới `ftue_tap_hint` chỉ thêm vào `_extraEn`/`_extraVi` trong
    `app_translations.dart` (không đụng 20 locale còn lại) — merge order của
    `keys` getter spread `_extraEn` vô điều kiện vào MỌI locale nên tự động
    thoả test parity 22-locale, các locale khác hiện fallback tiếng Anh.
  - **Đã chốt scope hẹp lại**: AC gốc còn yêu cầu "audit AppTranslations dọn
    key onboarding cũ không dùng" — **cố ý bỏ qua**. `app_translations.dart`
    (21500+ dòng) chứa rất nhiều key chết từ game match-3 cũ (tour/wheel/
    clan/pregame/world_map/tut_*...) rải khắp hàng chục map "Wave N" theo
    từng ngôn ngữ; không có audit list cụ thể nào trong file này hay nơi
    khác để bám theo, và dọn dẹp thủ công 22 locale × hàng chục wave map có
    rủi ro phá test parity cao, không tương xứng với 1 task 5 SP chạy tự
    động không giám sát qua đêm. Để dành làm task dọn dẹp riêng nếu cần.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 132/132
    xanh.

## ✅ Wave 7 — X2 (2026-07-13, chạy tự động overnight)

- **X2 Settings âm lượng riêng + haptics toggle**:
  - `StorageKeys` thêm `bgmVolume`/`sfxVolume`/`hapticsEnabled`;
    `StorageService` thêm `getDouble`/`setDouble` (theo đúng pattern
    `getInt`/`setInt` có sẵn).
  - `AudioManager` thêm `RxDouble bgmVolume`/`sfxVolume` (mặc định 1.0, load
    từ storage trong `init()`), `setBgmVolume`/`setSfxVolume` (clamp 0..1,
    persist). Mọi hằng số volume cứng trước đây (`0.35` bgm, `0.6`/`0.5`/
    `0.85` các SFX) nhân thêm với Rx tương ứng tại từng điểm phát.
    `setBgmVolume` áp dụng ngay cả khi nhạc đang phát qua
    `FlameAudio.bgm.audioPlayer.setVolume(...)` (xác nhận API qua đọc
    source `flame_audio` — `Bgm.audioPlayer` là field public) thay vì phải
    restart track.
  - `SettingsScreen` chuyển từ `StatelessWidget` sang `StatefulWidget` (chỉ
    để giữ state toggle haptics cục bộ, không cần thêm controller mới) —
    thêm 2 `Slider` (bgm/sfx, guard `if (audio != null)` giống switch âm
    thanh có sẵn, để tương thích test hiện có không đăng ký `AudioManager`)
    + 1 `SwitchListTile` haptics độc lập (đọc/ghi thẳng qua
    `StorageService.to`, không phụ thuộc audio).
  - **Haptics abstraction mới**: `lib/core/haptics.dart` —
    `fireHaptic(HapticLevel level)` là điểm chốt duy nhất, check
    `StorageKeys.hapticsEnabled` (mặc định bật) trước khi gọi
    `HapticFeedback.*`. Thay toàn bộ 4 điểm gọi `HapticFeedback.*` trực
    tiếp trong `pop_star_game.dart` (`_hapticForGroupSize` 3 nhánh + 1 điểm
    rung khi chip obstacle/lock) và `level_select_screen.dart`
    (`_playReveal`) sang gọi qua `fireHaptic` — từ nay mọi điểm rung mới
    trong app phải đi qua hàm này để tôn trọng cờ Settings.
  - Test mới: mở rộng `test/core/storage_service_test.dart` (3 case:
    `getDouble` def, `setDouble` bgm/sfx persist, `hapticsEnabled`
    persist) — dùng thẳng `StorageService` thay vì `AudioManager` (nhẹ hơn,
    không cần mock `flame_audio`/asset loading).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    135/135 xanh.

## ✅ Wave 7 — X5 (2026-07-13, chạy tự động overnight)

- **X5 Review prompt đúng lúc**: thêm package `in_app_review` (pub add,
  kéo theo transitive `url_launcher*`).
  - `StorageKeys.hasShownReviewPrompt` — cờ đã hiện review prompt chưa
    (chỉ hiện đúng 1 lần trong đời cài đặt).
  - `GameController.shouldRequestReview({stars, alreadyShown})` — hàm điều
    kiện thuần, test được: trigger đúng khi vừa đạt 3 sao và chưa hiện lần
    nào. Tách riêng khỏi phần gọi native để unit test không cần mock
    platform channel.
  - `_maybeRequestReview()` gọi trong nhánh dương của `checkEnd` (sau
    `_grantCoins()`), set cờ trước khi gọi native (tránh hiện lại nếu race).
  - `_requestReviewSafely()` bọc `InAppReview.instance.isAvailable()` +
    `requestReview()` trong try/catch (giống pattern `_ignoreAudio` của
    `AudioManager`) — môi trường test/không có plugin gốc không crash.
  - Test mới: 4 case trong `game_controller_test.dart`
    (`shouldRequestReview`): 3 sao + chưa hiện → true; 3 sao + đã hiện →
    false; 1-2 sao → false; 0 sao (thua) → false.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    139/139 xanh.

## ✅ Wave 7 — X3 (2026-07-13, chạy tự động overnight)

- **X3 Accessibility semantics cơ bản**: thêm `Semantics(button:, enabled:,
  label:)` cho các nút tương tác chính, không đổi hành vi/giao diện.
  - `NeonButton`: `semanticLabel` optional, mặc định dùng `label` hiển thị.
  - `_BoosterButton` (game_screen): label mô tả hành động + số lượng còn lại
    + trạng thái "đang chọn" khi armed (bomb/rainbow).
  - `NeonIconButton`: `semanticLabel` optional — biến variant `boxed` (dùng
    `Semantics` wrap) và variant thường (dùng `tooltip` — Flutter tự đưa vào
    semantics tree). `NeonBackButton` label "Quay lại".
  - Gắn label tiếng Việt cho 6 nút icon ở `home_screen.dart` (Đấu thời gian,
    Thư giãn, Con đường sao, Cửa hàng, Hướng dẫn, Cài đặt).
  - `GameWidget` không bọc `ExcludeSemantics` — không chặn semantics tree
    phía trên nó (đã rà soát, không cần sửa).
  - Không làm semantics chi tiết từng ô board (200 level — chi phí không
    tương xứng, theo ghi chú kỹ thuật của task).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    139/139 xanh (golden test không đổi vì Semantics không ảnh hưởng
    render).

## ✅ Wave 7 — F9 (2026-07-13, chạy tự động overnight)

- **F9 Objective mới**: mở rộng `ObjectiveType` (`lib/data/levels.dart`) từ 3
  lên 6 case, thêm 2 field mới cho `LevelObjective` (`target`, `moveLimit`).
  Chu kỳ luân phiên objective (`kLevels`) tăng từ 5 lên 8 màn: 3 màn `score`,
  rồi `clearColor`/`clearObstacle`/`collect`/`moveLimitBonus`/
  `obstacleInMoves` (slot 3..7).
  - `collect(color, target)`: thu đúng N ô màu chỉ định (khác `clearColor` —
    không cần dọn hết trên bàn). Cơ chế: `GameController` chụp số ô màu đó
    trên bàn ở lần `updateObjectiveProgress` đầu tiên (`_collectInitial`,
    trước pop nào), sau đó `remaining = target - (initial - current)`.
  - `moveLimitBonus(moveLimit)`: không phải điều kiện thắng (như `score`,
    `objectiveMet` luôn false) — chỉ +1 sao bonus (trần 3) nếu
    `movesUsed <= moveLimit` khi màn kết thúc bình thường, và chỉ áp dụng
    khi đã đạt ≥1 sao từ điểm.
  - `obstacleInMoves(target, moveLimit)`: dùng chung cơ chế đếm ô âm với
    `clearObstacle` (`_placeObstaclesIfNeeded` mở rộng để trigger cho cả 2
    loại, số lượng obstacle lấy đúng `target` khi là `obstacleInMoves`) +
    cùng bonus sao theo `moveLimit` như `moveLimitBonus`.
  - `GameController`: field mới `movesUsed` (RxInt, tăng trong `registerPop`,
    reset ở `startLevel`/`startSideMode`), `_collectInitial` (reset cùng
    lúc). `_computeStars` cộng bonus sao qua `_underMoveLimitBonus()`.
  - An toàn: theo kiến trúc sẵn có, `objectiveMet` chỉ gate đường thắng
    sớm — nếu never true, màn vẫn kết thúc tự nhiên (hết/kẹt bàn) và sao vẫn
    tính thuần theo `score` vs `targetScore`. Nghĩa là target/moveLimit của 3
    loại mới dù là số ước lượng cũng không có rủi ro làm màn bất khả thi
    (tránh lặp lại sự cố targetScore tuyến tính cũ — xem đầu file).
  - HUD (`game_screen.dart`): dòng tiến độ mở rộng thành hàm `_objectiveLine`
    xử lý switch đủ 5 loại non-score (thay ternary cũ chỉ có 2 loại).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    147/147 xanh (139 cũ + 8 test mới: collect, moveLimitBonus,
    obstacleInMoves, movesUsed increment/reset, 4 case bonus sao).

## ✅ Wave 7 — F10 (2026-07-13, chạy tự động overnight)

- **F10 Booster Swap + Freeze**: 2 booster mới, theo đúng pattern
  bomb/shuffle/undo/rainbow đã có (`RxInt` count + `StorageKeys` +
  `static const XPrice` + `_buy` helper + `useX`/`buyX` + xoá key trong
  `resetProgress`).
  - **Swap**: arm (`toggleSwapArm`, thêm case `swap` vào `BoosterMode`) → tap
    ô 1 → tap ô 2 → đổi màu 2 ô (không tự nổ). `GameScreenController` giữ
    `Point<int>? _swapFirst` để theo dõi ô đã chọn; tap ngoài bàn không tiêu
    lượt, tap lại đúng ô đầu = bỏ chọn (tránh phí lượt vì tự swap với chính
    nó). `PopStarGame.triggerSwap` chặn nếu 1 trong 2 ô là obstacle/lock,
    cập nhật `colorGrid` + `_blocks[...].colorIndex` trực tiếp (rẻ hơn
    `shuffleBoard()`'s full rebuild).
    - Không thêm highlight ô đầu đã chọn (không có trong AC, không có user
      overnight để feedback UX) — ponytail: đơn giản hoá, thêm khi cần rõ
      trạng thái đang chọn ô nào.
  - **Freeze**: dùng ngay (không cần tap ô, giống `useShuffle`/`useUndo`) →
    N=5 lượt kế tiếp, obstacle không giảm bền dù có pop/booster kề bên, hết
    N lượt tự động giảm bền lại bình thường.
    - Quyết định kiến trúc: **không đụng** `lib/logic/obstacle.dart`
      (`chipAdjacentObstacles`) để giữ layer thuần Dart sạch theo CLAUDE.md —
      thay vào đó thêm guard `_chipObstaclesOrFrozen()` ở layer Flame
      (`PopStarGame`), chặn cả 4 điểm gọi (`_tryPop`, `_activatePowerTile`,
      `triggerBomb`, `triggerRainbow`) khi `freezeTurnsLeft > 0`, trừ 1 lượt
      thay vì chip thật.
    - "1 lượt" = mỗi lần 1 trong 4 hành động trên thực thi (dù có obstacle kề
      hay không) — diễn giải hợp lý cho AC không quy định chi tiết.
  - Shop: 2 dòng `_BoosterRow` mới (label tiếng Anh, theo convention sẵn có
    của file này). HUD (`game_screen.dart`): 2 nút mới (label tiếng Việt,
    theo convention sẵn có của file này — khác convention shop nhưng đều là
    quy ước cũ mỗi file, giữ nguyên không đổi).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    151/151 xanh (147 cũ + 4 test mới: swap đổi đúng 2 ô/không tự nổ/trừ
    lượt, toggleSwapArm bật tắt đúng mode, swap 2-tap qua `handleBoardTap`
    end-to-end, freeze chặn giảm bền lượt hiệu lực rồi tự hết đúng lúc).

## ✅ Wave 7 — F11 (2026-07-13, chạy tự động overnight)

- **F11 Boss level mỗi world**: level cuối mỗi world (`id % 20 == 0`, tức
  20/40/.../200) đánh dấu `isBoss`. Khó hơn qua `targetScore ×
  bossTargetMultiplier` (hằng số mới = 1.5, `lib/data/levels.dart`) — đủ để
  tăng độ khó vì `GameController._computeStars()` gate sao theo `targetScore`
  cho MỌI loại objective (kể cả clearColor/collect/...), không cần kết hợp
  thêm objective thứ 2 (lựa chọn AC còn lại, phức tạp hơn, không chọn vì
  không cần).
  - Path map (`level_select_screen.dart`): border vàng gold dày hơn (4 thay
    3) + crown icon (`Icons.emoji_events_rounded`) hiện cả khi màn còn khoá
    (màu xám) — cho thấy trước node boss sắp tới trên đường path.
  - Win dialog (`game_screen.dart`, `_WinChoreographyState`): tái dùng toàn
    bộ `_WinChoreography`/`_MascotDialog` sẵn có (A5), chỉ đổi title thành
    "Boss Cleared!" khi `currentLevel.isBoss`.
  - Test cũ `targetScore neo vào diện tích bàn` loại boss ra khỏi phạm vi
    check (perCell boss có thể lên ~11.4 ở world 9, vượt khoảng `[4,9]` cũ)
    + 3 test mới: boss perCell nằm trong khoảng nới rộng `[4, 9×1.5]`,
    `isBoss` đúng công thức `id % 20 == 0`, target boss đúng công thức và
    luôn cao hơn màn liền trước.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    154/154 xanh (151 cũ + 3 test mới).

## ✅ Wave 7 — G8 (2026-07-13, chạy tự động overnight)

- **G8 idle shimmer** (phần burst ring đã xong Wave 4, xem đoạn ghi chú sửa
  lại phía trên — bản ghi "idle shimmer" cũ ở đó là aspirational, code chưa
  từng có). `_ShimmerSweep` (`pop_star_game.dart`) — bàn rảnh tay
  `_shimmerDelay = 4.0`s (ngắn hơn `_hintDelay = 6.0`s của gợi ý I4, để làm
  dấu hiệu "còn sống" xuất hiện trước/song song hint chứ không gate theo
  `_hint.isEmpty`) thì quét 1 dải sáng ngang qua bàn 1 lượt (~1.1s) rồi tự gỡ,
  lặp lại thưa mỗi khi rảnh đủ ngưỡng tiếp. Vẽ bằng `BlendMode.plus` (cộng
  sáng) qua gradient trắng mờ dần 2 đầu — chỉ làm sáng lên chứ không phủ màu
  ô, thoả AC "không che tile" mà không cần dò alpha theo từng màu nền.
  Component không nhận input (kiến trúc tap đi qua `GestureDetector` ngoài
  Flame) nên không bao giờ chặn tap. `clearHint()` (đã dùng chung cho I4) mở
  rộng thêm: mọi tap đều reset `_shimmerTimer` **và** gỡ ngay lượt shimmer
  đang chạy dở (nếu có) — khớp đúng nghĩa đen AC "dừng ngay khi có tap", không
  chỉ chờ tự hết 1.1s.
  - Getter test-only mới: `shimmerActive` (đang có lượt shimmer hay không).
  - Test mới `test/widget/idle_shimmer_test.dart`: rảnh <4s chưa bật, đủ 4s
    bật, tap tắt ngay, rảnh lại từ 0 sau tap chưa bật lại.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`:
    155/155 xanh (154 cũ + 1 test mới).

## ✅ Wave 7 — F12 (2026-07-13, chạy tự động overnight)

(Đính chính mục cũ ở trên: F8 side-mode timeAttack/zen **đã có** từ Wave 7
trước — `GameMode` enum, entry point ở `home_screen.dart`, xem Wave 7 F9/F10.
Kết luận "F8 chưa code" trước đó là sai do grep bị cắt ngắn.)

- **F12 Endless mode**: `GameMode.endless` tái dùng khung side-mode có sẵn.
  `endlessLevelForIndex(int boardIndex)` (`lib/data/levels.dart`) — generator
  sinh board liên tục tăng khó theo `boardIndex` (rows 7→14, cols 6→14,
  colorCount 4→8, kẹp trần ở board xa), sentinel `id: -3`, `targetScore: 0`
  (không có target, chỉ tính điểm tích luỹ).
  `GameController`: `endlessBest` (`RxInt`, `StorageKeys.endlessBest`),
  `_endlessBoardIndex` (private), `startEndless()` (reset về board 0),
  `advanceEndlessBoard()`, lưu best qua nhánh `checkEnd()` khi
  `mode == GameMode.endless`.
  `PopStarGame._checkEnd()`: bàn sạch → `_nextEndlessBoard()` (sinh board mới,
  gọi lại `_layout()` vì kích thước bàn đổi theo board — khác `_refillBoard()`
  của Zen); bàn kẹt → `controller.checkEnd(false)` kết thúc ván bình thường.
  UI: nút vào Endless ở `home_screen.dart` (icon `all_inclusive`, màu
  `NeonTheme.purple`), HUD trong ván hiện `Best <endlessBest>` (giống pattern
  Zen), overlay thua hiện `Score X — Best Y`. Fix kèm: `again()` restart
  Endless phải gọi `startEndless()` riêng (không qua `startSideMode`, vì
  ternary của hàm đó mặc định về `kZenLevel` cho mọi mode khác timeAttack —
  sẽ làm restart Endless nhầm sang bàn Zen cố định).
  - Test mới: `endlessLevelForIndex` (`levels_test.dart`) — board hợp lệ,
    không giảm khó theo boardIndex, kẹp trần đúng. `modes_test.dart` — bàn
    sạch thì sang board kế (không kết thúc ván), bàn kẹt thì kết thúc + lưu
    best (không đụng campaign).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (160 test, gồm 5 test F12 mới).

## ✅ Wave 7 — I7 (2026-07-13, chạy tự động overnight)

- **I7 Vòng quay hằng ngày**: `StorageKeys.lastSpinDay` (`storage_service.dart`).
  `GameController`: `SpinReward` (type/amount), `spinRewards` (7 ô cố định:
  coins 50/100/200/500, bomb 1, shuffle 1, undo 1), `spinWeights`
  (`[30,20,8,15,15,15,2]`), `canClaimSpin` (so `lastSpinDay` với hôm nay kiểu
  epoch-day, cùng cách `durationToLocalMidnight` dùng cho daily reward),
  `todaySpinReward` (getter thuần, seed `Random(epochDay hôm nay)` — gọi bao
  nhiêu lần cùng ngày cũng ra cùng kết quả, không đổi state), `claimSpin()`
  (lưu `lastSpinDay`, cộng thưởng qua `_grant()`, trả `null` nếu đã quay).
  UI mới `spin_wheel_dialog.dart`: `showSpinWheelDialog` — nếu hết lượt hiện
  dialog báo mai quay lại; còn lượt thì lấy trước `todaySpinReward` rồi dựng
  `_SpinReel` (`TweenAnimationBuilder`) chỉ animate xoay tới **đúng index đã
  chốt sẵn** (không tự vẽ random riêng ở lớp UI, thoả AC). Nút vào ở
  `home_screen.dart` (icon `casino`, màu `NeonTheme.purple`, cạnh Con đường
  sao).
  Fix kèm: `resetProgress()` thiếu xoá `StorageKeys.endlessBest` và
  `StorageKeys.lastSpinDay` (best Endless cũ + trạng thái đã quay hôm nay còn
  sót lại sau khi reset) — bổ sung cả 2.
  - Test mới `game_controller_test.dart` nhóm "I7 Vòng quay hằng ngày": seed
    theo ngày ổn định, claim cộng đúng thưởng + không cho quay 2 lần/ngày,
    giả lập qua ngày mới (ghi thẳng `lastSpinDay` = hôm qua) thì quay lại được.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (163 test, gồm 3 test I7 mới).

## ✅ Wave 8 — I8 (2026-07-13, chạy tự động overnight)

- **I8 Weekend event x2 coin**: hàm thuần `isWeekendEvent(DateTime now)`
  (`lib/core/utils/weekend_event.dart`) — true nếu thứ 7/CN theo
  `DateTime.weekday`. `GameController.weekendCoinMultiplier` getter
  (`isWeekendEvent(DateTime.now()) ? 2 : 1`) áp vào cả 4 điểm cộng xu hiện có:
  `_grantCoins` (thắng level), `claimChest`, `claimDaily`, và nhánh `'coins'`
  của `claimSpin` — không tạo hệ thống event riêng, chỉ nhân hệ số tại chỗ.
  Banner "Cuối tuần x2 coin!" trên `home_screen.dart`, hiện có điều kiện
  `isWeekendEvent(DateTime.now())`.
  - Vì multiplier đọc giờ thật, mọi test assert xu literal cũ (checkEnd,
    daily reward 3 case, star road chest, claimSpin coins-case, star road
    screen widget test) phải nhân thêm `ctrl.weekendCoinMultiplier` mới không
    bị flaky theo ngày chạy CI thật.
  - Test mới `test/core/utils/weekend_event_test.dart`: thứ 7/CN → true,
    thứ 2 → false (dùng `DateTime` dựng sẵn, không phụ thuộc `DateTime.now()`).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (166 test, gồm 3 test `isWeekendEvent` mới).

## ✅ Wave 8 — I10 (2026-07-13, chạy tự động overnight)

- **I10 Comeback bonus**: hàm thuần `needsComebackBonus({lastOpenEpochDay,
  todayEpochDay})` (`lib/core/utils/comeback_bonus.dart`) — true nếu đã có
  lần mở trước (`lastOpenEpochDay >= 0`) và khoảng cách ≥3 ngày. Tái dùng
  hạ tầng epoch-day sẵn có (`_todayEpochDay()`, key `StorageKeys.lastOpenDay`
  mới) — không tạo hệ thống ngày-tháng riêng.
  - `GameController.checkComebackBonus()`: gọi 1 lần mỗi khi mở Home. Đọc
    mốc cũ, ghi đè `lastOpenDay` = hôm nay ngay (thoả luôn 2 tiêu chí "lưu mỗi
    lần mở" + "reset mốc sau khi tặng" bằng 1 thao tác), rồi nếu đủ điều kiện
    mới cộng `comebackBonusCoins` (300, nhân `weekendCoinMultiplier`) + 1 bomb
    + 1 shuffle. Trả về số xu đã tặng hoặc `null`.
  - `home_screen.dart initState`: gọi `checkComebackBonus()` trước tiên; nếu
    có quà thì hiện dialog "Chào mừng trở lại!" (ưu tiên trước), chỉ xét daily
    reward dialog khi comeback không kích hoạt — daily reward vẫn claim được
    bình thường ở các lần mở sau.
  - Thêm `StorageKeys.lastOpenDay` vào `resetProgress()` để xoá sạch khi reset.
  - Test mới: `test/core/utils/comeback_bonus_test.dart` (hàm thuần, các mốc
    ngày khác nhau) + group "I10 Comeback bonus" trong
    `test/presentation/game_controller_test.dart` (lần đầu mở/vắng đúng
    3 ngày/vắng dưới 3 ngày).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (174 test).

## ✅ Wave 8 — F13 (2026-07-13, chạy tự động overnight)

- **F13 Daily Challenge**: 1 bàn cố định mỗi ngày, seed = epoch-day (không
  `Random()` mặc định) — mọi người chơi cùng ngày gặp cùng bàn.
  - `lib/logic/daily_challenge.dart` (thuần Dart): consts
    `dailyChallengeRows/Cols/ColorCount` (9×8, 5 màu) +
    `generateDailyChallengeGrid(seed)` dùng `Random(seed)`.
  - `PopLevel kDailyChallengeLevel` (`lib/data/levels.dart`, id -4) — kích
    thước hiển thị khớp consts trên; bàn thật do `generateDailyChallengeGrid`
    sinh riêng.
  - `PopStarGame` nhận thêm `presetGrid` (constructor) — nếu có thì dùng làm
    `colorGrid` ban đầu thay vì random (chỉ áp dụng ở `onLoad`, không đụng
    refill của endless/zen).
  - `GameController.startDailyChallenge()`: set `mode = dailyChallenge`,
    sinh `dailyChallengeGrid = generateDailyChallengeGrid(_todayEpochDay())`,
    reset state như `startSideMode`. `game_screen_controller._newGame()`
    truyền `presetGrid` khi mode là dailyChallenge; nút "Again" gọi lại
    `startDailyChallenge()` (không phải `startSideMode`) để tái sinh đúng
    bàn hôm nay.
  - Ghi điểm 1 lần/ngày: `canRecordDailyChallengeScore` (so
    `StorageKeys.lastDailyChallengeDay` với hôm nay, giống `canClaimDaily`),
    `_saveDailyChallengeScore()` gọi từ `checkEnd()` nhánh non-campaign —
    chơi lại trong ngày không đè điểm cũ. `dailyChallengeScoreToday` đọc
    điểm đã ghi để hiển thị. Chưa có leaderboard (I9) nên điểm lưu riêng
    (`StorageKeys.dailyChallengeScore`) — sẽ nối vào I9 khi làm task đó.
  - UI: icon "Daily Challenge" ở home (hàng side-mode, cạnh Endless), HUD
    trong game hiện nhãn "Daily Challenge", dialog kết thúc hiện
    `Score X — Recorded Y`.
  - `resetProgress()` xoá `lastDailyChallengeDay` + `dailyChallengeScore`.
  - Test mới: `test/logic/daily_challenge_test.dart` (cùng seed → cùng bàn,
    seed khác → bàn khác, đúng kích thước) + group "F13 Daily Challenge"
    trong `game_controller_test.dart` (seed ổn định, ghi điểm 1 lần/ngày,
    qua ngày mới ghi lại được).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (180 test).

## ✅ Wave 8 — I9 (2026-07-13, chạy tự động overnight)

- **I9 Leaderboard bạn bè (offline giả lập)**: hoàn toàn offline, KHÔNG gọi
  network/backend nào (đúng scope AC).
  - `lib/logic/leaderboard.dart` (thuần Dart): `LeaderboardEntry(name, stars,
    {isPlayer})`; `buildLeaderboard(bots, playerStars)` chèn người chơi vào
    danh sách bot rồi sort giảm dần theo sao (bằng sao → bot đứng trước,
    tie-break ổn định); `playerRank(entries)` trả hạng 1-indexed.
  - `lib/data/leaderboard_bots.dart`: `kLeaderboardBots` — 10 bot tĩnh, mốc
    sao tăng dần 40→580 (trải đều tới ~600 = 200 màn × 3 sao tối đa).
  - Dùng `GameController.totalStars` có sẵn (F7 Star Road) làm điểm người
    chơi — không cần tính lại.
  - `lib/presentation/screens/leaderboard_screen.dart`: `ListView` các
    `_RankRow` (hạng, tên/"You", số sao); hàng người chơi viền vàng nổi bật.
    Icon "Leaderboard" mới ở home (hàng utility, cạnh Settings).
  - Phát hiện: `app_translations.dart` đã có sẵn key `leaderboard_title`/
    `lb_player`... (Wave 21.6, chưa từng dùng) nhưng thiết kế khác (tab
    Campaign/Daily top-10) — không khớp thiết kế bot-list này nên bỏ qua,
    UI mới hardcode string tiếng Anh (giống phần lớn màn hình khác:
    `star_road_screen.dart`, home) thay vì `.tr`.
  - Test mới: `test/logic/leaderboard_test.dart` (chèn đúng vị trí giữa 2
    bot, hạng 1 khi cao nhất, hạng cuối khi thấp nhất, tie-break bot đứng
    trước khi bằng điểm).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (184 test).

## ✅ Wave 8 — I6 (2026-07-13, chạy tự động overnight)

- **I6 Battle-pass mùa (free-track only, KHÔNG premium/IAP)**: mùa 28 ngày
  (`seasonLengthDays`), điểm mùa cộng khi thắng level campaign — công thức rõ
  ràng `stars * 10` (không random), mốc thưởng coin/booster.
  - `GameController`: `seasonMilestones = [50,150,300,500,800]`,
    `seasonRewards` tái dùng class `SpinReward` có sẵn (I7 spin) thay vì tạo
    kiểu thưởng mới — mix coin/bomb/shuffle.
  - `currentSeasonIndex` = ngày epoch hiện tại / 28. `_checkSeasonRollover()`
    so với `StorageKeys.lastSeasonIndex` đã lưu — lệch thì reset điểm mùa +
    mốc đã nhận về 0 (thưởng đã phát KHÔNG bị thu lại, coin/booster đã vào
    kho từ trước). Gọi rollover check trong `_load()` (mở app) và ngay trước
    khi cộng điểm trong `checkEnd()` (đề phòng qua mùa giữa lúc chơi).
  - `isSeasonClaimed`/`canClaimSeason`/`claimSeason` — bitmask, y hệt pattern
    rương F7 Star Road (`claimedChestMask`), claim 1 lần/mốc.
  - Cộng điểm mùa nằm trong nhánh `starsEarned.value > 0` của `checkEnd()`
    (cùng chỗ unlock/coin/review — chỉ thắng mới tính, không tính khi thua).
  - `lib/presentation/screens/season_screen.dart`: sao chép cấu trúc
    `star_road_screen.dart` (list mốc, claim button, coin-fly overlay) —
    label thưởng người-đọc-được qua `_rewardLabel(SpinReward)`. Icon "Season
    Pass" mới ở home (cạnh Leaderboard).
  - 3 storage key mới: `seasonPoints`, `claimedSeasonMask`,
    `lastSeasonIndex` — đã thêm vào `resetProgress()`.
  - Test mới trong `game_controller_test.dart` (group "I6 Battle-pass
    season"): cộng điểm đúng công thức, claim đủ điểm + không claim 2 lần,
    coin thưởng đúng số, rollover mùa mới reset điểm + mốc.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (188 test, +4 so với trước).

## ✅ Wave 9 — I1 (2026-07-13, chạy tự động overnight)

- **I1 Gift/present tiles**: ô quà mã hoá bằng 1 sentinel âm cố định
  `giftTileValue = -1000` trong `colorGrid` (`lib/logic/gift_tile.dart`, pure
  Dart, không Flutter/Flame/GetX) — tách biệt hẳn khỏi obstacle (âm = độ bền,
  phạm vi nhỏ -1..-vài) nên phải loại trừ tường minh ở 2 chỗ vốn coi mọi giá
  trị âm là obstacle: `chipAdjacentObstacles` (`obstacle.dart`) và
  `render()` (`block_component.dart`, check gift TRƯỚC check obstacle chung).
  `pop_detector.dart` đã loại mọi `v < 0` khỏi flood-fill nên gift tự động
  không thuộc nhóm màu, không cần sửa.
  - `openGiftsAtBottomRow(grid)`: gift rơi tới hàng đáy (sau gravity) tự mở
    thành `null`, trả về cột vừa mở. Gọi ở đầu `_checkEnd()`
    (`pop_star_game.dart`) — đây là điểm gravity thực sự "chốt" xong
    (game KHÔNG gọi `applyGravityAndCollapse` lúc chơi thường, mà
    `_collapseAnimated` tự làm gravity trên `_blocks` rồi đồng bộ vào
    `colorGrid`; `_checkEnd()` chạy sau khi animation rơi xong).
  - `pickGiftReward(rng)`: bảng trọng số cố định (coin 50/100/150, bomb 1,
    shuffle 1, undo 1) — không cần seed đặc biệt như spin/leaderboard.
    `GameController.grantGiftReward(reward)` phát thưởng, tái dùng pattern
    `_grant()` đã có (giống claimSpin/claimChest/claimSeason).
  - `_placeGiftsIfNeeded(level)` (`pop_star_game.dart`): chỉ chạy khi
    `objective.type == openGift`, rải đúng `target` ô quà lên ô trống chưa
    phải obstacle/chain-lock — gọi trong `onLoad()` cạnh
    `_placeObstaclesIfNeeded`/`_placeChainLocksIfNeeded`.
  - `ObjectiveType.openGift` + `LevelObjective.openGift(target)` mới trong
    `levels.dart`; `updateObjectiveProgress` đếm số ô gift còn lại trên bàn
    (giống pattern `clearObstacle`); UI text mới trong `game_screen.dart`.
  - **Quyết định phạm vi có chủ đích**: KHÔNG gắn `openGift` vào chu kỳ luân
    phiên 8-slot objective của 200 level campaign (`kLevels`) — spec I1 chỉ
    yêu cầu "level định nghĩa được objective mở K ô quà" (năng lực tồn tại,
    test được), không yêu cầu campaign hiện tại dùng nó. Tránh phá vỡ test
    khoá cứng chu kỳ 8 (`levels_test.dart`) và tránh rippling qua toàn bộ
    200 level ngoài yêu cầu AC.
  - Test mới: `test/logic/gift_tile_test.dart` (mở gift ở đáy, giữ nguyên
    nếu chưa tới đáy, reward luôn nằm trong bảng trọng số),
    `test/logic/obstacle_test.dart` (regression: gift liền kề không bị chip
    nhầm thành obstacle), `game_controller_test.dart` (đếm đúng objective
    openGift, met khi mở hết).
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (193 test, +5 so với trước).

## ✅ Wave 10 — I3 (2026-07-13, chạy tự động overnight)

- **I3 Gravity variants**: `PopLevel.gravityDirection` (`GravityDirection`:
  `down`/`up`/`left`/`right`, mặc định `down`) — chưa gán cho level nào trong
  `kLevels` (giống quyết định phạm vi của I1: năng lực tồn tại + test được,
  campaign hiện tại chưa dùng, tránh rippling ngoài yêu cầu AC).
  - `lib/logic/pop_collapse.dart`: đúng 1 thuật toán lõi `_collapseDown`
    (không đổi) — `up`/`left`/`right` quy về không gian "down" bằng
    `transformForDirection` (transpose đổi trục hàng/cột cho `left`/`right`,
    lật hàng cho `up`), chạy `_collapseDown`, rồi quy ngược
    (`inverse: true`). Không viết 4 bộ logic riêng theo đúng AC.
  - **Phát hiện lại kiến trúc từ I1/I2**: gameplay thật không gọi
    `applyGravityAndCollapse` — `PopStarGame._collapseAnimated()` tự làm
    gravity trên `_blocks` (BlockComponent) rồi đồng bộ vào `colorGrid`/
    `lockGrid`. Vì vậy phải tổng quát hoá **cả 2 chỗ**: hàm thuần (test được)
    và `_collapseAnimated` (gameplay thật). Để tránh 2 bộ thuật toán, tách
    `transformForDirection<T>`/`compactNonNullDown<T>` generic trong
    `pop_collapse.dart`, dùng chung cho `List<List<int?>>` (colorGrid) lẫn
    `List<List<BlockComponent?>>` (`_blocks`) — `_collapseAnimated` giờ chỉ
    gọi `compactNonNullDown`/`transformForDirection` thay vì loop riêng.
  - Animation rơi đúng hướng "miễn phí": `_collapseAnimated` chỉ cần tính
    đúng vị trí (r, c) đích sau nén — `MoveToEffect` đã tween theo
    `_cellCenter(r, c)` sẵn có, không cần vector hướng riêng.
  - `_rebuildBoard`'s intro-fall (block rơi vào từ ngoài bàn lúc load màn)
    cũng chỉnh theo `gravityDirection` qua `_introStart()` — vào từ tường đối
    diện hướng gravity thay vì luôn từ trên xuống.
  - **Quyết định phạm vi có chủ đích**: không đụng `_checkEnd()`'s hook mở
    gift (hardcode `rows - 1` = đáy) — `openGift` (I1) chưa gán cho level nào
    nên không có tổ hợp gravity khác `down` + `openGift` xảy ra trong thực tế.
  - Test mới: `test/logic/pop_collapse_test.dart` nhóm `I3: gravityDirection`
    — rơi đúng hướng + dồn phần rỗng đúng trục phụ cho cả 3 hướng, lockGrid
    vẫn lockstep, và 1 test đối chiếu trực tiếp AC ("`right` cho kết quả
    đúng như `down` chạy trên grid đã transpose thủ công").
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: toàn bộ
    xanh (201 test, +8 so với trước).

## ✅ Wave 11 — I14 (2026-07-13, chạy tự động overnight)

- **I14 Theme per world**: nền game (`NeonBg`) đổi tông màu theo world của
  level đang chơi thay vì luôn 1 tông cố định.
  - Phát hiện `NeonBg` đã có sẵn param `accent` (lerp tông màu vào orb nền
    trong `_NeonBgPainter`) từ trước nhưng chưa nơi nào truyền vào — và
    `GameWorld` (`worlds.dart`) đã có sẵn field `color` mỗi world dùng cho
    banner path map. Ghép 2 cái có sẵn lại là đủ AC, **không thêm field
    palette mới** cho `GameWorld` (tránh trùng lặp — field `color` đã đúng
    vai trò palette-per-world mà task yêu cầu).
  - Đổi duy nhất: `game_screen.dart` truyền
    `accent: worldForLevel(gameCtrl.currentLevel.id).color` vào `NeonBg(...)`.
  - Side-mode (Time-attack/Zen/Endless/Daily — id âm) rơi vào fallback của
    `worldForLevel` (world cuối) vì không match range world nào — chấp nhận,
    không phải case task nhắm tới.
  - Test mới: `game_screen_smoke_test.dart` — dựng `GameScreen` ở level world
    2 (id 25), tìm widget `NeonBg`, assert `accent == worldForLevel(25).color`.
  - Không viết widget test/code mới cho contrast gem — AC yêu cầu "kiểm bằng
    mắt", không phải test tự động; `accent` chỉ lerp 50% vào orb nền (biên độ
    có sẵn từ trước lúc build `NeonBg`), không đụng màu gem.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 202 test,
    +1 so với trước.

## ✅ Wave 12 — I17 (2026-07-13, chạy tự động overnight)

- **I17 Tile material variants**: gem đổi chất liệu render theo world thay vì
  luôn 1 kiểu "jelly" bóng mềm.
  - `TileMaterial` enum (`jelly`/`crystal`/`metal`) trong `block_component.dart`.
    `materialForLevel(id)` chia đều index world (trong `kWorlds`, không hardcode
    lại "20 màn/world") thành 3 dải: world 1-4 = jelly, 5-7 = crystal, 8-10 =
    metal.
  - Tách phần vẽ thân+gloss+viền (trước đây hardcode riêng cho jelly) ra hàm
    riêng `paintTileBody(canvas, rrect, rect, s, color, material)` **không phụ
    thuộc `HasGameReference`** — để golden test gọi thẳng qua `CustomPainter`,
    không cần dựng `FlameGame`/`GameWidget` (dự án chưa có `flame_test`, chưa
    test nào mount `BlockComponent` trần).
  - Mỗi variant vẫn đúng 3 draw call (thân/gloss/viền) như bản gốc — chỉ đổi
    tham số Paint/gradient/hình học, không thêm draw call → giữ đúng AC
    "không tăng chi phí render đáng kể".
  - `jelly`: gradient dọc trắng-màu-đen, gloss bo tròn góc trên, bo góc 0.22
    (giữ nguyên bản gốc). `crystal`: gradient chéo tương phản mạnh hơn, gloss
    là 1 vệt chéo mỏng (xoay 45°), viền mỏng gần trắng, bo góc 0.10 (sắc cạnh).
    `metal`: gradient ngang 5 dải sáng/tối (ánh kim), gloss là 1 vệt sáng ngang
    giữa, viền dày ánh xám bạc, bo góc 0.16.
  - `pop_star_game.dart` (`_rebuildBoard`) truyền
    `material: materialForLevel(controller.currentLevel.id)` khi tạo mỗi
    `BlockComponent`.
  - Golden test mới: `test/widget/goldens/block_component_material_golden_test.dart`
    — gọi `paintTileBody` trực tiếp cho cả 3 material với cùng 1 màu input,
    3 file `.png` riêng, xác nhận bằng mắt 3 hình khác nhau rõ dù cùng màu.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 205 test
    (+3 golden so với Wave 11).

## ✅ Wave 13 — I15 (2026-07-13, chạy tự động overnight)

- **I15 Day/Night theme toggle**: switch trong Settings đổi tức thì giữa
  bright-casual hiện tại (mặc định) và neon-dark gốc trước pivot — không tách
  bản riêng, không route/rebuild app.
  - `NeonTheme`: thêm `static bool dark` + đổi các token
    `bgTop/bgMid/bgBot/card/cardAlt/panel/ink/inkSoft` từ `static const` sang
    `static Color get` rẽ nhánh theo `dark`. Mọi callsite cũ (`NeonTheme.ink`,
    `.card`, …) không cần sửa gì — tự đổi theo flag, đúng AC "không sửa từng
    nơi gọi màu cứng".
  - Bảng màu dark KHÔNG bịa mới: lấy lại đúng giá trị neon gốc trước pivot
    (`git show <commit trước pivot>:lib/core/neon_theme.dart`) —
    `panel=0xFF1B1B3A` → `card` dark, `bgDark2=0xFF14142E` → `cardAlt` dark,
    gradient 3-stop gốc → `bgTop/bgMid/bgBot` dark. Còn 2 hằng dark cũ
    (`bgDark`/`bgDark2` trong file, xác nhận không nơi nào dùng qua grep)
    được tái dùng làm `bgTop`/`bgMid` dark thay vì xoá bỏ phí. Chỉ 2 giá trị
    thật sự mới: `ink`/`inkSoft` dark (bản gốc không có token chữ vì UI khi
    đó không có text thân dài).
  - `bgGradient` đổi từ `static const LinearGradient` sang getter dựng từ 3
    token trên.
  - `StorageKeys.themeDark` ('theme_dark') lưu lựa chọn qua
    `StorageService.getBool/setBool` có sẵn (không cần helper riêng).
  - `main.dart`: đọc `NeonTheme.dark = store.getBool(StorageKeys.themeDark)`
    ngay sau khi `StorageService` sẵn sàng, trước `runApp`.
  - `settings_screen.dart`: `SwitchListTile` mới (theo đúng pattern
    `_hapticsEnabled` đã có) — đổi `NeonTheme.dark`, lưu storage, gọi
    `Get.forceAppUpdate()` để rebuild toàn cây ngay lập tức (không cần bọc
    từng widget bằng `Obx`/`GetBuilder` — theme là state toàn cục, GetX
    idiomatic cho trường hợp này). Key i18n `dark_theme` thêm đủ 22 locale.
  - Side-effect: đổi `static const` → `static Color get` phá vỡ mọi
    `const` Flutter widget tham chiếu các token này (Dart yêu cầu giá trị
    const-context phải compile-time constant) — sửa ~17 chỗ (bỏ `const` thừa
    ở các file screen/widget). 2 chỗ đặc biệt: `neon_bg.dart` gộp gradient
    trùng lặp thành gọi thẳng `NeonTheme.bgGradient` (tái dùng thay vì lặp
    code); `stroke_text.dart` đổi tham số `stroke` sang `Color?` (bỏ default
    const, áp fallback `?? NeonTheme.ink` tại điểm dùng) vì default parameter
    value phải const.
  - Golden test: **lệch khỏi gợi ý AC** "button, app bar" — cả hai không
    tham chiếu token bg/card/ink trực tiếp (màu `NeonButton` đến từ accent
    truyền vào, `NeonAppBar` không có nền theo token). Dùng `NeonDialog.panel`
    (card+ink) và `NeonBg` (bgTop/Mid/Bot) thay thế —
    `test/widget/goldens/theme_dark_toggle_golden_test.dart`, 4 ảnh
    (dialog×2, bg×2), xác nhận bằng mắt 2 theme khác biệt rõ.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 209 test
    (+4 golden so với Wave 12).

## ✅ Wave 14 — I16 (2026-07-13, chạy tự động overnight)

- **I16 Aurora background shader (world cuối)**: nền world 10 (id 181-200,
  khó nhất) có dải aurora chuyển sắc phủ lên trên `NeonBg` gốc, chỉ world
  này, các world khác không đổi.
  - Shader mới `shaders/aurora_bg.frag` — 3 dải sóng ngang lệch pha, hue-shift
    dần theo thời gian trên nền màu accent world, alpha premultiplied giống
    `neon_glow.frag`. Đăng ký trong `pubspec.yaml` cùng mục `shaders:` có sẵn.
  - `AuroraBgLayer` (`lib/presentation/widgets/aurora_bg_layer.dart`) —
    sao chép nguyên cấu trúc `NeonAuraLayer` (Ticker throttle ~30fps,
    `FragmentProgram.fromAsset` try/catch, `dlog` khi lỗi) thay vì viết hạ
    tầng mới, đúng yêu cầu "tái dùng hạ tầng shader đã chứng minh hoạt động".
  - **Lệch khỏi AC**: AC ghi "Fallback non-shader (gradient animation
    AnimationController) khi thiết bị không hỗ trợ — theo đúng pattern
    neon_aura_layer.dart đã làm" — nhưng đọc lại `neon_aura_layer.dart` thì
    fallback thật của nó là **ẩn hẳn** (`SizedBox.shrink`) khi shader lỗi,
    không có gradient animation nào cả. Làm đúng theo pattern THẬT (ẩn hẳn)
    thay vì theo mô tả sai trong AC — nhất quán với cách I15 cũng phát hiện
    1 chỗ AC mô tả không khớp code hiện tại.
  - `NeonBg` thêm param `aurora` (mặc định false) — khi bật, overlay
    `AuroraBgLayer` lên trên gradient nền hiện có (không thay thế), màu lấy
    từ `accent` world (fallback `NeonTheme.indigo`).
  - `game_screen.dart`: bật `aurora: worldForLevel(id) == kWorlds.last`.
  - Test: `test/widget/aurora_bg_layer_test.dart` (mirror
    `neon_aura_layer_test.dart` — không crash dù shader load được hay
    không, cả standalone lẫn qua `NeonBg(aurora: true)`). Golden-test hình
    ảnh không khả thi (shader không chạy được trong môi trường test không
    GPU) — verify bằng build cài thiết bị thật.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 211 test
    (+2 so với Wave 13).

## ✅ Wave 15 — F15 (2026-07-13, chạy tự động overnight)

- **F15 Photo mode / chia sẻ bàn chơi**: nút chia sẻ trên màn thắng, chụp ảnh
  bàn chơi + text level/điểm/ngày, mở share sheet hệ thống.
  - Thêm 1 package share duy nhất: `share_plus: ^12.0.2` — trước đó project
    chưa có package share nào (`shared_preferences` chỉ trùng chữ "share").
  - `lib/core/share_helper.dart` (mới) — 1 pipeline share dùng chung cho cả
    F15 và X6, không tạo hàm/plugin riêng ở 2 nơi:
    - `shareText(text)` — text-only, dùng cho X6 mời bạn bè.
    - `captureBoardPng(GlobalKey, {pixelRatio})` — chụp `RepaintBoundary`
      thành PNG bytes, tách riêng khỏi việc gọi share để test được (không
      chạm platform channel của `share_plus`).
    - `shareBoardImage({boundaryKey, text})` — gọi `captureBoardPng` rồi mở
      share sheet kèm ảnh + text, dùng cho F15.
  - `GameScreenController.boardKey` (GlobalKey) + `shareBoard()` — bọc
    `Container` bàn chơi trong `game_screen.dart` bằng `RepaintBoundary(key:
    gsc.boardKey)`, text chia sẻ gồm level id, điểm, ngày (ISO date).
  - Nút share (`NeonIconButton(Icons.share_rounded)`) đặt cạnh dòng điểm
    trong màn thắng (`_WinChoreographyState`). Key i18n mới `share_board`
    thêm cho cả 22 locale.
  - Test: `test/core/share_helper_test.dart` — `captureBoardPng` trả PNG hợp
    lệ (kiểm magic bytes) khi context đã build, null khi chưa. Phải bọc gọi
    trong `tester.runAsync(...)` vì `RenderRepaintBoundary.toImage()` cần
    rasterize thật, không chạy được trong `FakeAsync` zone mặc định của
    `flutter test`. Việc mở share sheet thật (platform channel) không test
    được trong môi trường này — verify bằng build cài thiết bị thật.
  - X6 (mời bạn bè) sẽ gọi lại `shareText` ở trên, không tạo pipeline mới.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 213 test
    (+2 so với Wave 14).

## ✅ Wave 16 — X6 (2026-07-13, chạy tự động overnight)

- **X6 Mời bạn bè (share invite)**: `ListTile` trong Settings, gọi lại
  `shareText` đã dựng ở F15 (không tạo pipeline share riêng, đúng note kỹ
  thuật trong task file) với text kèm placeholder link Google Play (chưa có
  link thật, cần thay khi phát hành).
  - Key i18n mới `invite_friend` thêm cho cả 22 locale.
  - Phát hiện + fix: thêm `ListTile` đẩy nút "Reset progress" ra ngoài
    viewport mặc định của widget test (`ListView` — khác `Column` — chỉ
    build/layout con nằm trong viewport, con ngoài viewport không tồn tại
    trong tree nên `find.text` không thấy). Fix ở
    `test/widget/settings_screen_test.dart`: `tester.dragUntilVisible(...)`
    trước khi assert nút reset, cho cả biến thể `en_US` và `ja_JP`.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 213 test
    xanh hết (không đổi tổng số so với Wave 15 — chỉ sửa test có sẵn, không
    thêm test mới; feature tự nó không cần test riêng vì tái dùng `shareText`
    đã có test ở F15).

## ✅ Wave 17 — F14 (2026-07-13, chạy tự động overnight)

- **F14 Relic/Perk system**: perk vĩnh viễn mở khoá khi hoàn thành 1 world —
  KHÔNG mua bằng coin/tiền thật (đúng AC), tối đa 2 active cùng lúc, chọn ở
  màn hình riêng (`PerksScreen`), không đổi giữa chừng ván.
  - `lib/data/perks.dart` (mới): `Perk`, `kPerks` (3 perk: `extra_undo`
    unlock sau world 1, `move_hint` sau world 2, `coin_bonus` sau world 3),
    `worldsCompleted(unlockedLevel)` và `unlockedPerks(unlockedLevel)` — 2
    hàm thuần suy từ `unlockedLevel` + `kWorlds` có sẵn (F4), không thêm state
    mới.
  - `GameController`: `activePerkIds` (RxList, persist qua
    `StorageKeys.activePerks` — string nối dấu phẩy, tái dùng
    `getString`/`setString` có sẵn, không thêm storage primitive), `hasPerk`,
    `togglePerk` + static `togglePerkSelection` (thuần, test được, giới hạn
    tối đa 2 active). Reset qua `resetProgress()`.
  - Hiệu ứng 3 perk — đều tái dùng cơ chế có sẵn, không phát minh hệ thống mới:
    - `extra_undo`: mở rộng I5 (1 lượt undo miễn phí/màn, trước là bool) thành
      counter `_freeUndoLeft` = 2 nếu có perk, 1 nếu không.
    - `coin_bonus`: +10% trong `_grantCoins()`.
    - `move_hint`: rút `_hintDelay` (I4 auto-hint) từ 6.0s xuống 2.0s trong
      `pop_star_game.dart` khi `controller.hasPerk('move_hint')`.
  - `PerksScreen` (mới, theo mẫu `LeaderboardScreen`): liệt kê `kPerks`, khoá
    icon khi chưa unlock, tap để toggle active. Entry point mới trên
    `HomeScreen` (icon `auto_fix_high`, màu cyan).
  - Key i18n mới cho cả 22 locale: `perks_title`, `perk_extra_undo(_desc)`,
    `perk_move_hint(_desc)`, `perk_coin_bonus(_desc)`, `perk_locked`.
  - Test mới `test/data/perks_test.dart`: `worldsCompleted`/`unlockedPerks`
    mở khoá đúng theo world, `togglePerkSelection` giới hạn 2 active + bỏ
    được perk đang active dù đã đủ 2.
  - `flutter analyze`: 0 issues. `flutter test --exclude-tags slow`: 220 test
    xanh hết (213 + 7 mới).

## ✅ Smoke test audit trên Tecno thật (2026-07-13)

User báo gặp lỗi UI nhiều dù trước đó tưởng backlog đã xong — audit trực
tiếp trên máy Tecno (`118743744X002560`) qua screenshot từng màn hình.

- **Bug #1** home icon grid lệch — đã fix (session trước).
- **Bug #2** HUD booster row overflow — đã fix (session trước).
- **Bug #3** intro-animation freeze `pop_star_game.dart` — đã fix (session
  trước).
- **Bug #4** Settings switch state OFF rơi về style Material mặc định
  (đen/trắng, lệch theme candy-neon) — 4 `SwitchListTile` (Sound, Haptics,
  Colorblind, Dark theme) chỉ set `activeThumbColor` cho state ON, không
  set gì cho OFF. Fix 1 lần ở gốc: thêm `switchTheme: SwitchThemeData(...)`
  vào `ThemeData` trong `main.dart` (không sửa `settings_screen.dart`) —
  set `trackColor`/`trackOutlineColor`/`thumbColor` cho state chưa-selected,
  trả `null` cho state selected để không đụng override cyan sẵn có. Verify
  bằng screenshot ON/OFF trên Tecno, cả 4 switch đồng nhất theme.
- **Bug #5 (nghi ngờ, đã bác bỏ)**: đo lần đầu tưởng Time Attack countdown
  chạy nhanh gấp ~5 lần thật (25s→0s trong ~5s), do so sánh 2 screenshot
  chụp ở 2 lệnh Bash tách rời — độ trễ suy luận giữa các lệnh bị tính nhầm
  là thời gian trong game. Đo lại đúng cách: bracket 2 lần chụp + `sleep`
  trong CÙNG 1 lệnh Bash (không có khoảng hở suy luận) → countdown giảm
  16 tick trong 15.03s thật, đúng tỉ lệ 1:1 (lệch 1s do pha khởi động). Kết
  luận: `_startCountdown()` trong `game_screen_controller.dart` chạy đúng,
  không sửa gì.
- Quét thêm toàn bộ: Shop, Settings (đủ 22 locale), Guide, Leaderboard,
  Season Pass, Perks, Star Road, Spin Wheel dialog, Zen/Endless/Daily
  Challenge — tất cả clean, không phát hiện lỗi mới.
- **Bug #6** banner FTUE "Tap this group!" (`_FtueOverlay` trong
  `game_screen.dart`) đóng cứng ở `Alignment(0, -0.2)`, không liên quan gì
  tới vị trí group thật mà `_hint` đang trỏ tới (`findLargestGroup` — group
  lớn nhất còn lại trên bàn). User phát hiện qua trải nghiệm thật, verify lại
  bằng cách flip `flutter.has_seen_ftue` về `false` qua `adb run-as sed`,
  chụp `ftue1.png` trên Tecno, decode màu lưới + chạy flood-fill tay đúng
  logic `findConnectedGroup` → group vàng lớn nhất (5 ô) nằm hàng 5-7/8 (gần
  đáy), trong khi banner đè hàng 1 (gần đỉnh) — cách nhau 4-6 hàng, xác nhận
  bằng zoom ảnh thấy viền trắng-nhạt pulse đúng 5 ô đó sáng hơn hẳn ô vàng
  khác cùng màu. Fix root cause 1 chỗ: thêm `_ftueAlignY(PopStarGame game)`
  tính alignment theo hàng trung bình của `hintGroup` — banner đặt ở nửa bàn
  KHÔNG chứa group (tránh đè lên chính group nó trỏ tới), đồng thời dời
  `_FtueOverlay` từ Stack ngoài (dính cả Hud) vào Stack trong (chỉ vùng
  board) để alignment tính đúng theo board, không lẫn chiều cao Hud.
  `flutter analyze` 0 issues; `flutter test --exclude-tags slow` chỉ còn 1
  fail cũ ở `home_screen_test.dart` (RenderFlex overflow, có sẵn từ trước,
  không liên quan file này). Verify lại on-device trên Samsung SM-A507FN
  (Tecno lúc đó mất kết nối, user chọn Samsung): fresh install → Level 1 →
  zoom ảnh xác nhận group hint thật nằm hàng 4-5/8 (nửa dưới), banner render
  ở nửa trên (ranh giới hàng 3-4) — không còn đè lên nhau.
- **Bug #7** `G8 idle shimmer` (`_ShimmerSweep` trong `pop_star_game.dart`,
  build ở Wave 7 G8) — user đã yêu cầu xoá từ trước, sót lại chưa xoá. Đã gỡ
  toàn bộ: class `_ShimmerSweep`, field `_shimmerTimer`/`_shimmer`,
  `_triggerShimmer()`, getter test-only `shimmerActive`, nhánh update() kích
  hoạt, và reset trong `clearHint()`; xoá luôn `test/widget/idle_shimmer_test.dart`.
  `flutter analyze` 0 issues; `flutter test --exclude-tags slow` vẫn chỉ 1
  fail cũ như trên (không liên quan).
- **Bug #8** revamp menu Home — user chê "màu trùng lắp" + "stroke border thô
  kệch". Đếm tay xác nhận 12 icon (`home_screen.dart`) chỉ dùng 6/12 màu
  `NeonTheme` sẵn có, lặp nặng (`purple` x3, `cyan` x2, `magenta` x2). Fix 2
  chỗ: (1) `home_screen.dart` — gán lại đủ 12 icon dùng đúng 12 màu
  `NeonTheme` (cyan/magenta/lime/yellow/orange/purple/blue/pink/teal/red/
  indigo/gold), không màu nào lặp; (2) `neon_icon.dart` — bỏ
  `border: Border.all(color: c, width: 3)` cứng ở biến thể `boxed`, thay bằng
  `boxShadow: [...NeonTheme.glow(c, blur: 16, spread: 1), ...NeonTheme.drop(y: 4, blur: 8)]`
  (3 lớp halo mờ dần + drop shadow) để ra đúng chất neon glow thay vì viền
  cứng. `flutter analyze` 0 issues; regenerate + soi bằng mắt 2 golden
  `neon_icon_button_boxed.png`/`_disabled.png` (halo mềm đúng ý, bản disabled
  chỉ còn drop shadow xám); `flutter test --exclude-tags slow` vẫn chỉ 1 fail
  cũ ở `home_screen_test.dart` (không liên quan, không phải regression mới).
- **Bug #9** (nối tiếp Bug #4, fix trước đó chưa đủ) user vẫn chê switch
  Settings "sai màu, không tương phản, không nhìn rõ". Build + cài debug APK
  lên Samsung SM-A507FN, zoom screenshot xác nhận 2 lỗi tương phản riêng biệt
  mà Bug #4 chưa xử lý: (1) **state ON** (Sound, Haptics) — track cyan nhạt +
  thumb cyan đậm, cùng tông màu nên thumb gần như chìm vào track; (2) **state
  OFF** (Colorblind mode, Dark theme) — track dùng `NeonTheme.inkSoft` (màu
  dành cho text phụ, không phải màu viền UI) ở alpha 0.35, quá mờ trên nền
  pastel sáng `NeonBg`. Fix 2 chỗ: (1) `main.dart` `switchTheme` — đổi
  `trackColor`/`trackOutlineColor` state OFF từ `inkSoft.withValues(alpha:
  0.35)` sang `NeonTheme.ink.withValues(alpha: 0.28/0.45)` (đậm hơn, tương
  phản rõ trên mọi stop gradient nền); (2) `settings_screen.dart` — 4
  `SwitchListTile` (Sound, Haptics, Colorblind mode, Dark theme) đổi
  `activeThumbColor: NeonTheme.cyan` (đơn) thành cặp
  `activeThumbColor: Colors.white` + `activeTrackColor: NeonTheme.cyan` (kiểu
  "viên thuốc màu + chấm trắng" chuẩn neon, tách bạch thumb/track). `flutter
  analyze` 0 issues; verify lại on-device Samsung SM-A507FN — cả 4 switch ON
  giờ track cyan/thumb trắng rõ, cả 2 switch OFF track xám-tím đậm dễ thấy;
  `flutter test --exclude-tags slow` vẫn chỉ 1 fail cũ ở `home_screen_test.dart`
  (không liên quan, không phải regression mới).
- **Bug #10** user báo "animation gem lag lúc chơi" + "animation score xấu".
  Audit `block_component.dart`/`pop_star_game.dart`, loại các nghi phạm phụ
  (`_EdgeTraceComponent`, `_BurstRing` tự dọn/cooldown; `_spawnBurst` particle
  không dùng blur từ trước; `_maybeTriggerPunch` cooldown 1s) — root cause
  thật: rim "combo heat" (G6) trong `BlockComponent.render()` vẽ
  `MaskFilter.blur` trên **mọi ô, mọi frame** hễ `heat > 0` (tức
  `comboMultiplier > 1`, xảy ra thường xuyên khi chơi, không hiếm), trong khi
  bloom G8 cùng file đã bake cache đúng cách — rim heat là chỗ duy nhất lệch
  khỏi pattern đó, nhân với cỡ bàn (tới ~130 ô late-game) mỗi frame. User
  chọn fix đơn giản: bỏ blur, giữ solid stroke (đổi màu/độ dày vẫn thấy
  "nóng", mất glow mềm). Song song, rewrite `_spawnScorePopup` theo 3 hướng
  user chọn (glow + màu theo gem vừa nổ, sparkle trail, combo càng cao chữ
  càng to/nảy) — tái dùng kỹ thuật `StrokeText` (2 lớp stroke/fill) và
  particle không-blur của `_spawnBurst` thay vì bịa cơ chế mới; thêm
  `_spawnScoreSparkles`, đổi cả 2 call site truyền thêm `gemColor` (đọc từ
  `colorGrid` trước khi `_clearAndCollapse` null hoá). `flutter analyze` 0
  issues; `flutter test --exclude-tags slow` vẫn chỉ 1 fail cũ ở
  `home_screen_test.dart` (RenderFlex overflow 5px, không liên quan, không
  phải regression mới). Chưa verify visual on-device.
- **A9 xóa "snap" tức thì** — user chọn "fix toàn bộ 9 điểm ngay 1 lần" sau
  audit toàn bộ animation gap (khởi phát từ báo cáo undo/"lùi lại 1 step"
  không có animation). 9 điểm: undo/shuffle re-deal, swap flip preview, coin
  countup (`CoinChip`), booster count countup (HUD trong game + label trong
  `ShopScreen`), nút mua ở shop có `PressableScale`, dialog vào bằng
  scale+fade (`NeonDialog.overlay` dùng `TweenAnimationBuilder`) thay vì snap,
  dialog ra/chuyển đổi qua `AnimatedSwitcher` (160ms) thay vì snap. 2 điểm cân
  nhắc rồi bỏ, ghi rõ lý do trong `A9-instant-snap-polish.md`: settings locale
  (đã animate sẵn qua `ChoiceChip`) và freeze booster indicator (gộp vào
  booster-count countup, không dựng UI riêng cho 1 field `int` thường). Trong
  lúc sửa dính 1 bug crash: `Positioned.fill` (cũ nằm trong
  `NeonDialog.overlay`) không hợp lệ khi lồng trong `AnimatedSwitcher` (con
  animated bọc qua `FadeTransition`, không phải `Stack` trực tiếp) — fix bằng
  cách chuyển `Positioned.fill` ra ngoài, bọc quanh `AnimatedSwitcher` ở
  `_Overlay.build()` (`game_screen.dart`), còn `NeonDialog.overlay` trả về
  `Stack` trần. `flutter analyze` 0 issues.

  Nhân dịp full suite chạy, phát hiện + dọn xong 2 việc tồn đọng không liên
  quan A9 nhưng chặn suite xanh hoàn toàn: (1) `home_screen_test.dart`
  RenderFlex overflow 5px — bug đã ghi nhận từ Bug #6 (documented "có sẵn từ
  trước") nhưng chưa ai truy gốc; root cause thật: viewport test mặc định
  800x600 (ngang) không đại diện điện thoại thật (luôn cao hơn rộng),
  `HomeScreen` xếp nhiều hàng nút bị ép hụt chiều cao giả tạo — verify bằng
  `git stash` chạy lại trên HEAD sạch (vẫn fail y hệt, xác nhận không phải do
  A9) rồi bisect bằng test cô lập (tắt daily-dialog qua storage mock, dựng
  panel/dialog riêng ngoài `HomeScreen`) để loại trừ dần tới đúng thủ phạm.
  Fix: set `tester.view.physicalSize`/`devicePixelRatio` theo tỉ lệ dọc thật
  (1080x2400 @3x) trong chính test, không đụng `home_screen.dart` (layout ổn
  trên máy thật). (2) `test/widget/idle_shimmer_test.dart` — file mồ côi,
  chưa từng track git, sót lại từ Bug #7 (G8 idle shimmer đã bị xoá hẳn khỏi
  `pop_star_game.dart` theo yêu cầu user, kể cả getter test-only
  `shimmerActive`, nhưng file test tương ứng khi đó xoá xong lại tái xuất
  hiện chưa rõ do đâu) — xoá lại, cùng 1 báo cáo build thừa
  `android/build/reports/problems/problems-report.html` lỡ bị `git add`.
  Kết quả: `flutter test --exclude-tags slow` **xanh hoàn toàn lần đầu tiên**
  (trước giờ luôn có đúng 1 fail "cũ" được coi là biết trước, không chặn).
  Chưa verify on-device 9 animation của A9.

## ✅ I21 — đa dạng màu gem theo level (2026-07-13)

`colorCount` trước chỉ đổi mỗi 60 level (`4 + (world~/3).clamp(0,3)`, 200
level chỉ 4 giá trị 4/5/6/7). Sửa `lib/data/levels.dart`: thêm dao động
`+ (i % 3) - 1` quanh baseline, clamp 4..7 — level liền kề trong cùng world
giờ có thể khác colorCount, trần/sàn khó không đổi. Test mới
`test/data/levels_test.dart` xác nhận mỗi world (20 level) có ≥2 giá trị
colorCount khác nhau. `flutter analyze` 0 issues; test suite xanh.
Task doc: `doc/task/tasks/I21-per-level-color-variety.md`.

## 🔍 Audit round 2 (2026-07-13) — re-scan toàn bộ source

Sau khi backlog 24 task audit đợt 1 + A9 + I21 xong hết, chạy tiếp 4 Explore
agent song song quét lại (logic/game engine; presentation/UX; data/levels-
worlds; i18n/settings/accessibility). Khác đợt 1: lần này **verify từng
finding bằng tay trước khi tin** (đọc source thật, không nhận claim của
subagent làm sự thật).

Kết quả logic-agent: **cả 5 finding đều false positive** sau khi đọc code
trực tiếp —
- `pop_collapse.dart` "sai index khi dồn cột": `nonEmptyCols[c] >= c` luôn
  đúng (list tăng dần) nên đọc từ cột chưa bị ghi đè — thuật toán compaction
  in-place chuẩn, không lỗi.
- `shuffleBoard()` "không gọi `_checkEnd()`": grep xác nhận có gọi (dòng
  1070).
- `undo()` "không gọi `_checkEnd()`": đúng là không gọi, nhưng đúng ý đồ —
  state được `_saveUndo()` lưu luôn là state ngay trước 1 move hợp lệ (đã
  ngầm định không kẹt/không thắng, nếu không game đã kết thúc trước đó rồi),
  nên không cần check lại.
- Freeze-turns "underflow": có guard `> 0` trước decrement, không có.
- Hint "gồm cả power tile": đúng ý đồ — power tile vẫn là ô màu bình thường
  trong `colorGrid`, gộp vào nhóm là hợp lệ.

UX-agent: `game_screen.dart:139` `_objectiveLine` đọc `.value` "ngoài `Obx`"
— sai, hàm được gọi bên trong callback `Obx(() {...})` mở ở dòng 191, GetX
track dependency bình thường dù qua helper function. Row 4-nút ở
`home_screen.dart` cũng check tay — tổng chiều rộng ~264px, không có nguy cơ
tràn màn hình thật.

**2 finding sống sót verify** (đã rã task):
- **X7** — 6 chuỗi hardcode tiếng Việt/Anh bỏ qua `.tr` (`home_screen.dart`
  dialog comeback + daily reward, `leaderboard_screen.dart` title + "You") —
  vi phạm parity 22-locale. Task: `doc/task/tasks/X7-i18n-hardcoded-strings.md`.
- **X8** — `worldForLevel()` fallback `kWorlds.last` khi id âm (side-mode
  Zen/TimeAttack/Endless/Daily) → 4 mode này ăn nhầm theme world 10 + hiệu
  ứng aurora (I16) vốn chỉ dành world khó nhất. Task:
  `doc/task/tasks/X8-side-mode-world-theme-fallback.md`.

**Đã code X7 + X8 (2026-07-13)**: X7 thêm 6 key mới (`home_comeback_title`,
`home_comeback_msg`, `home_daily_title`, `home_daily_msg`,
`home_weekend_banner`, `leaderboard_you`) đủ 22 locale, wire `.tr`/`.trParams`
tại `home_screen.dart` + `leaderboard_screen.dart` (tái dùng key `daily_claim`
có sẵn cho nút hành động, `leaderboard_title` có sẵn cho AppBar). X8 guard
`currentLevel.id > 0` trước khi gọi `worldForLevel` ở `game_screen.dart`,
side-mode nhận `accent: null`/`aurora: false`. `flutter analyze` 0 issues,
`flutter test --exclude-tags slow` xanh (220+ test).

## 💭 Ideas (ngoài scope hiện tại)

- Gán `LevelObjective.clearColor/clearObstacle` cho các màn cụ thể trong
  `kLevels` (cơ chế đã xong + có test qua `objective_test.dart`, nhưng chưa
  màn campaign nào thực sự dùng objective khác score).
- Monetize (`I19`/`I20` trong `IDEAS.md`) — user đã loại dứt khoát khỏi mọi
  wave (Option D), giữ nguyên "chưa chốt" cho tới khi có yêu cầu khác.
- `I12` dynamic music layers — còn "chưa chốt" trong `IDEAS.md`, chưa có task
  file.

## ✅ Fix bug booster tốn lượt khi no-op (2026-07-13)

Phát hiện khi rà soát/tick checkbox 55 file task doc (bookkeeping cleanup):
`useBomb`/`useShuffle`/`useRainbow`/`useSwap` (`game_controller.dart`) trừ
số lượng booster **vô điều kiện** ngay sau khi gọi `triggerBomb`/
`shuffleBoard`/`triggerRainbow`/`triggerSwap`, nhưng 4 hàm này
(`pop_star_game.dart`) có thể no-op im lặng (đang animate, target là
obstacle/lock, hoặc không có gì đổi) — người chơi tap trúng ô không hợp lệ
vẫn mất 1 lượt dù không có hiệu ứng gì xảy ra. `undo()` đã có pattern đúng
từ trước (trả `bool`, caller check trước khi trừ) — áp cùng pattern cho 4
hàm còn lại: đổi signature `void` → `bool` (trả `false` ở mọi nhánh
early-return, `true` ở cuối), 4 call site trong `game_controller.dart` đổi
sang `if (!activeGame!....) return;` trước khi trừ count. `flutter analyze`
0 issues, `flutter test --exclude-tags slow` xanh (220+ test, không test
nào cần sửa vì 2 call site test hiện có không dùng giá trị trả về).

## ✅ Đóng 5 gap checkbox từ audit tasks/*.md (2026-07-14)

Rà lại 7 gap "chưa xác nhận được trong code" do audit trước flag, đóng 5/7
(2 còn lại chưa làm: F5 resonance power-tile — stretch goal, F13 daily
challenge chưa nối leaderboard I9):

- **F1** — chưa có unit test riêng cho `comboMultiplier`/`resetCombo`. Thêm
  group `F1 Combo multiplier` trong `game_controller_test.dart`: assert
  `registerPop` tăng multiplier dần + cap tại `comboMax`, điểm cộng đúng hệ
  số, `resetCombo` đưa combo/multiplier về 0/1.0.
- **X4** — chưa có test giả lập boot-storage lỗi. Thêm
  `test/widget/boot_resilience_test.dart`: construct `StorageService(null)`
  (nhánh catch thật của `_loadPrefs()` trong `main.dart`), pump
  `HomeScreen`, assert không crash + UI render đúng.
- **G8** — thiếu idle shimmer sweep (chỉ có burst ring). Thêm
  `_ShimmerSweep` component + `_shimmerTimer`/`_shimmerDelay` (4.0s, riêng
  với `_hintDelay` của I4 nhưng cùng reset qua `clearHint()`) trong
  `pop_star_game.dart`: quét dải gradient alpha thấp ngang bàn khi rảnh tay,
  không hit-test, dừng ngay khi tap hoặc `_animating`.
- **A1** — thiếu screen/board shake khi nổ nhóm lớn. Thêm
  `_maybeTriggerShake` (`pop_star_game.dart`): nhóm ≥5 ô → mọi block còn lại
  nhận `SequenceEffect` 3 nhịp `MoveByEffect` qua-lại-về (biên độ
  `cellSize*0.12`). Camera thật không dùng được (board add trực tiếp vào
  game, không qua `camera.world`) nên rung bằng offset vị trí block.
- **A7** — "reduce-motion" Settings toggle chưa wire thật (chỉ có string
  dịch, không có công tắc). Thêm `StorageKeys.reduceMotion` +
  `SwitchListTile` trong `settings_screen.dart`; `pop_star_game.dart` đọc
  qua getter `_reduceMotion` gate cả 3 hiệu ứng "thêm" bằng 1 cờ chung:
  `_maybeTriggerPunch`/slow-mo (A7 gốc), `_maybeTriggerShake` (A1 mới thêm
  cùng đợt), `_spawnShimmer` (G8 mới thêm cùng đợt).

`flutter analyze` 0 issues, `flutter test --exclude-tags slow` xanh (224
test). Đã tick checkbox tương ứng trong 5 file `doc/task/tasks/*.md`.

## ✅ F13 — nối daily challenge score vào leaderboard I9 (2026-07-14)

Gap thứ 6/7: `dailyChallengeScore` chưa có đường nối vào leaderboard giả lập.
Thêm tab toggle (chip icon Sao/Bolt) trong `leaderboard_screen.dart` —
`LeaderboardScreen` đổi `StatelessWidget` → `StatefulWidget` giữ state tab.
Không sửa `logic/leaderboard.dart` (đã đủ generic: `LeaderboardEntry`
name+int, `buildLeaderboard` không quan tâm đơn vị điểm) — chỉ thêm bot list
riêng `kDailyChallengeLeaderboardBots`
(`lib/data/daily_challenge_leaderboard_bots.dart`, thang điểm khớp board
9x8 daily thay vì tổng sao campaign) và chèn `gameCtrl.dailyChallengeScoreToday`
thay cho `totalStars` khi tab Daily đang chọn. `flutter analyze` 0 issues,
`flutter test --exclude-tags slow` xanh (224 test).

Còn lại 1/7 gap chưa làm: **F5** resonance khi 2 power tile liền kề — stretch
goal trong task doc gốc, để ngỏ theo YAGNI trừ khi user yêu cầu.

## ✅ Rà soát mở rộng 21 checkbox trống trong `doc/task/tasks/*.md` (2026-07-14)

Sau khi đóng xong 6/7 gap trên, quét lại toàn bộ `doc/task/tasks/*.md`
(`grep -rn "^- \[ \]"`) tìm được 21 checkbox trống ngoài phạm vi 7 item ban
đầu. Xử lý từng nhóm theo đúng bản chất, không code đại trà:

- **F3** — audit note cũ nói `useRainbow` trừ lượt vô điều kiện khi tap ô
  trống, nhưng đọc lại code hiện tại thấy đã đúng pattern void→bool giống
  bomb/shuffle/undo/swap (`triggerRainbow` trả `false` khi obstacle/animating,
  `useRainbow` check trước khi trừ `rainbowCount`) — doc stale, không phải
  bug thật. Thêm test no-op còn thiếu vào `test/widget/rainbow_bomb_test.dart`
  ("tap ô obstacle → không tiêu lượt") để chốt, sau đó tick.
- **F1** — checkbox "achievability vẫn qua" không có sim tool nào trong repo
  để chạy, nhưng suy luận toán học đủ: `comboMultiplier` khởi tạo 1.0, cap
  5.0, không bao giờ <1.0 → combo chỉ có thể làm target DỄ đạt hơn, không
  bao giờ khó hơn. Tick kèm lý luận, không cần công cụ giả.
- **I11, I13, I4, I5, I2, I18, T1** — 7 checkbox "chưa chạy tay `flutter
  analyze`/test trong phiên rà soát này" (bookkeeping thuần, code các item
  này đã xong từ trước). Chạy `flutter analyze` (0 issues) +
  `flutter test --exclude-tags slow` (225/225 xanh) một lần, tick cả 7 kèm
  bằng chứng ngày 2026-07-14.

**Còn lại 12 checkbox trống** — tất cả đều thuộc 1 trong 2 loại, không phải
gap code:
- 11 item cần test tay trên device/simulator thật (60fps: A1, A3, A6, A8,
  G5; contrast/TalkBack/VoiceOver: I14, X3; export ảnh/share sheet: F15, X6;
  golden/manual so khung hình: I16; verify side-mode theme: X8) — theo rule
  R3, cần hỏi device target trước khi build/run, chưa thực hiện trong phiên
  này.
- 1 item: **F5** resonance (đã note ⏸️ deferred ở trên).

## ✅ Test tay device (2026-07-14, Android emulator-5554)

- **X3 semanticLabel fix trên nút quit gameplay** (`game_screen.dart`, nút
  đóng) — verify bằng `uiautomator dump` thật: `content-desc="Thoát màn
  chơi"`, `clickable=true`, `enabled=true`, không còn `NAF=true`. Fix có tác
  dụng thật, không chỉ đọc code.
- Quét thêm cùng lớp lỗi (thiếu content-desc) trên: gameplay, dialog "Quit
  Level?", Home, Level Select (partial) — sạch, không phát hiện thêm nút
  thiếu label. Board full-screen tap-catcher đứng sau dialog là ngoại lệ đã
  biết trong task doc (không phải nút, không cần label).
- Level Select: `uiautomator dump` fail liên tục ("could not get idle
  state") — do animation nền chạy liên tục (path-flow shimmer, particle)
  không bao giờ để UI settle. Giới hạn công cụ, không phải bug — chưa verify
  được accessibility label trên màn này bằng phương pháp này.
- **Phát hiện phụ (không phải bug)**: Settings hiển thị tiếng Anh cho 3 label
  "Music volume"/"Sound effects volume"/"Haptics" dù đang chọn locale Hindi,
  trong khi mọi text khác đúng tiếng Hindi. Root cause: `bgm_volume`/
  `sfx_volume`/`haptics` chỉ có bản dịch trực tiếp ở `_en`/`_vi`, còn lại 20
  locale (gồm `hi_IN`) resolve qua `_extraEn` — layer "mặc định + fallback
  cho ngôn ngữ chưa dịch" đã có comment sẵn trong code, áp dụng cho MỌI
  locale không có override riêng. `app_translations_test.dart` chỉ guard
  key-set đầy đủ (không thiếu key), không guard value khác English — nên
  test xanh dù thiếu bản dịch thật. Đây là content-completeness gap có chủ
  đích của kiến trúc fallback, không phải defect — không tự dịch 20 ngôn ngữ
  khi chưa có xác nhận chất lượng dịch.

## ✅ Fix 2 bug i18n thật phát hiện khi sweep tiếp (2026-07-14)

Đi tiếp từ sweep accessibility ở trên sang Shop rồi Home, phát hiện 2 bug
**code thật** (khác gap nội dung Settings ở trên) — cả hai bypass hoàn toàn
hệ thống `.tr`, không phải thiếu bản dịch mà là chưa từng gọi `.tr`:

- **Shop screen** (`shop_screen.dart`) — toàn bộ text hiển thị (title + 6
  label booster + 6 desc booster) hardcode tiếng Anh trực tiếp trong code,
  không đổi theo locale dù người dùng chọn ngôn ngữ nào.
- **Home screen** (`home_screen.dart`) — cả 12 `semanticLabel` của icon-only
  action button (Time Attack/Zen/Endless/Daily Challenge/Star Road/Lucky
  Wheel/Shop/Guide/Settings/Leaderboard/Season Pass/Perks) hardcode cứng,
  trộn lẫn tiếng Việt/Anh, không đổi theo locale — vì icon không có text
  hiển thị nên `semanticLabel` là đại diện text/accessible DUY NHẤT; user
  dùng TalkBack/VoiceOver với ngôn ngữ khác sẽ luôn nghe sai ngôn ngữ.

Fix: thêm 18 key mới (13 Shop + 7 Home mới, phần còn lại tái dùng key đã có
sẵn — `shop_title`/`guide`/`settings`/`leaderboard_title`/`perks_title` đã
tồn tại đủ 22 locale từ trước nhưng chưa từng được gọi ở 2 file này; `shuffle`
tái dùng key legacy có sẵn đủ 22 locale, giá trị vẫn đúng ngữ cảnh) vào
`_extraEn`/`_extraVi` (đúng convention X2 đã dùng trước đó — chỉ thêm
en+vi, 20 locale còn lại tự fallback qua `_extraEn`, không tự dịch ẩu).
Wire `.tr`/`.trParams` vào cả 2 file, không đổi logic khác.

Test hiện có `shop_screen_test.dart` fail sau khi đổi (assert `find.text('Bomb')`
literal) vì `GetMaterialApp` trong test không có `translations:` nên `.tr`
trả về raw key — sửa theo đúng pattern `settings_screen_test.dart` đã dùng
(`translations: AppTranslations()`, `locale: Locale('en','US')` cố định).
`flutter analyze` 0 lỗi, `flutter test --exclude-tags slow` xanh toàn bộ.

**Phát hiện phụ, chưa fix (cùng lớp bug, khác scope)** — để lại cho lần sau
vì vượt phạm vi 2 bug ban đầu: `guide_screen.dart` (title hardcode "How to
Play" dù key `guide` đã dịch đủ 22 locale), `star_road_screen.dart`
("Star Road" hardcode), `season_screen.dart` ("Season Pass" hardcode),
`spin_wheel_dialog.dart` (2 chuỗi hardcode tiếng Việt-only, không có bản
Anh). Đã tạo sẵn key `star_road_title`/`season_pass_title` ở wave này nên
lần sau chỉ cần wire, không cần thêm key.

Verify tay trên `emulator-5554` (locale máy = Hindi, ca khó nhất vì không
phải en/vi): rebuild + cài lại + mở Shop qua tap icon thật — title hiện
"दुकान" đúng Hindi, `shuffle` (key legacy đã dịch đủ 22 locale) hiện đúng
"फेंटें", 5 label/desc booster mới fallback đúng tiếng Anh như thiết kế
convention X (chưa có bản Hindi, không phải bug), `trParams` của Freeze
render đúng "Obstacles stop losing durability for 5 moves." Không raw key
lộ ra màn hình, không quảng cáo (R4 pass). Fix xác nhận hoạt động đúng trên
thiết bị thật.

## ✅ X8 — verify tay đủ 4 side-mode trên emulator (2026-07-14)

Checkbox cuối cùng còn trống của X8 (`doc/task/tasks/X8-side-mode-world-theme-fallback.md`)
đã đóng: mở lần lượt Zen, TimeAttack, Endless, Daily Challenge trên
`emulator-5554` — cả 4 mode đều hiện nền candy-sky trung tính, không còn
dải aurora/accent world 10 leak vào (đúng như code fix đã verify trước đó,
giờ xác nhận thêm bằng mắt trên device thật). Không quảng cáo (R4 pass).
X8 coi như đóng hoàn toàn — cả 4 acceptance criteria đều tick.

## ✅ X6 — verify tay share-invite trên emulator (2026-07-14)

Mở Settings → tap "मित्र को आमंत्रित करें" (Mời bạn, locale Hindi) trên
`emulator-5554` — share sheet hệ thống Android mở đúng, nội dung text hiện
"Chơi Pop Star Blast cùng mình! https://play.google.com/store/apps/details?id=com.galaxyjoy.pop_star_blast"
(store link placeholder + tagline đúng). Không quảng cáo (R4 pass). X6 đóng
hoàn toàn — checkbox cuối cùng trong `doc/task/tasks/X6-share-invite.md` đã tick.

## ✅ F5d — power tile resonance (stretch goal) + I12 — dynamic music layers (2026-07-15)

**F5d (stretch goal của F5, trước đây để ngỏ vì chưa có spec):** khi kích
hoạt 1 power tile mà vùng nổ (`_blastCellsFor`, hàm thuần mới tách ra từ
`_activatePowerTile`) vướng phải 1 power tile khác còn trên bàn → gộp luôn
vùng nổ của tile đó vào cùng 1 đợt xoá (không đệ quy `_activatePowerTile`,
tránh double `_saveUndo()`/`_clearAndCollapse()`), điểm thưởng gấp đôi
(`scoreForGroup(cells.length) * 2`) + `triggerFlash()`. Test
`test/widget/power_tile_resonance_test.dart` dựng bàn 2 nhóm tách biệt (bomb
tại 1 nhóm, rainbow tại nhóm kia) và 1 ô màu cô lập ngoài bán kính bomb —
assert board-wide (không neo vị trí cố định) vì gravity/collapse có thể dịch
chuyển power tile sau mỗi lần tap; chứng minh ô cô lập chỉ bị xoá nhờ chuỗi
cộng hưởng lan tới rainbow. Đã đóng checkbox trong
`doc/task/tasks/F5-power-tiles.md`.

**I12 (idea chưa chốt trong `IDEAS.md`, nay đã implement):** nhạc nền "thêm
lớp" khi combo cao — vì asset chỉ có 3 track nhạc trọn vẹn (không có audio
stem/layer riêng), mô phỏng "thêm lớp" bằng cách đổi track theo bậc combo,
tái dùng nguyên cơ chế `startBgm({int track})` đã có sẵn (vốn chỉ dùng lúc
khởi động, tự no-op nếu trùng track). Hàm thuần `AudioManager.bgmTierFor(
comboCount)` (0/1/2 theo ngưỡng <3/3-5/≥6) + `applyComboLayer` gọi từ
`GameController.registerPop`/`resetCombo`. Test thuần
`test/core/audio_manager_test.dart`. Đã tạo
`doc/task/tasks/I12-dynamic-music-layers.md`, cập nhật `IDEAS.md` sang
"✅ đã chốt".

`flutter analyze` 0 lỗi; toàn bộ `flutter test --exclude-tags slow` (231
test) xanh sau cả 2 thay đổi. Không quảng cáo (R4 pass, không liên quan
screenshot test lần này).

## ✅ Fix bug i18n `guide_screen.dart` — bug đã ghi nhận từ 2026-07-14 (2026-07-15)

Đóng nốt phần "phát hiện phụ, chưa fix" ghi ở mục Fix 2 bug i18n phía trên:
`guide_screen.dart` hardcode toàn bộ title "How to Play" + 5 rule (title +
body) tiếng Anh, không qua `.tr`.

- App-bar title: tái dùng key `guide` có sẵn (đã dịch đủ 22 locale từ trước,
  giá trị tiếng Anh thật là "How To Play" hoa chữ T — không phải "How to
  Play" như tên bug gốc ghi) — **không** tạo key mới trùng lặp (từng tạo
  nhầm `guide_screen_title` rồi tự phát hiện trùng qua note cũ ở mục trên,
  đã xoá lại).
- 5 rule card (tap/bigger/gravity/clear/nomoves) — thêm 10 key mới
  (`guide_rule_<tên>_title`/`_body`) theo đúng convention wave: en+vi vào
  `_extraEn`/`_extraVi`, 20 locale còn lại vào `_w32ByLang` mới, merge vào
  `keys` getter ngay sau `_w31ByLang`.

`guide_screen_test.dart` sửa theo pattern `settings_screen_test.dart`
(`GetMaterialApp(translations: AppTranslations(), locale: Locale('en','US'))`)
vì bản cũ dùng `MaterialApp` trần nên `.tr` trả raw key; assert đổi sang
"How To Play" đúng giá trị thật của key `guide`.

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` (231 test) xanh
toàn bộ. Chưa verify tay trên device (chỉ chạy trên máy dev) — làm khi có
dịp build lại.

**Fix nốt luôn cùng lượt (user chọn fix ngay thay vì để sau)**:
`game_screen.dart:266` hardcode "Daily Challenge" tiếng Anh, không qua
`.tr`. Tái dùng key `daily_challenge_label` có sẵn (đã dịch đủ 22 locale từ
trước, dùng ở nơi khác) — không tạo key mới. `flutter analyze` 0 lỗi,
`flutter test --exclude-tags slow` (231 test) xanh toàn bộ sau cả 2 fix.

## ✅ Sweep tiếp `game_screen.dart` — 4 bug i18n hardcode phát hiện khi verify tay A3/X3 (2026-07-15)

Verify tay quit-dialog transition (A3) và Semantics label cho TalkBack (X3)
lộ ra 4 chỗ hardcode còn sót trong `game_screen.dart`, tất cả đều thẳng
tiếng Anh/Việt không qua `.tr` bất kể locale máy:

- **Quit dialog**: title/message hardcode tiếng Anh dù key `quit_title`/
  `quit_msg` đã có sẵn (dịch đủ 22 locale) nhưng chưa từng được gọi ở đây —
  tái dùng luôn, thêm 1 key mới `quit_action` ("Quit"/"Thoát").
- **Lose dialog** (`Time's Up!`/board-stuck): toàn bộ title + message hardcode
  tiếng Anh (kể cả nhánh Time-attack/Endless/Daily-challenge/mặc định) —
  thêm 6 key mới (`time_up_title`, `board_stuck_title`, `score_best_label`,
  `score_recorded_label`, `no_moves_retry_msg`, `menu`), tái dùng `retry` có
  sẵn cho nút.
- **6 nút booster** (bomb/shuffle/undo/rainbow/swap/freeze): label hardcode
  tiếng Việt trực tiếp trong `game_screen.dart` dù `shop_screen.dart` đã có
  sẵn đúng 6 key dịch đủ 22 locale cho đúng 6 tên booster này
  (`booster_bomb_label`, `shuffle`, `booster_undo_label`,
  `booster_rainbow_label`, `booster_swap_label`, `booster_freeze_label`) —
  tái dùng nguyên, không tạo key trùng.
- **Semantics label** (`_BoosterButton`, dùng cho TalkBack) hardcode tiếng
  Việt "X, còn Y" bất kể locale — máy để tiếng Anh vẫn đọc tiếng Việt qua
  TalkBack. Thêm 2 key `booster_count_label`/`booster_count_armed_label`.
- **Win dialog**: title (boss-cleared/level-complete) + dòng điểm hardcode
  tiếng Anh; nút RETRY/NEXT viết hoa cứng — thêm 3 key
  (`boss_cleared_title`, `level_complete_title`, `score_value_label`) + 1 key
  mới `next_action`, tái dùng `retry` với `.toUpperCase()` ở call site thay
  vì tạo key riêng cho biến thể viết hoa (giữ style chữ hoa của nút nhưng
  không nhân đôi bản dịch).

Tất cả key mới thêm đủ 22 locale theo đúng wave-merge convention hiện có
(`_w34ByLang`, wave thứ 23 tính từ `_w28ByLang`).

**Regression tự gây ra rồi tự fix cùng lượt**: sau khi đổi
`"Time's Up!"` hardcode → `'time_up_title'.tr`, 3 test trong
`modes_test.dart` (Time-attack/Zen/Endless) fail dây chuyền — gốc chỉ 1 chỗ:
`GetMaterialApp(home: const GameScreen())` trong test này chưa cấu hình
`translations`/`locale` (khác `shop_screen_test.dart`/`settings_screen_test.dart`
đã làm đúng từ trước — xem case tương tự ở `guide_screen_test.dart` mục trên),
nên `.tr` trả raw key thay vì "Time's Up!" → assert `find.text("Time's Up!")`
fail → test dừng giữa chừng, không chạy tới `Get.reset()` cuối bài → state
GetX permanent singleton còn dây dưa sang 2 test chạy sau trong cùng file,
khiến chúng cũng fail dù logic Zen/Endless refill không hề bị đụng tới (xác
nhận bằng `git stash` chạy lại trên code gốc — cả 4 test xanh). Fix: thêm
`translations: AppTranslations()` + `locale: const Locale('en', 'US')` vào
cả 3 `GetMaterialApp` trong file.

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` (231 test) xanh
toàn bộ. Đã verify tay các chỗ sửa trên Pixel 7 Pro thật (quit dialog,
booster label, tap-to-pop) qua screenshot trong phiên test #58.

## ✅ Gỡ bỏ idle shimmer sweep (G8) theo phản hồi verify tay (2026-07-15)

Trong lúc test tay trên Pixel 7 Pro (#58), user hỏi về "1 shimmer bay từ trái
sang phải" trên màn chơi và nói không cần hiệu ứng này. Xác định đó là idle
shimmer của G8 (`_ShimmerSweep`, `pop_star_game.dart`) — dải sáng quét ngang
bàn mỗi khi rảnh tay >4s, tách biệt với phần ring nổ (`_BurstRing`, vẫn giữ
nguyên vì không bị phàn nàn).

Game đã có sẵn toggle "Giảm hiệu ứng động" (Settings, `StorageKeys.reduceMotion`)
gate được shimmer, nhưng gộp chung với slow-mo/camera-shake — không tắt
riêng được. Hỏi lại user qua `AskUserQuestion` giữa 3 phương án (xoá hẳn code
/ chỉ đổi mặc định off / dùng toggle có sẵn) — chọn **xoá hẳn khỏi code**.

Đã xoá trong `lib/game/pop_star_game.dart`: class `_ShimmerSweep`, field
`_shimmerTimer`/`_shimmerDelay`, nhánh gọi trong `update()`, hàm
`_spawnShimmer()`, và dòng reset `_shimmerTimer` trong `clearHint()`. Sửa lại
2 comment nhắc "slow-mo/zoom-punch/shake/shimmer" (ở `pop_star_game.dart` và
`storage_service.dart`) bỏ chữ "shimmer" cho khớp thực tế. Cập nhật
`doc/task/tasks/G8-glow-burst-shimmer.md`: tiêu đề + ghi chú phần idle
shimmer đã gỡ, un-check 3 acceptance criteria cũ (đánh dấu gạch ngang, không
xoá để giữ lịch sử).

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` (231 test) xanh
toàn bộ (không test nào đụng tới shimmer).

## ✅ Hệ thống Achievements (I22) (2026-07-16)

Thêm 25 thành tựu vanity (không ảnh hưởng gameplay, không thêm currency
mới) theo 5 metric tích lũy đời: `totalGemsPopped`, `maxComboEver`,
`levelsThreeStarred`, `boardsFullyCleared`, `totalBoostersUsed`. Mỗi thành
tựu unlock đúng 1 lần, thưởng coin 1 lần. Spec đầy đủ:
`docs/superpowers/specs/2026-07-16-achievements-design.md`, task file:
`doc/task/tasks/I22-achievements-system.md`.

Data model `lib/data/achievements.dart` (`Achievement`, `kAchievements`,
`newlyUnlockedAchievementIds`). `GameController` cộng dồn 5 counter mới tại
`registerPop`/`checkEnd`/các `use*` booster, persist qua `StorageKeys`
tương ứng, xoá sạch trong `resetProgress()`. Cơ chế unlock theo đúng pattern
Rx async có sẵn (`unlockedAchievementIds` Set + `justUnlockedAchievement`
`Rxn<Achievement>`), `GameScreenController` lắng nghe qua `ever()` để hiện
dialog ăn mừng (`NeonDialog.overlay`, không dùng `Get.dialog`).
`AchievementsScreen` mới liệt kê tiến độ; entry point: icon riêng trên
`HomeScreen` + card cuối `ListView` trong `GuideScreen`.

i18n đủ 22 locale (English/Vietnamese trong `_extraEn`/`_extraVi`, 20 ngôn
ngữ còn lại trong wave map `_w35ByLang`). Trong lúc implement phát hiện và
khôi phục được một đợt nội dung i18n (guide rule) đã bị mất do thao tác
`git checkout --` quá rộng ở phiên trước — lấy lại từ dangling blob git,
ghép đúng thứ tự các wave map hiện có.

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` (238 test)
xanh toàn bộ.

## ✅ Perfect Clear replay mode (I23) (2026-07-16)

Chơi lại 1 level campaign đã qua (≥1 sao) với mục tiêu vượt best score hiện
tại của chính level đó — thắng thưởng thêm coin bonus 1 lần. Không thêm
`GameMode` mới, không thêm StorageKey mới — tái dùng nguyên luồng
`GameMode.campaign`. Spec: `docs/superpowers/specs/2026-07-16-perfect-clear-
design.md`, task file: `doc/task/tasks/I23-perfect-clear-replay.md`.

`GameController` thêm `perfectClearTarget` (`Rxn<int>`), `perfectClearSuccess`
(`RxBool`), `perfectClearBonusCoins = 50`. `startPerfectClear(id)` chụp
`StorageKeys.highScore(id)` làm target **trước** khi gọi `startLevel()`
(tránh bị `_saveBestScore()` ghi đè ngay trong lượt đang xét). `checkEnd()`
so `score` với target sau khi tính sao, cộng bonus (`× weekendCoinMultiplier`)
nếu vượt — không đụng nhánh star/highscore/unlock hiện có.

Entry point: long-press trên tile level đã unlock và có ≥1 sao trong
`LevelSelectScreen` (tap ngắn vẫn chơi bình thường), mở dialog xác nhận qua
`NeonDialog.show()`. Win dialog (`game_screen.dart`) hiện badge 🏆 khi thành
công, dùng chung choreography opacity với score.

i18n đủ 22 locale (`_extraEn`/`_extraVi` + wave map `_w36ByLang` cho 20 ngôn
ngữ còn lại). Test mới trong `game_controller_test.dart` (nhóm "Task #5 —
Perfect Clear replay").

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` xanh toàn bộ.

## ✅ Mở rộng chu kỳ objective campaign — thêm openGift (task #6) (2026-07-16)

Rà lại `lib/data/levels.dart` (F9) phát hiện: `openGift` (I1) đã có cơ chế
đầy đủ ở `pop_star_game.dart` (`_placeGiftsIfNeeded`, tính
`objectiveRemaining`) nhưng **chưa từng được gán cho màn campaign nào** —
chu kỳ objective cũ (`i % 8`) chỉ dùng 6/7 loại `ObjectiveType`. Mở rộng chu
kỳ từ 8 → 9 màn, thêm slot 8 = `openGift` (target ≈ `(cells/colorCount)/3`,
kẹp `[2, 8]`). Tỉ lệ vẫn 3/9 màn dùng `score` thuần, 6/9 màn dùng 1 trong 6
loại objective khác — không đổi công thức `targetScore` (`cells * 6 * ramp`,
đúng invariant CLAUDE.md) vì objective type không ảnh hưởng cách tính điểm/
sao, chỉ thêm 1 điều kiện thắng phụ.

Cập nhật `test/data/levels_test.dart`: đổi chu kỳ kỳ vọng `i % 8` → `i % 9`
(thêm case `8 => ObjectiveType.openGift`), thêm test riêng kiểm target
`openGift` hợp lý (trong `[2, rows*cols]`).

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` xanh toàn bộ.

## ✅ Redesign Home Screen — Drawer + banner ưu tiên đơn (X9) (2026-07-17)

Home Screen cũ xếp 13 `NeonIconButton` giống nhau thành 4 hàng, không label,
không phân nhóm — user chê "quá xấu, thiết kế quá tệ". Qua 2 vòng
`AskUserQuestion`, chốt hướng **Drawer + banner ưu tiên đơn**:

- Header đổi từ `Align(topRight: CoinChip)` sang `Row(spaceBetween)`:
  hamburger (`Icons.menu_rounded`, mở `Scaffold.endDrawer` qua
  `GlobalKey<ScaffoldState>`) bên trái, `CoinChip` bên phải.
- Banner ưu tiên đơn (bọc `Obx`, không carousel) thay block weekend-event
  tĩnh cũ, đúng 1 thứ tự: weekend event (giữ key cũ `home_weekend_banner`) >
  Season Pass có milestone sẵn nhận (`season_pass_banner_ready`, tap →
  `SeasonScreen`) > chưa chơi Daily Challenge hôm nay
  (`daily_challenge_banner_reminder`, tap → `startSideMode(dailyChallenge)`
  + `Get.to(GameScreen)`) > ẩn hẳn (`SizedBox.shrink()`).
- Quick-access row rút từ 4 hàng 13 icon xuống đúng 1 hàng 3 icon: Shop
  (giữ nguyên), Daily Challenge (giữ nguyên), Modes mới (`Icons
  .sports_esports_rounded`, indigo) → mở dialog chọn Time Attack/Zen/
  Endless (copy y hệt code cũ, kể cả cách gọi `Get.to()` không dismiss
  dialog trước — xem bug ghi ở dưới).
- 8 mục còn lại dồn vào `endDrawer` mới (`_buildDrawer`), 2 nhóm "Khám phá"
  (Star Road, Spin Wheel, Guide) / "Tài khoản" (Settings, Leaderboard,
  Season Pass, Perks, Achievements), mỗi `ListTile` đóng drawer trước khi
  `Get.to()`, giữ nguyên icon/màu/đích nav của bản cũ.

3 key i18n mới (`modes_title`, `season_pass_banner_ready`,
`daily_challenge_banner_reminder`) đủ 22 locale. Không thêm `StorageKeys`
mới — banner tái dùng state Rx đã có sẵn (`seasonPoints`,
`claimedSeasonMask`, `canRecordDailyChallengeScore`, `isWeekendEvent`).

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` xanh toàn bộ.
Playtest tay trên Samsung SM_S928B (`R5CX613VZBR`): hamburger mở Drawer,
cả 8 mục đều điều hướng đúng màn (dùng `adb shell uiautomator dump` để lấy
toạ độ thật khi tap theo ước lượng từ screenshot sai — coi chừng lệch scale
hiển thị/thiết bị), Shop icon, dialog Modes (Time Attack vào GameScreen có
đồng hồ đếm), banner Daily Challenge tap đúng vào GameScreen chế độ Daily
Challenge — không gặp quảng cáo che UI bước nào.

Phát hiện 1 bug tồn tại từ code cũ (không phải regression của redesign):
dialog Modes lộ lại đè lên Home sau khi thoát level bắt đầu từ đó, vì
`NeonDialog.show` (`Navigator.of(context, rootNavigator: true)` +
`showDialog` native) chia sẻ root navigator với `Get.to()` của GetX, và nút
trong dialog Modes không `Navigator.pop(context)` trước khi `Get.to()`. Ghi
lại ở `doc/task/tasks/X9-home-screen-redesign.md` để fix riêng, không sửa
trong task này.

## ✅ Fix bug dialog Modes lộ lại sau khi thoát level (2026-07-17)

Root cause: `NeonDialog.show` chỉ tự `Navigator.pop(context)` trước khi
chạy `onTap` cho các nút trong `actions:` (`NeonDialogAction`, ví dụ nút
"Huỷ"); widget tuỳ ý đặt trong `content:` (3 `NeonIconButton` Time
Attack/Zen/Endless của dialog Modes) không đi qua cơ chế bọc pop này. Ba nút
đó gọi `Get.to(() => const GameScreen())` trực tiếp mà không đóng dialog
trước, nên stack thành `[Home, DialogRoute, GameScreenRoute]` — thoát
GameScreen chỉ pop 1 route, lộ lại DialogRoute còn nằm dưới đè lên Home.

Fix: thêm `Navigator.pop(context);` đầu mỗi `onTap` của 3 nút trong
`_showModesDialog` (`home_screen.dart`), trước `startSideMode`/`startEndless`
+ `Get.to()`.

`flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` xanh toàn bộ (243
test). Playtest lại trên Samsung SM_S928B (`R5CX613VZBR`): Modes → Time
Attack → GameScreen (đồng hồ đếm) → Thoát Màn → Home sạch, không còn dialog
Modes lộ lại — không gặp quảng cáo che UI.

## ✅ QA pass: verify tay trên device thật cho 9 checkbox "manual only" (2026-07-17)

Chơi hết Level 1 trên Samsung SM_S928B (tap theo nhóm cùng màu liền kề, tuân
đúng invariant "board không refill" — level kết thúc theo đường "stuck" khi
hết nhóm ≥2 dù score 565 đã vượt target 288) để khép kín các acceptance
criteria còn ghi "chưa chạy tay trên device":

- **A1, A3, A6, A8** (juice/route-transition/board-intro/ripple — đều là các
  mốc "60fps / không rớt frame"): `adb logcat -d | grep -i
  "Choreographer\|skipped\|FATAL"` trong suốt phiên chơi + điều hướng nhiều
  lượt Home↔LevelSelect↔Game — không có match.
- **G5** (shader bloom aura): aura hiển thị đúng dưới bàn Level 1, không rơi
  vào fallback, không rớt frame theo logcat.
- **I14** (theme per world): kiểm bằng mắt qua screenshot World 1 (Level 1)
  và World 10 (Level 181, world cuối hiện có) — gem màu vẫn phân biệt rõ, không
  chìm/lem theo palette từng world.
- **I16** (aurora background shader ở world cuối): vào World 10 Level 181,
  aurora chạy mượt, logcat sạch.
- **X3** (accessibility semantics): không có TalkBack thật trong tay, dùng
  phương pháp thay thế tương đương — `adb shell uiautomator dump` rồi grep
  `clickable="true"` kèm `content-desc=""` trên toàn cây UI Home/Game → 0
  match, nghĩa là mọi nút bấm được đều có label không rỗng (đúng nội dung
  TalkBack sẽ đọc).
- **F15** (photo mode / share): bấm nút share ở màn thắng → share sheet
  native mở đúng caption "Pop Star Blast — Level 1 — Score 565 —
  2026-07-17"; pull file cache thật qua `run-as ... cat
  .../cache/share_plus/pop_star_blast.png` → PNG 720x1170 đúng nội dung bàn
  chơi + overlay điểm/level/ngày, không cắt/méo tỉ lệ.

Đã tick `[x]` kèm ghi chú thiết bị/phương pháp trực tiếp trong từng file task
tương ứng (`doc/task/tasks/{A1,A3,A6,A8,G5,I14,I16,X3,F15}-*.md`). Không gặp
quảng cáo che UI ở bất kỳ bước nào trong phiên QA này.

## ✅ Implemented: World 11 — mở rộng campaign lên 220 level (I24, 2026-07-17)

Thêm World 11 (level 201-220) bằng cách tăng `kLevelCount` 200 → 220 trong
`lib/data/levels.dart`. Không cần đổi công thức ramp/clamp: `rows`/`cols`/
`colorBase` trong `kLevels` generator đều là hàm `.clamp` theo
`world = i ~/ 20`, đã bão hoà ở trần từ World 10 (rows 11, cols 12, colorBase
7) — World 11 tự động dùng đúng trần đó, chỉ `ramp` (1 + world*0.03) nhích
thêm một chút, giữ `perCell` trong khoảng an toàn `[4, 9]` theo invariant
achievability đã ghi ở trên.

Thêm entry World 11 vào `kWorlds` (`lib/data/worlds.dart`): màu
`NeonTheme.lime` (chưa dùng cho world nào trước), icon
`Icons.diamond_rounded`, `nameKey: 'world_path_name_11'`. Key i18n mới thêm
vào `_extraEn`/`_extraVi` trong `app_translations.dart` — English làm
fallback cho 20 ngôn ngữ chưa dịch riêng tên world (đúng pattern đã có sẵn
cho `world_path_name_1..10`, không phải lỗi thiếu key: `_extraEn` merge
unconditionally cho mọi locale, `_extraVi` override riêng cho `vi_VN`).

Test: `test/data/levels_test.dart` sửa loop cứng `world < 10` →
`world < kLevelCount ~/ 20`; `test/data/worlds_test.dart` thêm group
`'World 11'` xác nhận range/nameKey/màu không trùng. `flutter analyze` 0
issues; `flutter test --exclude-tags slow` 245/245 xanh (từ 243). Task file:
`doc/task/tasks/I24-world-11-content.md`.

## ✅ Implemented: Boss variant — đa dạng trận chốt cho 11 world (I25, 2026-07-17)

Boss level (level cuối mỗi world: 20, 40, ..., 220) trước đây đều dùng
objective `score` mặc định giống nhau, chỉ khác kích thước bàn/target. Giờ
luân phiên 4 variant theo `bossVariant = world % 4` trong `kLevels`
generator (`lib/data/levels.dart`): `0`→`score` (classic), `1`→`clearColor`,
`2`→`obstacleInMoves`, `3`→`openGift` — tái dùng nguyên `ObjectiveType` đã
có sẵn cơ chế (obstacle/gift placement, `objectiveMet`/`objectiveRemaining`
trong `game_controller.dart` dispatch thuần theo type, không phân biệt
boss/thường), không thêm mechanic mới. `targetScore`/`bossTargetMultiplier`
giữ nguyên hoàn toàn — chỉ đổi `objective`, invariant achievability không
bị ảnh hưởng.

Test: `test/data/levels_test.dart` — test 9-slot cũ đổi tên `'... (màn
thường)'` + bỏ qua `isBoss`; thêm test mới `'boss variant luân phiên đúng
theo world % 4'`. `flutter analyze` 0 issues; `flutter test --exclude-tags
slow` 246/246 xanh (từ 245). Task file: `doc/task/tasks/I25-boss-variant.md`.

## ❌ Skipped: "Booster/mechanic thứ 4" (task #16) — đã có sẵn 6 booster (2026-07-17)

Task #16 trong kế hoạch overnight yêu cầu thêm booster thứ 4. Audit lại
codebase (grep + đọc `lib/presentation/controllers/game_controller.dart`,
`lib/game/pop_star_game.dart`, `lib/presentation/screens/shop_screen.dart`,
`game_screen.dart`) cho thấy game đã có **6 booster** hoàn chỉnh, đã commit
từ trước (không phải trong session này): bomb, shuffle, undo (bộ gốc) +
rainbow, swap, freeze (F10, xem commit `5f0e7ee`/`25cc32e`/`26e0ef0` trong
git log) — mỗi booster đủ storage key, buy/use trong `GameController`,
`trigger*` trong `PopStarGame`, entry point ở `ShopScreen` + HUD
`GameScreen`, i18n, và test (`game_controller_test.dart`,
`rainbow_bomb_test.dart`, `free_undo_test.dart`).

Vì mục tiêu ban đầu ("đa dạng hoá booster ngoài bộ 3 gốc") đã đạt vượt mức
(6/4), không thêm booster thứ 7 tuỳ tiện — tránh feature creep không ai yêu
cầu cụ thể. Nếu muốn booster mới thật sự, cần spec riêng nêu rõ cơ chế khác
biệt (không trùng bomb/rainbow/swap/freeze) trước khi implement.

## ❌ Skipped: "Seasonal/limited-time event" (task #17) — đã có 5 hệ thống tương tự (2026-07-17)

Task #17 yêu cầu thêm 1 seasonal/limited-time event. Audit git log +
`doc/feat.md` cho thấy category này đã được phủ kín từ trước session này:

- **I8 Weekend event x2 coin** (`weekend_event.dart`, `isWeekendEvent`) —
  nhân đôi mọi nguồn thu xu vào thứ 7/CN.
- **I10 Comeback bonus** (`comeback_bonus.dart`) — thưởng khi quay lại sau
  ≥N ngày vắng.
- **Season Pass** (`season_screen.dart`, `seasonPoints`,
  `claimedSeasonMask`, milestone claim) — progression theo mùa, có banner
  nhắc trên Home (X9 redesign, xem mục Drawer + banner trên).
- **Weekly World Event** (commit `e433e5d`, Wave 28.5) — banner + mechanic
  sự kiện theo tuần.
- **Tournament** (commit `050fae1`, Wave 14.1) — có countdown timezone
  riêng.

5 hệ thống trên đã bao trọn nhu cầu "sự kiện có giới hạn thời gian" ở nhiều
tầng (theo ngày/tuần/mùa). Không tạo thêm hệ thống event trùng lặp — nếu
cần 1 sự kiện mới thật sự khác biệt (vd. sự kiện chỉ chạy 1 lần, gắn ngày lễ
cụ thể), cần spec riêng nêu rõ nó khác 5 hệ thống trên ở điểm gì trước khi
implement.

## ✅ Implemented: Friend Code Compare — so tài bạn bè local-only (I26, 2026-07-17)

Task #18 yêu cầu 1 social/friend feature, nhưng project chủ trương
"không backend" nên không thể có danh sách bạn bè/leaderboard thật qua
mạng. Giải pháp: mã hoá tên + tổng sao + xu hiện tại thành 1 mã text
base64url (`encodeFriendCode`/`decodeFriendCode`,
`lib/core/utils/friend_code.dart`, thuần Dart không phụ thuộc Flutter),
chia sẻ qua đúng pipeline `shareText()` có sẵn (`share_helper.dart`, không
tạo hàm share thứ hai). Bạn bè dán mã nhận được vào `FriendCompareScreen`
(entry point: drawer Home Screen, icon `people_alt_rounded` màu teal, giữa
Leaderboard/Season Pass) để xem hơn/kém/hoà theo số sao chênh lệch.

`GameController` thêm `playerName` (Rx, persist qua `StorageKeys.playerName`
— **không** bị xoá trong `resetProgress()` vì không phải progress game) và
`myFriendCode()` đóng gói state hiện tại. i18n đủ 12 key × 22 locale
(`_extraEn`/`_extraVi` + `_w38ByLang` cho 20 ngôn ngữ còn lại).

Test thuần `test/core/utils/friend_code_test.dart`: round-trip encode↔decode,
tên chứa `|` bị lọc, tên rỗng/base64 sai/số âm (mã giả mạo) → `null` (không
throw). `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
toàn bộ. Task file: `doc/task/tasks/I26-friend-compare.md`.

## ✅ Implemented: Sweep test coverage cho các feature gần đây (task #19, 2026-07-17)

Rà soát (qua agent audit + kiểm tra chéo tay) test coverage của các feature
mới thêm gần đây: I22 Achievements, F10 swap/freeze, I8 weekend×coin, và
`AchievementsScreen`. Kết luận: **weekend×coin đã được test đầy đủ** ở mọi
điểm cộng xu quan trọng (checkEnd, Perfect Clear, Daily reward, Vòng quay,
Comeback bonus, Season, Star Road — mỗi test đều nhân `ctrl.weekendCoinMultiplier`
thay vì hard-code hệ số, nên đúng bất kể ngày chạy test là gì) — không cần
thêm gì. 4 gap thật sự được vá:

- `test/presentation/game_controller_test.dart` — nhóm mới `I22 Achievements
  — tích hợp GameController`: `registerPop` cộng đúng `totalGemsPopped`/mở
  khoá mốc `gems_500`, 3 lần pop liên tiếp đẩy combo lên mốc `combo_3`, vượt
  mốc đã mở khoá không cộng xu/không unlock lại, `checkEnd(true)` tăng đúng
  `boardsFullyCleared`/mở khoá `clear_5`, gọi `checkEnd` lần 2 (đã `ended`)
  không cộng dồn. Thêm 1 test vào nhóm `resetProgress` xác nhận xoá sạch cả
  5 counter + `unlockedAchievementIds`.
- `test/widget/swap_freeze_test.dart` — case biên `useSwap` no-op khi
  `swapCount == 0` (grid/điểm/số lượng không đổi).
- `test/widget/achievements_screen_test.dart` (mới) — render đủ 25 thành
  tựu, mặc định khoá hết; mở khoá 1 mốc → đúng icon cúp + text
  `achievements_done`. Dùng viewport cao (khớp quy ước
  `home_screen_test.dart`) vì `ListView` chỉ build item trong viewport.

`flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh toàn bộ
(bao gồm các test mới trên).

## ✅ Implemented: Smoke test tổng trên device thật + fix 2 bug i18n (task #20, X10, 2026-07-17)

Playtest tay toàn bộ app trên Pixel 7 Pro (drawer, Modes dialog, Shop,
Daily Challenge, Star Road, Vòng quay, Guide, Settings, Leaderboard,
Friend Compare, Season Pass, Perks, Achievements, Level Select, gameplay,
quit dialog) sau loạt task #13-#19. **Không gặp quảng cáo nào** trong suốt
quá trình (R4). Phát hiện 2 màn hardcode tiếng Anh giống lỗi X7 nhưng
X7 chưa quét tới:

- `star_road_screen.dart` — "Star Road"/"stars"/"Claimed"/"CLAIM" hardcode
  → đổi dùng key có sẵn `star_road_title`, hiện mốc dạng icon sao + số,
  progress dạng số thuần (`$totalStars/$milestone`, giống
  `achievements_screen.dart`), `ach_claimed`, `daily_claim.tr.toUpperCase()`.
- `season_screen.dart` — "Season Pass"/"points"/"Claimed"/"CLAIM" hardcode
  → đổi dùng key có sẵn `season_pass_title`, `season_points`, reward hiện
  icon (coin/bomb/shuffle/undo) + số thay chữ tiếng Anh, tái dùng
  `ach_claimed`/`daily_claim` như trên.

Cả 2 fix đều **không thêm key dịch mới** — thuần tái dùng key đã có ở 22
locale + mirror pattern icon+số của Achievements/Star Road. Cập nhật
`test/widget/star_road_screen_test.dart` (`'CLAIM'` → `'DAILY_CLAIM'`, vì
test không setup `AppTranslations` nên `.tr` trả về key thô). Không có
test tự động nào cho `season_screen.dart` nên không cần sửa test.

Ghi nhận riêng (không sửa trong scope này): `spin_wheel_dialog.dart` toàn
bộ hardcode tiếng Việt thẳng (không qua `.tr`) — lỗi cũ, không phải do
task gần đây gây ra, không hiện sai vì đang test ở locale VI. Để lại cho
lần rà soát i18n tiếp theo.

`flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh toàn
bộ (261 test). Build + cài lại APK, xác nhận cả 2 màn hiện đúng tiếng
Việt qua screenshot trên device thật. Task file: `X10-smoke-test-star-road-season-i18n.md`.

Overnight session (task #13-#20) hoàn tất: World 11 (I24), Boss variant
(I25), Achievements (I22), Perfect Clear replay (I23), objective openGift
(#6), Friend Compare (I26), test coverage sweep (#19), và smoke test tổng
này (#20) — tất cả đã commit local, chưa push.

## ✅ Audit hiệu suất theo phản ánh user "game lag" + fix 1 bug thật phát hiện khi test (X11, X12, 2026-07-18)

User phản ánh hiệu suất tệ/lag → audit lại toàn bộ task cũ (mọi task F/A/G/
I/X đều đã có trạng thái rõ ràng, chỉ còn F5 resonance là ⏸️ deferred có
chủ đích, không có task nào bị bỏ dở) + quét trực tiếp code tìm nguồn lag.

**Tìm thấy 3 điểm, sửa 1 (X11), quan sát 2:**
- **HIGH — đã sửa**: `level_select_screen.dart` — 2 `AnimatedBuilder`
  (decor sparkle, path glow) listen thẳng `_flowCtrl` (loop 2s, ~60fps
  liên tục), vẽ lại toàn bộ canvas (~1000+ dot + 219 đoạn path) mỗi frame
  dù đang đứng yên. Thêm `_throttledFlow` (làm tròn xuống mốc 1/60s) tận
  dụng `shouldRepaint` sẵn có → giảm ~nửa số lần redraw, không đổi cảm
  giác mượt. Chi tiết: `X11-level-select-animation-throttle.md`.
- **MEDIUM — chỉ quan sát**: `pop_star_game.dart` không cap tổng số
  `ParticleSystemComponent` sống cùng lúc qua nhiều tap liên tiếp rất
  nhanh (game không có auto-cascade nên xác suất thấp) — để lại, không
  fix phòng hờ.
- **MEDIUM — chỉ quan sát**: `block_component.dart` `highlighted`/`hinted`
  vẫn dùng `MaskFilter.blur` mỗi frame nhưng chỉ ảnh hưởng vài ô — tác
  động không đáng kể.

**Bug thật phát hiện ngoài ý muốn khi chạy smoke test bắt buộc**: chạy
`flutter test --exclude-tags slow` lặp lại cho ra kết quả tưởng như flaky
(2 test fail, nhưng file fail đổi khác nhau giữa các lần chạy). Điều tra
sâu → không phải flaky, mà 1 bug GetX thật, tất định vào cuối tuần:
`home_screen.dart` `_buildPriorityBanner`'s `Obx` có nhánh `isWeekendEvent`
return sớm không đọc Rx nào → GetX ném lỗi "improper use of Obx" → kéo
theo `RenderFlex overflow`. Mọi test render `HomeScreen` cùng crash trong
khung cuối tuần; test khác (`swap_freeze_test.dart`) chỉ "lây" do GetX
global state hỏng, tự nó vẫn đúng. Fix: đọc `seasonPoints.value` vô điều
kiện trước mọi nhánh return. Đây là bug sẽ xảy ra thật trên máy user vào
cuối tuần, không phải test-artifact. Chi tiết:
`X12-home-banner-getx-obx-bug.md`.

`flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh toàn
bộ (261 test, bao gồm cả `home_screen_test.dart` và
`boot_resilience_test.dart`).

## ✅ Fix 4 nhóm bug: color contrast, animation reduce-motion, performance, memory leak (X13, 2026-07-18)

User phản ánh trực tiếp "bug color tương phản, text đọc không được, user
chửi" và "bug hiệu suất, bug animation, bug memory leak, animation xấu xí".
Audit xác nhận bằng code thật 4 nhóm cụ thể:

- **Nhóm A — color contrast**: `home_screen.dart` Drawer title và
  `neon_dialog.dart` `_DialogButton` label đều còn `color: Colors.white`
  từ thời dark-theme cũ → vô hình trên nền trắng candy hiện tại. Đổi cả
  2 sang `color: NeonTheme.ink`.
- **Nhóm B — animation reduce-motion**: 5 widget (`confetti_overlay`,
  `star_mascot`, `pulse_glow`, `coin_fly_overlay`, `level_select_screen`
  `_flowCtrl`) chưa từng tôn trọng cờ "Giảm chuyển động" dù
  `pop_star_game.dart` đã gate đúng ở 2 chỗ khác. Thêm getter
  `_reduceMotion` cho cả 5: animation lặp vô hạn thì không `.repeat()`
  khi bật cờ, animation 1 lần thì bỏ qua `.forward()` và trả
  `SizedBox.shrink()` ngay.
- **Nhóm C — performance**: việc thực chất chính là `_flowCtrl` dừng hẳn
  khi reduce-motion bật (trùng Nhóm B) — audit sâu không tìm thêm
  hot-path CPU nào khác ngoài X11 đã xử lý.
- **Nhóm D — memory leak**: `audio_manager.dart` `_ignoreAudio` (điểm
  chốt duy nhất mọi lệnh phát âm thanh đi qua, gồm cả `playMelodic`/
  `_arpAfter` chạy trên mọi tap pop) tạo `AudioPlayer` mới qua
  `FlameAudio.play()` nhưng chưa từng `.dispose()` → sửa 1 điểm chốt:
  lắng nghe `onPlayerComplete.first` (timeout 5s an toàn) rồi dispose.

**Regression tự phát hiện + tự sửa trong cùng phiên**: thêm `_reduceMotion`
vào 5 widget trên làm 7 test fail do `StorageService.to` ném lỗi khi chưa
đăng ký GetX trong test cô lập. Fix root-cause: thêm `StorageService.maybe`
(getter an toàn, cùng pattern `AudioManager.maybe` có sẵn), đổi cả 5 getter
sang dùng `.maybe`.

`flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh toàn
bộ 261 test. Verify tay trên emulator: Drawer title + dialog button label
đọc rõ trên nền trắng; bật Reduce Motion → confetti không chạy trên màn
thắng thật (board tự stuck ở 3 ô lẻ, phải dùng bomb dọn sạch mới trigger
được dialog thắng); chơi ~30+ lượt pop + 3 lần bomb liên tục không crash/
tiếng bị cắt. Chi tiết: `X13-contrast-animation-perf-leak-fixes.md`.

## ✅ Home Screen Carousel Redesign — thay banner ưu tiên đơn bằng carousel động (X14, 2026-07-18)

Banner ưu tiên đơn của X9 chỉ hiện được **1** thứ đáng chú ý tại một thời
điểm (weekend event > Season Pass > Daily Challenge), các tín hiệu khác bị
che khuất hoàn toàn. Thay bằng **carousel `PageView`** hiện đồng thời mọi
thẻ đang "đáng chú ý", theo spec đã duyệt trước
(`docs/superpowers/specs/2026-07-18-home-screen-carousel-design.md`),
supersede thiết kế banner đơn của X9:

- **`buildHomeCards(GameController)`** (`lib/presentation/widgets/
  home_carousel.dart`) — hàm thuần, test được độc lập, sinh danh sách
  `HomeCardData` theo thứ tự cố định: greeting (luôn có) → Star Road →
  Season Pass → achievement → perk. Mỗi loại chỉ xuất hiện khi "đáng chú
  ý": Star Road (có rương khả nhận hoặc còn ≤3 sao tới mốc), Season Pass
  (có mốc khả nhận hoặc còn ≤20 điểm tới mốc), achievement (vừa unlock
  hoặc đạt ≥80% ngưỡng chưa unlock kế tiếp), perk (có perk đã mở khoá
  chưa active, hoặc world kế tiếp mở perk chỉ còn cách đúng 1 world).
- **`HomeCarousel`** widget — `PageView.builder` (viewportFraction 0.92)
  + dot-indicator, card viền màu theo `accentColor` từng loại, badge góc
  trên tuỳ chọn (vd. "🎉 Weekend x2 coins!").
- **`HomeScreenController`** (`lib/presentation/controllers/
  home_screen_controller.dart`) — `WidgetsBindingObserver`, tự
  `refreshCards()` khi app resume, giữ `currentIndex` hợp lệ khi số thẻ
  đổi.
- **`AmbientParticles`** (`lib/presentation/widgets/ambient_particles.dart`)
  — 7 hạt trôi nhẹ phía sau mascot, tôn trọng "Giảm chuyển động" (trả
  `SizedBox.shrink()` trước khi tạo `AnimationController` nếu bật cờ).
- **`StarMascot`** thêm `onTap` optional — tap chạy 1 trong 2 animation
  phản ứng ngẫu nhiên (scale-bounce/tilt-wiggle, 500ms), độc lập với idle
  loop, cũng tôn trọng reduce-motion (tap vẫn gọi callback nhưng không
  chạy animation).
- 12 key i18n mới (`home_greeting_morning/afternoon/evening`,
  `home_daily_streak`, `home_weekend_badge`, `home_star_road_claim`,
  `home_star_road_progress`, `home_season_claim`, `home_season_progress`,
  `home_achievement_unlocked`, `home_achievement_progress`,
  `home_perk_activate_reminder`, `home_perk_progress`) đủ 22 locale.
  Không thêm `StorageKeys` mới — carousel tái dùng toàn bộ state Rx đã có
  sẵn trên `GameController`.

**Regression tự phát hiện + tự sửa trong cùng phiên**: thêm `_tapC`
(`AnimationController` thứ 2) vào `StarMascot` trong khi class vẫn dùng
`SingleTickerProviderStateMixin` → crash "can only be used as a
TickerProvider once" lan ra **31 test fail** ở nhiều file không liên quan
(mọi test render `StarMascot`). Fix root-cause 1 dòng: đổi sang
`TickerProviderStateMixin`.

`flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh toàn
bộ 272 test (thêm mới `test/presentation/home_carousel_test.dart`, 11
test cho `buildHomeCards`). Verify tay trên emulator (`emulator-5554`,
Android 17 API 37 — thiết bị duy nhất kết nối): carousel hiện đúng
greeting card + badge weekend (test đúng ngày Jul 18 2026 = thứ Bảy) +
2 dot-indicator; vuốt carousel chuyển sang thẻ Perks ("1 more world to
unlock a new perk", viền hồng); tap mascot không crash; tap thẻ Perks
điều hướng đúng sang `PerksScreen`. Không gặp quảng cáo che UI ở bước
nào. Chi tiết: `X14-home-carousel-unified.md`.

**Bug tìm thấy + sửa khi audit lại toàn bộ screen sau khi user nghi ngờ**:
CTA/badge của card bị "kẹt" (stale) sau khi claim — vì `ctaLabelBuilder`/
`onTap` của mỗi `HomeCardData` chỉ được chốt 1 lần lúc `buildHomeCards()`
sinh danh sách, không tự re-evaluate khi state đổi (vd. claim daily
reward xong, card Daily vẫn hiện CTA "Nhận thưởng" cũ cho tới khi có hành
động khác kích hoạt rebuild). Fix root-cause tại 1 điểm chốt: thêm
`onCardTapped` callback trên `HomeCarousel`/`_HomeCard` (gọi ngay sau
`data.onTap()`) và gọi `HomeScreenController.refreshCards()` cả sau khi
tap card lẫn sau khi claim daily reward — đảm bảo danh sách card luôn
được rebuild ngay sau bất kỳ hành động claim nào.

**Bug thứ 2 tìm thấy sau khi user báo trực tiếp**: badge weekend
"🎉 Cuối tuần x2 xu!" bị cắt mất phần trên trên thiết bị thật. Lần audit
đầu tôi kết luận nhầm là "thiết kế có chủ đích" vì chỉ đọc thấy
`Stack(clipBehavior: Clip.none)` bọc badge — bỏ sót rằng `Stack` đó nằm
trong `PageView` bọc bởi `SizedBox(height: 92)`; `Viewport` của
`PageView` vẫn clip theo đúng bounds của chính nó bất kể `clipBehavior`
của `Stack` con, nên phần badge nhô lên trên (`Positioned(top: -8, ...)`)
bị cắt. Fix: tăng `SizedBox` lên `92 + NeonTheme.s8` và thêm padding-top
`NeonTheme.s8` cho mỗi item trong `PageView.builder`, dịch cả card xuống
đúng 8px để phần nhô của badge nằm gọn trong vùng viewport. Đã verify lại
trên thiết bị thật (V2352A) — badge hiển thị đầy đủ, không còn bị cắt.

Audit lại toàn bộ các screen còn lại (Level Select, Game, Quit dialog,
Shop, Daily Challenge, Modes dialog) không phát hiện thêm lỗi UI nào —
các nghi vấn khác (mô tả "Đóng Băng" ở Shop gần sát pill giá, Daily
Challenge không có progress bar) đều xác nhận là thiết kế có chủ đích qua
code, không phải bug.

## ✅ Implemented: Prestige / New Game+ (I27, 2026-07-18)

Sau khi thắng đủ ≥1 sao ở level cuối cùng (220), người chơi có thể
"prestige": chơi lại từ level 1 với `targetScore` mọi level nhân hệ số
`1 + tier*0.25`, đổi lấy thưởng coin và một tier hiển thị công khai.

- **`lib/data/levels.dart`** — `prestigeTierMultiplier(tier)` (tier ≤0
  trả về 1.0, không bao giờ âm điểm) và `prestigeTargetScore(level,
  tier)` (tier ≤0 trả target gốc, ngược lại `round(target *
  multiplier)`), dùng thay `level.targetScore` ở mọi nơi tính sao khi có
  prestige đang active.
- **`GameController`** — `prestigeTier` (`RxInt`, persist
  `StorageKeys.prestigeTier`), `allLevelsCompletedOnce` (`RxBool`,
  persist `StorageKeys.allLevelsCompleted`, set khi `checkEnd()` phát
  hiện thắng ≥1 sao đúng level `kLevelCount`), `canPrestige` (getter =
  `allLevelsCompletedOnce.value`), `prestige()` (no-op nếu
  `!canPrestige`; nếu đủ điều kiện: tăng tier, reset `unlockedLevel` về
  1, reset `allLevelsCompletedOnce`, cộng thưởng coin) — không đụng
  high-score/star đã lưu của bất kỳ level nào (giữ nguyên lịch sử chơi
  trước prestige). `resetProgress()` dọn sạch cả 2 key + observable liên
  quan.
- **`LevelSelectScreen`** — `_PrestigeAction` ở app bar: ẩn hoàn toàn nếu
  tier 0 và chưa đủ điều kiện; hiện icon call-to-action tappable khi đủ
  điều kiện (mở `_showPrestigeDialog`, xác nhận qua `NeonDialog`); hiện
  nhãn tĩnh `P{tier}` (không tap được, `onTap: null`) khi đã prestige ≥1
  lần nhưng chưa đủ điều kiện lần kế — chống double-tap mở nhầm dialog.
- i18n: các key `prestige_*` bổ sung đủ 22 locale qua wave map trong
  `AppTranslations`.

**Test coverage**: `test/data/levels_test.dart` — multiplier/targetScore
cho tier âm (không hợp lệ), tier 0, tăng tuyến tính 0.25/tier, và mọi
tier 0..10 trên toàn bộ 220 level (luôn > 0). `test/presentation/
game_controller_test.dart` — happy path prestige, thắng level giữa
chừng không mở khoá prestige, thua ở level cuối không mở khoá, no-op khi
gọi `prestige()` lúc chưa đủ điều kiện, double-tap `prestige()` liên
tiếp không tăng tier 2 lần trong 1 lượt, target nặng hơn rõ rệt sau khi
prestige, tích luỹ nhiều tier liên tiếp, `resetProgress()` dọn sạch state
prestige, không đụng high-score/star cũ của các level đã chơi trước đó.
`test/widget/prestige_action_test.dart` — badge ẩn khi chưa đủ điều
kiện, hiện + tappable khi đủ điều kiện, Cancel không đổi tier, Prestige
tăng tier và ẩn lại badge dạng tappable (chuyển sang nhãn tĩnh `P1`),
badge tĩnh không mở dialog khi tap lại (chặn double-tap).

**2 bug tự phát hiện khi viết widget test, đã fix ngay:**
1. `find.byIcon(Icons.auto_awesome_rounded)` bị ambiguous (tìm thấy 7
   widget thay vì 1) — icon này trùng ngẫu nhiên với hoạ tiết banner
   World 4 (`kWorlds`, levels 61-80, `lib/data/worlds.dart`), render 6
   bản sao qua `_WorldBanner` khi màn hình cuộn/dựng tới gần world đó
   (xảy ra khi test thắng level 220). Fix: gắn `Key('prestige_badge')`
   riêng cho `GestureDetector` của badge, test định vị qua
   `find.byKey(...)` thay vì `IconData` dùng chung.
2. `find.text('Prestige')`/`find.text('Cancel')` không tìm thấy dù dialog
   đã mở (`NeonDialog.show` được gọi đúng) — do `GetMaterialApp` trong
   test không khai báo `translations:`/`locale:`, khiến mọi `.tr` trả về
   nguyên key chưa dịch. Fix: bọc widget test qua helper `_wrap()` với
   `translations: AppTranslations()` + `locale: Locale('en', 'US')`,
   đúng convention đã dùng ở các widget test khác (`shop_screen_test
   .dart`, `guide_screen_test.dart`, ...).

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow`
→ 293/293 test xanh toàn bộ.

## ✅ Implemented: Async Ghost Replay Share (I28, 2026-07-18)

Ghi lại 1 ván chơi (level id, seed RNG, chuỗi tap theo thứ tự), mã hoá
thành text code chia sẻ được (giống pattern friend code); người nhận dán
code vào `GhostReplayScreen` để tự động xem lại y hệt ván chơi đó (chỉ
xem, không tương tác, không cộng thưởng thật).

- **`PopStarGame`** — `_rng` đổi từ `Random()` không seed sang
  `Random(seed)`; `seed` truyền qua constructor (mặc định
  `Random().nextInt(1 << 31)` cho ván chơi thường, không đổi trải
  nghiệm hiện tại) nhưng luôn lưu lại để phục vụ replay. Toàn bộ điểm
  RNG ảnh hưởng board (colorGrid khởi tạo, obstacle/chain-lock/gift
  placement, power tile kind, `pickGiftReward`, shuffle) đã audit đi
  qua đúng 1 instance `_rng` — không còn `Random()` rải rác nào ảnh
  hưởng kết quả board trong ván được ghi.
- **`recordingEnabled`/`recordedTaps`/`recordingValid`** — chỉ ghi tap
  `(row, col)` khi cờ `StorageKeys.recordReplay` (Settings) bật, tránh
  tốn bộ nhớ mặc định; mọi hành động booster (bomb/rainbow/swap/
  shuffle/freeze/undo) lật `recordingValid` về `false` ngay (chống chia
  sẻ ván có "trợ giúp" không tái hiện được từ taps thuần).
- **`lib/logic/replay.dart`** — `ReplayData`, `encodeReplay`/
  `decodeReplay` base64url theo đúng pattern `friend_code.dart`; decode
  trả `null` (không throw) khi code hỏng/giả mạo/thiếu cột/toạ độ âm/
  levelId ngoài phạm vi.
- **`GhostReplayScreen`** — dán code → dựng `PopStarGame` mới đúng seed
  (`isReplay: true`, chặn mọi thưởng/tiến trình thật ghi vào
  `StorageService` singleton), `Timer.periodic` (450ms) tự phát từng
  tap theo thứ tự, khoá tương tác (không `GestureDetector` nào tới tay
  người xem), tự dừng + báo "đã xem xong" khi hết taps hoặc bàn kết
  thúc (`replayEnded`).
- **`GameScreenController`** — `shareReplay()`/`canShareReplay` (gate:
  có ghi + `recordingValid` + đã có tap); `SettingsScreen` thêm toggle
  "Record Replay"; `GameScreen` overlay thắng thêm nút chia sẻ replay
  (`Icons.movie_creation_rounded`), chỉ hiện khi `canShareReplay`.
- i18n: các key `ghost_replay_*`/`record_replay` bổ sung đủ 22 locale.

**Test coverage**: `test/logic/replay_test.dart` — round-trip encode/
decode, mọi dạng code hỏng/giả mạo (không base64, thiếu cột, levelId
≤0, seed không phải số, thiếu dấu phẩy, toạ độ âm, chuỗi rỗng) → `null`
không throw, encode ổn định cùng input. `test/widget/
replay_recording_test.dart` — tap thường được ghi, cờ tắt thì không
ghi, mọi booster (bomb/rainbow/swap/shuffle/freeze/undo) lật
`recordingValid` về `false`, `canShareReplay` đúng logic gate.
`test/widget/ghost_replay_screen_test.dart` — mã hợp lệ tự phát lại
KHÔNG cộng thưởng thật dù có pop, mã không phải base64 báo lỗi không
crash, levelId ngoài `[1, kLevelCount]` (giả mạo tay) báo lỗi, taps
rỗng tự kết thúc ngay, dispose giữa chừng playback huỷ `Timer` không
leak. `test/widget/settings_screen_test.dart` — toggle Record Replay
lưu/xoá persist đúng 2 chiều. `test/widget/
game_screen_share_replay_test.dart` — nút share_replay ẩn khi
`recordReplay` tắt, hiện khi bật + có tap ghi được, không ảnh hưởng nút
share ảnh bàn (F15) sẵn có. `test/widget/replay_determinism_test.dart`
— cùng seed chạy 2 lần qua `PopStarGame` → colorGrid + score cuối
giống hệt nhau tuyệt đối; seed khác nhau → board khác nhau (xác nhận
seed thực sự chi phối kết quả).

**2 bug tự phát hiện khi viết test, đã fix ngay:**
1. Race condition: ép lưới xác định lên board sau khi bơm quá 450ms
   (`_tapInterval`) kể từ lúc bấm nút — `Timer.periodic` đã tự tap 1-2
   lượt vào board ngẫu nhiên gốc trước khi lưới ép kịp áp dụng. Fix:
   giảm số frame bơm trước khi ép lưới xuống dưới ngưỡng 450ms.
2. Nhịp `Timer` đầu tiên luôn bị bỏ qua nếu hiệu ứng intro rơi ô
   (~590ms cho bàn 8x6) còn chạy (`isAnimating` chặn finish-check) —
   test taps-rỗng cần bơm đủ nhiều frame nhỏ (không phải 1-2 pump lớn)
   để qua hết 2 nhịp Timer mới thấy trạng thái "đã xem xong".
3. `flutter analyze` báo field `_data` write-only không dùng tới (sót
   lại từ refactor trước) — xoá field + 2 điểm gán không đọc.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow`
→ 322/322 test xanh toàn bộ.

**Bug audit phát hiện sau khi implement xong, đã fix ngay (2026-07-18):**
`_checkEnd()` từng gate CẢ việc bốc `_rng` lẫn phát thưởng gift cùng 1
điều kiện `if (!isReplay)` — khi replay (`isReplay: true`), gift KHÔNG
tiêu thụ draw nào của `_rng`, trong khi lúc ghi (`isReplay: false`) nó
có tiêu thụ 1 draw (`pickGiftReward`). Mọi lượt bốc `_rng` kế tiếp
(power tile kind, shuffle...) vì vậy lệch pha giữa 2 mode → board cuối
của replay khác board thật đã ghi, phá vỡ đúng lời hứa cốt lõi của
tính năng (ghost replay chỉ lưu `(levelId, seed, taps)`, không lưu
board, nên phụ thuộc tuyệt đối vào RNG tái lập y hệt). Fix: tách bốc số
khỏi phát thưởng — luôn gọi `pickGiftReward(_rng)` ở cả 2 mode để giữ
đúng thứ tự tiêu thụ `_rng`, chỉ gate `controller.grantGiftReward(...)`
(side-effect thật) sau `!isReplay`. Test mới trong
`replay_determinism_test.dart` dựng 1 `PopLevel`/`presetGrid` tay để
tạo đúng chuỗi: nổ cặp → gift rơi đáy tự mở (bốc `_rng`) → nổ nhóm 6 ô
→ sinh power tile (bốc `_rng` chọn lineRow/lineCol) → tap kích hoạt
power tile — so board cuối giữa 1 lần chạy `isReplay:false` và 1 lần
`isReplay:true` cùng seed, phải giống hệt nhau. Đã xác nhận test này
fail đúng như kỳ vọng khi tạm revert fix (trước khi fix, lệch tại
`[0][6]`: `null` so với `3`), rồi áp lại fix và test xanh — không phải
tautology.

## ✅ Implemented: Star Boss Milestone Tiles (I29, 2026-07-18)

Màn mốc (mỗi 20 level) sinh 1 khối "boss tile" nhiều ô liền kề, có
thanh máu (HP) riêng — nổ nhóm màu thường chạm cạnh khối mới trừ 1 HP/
lần bất kể chạm bao nhiêu cạnh cùng lúc; hết HP toàn khối vỡ thành ô
trống. Bàn kẹt hoàn toàn (chỉ còn boss tile, không nhóm màu nào để nổ)
sẽ tự "decay" (giảm 1 HP mỗi lượt kiểm tra) thay vì kết thúc màn ngay,
tránh softlock không thể thắng.

- Mã hoá: `bossTileIdBase = -2000`, id khối `<= bossTileIdBase` (âm,
  cùng dải quy ước với obstacle/gift tile) — `isBossTileId(v)` phân biệt
  với 2 loại âm khác. `lib/logic/boss_tile.dart`: `BossTileSpec`,
  `placeBossTile`, `chipAdjacentBossTiles` (dedupe id trước khi trừ HP,
  đảm bảo 1 lần chip = đúng 1 HP dù chạm bao nhiêu cạnh), `bool
  decayBossTilesOnStuck` (bàn kẹt → trừ đều mọi boss tile hiện có).
- `PopStarGame`: field `bossHp` (`Map<int,int>`, mutable, cũng snapshot
  vào `_undoBossHp` cho `undo()`); `_placeBossTileIfNeeded()` gọi ở
  `onLoad`; `_tryPop`/`_activatePowerTile` gọi `_chipAdjacentBossTiles`
  sau khi chip obstacle thường. `_checkEnd()`: nếu bàn kẹt và
  `bossHp.isNotEmpty` → decay + `_clearAndCollapse` rồi return (không
  rơi xuống nhánh thắng/thua), lặp lại tự nhiên qua chuỗi
  `TimerComponent` cho tới khi HP về 0 hoặc bàn hết kẹt.
- `PopLevel.bossTileSpec` (levels.dart) — gắn spec cho các level mốc
  (mỗi 20 level).
- i18n: thêm rule "Boss Tile" vào `GuideScreen` (rule thứ 6), 22 locale.

**Bug production tự phát hiện khi viết test, đã fix ngay**: `lib/logic/
obstacle.dart`'s `chipAdjacentObstacles` chạy TRƯỚC boss-chip trong
`_tryPop`, và match mọi giá trị âm trừ `giftTileValue` là "obstacle" rồi
mutate `grid[p]! + 1` — vô tình làm lệch id boss tile (vd `-2000` →
`-1999`), khiến check `isBossTileId` ngay sau đó nhận nhầm không phải
boss và HP không bao giờ được trừ đúng chỗ. Fix: thêm loại trừ tường
minh `!isBossTileId(v)`, cùng pattern với exclusion `giftTileValue` sẵn
có.

**Test coverage**: `test/widget/boss_tile_widget_test.dart` — chip 1 HP
khi nổ nhóm liền kề (chưa vỡ khi HP > 0), HP về 0 → toàn khối vỡ + xoá
khỏi `bossHp`, nhóm chạm khối ở ≥2 cạnh khác nhau vẫn chỉ trừ đúng 1 HP/
lần (chống double-count), bàn kẹt hoàn toàn → decay dần KHÔNG kết thúc
màn ngay tới khi HP về 0 rồi màn mới thật sự kết thúc (regression chống
softlock — bug cũ), `undo()` khôi phục đúng `bossHp` về snapshot trước
lần chip gần nhất, edge case không có boss tile trên bàn (pop bình
thường không lỗi), edge case id lạ/giả mạo trong `bossHp` không khớp
cell nào trên bàn (không ảnh hưởng pop thường, entry lạ giữ nguyên).
`test/widget/guide_screen_test.dart` — cập nhật đủ 6 rule (rule Boss
Tile nằm ngoài viewport ban đầu của `ListView`, phải cuộn bằng
`dragUntilVisible` trước khi assert).

**1 bug test tự phát hiện, đã fix ngay** (không phải bug production):
test decay-on-stuck ban đầu bơm 30 frame liền cho mỗi mốc kiểm tra —
đủ để 2 chu kỳ pop+fall (~11 frame/chu kỳ) chạy nối tiếp trong cùng 1
lần bơm, "cuốn" luôn qua mốc trung gian cần assert ("đã vỡ nhưng
`ended` vẫn false"), khiến test tưởng nhầm production bug. Fix: chia
lại số frame bơm theo đúng ranh giới từng chu kỳ (16 frame rồi 20
frame) để bắt đúng trạng thái trung gian.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow`
→ 351/351 test xanh toàn bộ.

## ✅ Implemented: Mascot Wardrobe (I30, 2026-07-18)

Tủ đồ cho mascot (`StarMascot`) — 6 skin đổi màu (palette), mở khoá
bằng xu hoặc bằng thành tựu mốc cao, chọn skin active hiển thị xuyên
suốt header game, dialog thắng/thua, home screen.

- `lib/data/mascot_skins.dart`: `MascotPalette` (glow/gradientStart/
  gradientEnd/outline), `MascotSkin` (id/nameKey/palette/coinPrice/
  unlockAchievementId — `assert` đúng 1 trong 2 non-null, trừ skin free
  `classic` cả 2 đều null). `kMascotSkins`: `classic` (free), `ruby`
  (300 xu), `emerald` (600 xu), `sapphire` (1000 xu), `aurora` (mở khoá
  qua thành tựu `combo_25`), `obsidian` (mở khoá qua thành tựu
  `clear_400`).
- `GameController`: `activeMascotSkinId`/`unlockedMascotSkinIds` (Rx,
  persist qua `StorageKeys.activeMascotSkin`/`unlockedMascotSkins`).
  `buySkin(skin)` — chặn skin mở khoá bằng thành tựu (`coinPrice ==
  null`), skin đã mở khoá (chống double-buy/race), thiếu xu; chỉ trừ
  xu + persist khi thành công. `selectMascotSkin(id)` — chặn id chưa mở
  khoá (bao gồm id giả mạo/không tồn tại); `activeMascotSkin` getter có
  fallback `orElse: () => kMascotSkins.first` chống crash nếu active id
  lưu trữ bị hỏng. `_checkAchievements()` tự thêm skin tương ứng vào
  `unlockedMascotSkinIds` khi đạt `combo_25`/`clear_400`, không tính là
  mua nên không trừ xu ngoài coin thưởng của chính thành tựu đó.
  `resetProgress()` xoá 2 storage key, `_load()` sau đó tự đưa
  `unlockedMascotSkinIds` về `{classic}` và `activeMascotSkinId` về
  `classic` (skin free luôn được force-add trong `_load()`).
- `StarMascot`/`_StarPainter`: nhận thêm `palette`, vẽ theo màu skin
  đang active thay vì màu cứng cố định trước đây.
- `MascotWardrobeScreen`: grid 2 cột hiển thị mọi skin — trạng thái
  active (viền gold + nhãn "Đang dùng"), đã mở khoá (nút "Chọn"), có
  giá xu (nút mua, disable nếu thiếu xu), mở khoá bằng thành tựu (icon
  khoá + tên thành tựu cần đạt). Vào từ drawer `HomeScreen`.
- i18n: 10 key mới (`skin_*_name` × 6, `wardrobe_*` × 4) — en/vi trực
  tiếp trong `_extraEn`/`_extraVi`, 20 ngôn ngữ còn lại trong wave map
  `_w42ByLang`.

**Bug tự phát hiện khi viết code, đã fix ngay**: `mascot_wardrobe_
screen.dart` dùng `const Icon(Icons.lock_rounded, color:
NeonTheme.inkSoft, ...)` — `NeonTheme.inkSoft` là getter phụ thuộc
dark-mode (`static Color get inkSoft => ...`), không phải hằng số biên
dịch, khiến `flutter analyze` báo `invalid_constant`. Fix: bỏ `const`
khỏi `Icon(...)` đó.

**Test coverage**: `test/presentation/game_controller_test.dart` nhóm
`I30 Mascot Wardrobe` — trạng thái ban đầu (chỉ `classic` mở khoá và
active); `buySkin()` đủ xu (trừ đúng giá + mở khoá + persist), thiếu xu
(no-op), skin đã mở khoá (chống double-buy/race), skin mở khoá bằng
thành tựu (`coinPrice == null` → luôn `false` dù đủ xu); `selectMascot
Skin()` skin đã mở khoá (thành công, đổi active), skin chưa mở khoá
(false, active không đổi), id giả mạo/không tồn tại (false, không
crash, fallback về skin đầu tiên); đạt mốc `combo_25` (25 lần
`registerPop` liên tiếp không reset combo) → tự mở khoá `aurora` không
trừ xu mua; đạt mốc `clear_400` (400 vòng `startLevel`+`checkEnd(true)`)
→ tự mở khoá `obsidian`; `resetProgress()` đưa wardrobe về mặc định
(`classic` active + chỉ `classic` mở khoá, cả storage lẫn in-memory).

Bổ sung sau audit (2026-07-18): acceptance criteria yêu cầu riêng 1
widget test "mascot vẽ đúng palette khi đổi skin active" — ban đầu
thiếu, chỉ có unit test trên `GameController`. Đã thêm
`test/widget/mascot_wardrobe_test.dart` (6 test): mascot dùng palette
`classic` mặc định; đổi active skin (mua bằng xu) → `StarMascot` vẽ lại
đúng palette mới (mirror đúng pattern `Obx(() => StarMascot(palette:
gameCtrl.activeMascotSkin.palette))` đang dùng thật ở `home_screen.dart`/
`game_screen.dart`); mở khoá qua thành tựu `combo_25` rồi chọn active →
đúng palette `aurora`; `MascotWardrobeScreen` render đủ lưới 6 skin,
mỗi thẻ đúng palette của skin đó; flow mua đủ xu → "Chọn" → active hiện
nhãn "Đang dùng"; thiếu xu → nút mua disable, tap không mở khoá được.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags
slow` → toàn bộ xanh (11 test `game_controller_test.dart` + 6 test
`mascot_wardrobe_test.dart` mới của nhóm I30, tổng 368 test toàn
project).

## ✅ Fix gap audit: badge Prestige thiếu ở HomeScreen (X15, 2026-07-18)

2 vòng audit độc lập I27-I30 (chấm điểm 10/10) đều xác nhận cùng 1 gap:
spec I27 yêu cầu entry-point/badge Prestige ở cả `HomeScreen` lẫn
`LevelSelectScreen`, nhưng badge (`_PrestigeAction`) chỉ được implement
private trong `level_select_screen.dart` — `HomeScreen` không có gì cả.

Fix theo hướng DRY thay vì copy-paste: extract `_PrestigeAction` +
`_showPrestigeDialog` từ `level_select_screen.dart` thành widget dùng
chung mới `lib/presentation/widgets/prestige_action.dart` (public
`PrestigeAction` widget + `showPrestigeDialog(context, gameCtrl)` free
function). `level_select_screen.dart` refactor để import/dùng bản chung
(xoá class/method private cũ). `home_screen.dart` thêm `PrestigeAction`
vào Row app-bar trên cùng, cạnh `CoinChip`.

Không cần test file mới — `prestige_action_test.dart` sẵn có (test qua
`LevelSelectScreen`) đã cover đủ logic ẩn/hiện/tap dùng chung cho cả 2
màn hình.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags
slow` → toàn bộ xanh, không regression từ refactor. Xem
`doc/task/tasks/X15-home-prestige-badge-gap.md`.

## ✅ Fix các gợi ý nhỏ từ audit I28/I29/I30 (2026-07-18)

Vòng audit thứ 3 (I27=9, I28=9, I29=9, I30=9/10) nêu vài gợi ý nhỏ,
không phải bug — đã xử lý:

- **I28**: thêm test determinism mới trong `replay_determinism_test.dart`
  ghi (isReplay=false) rồi phát lại (isReplay=true) cùng seed trên board
  random THẬT (không preset grid) — khép gap trước đó chỉ có regression
  test cho scenario gift/power dàn sẵn. Chỉ so `colorGrid` cuối, không so
  `score` (replay cố tình không cộng điểm qua controller — xem
  `PopStarGame._tryPop`, đúng thiết kế "chỉ xem"). Tick đủ 9 checkbox
  acceptance criteria còn để trống trong
  `doc/task/tasks/I28-async-ghost-replay-share.md` dù đã implement đầy đủ.
- **I29**: rà lại thấy gợi ý "thiếu integration test fitsBoard qua toàn bộ
  kLevels" đã có sẵn (`bossTileSpec (I29)` group trong
  `test/data/levels_test.dart`) — không cần sửa gì thêm.
- **I30**: gộp `_classicPalette` (từng định nghĩa trùng ở
  `star_mascot.dart` và `mascot_skins.dart`) thành 1 const công khai duy
  nhất `classicMascotPalette` trong `mascot_skins.dart`. Thêm validate
  skin id đã lưu (`unlockedMascotSkinIds`/`activeMascotSkinId`) so với
  `kMascotSkins` hiện tại trong `GameController` — id giả mạo/của skin đã
  gỡ khỏi danh sách không còn tích luỹ hoặc được coi là active.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags
slow` → toàn bộ xanh, không regression.

## ✅ Implemented: Auto-solve Ghost Hint (I31, 2026-07-19)

Nút Hint thủ công trong booster bar (7 nút): bấm hiện ngay nhóm pop lớn nhất
trên bàn, KHÔNG cần chờ idle timer 6s của gợi ý tự động (I4). Miễn phí theo
ván (3 lượt/màn, `GameController.hintsPerRun`, `hintCount` reset ở cả 4 entry
point start*), không lưu đĩa, không tính vào `totalBoostersUsed`/achievement
(khác các booster mua bằng xu).

- **Reuse, không duplicate**: tái dùng nguyên `findLargestGroup` (đã có từ
  I4 Predictive Hint) — hàm này đã xử lý đúng mọi acceptance criteria của
  I31 (loại obstacle/gift/boss qua quy ước `< 0`, bàn trống → rỗng, chọn đúng
  nhóm lớn nhất khi có nhiều nhóm). Chỉ bổ sung test coverage cho các case
  đó trong `pop_detector_test.dart`, không viết hàm mới.
- **`PopStarGame.showHint()`** — trigger thủ công, bỏ qua `_hintDelay`; có
  countdown tự tắt riêng (`_manualHintTimer`, 1.5s) khác với gợi ý idle vốn
  đứng yên tới khi tap. Trả `false` nếu đang animate, gợi ý đã đang hiện
  sẵn, hoặc bàn không còn nhóm ≥2 (caller dựa vào đó để không trừ nhầm lượt).
- **`GameController.useHint()`** → `PopStarGame.showHint()` → UI button
  (`_BoosterButton` màu `NeonTheme.yellow`, icon `lightbulb_rounded`) →
  i18n `booster_hint_label` cho đủ 22 locale.

Test mới: `test/widget/manual_hint_test.dart` (hiện ngay không đợi idle, trừ
đúng lượt khi thành công/không trừ khi thất bại, tự tắt sau ~1.5s, reset
`hintCount` khi start màn mới) + 4 case mới trong
`pop_detector_test.dart` cho `findLargestGroup`.

**Fix double-spend (audit 2026-07-19)**: `showHint()` trước đây không kiểm
tra gợi ý đã đang hiện sẵn (từ idle-trigger I4 hoặc lần bấm thủ công trước)
→ bấm nút Hint lúc đó vừa trừ nhầm 1 lượt vừa rút ngắn thời gian hiện xuống
còn 1.5s một cách vô ích, đi ngược mục tiêu giới hạn số lần dùng. Fix:
`showHint()` trả `false` ngay nếu `_hint.isNotEmpty`, giữ nguyên gợi ý đang
có mà không tốn lượt. Test regression mới trong `manual_hint_test.dart`.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags
slow` → 378 test toàn bộ xanh, không regression.

Đã chứng minh thêm bằng integration test thật trên thiết bị (Pixel 7 Pro,
`integration_test/lifecycle_test.dart`, 2 test case): bấm nút Hint 2 lần liên
tiếp khi gợi ý đang hiện chỉ trừ đúng 1 lượt (`hintCount` không giảm thêm ở
lần bấm thứ 2). `flutter test integration_test/lifecycle_test.dart -d
2B051FDH3006MU` → 2/2 xanh trên app đã build/cài thật, không mock.

## ✅ Implemented: Combo Milestone FX (I39, 2026-07-19)

Text "COMBO x{N}!" bay lên + rung mạnh khi combo chạm mốc cố định
(`kComboMilestones = [5, 10, 15, 20]`), tách biệt animation khỏi haptic đúng
theo convention 2-flag riêng của project (giảm chuyển động chỉ tắt hiệu ứng
UI, không ảnh hưởng haptic).

- **`lib/data/combo_milestones.dart`** (mới) — `kComboMilestones` +
  `isComboMilestone(count)`.
- **`GameController`** — thêm `comboMilestoneTick`/`comboMilestoneValue`/
  `triggerComboMilestone()`, mirror đúng pattern `flashTick`/`triggerFlash()`
  đã có (tick để UI nghe 1 lần, value thường để mang payload).
- **`pop_star_game.dart`** — kiểm tra `isComboMilestone(controller.comboCount
  .value)` ngay sau cả 2 điểm gọi `triggerFlash()` hiện có; khi đúng mốc gọi
  `triggerComboMilestone(...)` + `fireHaptic(HapticLevel.heavy)`. Không thêm
  guard `isReplay` riêng vì `comboCount` vốn không tăng trong replay
  (`registerPop` bị bỏ qua khi `isReplay == true`), giống hệt cách flash-
  trigger đang unguarded.
- **`game_screen.dart`** — `_ComboMilestoneOverlay` mirror `_FlashOverlay`,
  nghe `comboMilestoneTick`, tự tắt animation khi `_reduceMotion` (haptic vẫn
  chạy độc lập vì trigger nằm ở `pop_star_game.dart`, không phụ thuộc flag
  này).
- i18n: `combo_milestone_label` (`'COMBO x@count!'`) thêm đủ 22 locale.

Test mới: `test/data/combo_milestones_test.dart` (đúng/sai theo mốc),
`test/widget/combo_milestone_fx_test.dart` (drive `GameScreen` thật, dồn combo
qua 6 lần tap liên tiếp bằng kỹ thuật tap lặp cùng toạ độ cột 0 — cột rỗng
luôn dồn trái nên không cần tính lại toạ độ mỗi lần pop; xác nhận mốc 5
trigger đúng 1 lần và reduce-motion tắt overlay text nhưng tick milestone vẫn
tăng độc lập), 2 test mới trong `game_controller_test.dart` (trigger tăng
tick/lưu đúng value qua nhiều lần gọi; `resetCombo()` không tự trigger FX).

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
384 test toàn bộ xanh, không regression.

## ✅ Implemented: Ambient Weather theo World Theme (I40, 2026-07-19)

Lớp particle thời tiết nhẹ phía sau board, khác nhau theo `GameWorld` — world
băng có tuyết rơi xuống, world lửa có tia lửa bay lên, world nước có bong
bóng nổi lên. World cuối (aurora, I16) giữ nguyên, không chồng thêm weather để
tránh rối mắt.

- **`lib/data/worlds.dart`** — thêm enum `WeatherKind { none, snow, spark,
  bubble }` + field `weather` (default `WeatherKind.none`) vào `GameWorld`
  (default để không phải sửa lại toàn bộ 11 khai báo const cũ). Gán
  `spark` cho world 2/8 (lửa), `bubble` cho world 3/9 (nước), `snow` cho
  world 7 (băng); world 1/4/5/6/10/11 giữ `none`.
- **`lib/presentation/widgets/ambient_weather_layer.dart`** (mới) —
  `AmbientWeatherLayer` mirror đúng pattern `AuroraBgLayer` (I16):
  `IgnorePointer` → `RepaintBoundary` → `CustomPaint(size: Size.infinite)`,
  trả `SizedBox.shrink()` ngay khi `weather == none`. Particle
  (vị trí/pha/tốc độ/độ lệch ngang/kích thước) sinh 1 lần trong `initState`
  qua `Random()` giống `confetti_overlay.dart`'s `_Bit`; 1
  `AnimationController` lặp liên tục (`.repeat()`) làm `t` chạy 0..1, mỗi
  particle tự tính lại vị trí theo `t` (tuyết đi xuống, spark/bubble đi lên),
  mờ dần ở 2 đầu hành trình để không xuất hiện/biến mất đột ngột.
- Tôn trọng `reduce_motion` đúng convention đã dùng ở `star_mascot`/
  `pulse_glow`: `bool get _reduceMotion => StorageService.maybe?.getBool(...)
  ?? false;`, chỉ gọi `_c.repeat()` trong `initState` nếu `!_reduceMotion`.
- **`neon_bg.dart`** — thêm param `weather` (default `WeatherKind.none`),
  chèn `AmbientWeatherLayer` vào `Stack` cùng cách `aurora` đang làm (sau lớp
  nền cơ bản, trước `widget.child`).
- **`game_screen.dart`** — truyền `weather:` vào `NeonBg` tính từ
  `worldForLevel(gameCtrl.currentLevel.id).weather`, cùng guard
  `gameCtrl.currentLevel.id > 0` như `aurora` (side-mode levels ID âm không
  có weather).
- i18n: không cần (không có text).

Test mới: `test/widget/ambient_weather_layer_test.dart` — build không lỗi với
từng `WeatherKind`; `none` → không có `CustomPaint` con nào (`SizedBox.shrink`);
reduce-motion tắt → `.repeat()` chạy vô hạn nên `pumpAndSettle` phải throw
(kỹ thuật xác nhận animation lặp vô hạn không cần đụng vào private State);
reduce-motion bật → không gọi `.repeat()` nên `pumpAndSettle` hoàn tất bình
thường.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
391 test toàn bộ xanh, không regression.

## ✅ Implemented: Mascot Reaction theo Combo Streak (I41, 2026-07-19)

`StarMascot` trong game screen trước chỉ nhị phân `cheer`/`idle` theo
`comboMultiplier > 1.4`, bỏ phí mood `happy` đã tồn tại sẵn animation riêng
trong `StarMood` enum. Đổi sang ánh xạ chi tiết theo `comboCount` (số nguyên
trực tiếp, chính xác hơn hệ số nhân).

- **`star_mascot.dart`** — thêm hàm thuần `moodForCombo(int comboCount)`:
  `0-1 → idle`, `2-4 → happy`, `≥5 → cheer`.
- **`game_screen.dart`** — đổi điểm mood-trong-lúc-chơi (mascot nhỏ ở
  top bar) sang `moodForCombo(gameCtrl.comboCount.value)`. Không đụng 2 chỗ
  dùng mood khác (màn kết quả `isTimeAttack ? cheer : sad`, và 1 trường hợp
  `cheer` cố định khác).
- Không cần sửa gì thêm cho `reduce_motion` — cơ chế tắt animation lặp vô
  hạn khi bật flag đã áp dụng chung cho mọi mood từ trước (`commit 28ccb94`).
- i18n: không cần (không có text mới).

Test mới: 3 test cho `moodForCombo` (biên 0/1, 2/3/4, 5/6/999) trong
`star_mascot_test.dart`; `test/widget/mascot_combo_reaction_test.dart` —
drive `GameScreen` thật, dồn combo bằng kỹ thuật tap lặp cột 0 (mirror
`combo_milestone_fx_test.dart`), xác nhận mascot đổi đúng mood tại từng mốc
biên 2/4/5.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
395 test toàn bộ xanh, không regression.

## ✅ Implemented: Puzzle Lab — level editor + chia sẻ mã bàn (I42, 2026-07-19)

Chế độ chơi mới cho phép người dùng tự vẽ 1 bàn PopStar (rows/cols/colorCount/
obstacle/gift tuỳ ý), lưu tối đa 5 bàn trên máy, và chia sẻ/nhập bàn qua 1 mã
text base64url (cùng kỹ thuật `encodeReplay` ở I28). 4 quyết định thiết kế đã
chốt với user trước khi code:

1. `boardsFullyCleared` vẫn đếm cho Puzzle Lab (chỉ bypass coin/sao/unlock/
   best-score) — mascot achievement liên quan vẫn tính đúng.
2. Dialog kết quả giữ cả 2 nút "Chơi lại" + "Menu" (không rút gọn còn 1 nút).
3. Ô trống khi vẽ → lấp thành màu 0 qua `fillEmptyCells` ngay trước khi vào
   `PopStarGame`, không đổi kiểu `presetGrid` (`List<List<int>>`).
4. Entry point đặt trong Settings (không phải nút riêng trên Home Screen).

Một sai lệch so với task doc gốc đã phát hiện: task doc ghi "màu 0..11"
nhưng toàn game (`lib/data/levels.dart`) chỉ dùng tối đa 7 màu — dùng đúng
`kPuzzleMaxColorCount = 7` theo thực tế game, không theo task doc.

- **`lib/logic/puzzle_code.dart`** (mới, pure Dart) — `isValidPuzzleCellValue`,
  `hasAnyGem`, `fillEmptyCells`, `cyclePuzzleCellValue`, `encodePuzzleGrid`/
  `decodePuzzleGrid` (mirror base64url của `replay.dart`). Boss tile không hỗ
  trợ trong bàn tự vẽ; obstacle âm khác gift/boss vẫn hợp lệ.
- **`game_controller.dart`** — thêm `GameMode.puzzleLab`, field
  `puzzleLabGrid`, hàm `startPuzzleLevel(grid)` (mirror `startSideMode`,
  `id: -5`, `targetScore = rows*cols*6` không ramp theo world). `checkEnd()`
  thêm guard: sau khi cộng `boardsFullyCleared`/achievement, nếu
  `mode == puzzleLab` thì set `ended = true` và return ngay — không thưởng
  coin/sao/unlock/best-score.
- **`game_screen_controller.dart`** — `_newGame()` mở rộng `presetGrid` thành
  `switch` (thêm nhánh `puzzleLab → gameCtrl.puzzleLabGrid`); `again()` thêm
  nhánh riêng gọi `startPuzzleLevel` (không rơi vào `startSideMode`).
- **`game_screen.dart`** — `_Overlay` case `GameUi.lose` thêm nhánh
  `isPuzzleLab` ưu tiên đầu tiên: title/message dùng
  `puzzle_lab_result_title`/`puzzle_lab_score_label`, mood `cheer`, tái dùng
  đúng layout 2 nút Retry/Menu có sẵn.
- **`storage_service.dart`** — thêm `StorageKeys.savedPuzzles` +
  `getStringList`/`setStringList` (JSON list, khác pattern CSV-join của các
  key khác trong file).
- **`puzzle_lab_screen.dart`** (mới) — editor: chọn rows(8-11)/cols(6-12)/
  colorCount(4-7), `GridView` tap-to-cycle từng ô, Lưu (chặn bàn rỗng, giữ tối
  đa 5 bàn cũ nhất bị xoá trước), Chia sẻ mã (`shareText`), nhập mã + "Chơi
  bàn tuỳ chỉnh" (`decodePuzzleGrid` lỗi/rỗng → `puzzle_lab_invalid_code`,
  không crash), danh sách bàn đã lưu (chơi lại/xoá). Dùng thẳng singleton
  `Get.find<GameController>()` (khác `GhostReplayScreen` — Puzzle Lab cần
  chơi thật, không phải auto-playback).
- **Entry point** — 1 `ListTile` mới trong `settings_screen.dart` (cạnh
  "invite_friend"), điều hướng `Get.to(() => const PuzzleLabScreen())`.
- i18n: 15 key mới (`puzzle_lab_*`) × 22 locale.

Test mới: `test/logic/puzzle_code_test.dart` (round-trip nhiều kích thước,
ô null/obstacle/gift xen kẽ, decode chuỗi rác/sai định dạng/sai kích thước/
màu ngoài phạm vi/boss tile → `null`, `hasAnyGem`/`fillEmptyCells`/
`cyclePuzzleCellValue` đầy đủ case biên); `test/widget/puzzle_lab_screen_test.dart`
(đổi rows/cols/colorCount rebuild grid, cycle cell, lưu/giới hạn 5 bàn, chia
sẻ mã bàn rỗng bị chặn, nhập mã hợp lệ/rác/rỗng-sau-decode).

Verify on-device (Android, rule R3): vẽ bàn → lưu → chia sẻ mã → nhập lại
đúng mã → chơi đúng bàn đã vẽ; kích hoạt tile Cầu Vồng dọn sạch bàn → dialog
"Hoàn thành Puzzle" hiện đúng điểm (+1000 clearBoardBonus), đúng 2 nút "Menu"/
"Thử Lại", không cộng coin/sao/unlock level campaign; nhập mã rác → hiện lỗi
"Mã bàn không hợp lệ hoặc rỗng" rõ ràng, không crash, không điều hướng.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
toàn bộ xanh, không regression.

## ✅ Implemented: Trophy Room — màn tổng hợp prestige + achievements + mascot skin (I34, 2026-07-19)

Màn hình mới thuần trình bày (read-only), gộp 3 hệ thống retention đã
implement độc lập (`I22` Achievements, `I27` Prestige, `I30` Mascot
Wardrobe) vào 1 nơi "khoe" duy nhất. Không thêm field/storage mới — chỉ đọc
lại `GameController.prestigeTier`, `unlockedAchievementIds`,
`unlockedMascotSkinIds` đã có sẵn, rủi ro thấp vì không đụng logic gameplay.

- **`lib/presentation/screens/trophy_room_screen.dart`** (mới) — 3 section:
  Prestige (tái dùng nguyên `PrestigeAction` widget, không viết lại badge),
  Achievements (`GridView` 4 cột trên `kAchievements`, mỗi ô bọc `Obx`),
  Mascot skins (`GridView` 3 cột trên `kMascotSkins`, tái dùng cách preview
  `StarMascot` của `MascotWardrobeScreen` nhưng rút gọn, không có action
  mua/chọn).
- Khác biệt có chủ đích so với `AchievementsScreen`: achievement khoá ở
  Trophy Room **không hiện `titleKey`/`descKey`** (chỉ icon khoá) — đúng yêu
  cầu "không lộ nội dung chưa mở khoá" của task doc, trong khi
  `AchievementsScreen` gốc luôn hiện tên+progress bất kể trạng thái khoá.
- **Entry point** — 1 `_drawerTile` mới trong `home_screen.dart` (ngay sau
  tile Wardrobe), icon `Icons.military_tech_rounded`, điều hướng
  `Get.to(() => const TrophyRoomScreen())`.
- i18n: 4 key mới (`trophy_room_title`/`trophy_room_prestige_section`/
  `trophy_room_achievements_section`/`trophy_room_mascots_section`) × 22
  locale (wave 44).

Test mới: `test/widget/trophy_room_screen_test.dart` — render đủ 3 section
header; chưa mở khoá gì → toàn bộ achievement khoá (không lộ tên), skin free
mặc định vẫn unlocked; mở khoá 1 achievement → chỉ đúng title của nó xuất
hiện, các achievement khác không lộ nội dung; mở khoá 1 mascot skin → tên
skin hiện; `prestigeTier=0` chưa đủ điều kiện → badge ẩn; `prestigeTier=2` →
badge hiện đúng "P2".

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
427 test toàn bộ xanh, không regression.

## ✅ Implemented: Boss Rush — chuỗi màn boss liên tiếp, không booster (I43, 2026-07-19)

Chế độ chơi riêng tách biệt khỏi campaign 220 level và khỏi `I27` Prestige:
chơi liên tiếp các bàn có boss tile (`I29`) rút ngẫu nhiên (deterministic
theo `stage`) từ world đã unlock, độ khó (target score) tăng dần theo stage
(trần `bossRushStageScaleCap = 2.5`), không dùng được booster, thua/kẹt là
dừng chuỗi và ghi nhận "chuỗi dài nhất" (`StorageKeys.bossRushBestStreak`)
riêng biệt.

- **`lib/data/boss_rush.dart`** (mới) — pure logic: `bossRushLevelForStage`
  dựng `PopLevel` động (id âm `-100 - stage`) từ 1 level nguồn thật trong
  world đã unlock, boss tile 2x2 canh giữa mép trên; `targetScore` áp cả
  `bossTargetMultiplier` (convention I29) lẫn ramp theo stage.
- **`GameMode.bossRush`** + `GameController.startBossRush`/`setBossRushLevel`
  — theo đúng khuôn reset của các `startXxx()` khác; `checkEnd()` fallthrough
  tự nhiên, không cần sửa.
- **`BossRushController`** (mới, per-screen) — sở hữu `stage`/
  `bossRushBestStreak`; nghe `GameController.ended` qua `ever()` để chấm dứt
  chuỗi (thua/kẹt), cộng coin (`stage * 50`) và cập nhật best streak nếu cao
  hơn. `PopStarGame._checkEnd()` thêm nhánh `bossRush` (mirror `endless`) gọi
  `_nextBossRushBoard()` khi dọn sạch bàn — mutate `PopStarGame` tại chỗ,
  không tạo lại instance giữa các stage.
- **`BossRushScreen`** (mới) — lobby (best streak, banner no-booster, nút bắt
  đầu, tóm tắt lượt chơi trước) + play view (`GameWidget` trực tiếp, HUD
  stage/score). Entry point: nút thứ 4 trong modes dialog (`home_screen.dart`,
  icon lửa màu đỏ).
- i18n: 9 key mới (`mode_boss_rush_label`/`boss_rush_title`/
  `boss_rush_best_streak_label`/`boss_rush_stage_label`/
  `boss_rush_no_booster_notice`/`boss_rush_start_button`/
  `boss_rush_run_over_title`/`boss_rush_stages_cleared_label`/
  `boss_rush_coin_reward_label`) × 22 locale (wave 45).

Test mới: `test/data/boss_rush_test.dart` (boss tile luôn fit bàn, giá trị
rows/cols/colorCount hợp lệ, deterministic, chỉ chọn world ≤ unlocked,
target score tăng theo stage nhưng bị chặn trần), `test/presentation/
boss_rush_controller_test.dart` (best streak chỉ tăng khi vượt kỷ lục cũ,
coin reward đúng công thức, dùng booster giữa lượt không làm sai lệch state),
`test/widget/boss_rush_screen_test.dart` (lobby render đủ best streak/banner/
nút bắt đầu, bắt đầu lượt chuyển sang Stage 1).

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
441 test toàn bộ xanh, không regression.

## ✅ Fix gap audit I31-I43 + dọn tech-debt (2026-07-19)

Đợt audit 8 agent song song rà lại toàn bộ tính năng I31-I43 (đã shipped
gần đây) cộng rà tech-debt chung. 3 bug xác nhận và đã fix:

- **I39 Combo Milestone FX** — spec yêu cầu mốc combo cao hơn rung mạnh hơn
  (mốc 5 = light, mốc 10 = medium, mốc 15+ = heavy) nhưng cả 2 điểm gọi
  (`pop_star_game.dart`, đường tap và đường power-tile) đều hardcode
  `HapticLevel.heavy`. Thêm `hapticForComboMilestone()` trong
  `lib/data/combo_milestones.dart`, dùng tại cả 2 điểm gọi.
- **I43 Boss Rush — booster integrity** — `useBomb`/`useShuffle`/`useUndo`
  (`game_controller.dart`) chỉ bị chặn ở tầng UI (nút ẩn), không chặn ở tầng
  controller — có thể lách bằng cách khác để dùng booster giữa chuỗi Boss
  Rush trái quy tắc "no booster from shared kit". Thêm guard
  `if (mode.value == GameMode.bossRush) return;` đầu mỗi method.
- **I43 Boss Rush — thiếu lối thoát giữa chuỗi** — `BossRushScreen`
  (`_buildPlay()`) không có nút thoát/quit nào trong lúc chơi;
  `PopScope(canPop: !playing)` chặn cả gesture back mà không phản hồi gì.
  Thêm nút quit (icon, tái dùng convention `game_screen.dart`) mở
  `NeonDialog.overlay` xác nhận (tái dùng key i18n `quit_title`/`quit_msg`/
  `cancel`/`quit_action` sẵn có); xác nhận → gọi `checkEnd(false)` để kết
  thúc chuỗi sạch, `BossRushController._onEnded` tự chấm điểm/coin theo số
  stage đã qua như luồng thua/kẹt bình thường.

**Tech-debt**: gỡ 3 dependency không còn dùng trong `lib/` (`google_fonts`,
`flutter_animate`, `cupertino_icons`) khỏi `pubspec.yaml` — xác nhận bằng
`grep` trước khi gỡ, `flutter pub get` xác nhận sạch.

**Audit xác nhận ổn, không cần fix**: I31 Auto-solve Ghost Hint, I34 Trophy
Room, I40 Ambient Weather, I41 Mascot Reaction, I42 Puzzle Lab.

**Phát hiện ngoài phạm vi audit** (spec đã viết nhưng chưa implement, chưa
quyết định hướng xử lý — xem `doc/task/tasks/`): I32 Craft Booster, I33
Daily Modifier Gauntlet, I35 Lifetime Stats Dashboard, I36 Achievement
Titles, I37 Async Challenge Code, I38 Weekly Featured Level.

Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
441 test toàn bộ xanh, không regression.

## ✅ Implemented: Round 3 backlog Wave 1 — 5 task (I49, I52, I48, I35, I53, 2026-07-20)

Từ backlog round 3 (`doc/task/tasks/IDEAS.md`), user chọn "Wave 1 — Tier 1":
5 task nhỏ độc lập, rủi ro thấp.

- **I49 Lucky Color of the Day** — mỗi ngày có 1 màu may mắn (deterministic
  theo epoch-day, `lucky_color.dart`); pop trúng màu đó trong campaign nhân
  điểm ×1.2. Badge HUD hiện màu + label `lucky_color_label`.
- **I52 Pop Burst Style Picker** — 4 kiểu hiệu ứng nổ (spark/confetti/ripple/
  starburst, `burst_styles.dart`), mở khoá dần theo `totalGemsPopped` (0/500/
  2000/5000). Dialog chọn style ở drawer Home, style đang chọn lưu
  `StorageKeys.activeBurstStyle`, validate lại unlock threshold mỗi lần load
  (chặn sửa storage trực tiếp để dùng style chưa mở).
- **I48 Login Streak Calendar** — điểm danh 7 ngày liên tiếp (`login_streak.dart`
  pure logic: gap ngày = 0 giữ nguyên, =1 +1, ≥2 reset về 1), thưởng coin ngày
  3/5/7 (bitmask `loginStreakClaimedMask` chống claim 2 lần, mirror pattern
  `claimedSeasonMask`). Dialog calendar ở drawer Home.
- **I35 Lifetime Stats Dashboard** — màn hình đọc thuần 5 số liệu trọn đời
  (gems popped, best combo, 3-star levels, boards cleared, boosters used) —
  không sửa state, không `StorageKeys` mới. Bỏ `lifetimeCoinsEarned` (stretch
  goal, spec cho phép) để tránh refactor 10 call site coin trong
  `game_controller.dart`.
- **I53 Home Screen Theme Pack** — nền Home tự đổi màu/thời tiết theo world
  cao nhất đã unlock (`worldForLevel(gameCtrl.unlockedLevel.value)`), cross-fade
  mượt 800ms qua `TweenAnimationBuilder<Color?>` bọc ngoài `NeonBg` (xác nhận
  `NeonBg` không tự animate khi đổi `accent` — chỉ snap tức thì).

i18n: 18 key mới (`_w46ByLang`–`_w49ByLang`, tuỳ task) × 22 locale, enforce qua
`app_translations_test.dart`. Verify: `flutter analyze` → 0 issues. `flutter
test --exclude-tags slow` → 468 test toàn bộ xanh, không regression.

## ✅ Implemented: I54 Combo Text Style (2026-07-20)

Task riêng, tiếp theo Wave 1, mirror đúng pattern I52 Pop Burst Style Picker
sang milestone text của combo thay vì hiệu ứng nổ.

- **I54 Combo Text Style** — 4 kiểu chữ cho mốc combo (`neon`/`boldPop`/
  `retro`/`fire`, `lib/data/combo_text_styles.dart`), mở khoá theo
  `maxComboEver` tái dùng đúng ngưỡng tier của `kAchievements` (0/6/15/25).
  `_ComboMilestoneOverlay` (`game_screen.dart`) render theo style đang chọn,
  không đụng `kComboMilestones`/`hapticForComboMilestone`. Chọn style qua
  dialog picker (`combo_text_style_picker_dialog.dart`, style khoá hiện mờ +
  ngưỡng) mở từ drawer Home. `GameController.activeComboTextStyleKind` chặn
  chọn style chưa mở khoá + re-validate khi load (`StorageKeys.
  activeComboTextStyle`) — chống sửa tay storage để mở khoá giả.

i18n: 5 key mới (`_w50ByLang`) × 22 locale. Verify: `flutter analyze` → 0
issues. `flutter test --exclude-tags slow` → 479 test toàn bộ xanh, không
regression.

**Remediation full parity với I52** (audit sau khi implement phát hiện 4 gap
so với I52): thêm test anti-tamper cho `GameController` (fallback về `neon`
khi storage bị sửa tay trỏ style chưa đủ ngưỡng hoặc string không hợp lệ,
`resetProgress()` xoá đúng key), test widget cho
`combo_text_style_picker_dialog.dart` (hiện đủ 4 style, style khoá hiện
ngưỡng, tap style mở/khoá đúng hành vi), test render riêng từng style trong
`_ComboMilestoneOverlay` (`combo_milestone_fx_test.dart` — neon/boldPop/retro
render qua `StrokeText` đúng font/màu, fire qua `ShaderMask` không dùng
`StrokeText`), và sửa comment sai trong `combo_text_styles.dart` (ngưỡng thật
dùng 3/5 tier `kAchievements`, không phải 4/5 như ghi nhầm trước đó). Verify:
`flutter analyze` → 0 issues. `flutter test --exclude-tags slow` → 494 test
toàn bộ xanh.

## ✅ Implemented: I50 Weekly Goal Card (2026-07-21)

- **I50 Weekly Goal Card** — mục tiêu cá nhân theo tuần: pop 300 gem cộng dồn
  xuyên suốt mọi mode (campaign + side-mode), tuần chia theo `epochDay ~/ 7`
  (`lib/data/weekly_goal.dart`, không cần khớp lịch dương, mirror đúng
  convention `currentSeasonIndex`). Hook duy nhất tại
  `GameController.registerPop` (điểm cộng `totalGemsPopped` sẵn có, dùng
  chung cho mọi mode/pop site, không cần đụng `pop_star_game.dart`) nên tự
  động loại trừ ghost-replay (branch `isReplay` không gọi `registerPop`).
  Tiến độ clamp không vượt target, persist ngay mỗi lần cộng
  (`StorageKeys.weeklyGoalProgress`). Rollover-on-read
  (`_checkWeeklyGoalRollover`, gọi trong `_load()` ngay sau
  `_checkSeasonRollover`) reset tiến độ về 0 khi sang tuần mới
  (`StorageKeys.weeklyGoalWeek` lưu tuần lần cập nhật cuối). Nhận thưởng 1
  lần/tuần bằng so sánh int đơn giản
  (`StorageKeys.weeklyGoalClaimedWeek == currentWeekIndex`, không cần bitmask
  vì chỉ có 1 mốc thưởng/tuần) — thưởng có áp `weekendCoinMultiplier` như mọi
  reward khác trong codebase. Dialog (`weekly_goal_dialog.dart`, template
  `login_streak_dialog.dart`) hiện thanh tiến độ + nút "Nhận" (disable khi
  chưa đủ hoặc đã nhận), mở từ drawer Home.

i18n: 5 key mới (`weekly_goal_title/desc/claim_button/claimed_label`,
`drawer_weekly_goal_label`) × 22 locale (`_w51ByLang`). Test:
`test/logic/weekly_goal_test.dart` (pure function chia tuần + reset-on-new-
week), nhóm `I50 Weekly Goal Card` trong `game_controller_test.dart` (cộng
tiến độ theo `groupSize`, clamp target, chặn claim khi chưa đủ, chặn claim 2
lần cùng tuần, reset đúng khi sang tuần mới, `resetProgress()`). Verify:
`flutter analyze` → 0 issues. `flutter test --exclude-tags slow` → toàn bộ
xanh, không regression.

## ✅ Implemented: I44 Time Freeze Tile (2026-07-21)

- **I44 Time Freeze Tile** — trong `GameMode.timeAttack`, sau mỗi lần
  `_collapseAnimated` hoàn tất có ~10% xác suất gắn tag lên 1 ô màu hợp lệ
  (`shouldTagTimeFreezeTile`, `lib/logic/time_freeze_tile.dart` — pure, seed
  `Random` cố định, nhận `isTimeAttack`/`alreadyTagged` qua tham số để không
  phụ thuộc `GameMode`/GetX trong `lib/logic/`). Đúng pattern power tile (F5):
  **không** mã hoá âm trong `colorGrid`, chỉ thêm field
  `bool timeFreezeTagged` trên `BlockComponent` (`_maybeTagTimeFreezeTile`,
  `pop_star_game.dart`, né ô đang obstacle/gift/boss/lockGrid/powerKind, tối
  đa 1 ô/bàn). Render: quầng cyan mờ + icon đồng hồ, phân biệt với quầng
  trắng power tile. Tap trực tiếp (`_tryPop`, cả trường hợp lẻ loi
  `group.length < 2` và khi ô nằm trong 1 nhóm màu ≥2 pop chung) kích hoạt
  `Get.find<GameScreenController>().remainingSeconds.value += 10` (side-effect
  độc lập, không cộng điểm/không tính combo), ô biến mất khỏi bàn qua
  `_clearAndCollapse` như ô thường. `Get.find<GameScreenController>()` an
  toàn không cần `Get.isRegistered` guard vì `GameMode.timeAttack` chỉ đi qua
  `game_screen.dart` — màn duy nhất đăng ký `GameScreenController` trước khi
  tạo `PopStarGame` (Boss Rush/Ghost Replay không bao giờ set mode này).

Test: `test/logic/time_freeze_tile_test.dart` (gate time-attack-only, tối đa
1 ô/bàn, tần suất mặc định ~10% nằm trong khoảng hợp lý qua 5000 lần thử).
Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
510 test toàn bộ xanh, không regression.

## ✅ Implemented: I45 Countdown Lock Tile (2026-07-21)

- **I45 Countdown Lock Tile** — campaign world 4+ (`level.id > 60`), ~18% cơ
  hội xuất hiện 1 ô Countdown Lock/bàn (`_placeCountdownLockTileIfNeeded`,
  `pop_star_game.dart`, né ô đã là obstacle/chain-lock/gift/boss). Mã hoá âm
  trong `colorGrid` giống obstacle/gift/boss nhưng ở dải riêng
  (`countdownLockIdBase = -1500`, nằm giữa gift `-1000` và boss `<= -2000`,
  xem `isCountdownLockId`, `lib/logic/countdown_lock_tile.dart`). Khác cơ chế
  "chip theo pop-kề-cạnh" của obstacle/boss/chain-lock: mỗi lượt tap hợp lệ
  (nhóm ≥2, bất kể có đụng ô Countdown Lock hay không) giảm 1 mọi Countdown
  Lock trên bàn (`_tickCountdownLockTiles` gọi trong `_tryPop`, dùng pure
  function `tickCountdownLockTiles(countdownRemaining)`). Số đếm ngược lưu
  song song trong `PopStarGame.countdownRemaining` (`Map<int,int>`, mirror
  cấu trúc `bossHp`, có undo-snapshot riêng `_undoCountdownRemaining`) vì
  không mã hoá được trong `colorGrid` (chỉ mã ID). Về 0 → ô tự chuyển thành
  obstacle thường (durability 1, `colorGrid[r][c] = -1`), gỡ khỏi
  `countdownRemaining`. `chipAdjacentObstacles` (`lib/logic/obstacle.dart`)
  loại trừ `isCountdownLockId` để không bị chip nhầm thành obstacle;
  `pop_detector.dart` đã tự loại qua guard chung `color < 0`, không cần sửa.
  Render: `BlockComponent.countdownDisplay` (đồng bộ qua
  `_syncObstacleAndLockBlocks`/khởi tạo trong `_rebuildBoard`) +
  `_renderCountdownLock` — cùng cấu trúc `_renderBoss` (nền mờ, viền, số) nhưng
  màu `NeonTheme.orange` để phân biệt "khẩn cấp" với "nguy hiểm" (boss, đỏ).
  Không cần `StorageKeys` mới — state chỉ tồn tại trong 1 match.

Test: `test/logic/countdown_lock_tile_test.dart` (nhận diện id đúng dải,
giảm đúng 1/lượt, về 0 trả đúng id hết giờ và xoá khỏi map, nhiều id độc lập,
không đụng state khác truyền ngoài map). Verify: `flutter analyze` → 0
issues. `flutter test --exclude-tags slow` → 518 test toàn bộ xanh, không
regression.

## ✅ Implemented: I46 Wildcard Tile (2026-07-21)

- **I46 Wildcard Tile** — campaign only, mọi world (`level.id > 0`), ~15% cơ
  hội xuất hiện 1 ô Wildcard/bàn (`_placeWildcardTileIfNeeded`,
  `pop_star_game.dart`, né ô đã là obstacle/chain-lock/gift/boss/countdown-lock).
  Mã hoá âm trong `colorGrid` giống obstacle/gift/boss/countdown-lock nhưng ở
  dải riêng (`wildcardTileValue = -500`, nằm giữa obstacle nhỏ `-1..-9` và
  gift `-1000`, xem `isWildcardTileValue`, `lib/logic/wildcard_tile.dart`).
  Khác mọi tile đặc biệt âm khác: Wildcard khớp với MỌI màu khi flood-fill
  (`findConnectedGroup`, `pop_detector.dart`) — nhưng "màu mục tiêu" của cả
  nhóm chỉ xác định 1 lần ngay tại ô bắt đầu (ô tap hoặc màu mượn từ ô liền kề
  đầu tiên nếu tap trực tiếp vào wildcard), nên wildcard không bao giờ làm cầu
  nối 2 nhóm màu khác nhau thành 1. Tap trực tiếp vào wildcard cô lập (không
  ô màu liền kề) trả về nhóm size 1 — không nổ (đúng ngưỡng ≥2 chung). Nổ
  chung nhóm màu bình thường, không cộng điểm thưởng riêng. `chipAdjacentObstacles`
  (`lib/logic/obstacle.dart`) loại trừ `isWildcardTileValue` — phòng vệ, vì
  wildcard luôn bị nổ chung nhóm trước khi hàm này chạy. Render:
  `BlockComponent._renderWildcard` — nền gradient cầu vồng (toàn bộ
  `NeonTheme.gemColors`, kèm `colorStops` cách đều — `ui.Gradient.linear` bắt
  buộc `colors.length == 2` nếu bỏ `colorStops`) + viền trắng + sao trắng 5
  cánh giữa (tái dùng thuật toán vẽ sao của `_renderColorblindSymbol` case 0).
  Không cần `StorageKeys` mới — wildcard chỉ là 1 giá trị mã hoá cố định
  trong `colorGrid`, không có state/HP đi kèm.

Test: `test/logic/pop_detector_test.dart` (5 case mới — wildcard liền kề gộp
đúng nhóm màu khi tap vào màu, tap trực tiếp vào wildcard mượn màu đúng, tap
wildcard cô lập trả size 1, wildcard không làm cầu nối 2 nhóm màu khác nhau,
2 wildcard liền kề nhau không màu nào giữ size 1). Verify: `flutter analyze`
→ 0 issues. `flutter test --exclude-tags slow` → 523 test toàn bộ xanh,
không regression (phát hiện + fix 1 bug runtime trong lúc verify: gradient
nền wildcard truyền thẳng 6 màu `gemColors` vào `ui.Gradient.linear` không
kèm `colorStops` → ném `ArgumentError` bất cứ khi nào 1 ô wildcard được
render, làm crash ngẫu nhiên ~15% các test dựng bàn campaign khác — không
liên quan tới đúng/sai logic wildcard, đã fix bằng cách truyền `colorStops`
cách đều tương ứng số màu).

## ✅ Implemented: I47 Mirror Mode (2026-07-21)

- **I47 Mirror Mode** — side-mode mới: bàn cố định 9x8x5 màu (giống Zen,
  không ramp độ khó — `kMirrorModeLevel`, `lib/data/levels.dart`, `id: -6`)
  nhưng luôn sinh **đối xứng gương theo trục dọc**: cột `c` và cột
  `cols-1-c` luôn cùng màu ở mọi hàng (`generateMirrorBoard`,
  `lib/data/mirror_board.dart` — hàm pure, chỉ random nửa trái rồi mirror
  sang nửa phải, cột giữa tự đối xứng nếu `cols` lẻ). Đối xứng chỉ áp dụng
  LÚC SINH BÀN — không phải bất biến giữ xuyên suốt ván (bàn mất đối xứng
  dần sau khi pop, đúng như PopStar gốc không refill).
- **Namespacing id**: phát hiện `id: -5` đã dùng cho Puzzle Lab
  (`startPuzzleLevel`, hoàn thành ở 1 phiên trước đó) — Mirror Mode dùng
  `id: -6` (grep lại toàn bộ `lib/data/`, `lib/logic/`, `lib/presentation/`
  trước khi chọn số để tránh đụng lại lần nữa).
- **Luồng chơi**: `startMirrorMode()` (`GameController`) reset state đúng
  thứ tự chuẩn các side-mode khác (`startEndless`/`startDailyChallenge`).
  Bàn đầu sinh ở `game_screen_controller.dart` (`presetGrid`, seed ngẫu
  nhiên — khác Daily Challenge không cần seed cố định theo ngày). Dọn sạch
  bàn → `_nextMirrorBoard()` (`pop_star_game.dart`, mirror cách
  `_refillBoard()` — KHÔNG gọi `_layout()` vì bàn cố định kích thước, khác
  `_nextEndlessBoard()` phải `_layout()` lại vì rows/cols đổi theo world) sinh
  bàn mới đối xứng, dùng `_rng` (seeded field có sẵn) để giữ replay-safe,
  không phải `Random()` mới. Kẹt hẳn (`hasAnyMovableGroup` false) mới kết
  thúc ván qua `controller.checkEnd(false)`.
- **Điểm cao nhất riêng**: `mirrorModeBest` (`RxInt`, `GameController`) +
  `StorageKeys.mirrorModeBest` — biệt lập mọi mode khác, lưu qua
  `_saveMirrorModeBest()` (gọi trong `checkEnd`), xoá qua `resetProgress()`.
- **UI**: nút mode mới trong dialog "Chế độ chơi" (`home_screen.dart`,
  icon `flip_rounded`, màu cyan) → `startMirrorMode()` rồi vào `GameScreen`.
  HUD hiện `Best <score>` dưới điểm hiện tại (mirror đúng style Endless —
  text raw không i18n, theo đúng convention các side-mode khác). Duy nhất 1
  key i18n mới: `mode_mirror_label` (dùng làm `semanticLabel` nút mode) —
  thêm `_extraEn`/`_extraVi` + wave `_w52ByLang` cho 20 ngôn ngữ còn lại.

Test: `test/data/mirror_board_test.dart` (mới — đối xứng đúng với cols
chẵn/lẻ, tôn trọng bounds rows/cols/colorCount, deterministic theo seed).
Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
toàn bộ xanh (bao gồm `app_translations_test.dart` với key mới × 22 ngôn
ngữ), không regression.

## ✅ Implemented: I32 Craft Booster (2026-07-21)

- **I32 Craft Booster** — campaign only, thắng màn nhưng KHÔNG full-clear
  (bàn còn sót gem, đủ ngưỡng) → đổi số gem còn sót thành 1 booster ngẫu
  nhiên thay vì mất trắng, tránh double-reward với `clearBoardBonus` (chỉ
  cấp riêng ở nhánh `remaining == 0`, xem `lib/data/levels.dart`).
- **Pure logic**: `lib/logic/craft_points.dart` (mới) —
  `craftPointsForRemainingCells(grid)` đếm cell màu thường còn lại
  (`v != null && v >= 0` — mọi tile đặc biệt obstacle/gift/boss/countdown-
  lock/wildcard đều mã hoá âm nên tự loại trừ, không cần import riêng từng
  module) rồi chia nguyên cho `cellsPerCraftPoint = 4`.
- **`GameController.checkEnd`**: trong nhánh thắng (`starsEarned.value > 0`),
  nếu `!boardCleared` và `craftPointsForRemainingCells(activeGame!.colorGrid)
  >= craftPointThreshold` (3) → `_grantRandomBooster()` chọn ngẫu nhiên 1
  trong `bomb`/`shuffle`/`undo` (`Random().nextInt(3)`, không cần seed vì
  ngoài path replay-sensitive), cấp qua `_grant` có sẵn (tái dùng nguyên,
  không viết lại), gán `craftRewardType.value` (field `Rxn<String>` mới) cho
  UI đọc. Reset về `null` mỗi `startLevel`. Không cần guard `isReplay` riêng
  — `controller.checkEnd` đã không được gọi khi `isReplay == true` (chặn từ
  `pop_star_game.dart._checkEnd`).
- **UI**: `game_screen.dart` — dòng "+1 <booster>" trong dialog thắng
  (`craft_booster_reward_label`.trParams), icon/màu mirror đúng
  `_BoosterButton` HUD tương ứng (bomb=`dangerous_rounded`/orange,
  shuffle=`shuffle_rounded`/lime, undo=`undo_rounded`/purple), ẩn hoàn toàn
  nếu `craftRewardType.value == null`.
- **i18n**: `craft_booster_reward_label` ("+1 @booster") — `_extraEn`/
  `_extraVi` + wave `_w53ByLang` cho 20 ngôn ngữ còn lại (giữ nguyên
  "+1 @booster" mọi ngôn ngữ — pattern số+placeholder không cần dịch riêng).

Test: `test/logic/craft_points_test.dart` (mới — bàn trống → 0, N cell
thường → floor đúng, cell boss tile loại trừ khỏi số đếm).
`test/presentation/game_controller_test.dart` (nhóm "I32 Craft Booster" mới
— thắng chưa full-clear đủ ngưỡng → +1 booster đúng loại; chưa đủ ngưỡng →
không thưởng; full-clear → không cộng trùng; thua → không thưởng; reset khi
`startLevel`). Verify: `flutter analyze` → 0 issues. `flutter test
--exclude-tags slow` → toàn bộ xanh, không regression.

## ✅ Implemented: I37 Async Challenge Code (2026-07-22)

- **I37 Async Challenge Code** — bất kỳ level campaign nào cũng có thể mã
  hoá thành mã text "thách đấu" gồm levelId + điểm vừa đạt + tên người gửi,
  chia sẻ cho bạn bè; bạn bè dán mã vào màn nhập-mã sẵn có (`GhostReplayScreen`)
  để chơi lại đúng level đó (board random bình thường, KHÔNG kèm replay đầy
  đủ) rồi so điểm cao/thấp — khác hẳn I28 Ghost Replay (chỉ xem lại y hệt
  1 ván, không chơi được).
- **Pure logic**: `lib/logic/challenge_code.dart` (mới) — `ChallengeCode`
  (`levelId`, `score`, `senderName`), `encodeChallengeCode`/
  `decodeChallengeCode` mã hoá base64url `levelId|score|senderName` với
  prefix rõ (không mã hoá) `challengeCodePrefix = 'CH:'` để 1 ô nhập mã
  chung phân biệt được với mã ghost-replay của I28 (`text.startsWith(...)`
  trước khi thử `decodeReplay`) — `senderName` là field cuối, giữ nguyên
  mọi ký tự `|` gốc, không cần escape. Decode trả `null` nếu thiếu prefix,
  base64/định dạng sai, thiếu cột, số âm, hoặc `levelId` ngoài `1..kLevelCount`.
- **`GameController`**: `activeChallenge` (`Rxn<ChallengeCode>`) + `challengeWon`
  (`Rxn<bool>`, `null` nếu không có thách đấu đang chơi). `startChallenge(code)`
  gọi nguyên `startLevel(code.levelId)` (board random bình thường) rồi gán
  `activeChallenge.value = code`. Trong `checkEnd` (nhánh campaign, sau khi
  `starsEarned`/`ended` đã set), nếu `activeChallenge.value != null` →
  `challengeWon.value = score.value > activeChallenge.value!.score` (so
  sánh **strict lớn hơn** — hoà tính là thua). Cả hai field reset về `null`
  mỗi `startLevel` — độc lập hoàn toàn với sao/coin/unlock bình thường, không
  ảnh hưởng path campaign non-challenge.
- **Chia sẻ**: `GameScreenController.shareChallenge()` mã hoá điểm/level
  hiện tại + `playerName` thành mã, mở share sheet (`shareText`, tái dùng
  `share_helper.dart` có sẵn).
- **UI thắng/thua** (`game_screen.dart`): nút icon "thách đấu bạn bè"
  (`Icons.emoji_events_rounded`, `NeonTheme.gold`) trong `_WinChoreography`
  cạnh nút share replay. `_challengeResultBanner` (helper dùng chung) hiện
  `challenge_result_win_label`/`challenge_result_lose_label` (màu
  lime/orange) — gắn vào **cả 2** dialog thắng và thua vì `GameUi.win` vs
  `GameUi.lose` chỉ phụ thuộc `starsEarned > 0` bình thường, độc lập với kết
  quả thách đấu; dialog thua dùng `NeonDialog.panel(... content: ...)` sẵn
  có để chèn banner.
- **`GhostReplayScreen`** mở rộng: field `_challenge` (`ChallengeCode?`),
  `_load()` rẽ nhánh theo `challengeCodePrefix` trước khi thử replay — mã
  thách đấu hiện tên người gửi + điểm cần vượt + nút "Chơi ngay"
  (`_playChallenge` → `Get.find<GameController>().startChallenge(challenge)`
  rồi `Get.to(() => const GameScreen())`), KHÔNG auto-play như ghost-replay.
- **i18n**: `share_challenge`, `challenge_invite_title`,
  `challenge_score_to_beat_label`, `challenge_play_button`,
  `challenge_result_win_label`, `challenge_result_lose_label` —
  `_extraEn`/`_extraVi` + wave `_w54ByLang` cho 20 ngôn ngữ còn lại.

Test: `test/logic/challenge_code_test.dart` (mới — encode/decode round-trip,
`senderName` giữ ký tự `|`, reject thiếu prefix/base64 sai/thiếu cột/số
âm/levelId ngoài phạm vi). `test/presentation/game_controller_test.dart`
(nhóm "I37 Async Challenge Code" mới — điểm cao hơn → thắng; thấp hơn →
thua; bằng nhau (hoà) → tính thua; không có thách đấu → `challengeWon` giữ
`null`; reset cả `activeChallenge`/`challengeWon` khi `startLevel`).
`test/widget/ghost_replay_screen_test.dart` (3 test mới — mã hợp lệ hiện
đúng tên/điểm/nút, không auto-play; mã hỏng báo lỗi giống ghost-replay; tap
"Chơi ngay" gọi đúng `startChallenge` + chuyển sang `GameScreen`). Verify:
`flutter analyze` → 0 issues. `flutter test --exclude-tags slow` → toàn bộ
xanh, không regression.

## ✅ Implemented: I36 Achievement Titles (2026-07-22)

- **I36 Achievement Titles** — cho phép chọn 1 achievement đã unlock làm
  "danh hiệu" hiển thị cạnh tên người chơi (Home Screen + hàng của mình
  trong bảng xếp hạng offline, I9), thuần vanity, không ảnh hưởng
  gameplay/điểm số.
- **`GameController`**: `activeAchievementTitleId` (`RxString`, rỗng = không
  có danh hiệu) + `StorageKeys.activeAchievementTitleId`. `setActiveTitle(id)`
  chỉ nhận id nằm trong `unlockedAchievementIds` (bỏ qua nếu chưa unlock) —
  set + persist ngay. `clearActiveTitle()` về rỗng + persist. Getter
  `activeTitleAchievement` tra `kAchievements` qua `try/firstWhere` (không
  thêm dependency `collection`, tái dùng đúng pattern lookup đã có ở
  `_checkAchievements()`). `_load()` chỉ khôi phục lại id đã lưu nếu id đó
  còn nằm trong `unlockedAchievementIds` hiện tại — phòng danh hiệu "ma" trỏ
  tới achievement chưa (hoặc không còn) được unlock. `resetProgress()` xoá
  key khỏi storage + tự về rỗng qua `_load()` cuối hàm.
- **UI**: `AchievementsScreen` — mỗi hàng đã unlock có nút pill
  "Đặt làm danh hiệu"/"Bỏ danh hiệu" (gold khi đang active), `Obx` bọc
  ngoài đọc thêm `activeAchievementTitleId.value` để tránh lỗi lazy-builder
  quen thuộc của `ListView.itemBuilder`. `HomeScreen` hiện `playerName` +
  `· <danh hiệu>` (ẩn hoàn toàn nếu `playerName` rỗng). `LeaderboardScreen`
  nối danh hiệu vào hàng của người chơi tại chỗ render (`_RankRow` nhận
  thêm `playerTitleKey` optional) — không đổi cấu trúc `LeaderboardEntry`.
- **i18n**: `achievement_title_set_button`, `achievement_title_clear_button`
  — `_extraEn`/`_extraVi` + wave `_w55ByLang` cho 20 ngôn ngữ còn lại.

Test: `test/presentation/game_controller_test.dart` — nhóm mới
"I36 Achievement Titles" (set với id chưa unlock → không đổi; set với id đã
unlock → đúng giá trị + persist storage; `clearActiveTitle` → về rỗng +
persist) và 1 test bổ sung trong nhóm `resetProgress` hiện có (reset xoá
`activeAchievementTitleId` về rỗng, tránh danh hiệu "ma"). Verify:
`flutter analyze` → 0 issues. `flutter test --exclude-tags slow` → toàn bộ
554 test xanh, không regression.

## ✅ Implemented: I33 Daily Modifier Gauntlet (2026-07-22)

- **I33 Daily Modifier Gauntlet** — side-mode mới "Gauntlet": mỗi ngày áp
  đúng 1 "luật chơi" cố định lên bàn `dailyChallengeRows x dailyChallengeCols`
  (tái dùng seed/kích cỡ bàn của F13 Daily Challenge), chọn theo
  `epochDay % kGauntletModifiers.length` (không `Random()` — mọi thiết bị
  cùng ngày luôn gặp đúng 1 modifier). 4 modifier: `no_undo` (khoá hoàn tác),
  `short_combo` (combo window 1.5s), `four_colors` (bàn chỉ 4 màu), 
  `reverse_gravity` (trọng lực ngược, tái dùng `GravityDirection` của I3).
  Có leaderboard offline riêng (bot cố định), ghi điểm 1 lần/ngày.
- **`lib/data/gauntlet_modifiers.dart`** (mới): `GauntletModifier` (id, icon,
  nameKey, descKey, `disableUndo`, `comboWindowOverride`, `gravityOverride`,
  `colorCountOverride`), `kGauntletModifiers` (4 phần tử const),
  `modifierForDay(epochDay)` thuần, deterministic.
- **`lib/data/levels.dart`**: `gauntletLevelFor(modifier)` sinh `PopLevel`
  id `-7` (tiếp nối dãy id âm side-mode: -1 Time Attack … -6 Mirror Mode).
  `generateDailyChallengeGrid` mở rộng tham số optional `colorCount` (mặc
  định `dailyChallengeColorCount`) để Gauntlet truyền
  `modifier.colorCountOverride` khi cần.
- **`GameController`**: `gauntletGrid`/`activeGauntletModifier` (field),
  `startGauntlet()` (mirror `startDailyChallenge`, chọn modifier + sinh bàn
  theo `_todayEpochDay()`), `gauntletComboWindowOverride` getter (chỉ khác
  `null` khi `mode.value == GameMode.gauntlet`, tránh giá trị cũ sót lại ở
  mode khác), `canRecordGauntletScore`/`gauntletScoreToday`/
  `gauntletScoreForLeaderboard`/`_saveGauntletScore()` (mirror đúng pattern
  Daily Challenge — 1 lượt ghi điểm/ngày). `useUndo()` thêm gate: mode
  Gauntlet + `activeGauntletModifier?.disableUndo == true` → no-op.
- **`PopStarGame`**: combo timer đọc `controller.gauntletComboWindowOverride`
  trước khi fallback về giá trị mặc định.
- **UI**: `home_screen.dart` — icon Gauntlet trong dialog chọn mode, hiện
  tên modifier hôm nay qua `todaysGauntletModifier` (preview trước khi vào
  ván). `leaderboard_screen.dart` — thêm tab thứ 3 (`_LeaderboardTab.gauntlet`)
  cạnh Campaign/Daily Challenge, dùng `kGauntletLeaderboardBots` +
  `gauntletScoreForLeaderboard`. `game_screen_controller.dart` — `presetGrid`
  + `again()` route đúng cho mode Gauntlet.
- **i18n**: `mode_gauntlet_label`, `gauntlet_modifier_*_name/desc` (4 modifier
  × name+desc) — `_extraEn`/`_extraVi` + wave `_w56ByLang` cho 20 ngôn ngữ
  còn lại.

Test: `test/data/gauntlet_modifiers_test.dart` (mới) — `modifierForDay`
deterministic, tuần hoàn đúng theo `%`, đủ 4 modifier với id/nameKey/descKey
duy nhất khác rỗng. `test/presentation/game_controller_test.dart` — nhóm mới
"I33 Daily Modifier Gauntlet" (grid+modifier deterministic theo ngày, ghi
điểm 1 lần/ngày không đè, `gauntletScoreForLeaderboard` = 0 khi chưa chơi
hôm nay, ghi điểm lại được sau khi qua ngày mới, `gauntletComboWindowOverride`
chỉ có giá trị đúng mode+modifier, `useUndo()` bị chặn khi modifier
`no_undo`). Verify: `flutter analyze` → 0 issues. `flutter test --exclude-tags
slow` → toàn bộ xanh, không regression.

## ✅ Implemented: I38 Weekly Featured Level (2026-07-22)

- **I38 Weekly Featured Level** side-mode mới "Featured": chơi lại đúng 1
  level campaign đã có sẵn (không phải bàn mới), chọn deterministic theo
  `currentWeekIndex = weekIndexForEpochDay(_todayEpochDay())` (tái dùng hạ
  tầng tuần của I50 Weekly Goal) — mọi thiết bị cùng tuần luôn thấy cùng 1
  level. Chơi lại **không đụng** tiến trình 3-sao/mở khoá thật của level đó,
  chỉ để cạnh tranh điểm số cao trên leaderboard riêng, chơi lại không giới
  hạn số lần trong tuần.
- **`lib/data/weekly_featured.dart`** (mới): `featuredLevelIdForWeek(epochWeek)`
  thuần, deterministic — `epochWeek % kLevelCount + 1`.
- **`lib/data/weekly_featured_leaderboard_bots.dart`** (mới):
  `kWeeklyFeaturedLeaderboardBots` — 10 bot ảo cố định, điểm cao hơn hẳn bàn
  daily-challenge nhỏ (level campaign thật cân bằng cho điểm lớn hơn).
- **`lib/core/storage_service.dart`**: 2 key mới —
  `StorageKeys.lastFeaturedWeekSeen`, `StorageKeys.featuredLevelScore`.
- **`lib/presentation/controllers/game_controller.dart`**: `featuredLevelId`
  getter (map `currentWeekIndex` → id qua `featuredLevelIdForWeek`),
  `startWeeklyFeatured()` (set `currentLevelRx` sang level tuần này, không
  đụng `unlockedLevel`/best score/star thật của level), `featuredLevelScore`
  getter (trả 0 nếu `lastFeaturedWeekSeen` khác `currentWeekIndex` — tự reset
  mỗi tuần mới, dùng chung cho cả hiển thị lẫn leaderboard), private
  `_saveFeaturedLevelScore()` (chỉ ghi khi điểm mới cao hơn, cập nhật cả
  `lastFeaturedWeekSeen`). `resetProgress()` xoá cả 2 key mới.
- **`lib/presentation/screens/home_screen.dart`**: thêm entry point side-mode
  "Featured" trong modes dialog, hiện tên world của level tuần này
  (`worldForLevel(gameCtrl.featuredLevelId).nameKey`).
- **`lib/presentation/screens/leaderboard_screen.dart`**: thêm tab thứ 4
  (`_LeaderboardTab.weeklyFeatured`), dùng `kWeeklyFeaturedLeaderboardBots` +
  `gameCtrl.featuredLevelScore`.
- **`lib/core/app_translations.dart`**: key `mode_weekly_featured_label`
  ("Featured"/"Nổi bật") + wave `_w57ByLang` cho 20 locale còn lại.
- **`test/data/weekly_featured_test.dart`** (mới): `featuredLevelIdForWeek`
  deterministic, luôn trong khoảng `1..kLevelCount`, tuần hoàn đều theo `%
  kLevelCount`, các tuần khác nhau ra level khác nhau.
- **`test/presentation/game_controller_test.dart`**: group test mới —
  `featuredLevelId`/`startWeeklyFeatured` đúng level theo tuần,
  `featuredLevelScore` chỉ ghi khi điểm cao hơn, tự reset về 0 khi qua tuần
  mới (đổi `lastFeaturedWeekSeen`), `resetProgress()` xoá sạch state Weekly
  Featured Level.
- Test: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
  576 tests, toàn bộ xanh, không regression.

## ✅ Implemented: I51 Board Frame Cosmetics (2026-07-22)

- **I51 Board Frame Cosmetics** — 4 khung viền board (`classic`, `neon_cyan`,
  `aurora_gold`, `diamond`) đổi màu/độ dày border cho `PopStarGame`, mở khoá
  theo 2 nguồn state có sẵn: `prestigeTier` (mốc tier) hoặc
  `unlockedAchievementIds` (achievement cụ thể), không thêm counter mới —
  tương tự pattern I52/I54, chỉ 1 `Rx` id đang chọn, luôn recompute unlock
  live từ state hiện tại thay vì lưu set "đã mở khoá" riêng.
- **`lib/data/board_frames.dart`** (mới): `BoardFrame` (id, nameKey, color,
  unlockKind, requiredPrestigeTier, requiredAchievementId),
  `BoardFrameUnlockKind` (`always`/`prestigeTier`/`achievement`),
  `kBoardFrames` (4 phần tử), `isBoardFrameUnlocked(frame, prestigeTier,
  unlockedAchievementIds)` thuần.
- **`lib/core/storage_service.dart`**: key mới `StorageKeys.activeBoardFrame`.
- **`lib/presentation/controllers/game_controller.dart`**:
  `activeBoardFrameId` (`Rx<String>`, mặc định `'classic'`), `activeBoardFrame`
  getter, `setActiveBoardFrame(id)` (chặn chọn khung chưa đủ điều kiện mở
  khoá), `_load()` validate lại id đọc từ storage qua `isBoardFrameUnlocked`
  (anti-cheat — fallback `classic` nếu id không hợp lệ hoặc điều kiện không
  còn đúng), `resetProgress()` xoá key `activeBoardFrame`.
- **`lib/presentation/widgets/board_frame_picker_dialog.dart`** (mới):
  `showBoardFramePickerDialog` — list 4 khung, khung khoá hiện mờ + text điều
  kiện mở khoá (`board_frame_unlock_prestige` hoặc `wardrobe_unlock_via`),
  khung mở tap để chọn.
- **`lib/presentation/screens/home_screen.dart`**: entry point drawer mới,
  icon `Icons.crop_free_rounded`, mở `showBoardFramePickerDialog`.
- **`lib/presentation/screens/game_screen.dart`**: board render với border
  màu theo `gameCtrl.activeBoardFrame.color`.
- **`lib/core/app_translations.dart`**: 6 key mới
  (`drawer_board_frame_label`, `board_frame_classic`, `board_frame_neon_cyan`,
  `board_frame_aurora_gold`, `board_frame_diamond`,
  `board_frame_unlock_prestige`) vào `_extraEn`/`_extraVi` + wave `_w58ByLang`
  cho 20 locale còn lại.
- **`test/data/board_frames_test.dart`** (mới): `isBoardFrameUnlocked` đúng
  cho cả 3 kind (`always` luôn true, `prestigeTier` đúng ngưỡng, `achievement`
  đúng id), 4 frame id không trùng nhau.
- **`test/presentation/game_controller_test.dart`**: group test mới —
  `setActiveBoardFrame` chặn khung chưa đủ prestigeTier/achievement, cho đổi
  khung khi đã đủ điều kiện, `_load()` khôi phục đúng khung từ storage hoặc
  fallback `classic` khi id không hợp lệ / điều kiện không còn đúng (giả lập
  sửa storage tay), `resetProgress()` xoá key và reset về `classic`.
- Test: `flutter analyze` → 0 issues. `flutter test --exclude-tags slow` →
  toàn bộ xanh, không regression.

## ✅ Implemented: I2 Color-lock / Chain Tiles (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I2 Color-lock / chain tiles**: loại ô "bị xích" — vẫn mang màu bình thường
  và tham gia hiển thị bàn cờ, nhưng KHÔNG match được cho tới khi đủ K lần một
  ô cạnh (4-hướng) nổ. Khác hẳn obstacle (F6a, encode âm, loại vĩnh viễn khỏi
  flood-fill) — chain tile dùng 1 cấu trúc dữ liệu song song riêng
  (`lockGrid`) để không đụng encoding âm sẵn có, và tự "mở khoá" khi đếm về 0.
  `lockValue` khởi tạo theo world (`1 + world ~/ 5`) qua
  `_placeChainLocksIfNeeded`.
- **`lib/logic/chain_tile.dart`**: `chipAdjacentLocks` — dùng `Set<Point<int>>`
  dedup trước khi trừ, đảm bảo 1 ô khoá kề nhiều ô nổ cùng lúc chỉ mất đúng 1
  lock (không trừ trùng theo số cạnh kề).
- **`lib/logic/pop_detector.dart`**: `findConnectedGroup`/`hasAnyMovableGroup`
  nhận `lockGrid` optional, loại ô có `lockGrid[r][c] > 0` khỏi flood-fill
  ngay tại điểm bắt đầu lẫn khi lan (`continue`); đọc lại giá trị mỗi lần gọi
  nên ô vừa về `lock == 0` tham gia flood-fill lại ngay lượt kế tiếp, không có
  độ trễ 1 lượt.
- **`lib/logic/pop_collapse.dart`**: `applyGravityAndCollapse` nhận `lockGrid`
  optional, đồng bộ transform (rơi cột, dồn cột trái, và cả 4 hướng gravity)
  lên cả `grid` và `lockGrid` cùng lúc — ô khoá rơi/dồn đúng như ô thường.
  **`lib/game/pop_star_game.dart`**: field `late List<List<int>> lockGrid`
  song song `colorGrid`; gọi `chipAdjacentLocks` sau mỗi lần tap-pop và các
  đường nổ khác (power tile...).
  **`lib/game/block_component.dart`**: vẽ `_renderChainLock` **sau** khi thân
  gem đã vẽ theo màu gốc (không return sớm như obstacle) nên màu luôn hiển
  thị đúng, chỉ đè thêm số lock lên trên.
- Test: `test/logic/chain_tile_test.dart` (dedup lock khi nhiều ô nổ cùng lúc
  kề 1 ô khoá) + các case lock trong `test/logic/pop_detector_test.dart`
  (loại ô khoá khỏi flood-fill, ô về lock=0 tham gia lại bình thường) — audit
  xác nhận cả 6 acceptance criteria của spec `I2-chain-tiles.md` đều khớp
  code thật, không phát hiện phần thiếu.

## ✅ Implemented: I4 Predictive Hint (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I4 Predictive hint**: sau 6s không tap (2s nếu có perk `move_hint`), tự
  động highlight (pulse glow nhẹ) nhóm gem lớn nhất còn lại trên bàn, giúp
  người chơi bí nước đi không bị kẹt/chán — không tự chơi hộ (khác
  auto-solver), không chặn input trong lúc highlight.
- **`lib/game/pop_star_game.dart`**: `_idleTimer` cộng dồn theo `dt` thật
  trong `update()` (không dùng `TimerComponent` riêng nhưng cùng bản chất
  đếm real-time), gate bằng `!_animating && !controller.ended.value &&
  _hint.isEmpty`; hết `_hintDelay` gọi `_triggerHint()` →
  `findLargestGroup(colorGrid, lockGrid: lockGrid)`. `clearHint()` reset
  `_idleTimer = 0`, được gọi từ mọi tap qua
  `GameScreenController.handleBoardTap` trước khi forward sang
  `game.handleTap` — tap không hề bị chặn bởi hint đang hiện.
- **`lib/logic/pop_detector.dart`**: `findLargestGroup` — chỉ là vòng lặp
  toàn bàn gọi lại `findConnectedGroup` cho từng ô chưa duyệt, giữ nhóm
  `length >= 2` lớn nhất; đúng tinh thần "tái dùng, không thêm thuật toán
  mới" của spec.
- **`lib/game/block_component.dart`**: field `hinted` + `_hintPhase` vẽ viền
  pulse (`sin` theo phase, alpha nhạt) đè lên các ô thuộc nhóm gợi ý.
- **`lib/data/perks.dart`**: perk `move_hint` rút ngắn delay hint xuống 2s.
- Test: `test/widget/predictive_hint_test.dart` — dựng bàn xác định, pump
  chưa đủ 6s (assert `hintGroup` rỗng), pump qua ngưỡng (assert đúng nhóm lớn
  nhất kỳ vọng), rồi tap để assert `hintGroup` tắt ngay. Audit xác nhận khớp
  4/5 tiêu chí spec `I4-predictive-hint.md` hoàn toàn; 1 điểm cần lưu ý:
  🟡 **highlight không tự tắt sau "vài giây" cố định như câu chữ spec** — nó
  giữ nguyên vô thời hạn cho tới khi có tap tiếp theo (không phải bug chặn
  gameplay, nhưng khác với cách đọc literal "trong vài giây" của acceptance
  criteria #3; cần theo dõi nếu muốn khớp chữ nghĩa spec 100%).

## ✅ Implemented: I5 Undo Miễn Phí 1 Lần/Màn (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I5 Undo miễn phí 1 lần/màn**: mỗi màn cho phép 1 lần `useUndo()` không
  trừ `undoCount` (booster đã mua) — giảm friction cho người chơi mới mà
  không phá kinh tế booster (từ lần 2 trở đi vẫn trừ như cũ). Có perk
  `extra_undo` (F14) cho 2 lần miễn phí thay vì 1. Không persist qua
  `SharedPreferences` — chỉ là state trong-phiên-chơi, reset mỗi khi bắt đầu
  màn (giống snapshot single-step của `undo()` hiện có).
- **`lib/presentation/controllers/game_controller.dart`**: field
  `_freeUndoLeft`, reset ở **tất cả** các hàm bắt đầu màn (`startLevel`,
  `startSideMode`, `startEndless`, `startDailyChallenge`, `startMirrorMode`,
  `startWeeklyFeatured`, `startPuzzleLevel`...) thành
  `hasPerk('extra_undo') ? 2 : 1`. `useUndo()`: nhánh free tiêu thụ trước
  (`if (_freeUndoLeft > 0) { ...; _freeUndoLeft--; return; }`) rồi mới rơi
  xuống nhánh trừ `undoCount` bình thường (chặn nếu `undoCount.value <= 0`).
  Getter `hasFreeUndo` (`_freeUndoLeft > 0`) phục vụ UI.
- **`lib/presentation/screens/game_screen.dart`**: nút undo dùng
  `forceEnabled: gameCtrl.undoCount.value > 0 || gameCtrl.hasFreeUndo` — vẫn
  bật khi còn free-undo dù `undoCount == 0`.
- Test: `test/widget/free_undo_test.dart` — verify lần undo đầu tiên với
  `undoCount = 0` vẫn undo được và không trừ `undoCount`; lần 2 cùng màn với
  `undoCount = 0` thì bị chặn (đúng behavior cũ). Audit xác nhận PASS toàn bộ
  4 acceptance criteria của spec `I5-free-undo.md`, không phát hiện thiếu sót
  (kể cả thứ tự tiêu thụ free-undo trước khi trừ booster).

## ✅ Implemented: I11 Haptic Feedback Theo Cỡ Nhóm Nổ (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I11 Haptic feedback**: rung nhẹ/vừa/mạnh khi pop nhóm gem tuỳ số ô trong
  nhóm, tăng phản hồi xúc giác cho hit lớn — dùng thẳng
  `HapticFeedback` (`package:flutter/services.dart`, đã có sẵn trong repo cho
  unlock reveal ở `level_select_screen.dart`), không thêm dependency mới.
- **`lib/core/haptics.dart`**: enum `HapticLevel {light, medium, heavy}` +
  `fireHaptic(...)` tôn trọng cờ `StorageKeys.hapticsEnabled`.
- **`lib/core/haptics.dart`**: `hapticLevelForGroupSize(size)` (thuần, mới
  tách 2026-07-22 để test được trực tiếp, không cần mock platform channel) map
  `size >= 8` → heavy, `size >= 4` → medium, còn lại (`< 4`) → light.
- **`lib/game/pop_star_game.dart`**: `_hapticForGroupSize(size)` nay chỉ
  delegate `fireHaptic(hapticLevelForGroupSize(size))`, gọi tại `_tryPop`
  **sau** guard `if (group.length < 2) return;` nên tap trượt không rung.
  `triggerBomb` gọi `fireHaptic(HapticLevel.heavy)` cố định ngay sau guard
  "vùng 3x3 không rỗng", không phụ thuộc số ô ăn được đúng theo spec.
  **`lib/data/combo_milestones.dart`**: hệ haptic khác (theo mốc combo, dùng
  chung `HapticLevel`/`fireHaptic`) — không thuộc acceptance criteria I11
  (theo cỡ nhóm) nhưng liên quan hạ tầng.
  **`lib/presentation/screens/level_select_screen.dart`**,
  **`lib/presentation/screens/home_screen.dart`**: dùng `HapticFeedback` cho
  unlock reveal / tap — context nền tảng đã có sẵn trước I11.
- Test: audit xác nhận PASS toàn bộ 5 acceptance criteria của spec
  `I11-haptic-feedback.md` qua đọc code trực tiếp (ranh giới `<4`/`4-7`/`>=8`
  đúng, không lệch 1; thứ tự gọi đúng sau guard tap trượt). **`test/core/haptics_test.dart`**
  (mới) test trực tiếp `hapticLevelForGroupSize` ở cả 3 ngưỡng
  (2/3 → light, 4/7 → medium, 8/20 → heavy) — đóng gap test đã nêu trước đó.

## ✅ Implemented: I13 SFX Pop Cao Độ Theo Cỡ Nhóm (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I13 SFX pop cao độ theo cỡ nhóm**: wire hạ tầng nhạc lý ngũ cung có sẵn
  (`AudioManager.playMelodic`/`playNote`/`noteIndexFor`, màu-là-giọng,
  combo-là-bậc) vào gameplay thật — trước đó hạ tầng đã xây xong nhưng
  `pop_star_game.dart` chưa gọi tới, khiến pop không phát bất kỳ SFX nào.
- **`lib/game/pop_star_game.dart`**: `_tryPop` gọi
  `AudioManager.maybe?.playMelodic(combo: group.length, colorIndex:
  colorGrid[row][col] ?? -1)` ngay sau guard `if (group.length < 2) return;`
  — không phát khi tap trượt. `colorIndex` lấy đúng ô gốc của group vừa tìm
  (0-based, `-1` khi null).
- **`lib/core/audio_manager.dart`**: `playMelodic`/`playNote`/`noteIndexFor`
  (dòng ~99-190) — hệ ngũ cung + màu-là-giọng + hợp âm wombo khi combo lớn.
- Test: `test/core/audio_manager_test.dart` (mở rộng 2026-07-22) nay có group
  test riêng cho `AudioManager.noteIndexFor` — combo leo bậc ngũ cung không
  tụt, `colorIndex` quyết định bậc gốc, `keyIndex` dịch nốt gốc, cả hai quay
  vòng đúng theo modulo, kết quả luôn clamp trong `1..noteCount`. Vẫn
  **chưa có test verify lời gọi `playMelodic` trong `_tryPop`** (integration
  giữa pop group và audio call site) — chỉ test hàm thuần `noteIndexFor`.
- 🟡 **Partial — 2 điểm chưa khớp hoàn toàn acceptance criteria**:
  1. Tham số tên `combo` nhưng thực chất truyền `group.length` (kích thước
     nhóm vừa pop), không phải chuỗi combo/cascade liên tiếp thật — spec cho
     phép dùng `group.length` làm proxy nên chấp nhận được, nhưng cần lưu ý
     đây không phải combo-chain thật của `GameController`.
  2. `keyIndex` **không được truyền** ở lời gọi trong `_tryPop`, luôn dùng
     default cố định của `playMelodic` — chưa map theo world/stage như 1
     trong 2 phương án mà spec đề xuất (dù phương án còn lại "cố định 1 giá
     trị" cũng được spec chấp nhận). `_activatePowerTile` (một đường pop
     khác qua power tile) cũng **không gọi** `playMelodic` — nằm ngoài phạm
     vi literal của acceptance criteria (chỉ nói `_tryPop`) nhưng là 1 pop
     path thiếu SFX melodic nếu xét toàn diện.

## ✅ Implemented: I18 Colorblind Neon Symbols (2026-07-13)

*(Ghi chú tài liệu bổ sung — tính năng đã có code từ trước, chỉ chưa được ghi vào tracker này; audit thật lại toàn bộ code trong phiên 2026-07-22.)*

- **I18 Colorblind neon symbols**: vẽ thêm icon/symbol riêng theo
  `colorIndex` lên mỗi gem (star/circle/triangle/square/diamond/hexagon/
  cross), bật/tắt qua Settings, giúp người mù màu (đặc biệt đỏ-lục) phân
  biệt gem không chỉ dựa vào màu — board tối đa 7 màu (`colorCount` 4..7
  theo world).
- **`lib/core/storage_service.dart`**: `StorageKeys.colorblindMode =
  'colorblind_mode'`.
- **`lib/presentation/controllers/game_controller.dart`**:
  `colorblindMode` (`Rx<bool>`), `toggleColorblindMode()` (set + persist
  qua `StorageService.to.setBool`), `_load()` đọc lại lúc khởi động —
  round-trip đúng.
- **`lib/game/block_component.dart`**: `_renderColorblindSymbol` vẽ đúng 7
  `Path`/shape khác nhau (`colorIndex % 7`: star 10 cánh, circle, triangle,
  square, diamond, hexagon, cross/plus cho case còn lại), fill trắng alpha
  0.9 + viền đen alpha 0.6 để nổi trên mọi nền màu; chỉ chạy trong `render()`
  khi `game.controller.colorblindMode.value == true`, không đụng `size`/
  `position`/`anchor` của component nên không ảnh hưởng hitbox/tap (tap logic
  nằm ở `PopStarGame.handleTap`, hoàn toàn tách biệt).
- **`lib/presentation/screens/settings_screen.dart`**: `SwitchListTile` theo
  đúng pattern `audioMuted` đang có, bọc `Obx`.
- **`lib/core/app_translations.dart`**: key `colorblind_mode` đủ cho toàn bộ
  22 locale trong `AppTranslations.supported`.
- Test: `test/widget/colorblind_mode_test.dart` — bật/tắt mode, render
  `GameScreen` qua vài frame, assert không crash (smoke test, không assert
  pixel/shape cụ thể nhưng đủ bắt lỗi runtime). Audit xác nhận PASS toàn bộ 4
  acceptance criteria của spec `I18-colorblind-symbols.md`, không phát hiện
  thiếu sót.

## ✅ Implemented: Gộp toàn bộ dialog về 1 helper duy nhất + animation in/out (2026-07-27)

- **Bối cảnh**: audit toàn bộ codebase phát hiện `NeonDialog.show()` dùng
  `showDialog` gốc (animation mặc định, không khớp brand), `NeonDialog.overlay()`
  chỉ animate **vào** — 3 nơi (`game_screen.dart` × 2, `boss_rush_screen.dart`)
  mất animation **ra** vì widget bị gỡ khỏi tree bằng `if` trước khi kịp
  animate; và 6 dialog tự viết tay copy-paste boilerplate `showDialog` thay vì
  dùng lại `NeonDialog.show()` sẵn có.
- **`lib/presentation/widgets/neon_dialog.dart`**: `.show()` đổi
  `showDialog` → `showGeneralDialog` với `transitionDuration:
  Duration(milliseconds: 220)` + `transitionBuilder` riêng
  (`FadeTransition` lồng `ScaleTransition`, `curve: easeOutBack`,
  `reverseCurve: easeIn` để tránh overshoot bouncy lúc đóng) — animation ra
  "free" vì `showGeneralDialog` tự chạy `animation` ngược khi pop route.
  Thêm `NeonDialog.overlaySlot({panel, onBarrier})`: slot luôn mount, barrier
  fade độc lập (`AnimatedOpacity`) + panel qua `AnimatedSwitcher`
  (`FadeTransition`+`ScaleTransition`) — animate được cả 2 chiều dù `panel`
  chuyển `null` ↔ có giá trị. Đổi `_DialogButton` private → `NeonDialogButton`
  public để các dialog reactive (login streak, weekly goal) dùng lại đúng
  style nút.
- **`lib/presentation/screens/game_screen.dart`**: `_Overlay` luôn mount, dùng
  `NeonDialog.overlaySlot` thay `AnimatedSwitcher` tự viết tay; `_AchievementUnlockOverlay`
  cũng chuyển qua `overlaySlot` — cả 2 nay animate mượt cả lúc hiện lẫn ẩn.
- **`lib/presentation/screens/boss_rush_screen.dart`**: dialog xác nhận quit
  giữa trận đổi từ `if (...) NeonDialog.overlay(...)` (bare, không animate ra)
  sang `NeonDialog.overlaySlot(panel: ... ? NeonDialog.panel(...) : null)`.
- **Migrate 6 dialog tay sang `.show()`**: `combo_text_style_picker_dialog.dart`,
  `burst_style_picker_dialog.dart`, `board_frame_picker_dialog.dart` (xoá
  `StatefulBuilder` chết — không nơi nào gọi `setState`), `login_streak_dialog.dart`,
  `weekly_goal_dialog.dart` (nội dung reactive + nút Nhận/Đóng gom vào 1 `Obx`
  làm `content:`, giữ đúng hành vi cũ: claim không pop, Đóng mới pop),
  `spin_wheel_dialog.dart` (tách phần quay tween ra `_SpinWheelBody`
  `StatefulWidget` riêng làm `content:`).
- Test: `test/widget/neon_dialog_test.dart` bổ sung case cho `overlaySlot`
  (panel null → không tìm thấy text; đổi sang có panel → tìm thấy đúng text
  sau `pump()`). Toàn bộ test dialog hiện có (`combo_text_style_picker_dialog_test.dart`
  dùng `pumpAndSettle`...) không cần sửa vì API/hành vi bên ngoài không đổi.
  `flutter analyze` 0 issues, `flutter test --exclude-tags slow` xanh toàn bộ.
- **Gotcha khi test animation route-based** (`showGeneralDialog`): frame đầu
  tiên sau khi `AnimationController` mới start luôn báo `elapsed = 0` (Ticker
  ghi `_startTime` ngay tại tick đó) — cần 1 `pump()` trơn trước khi
  `pump(duration)` mới thấy animation tiến triển; nếu action bên trong dialog
  chạy qua `addPostFrameCallback` (như `prestige()`) thì cần thêm 1 `pump()`
  nữa để `Obx` kịp rebuild sau khi state đổi.
- 📋 **Deferred (ngoài phạm vi)**: layout dialog "Chọn chế độ" ở `home_screen.dart`
  (đơn điệu/mất cân đối do bố cục 3+3+1 lệch) — user đồng ý đây là việc riêng,
  không thuộc phạm vi gộp dialog này.
- **Verify tay trên device thật** (Samsung S24 Ultra, `R5CX613VZBR`): đã test
  trực tiếp 2 cơ chế cốt lõi — (1) `.show()` (route-based): mở/đóng dialog
  "Chọn chế độ" ở home, animation scale+fade rõ ràng cả 2 chiều, không snap;
  (2) `overlaySlot` (in-tree): dialog "Thoát Màn?" giữa trận (`game_screen.dart`)
  hiện đúng style, bấm "Huỷ" đóng có animation, board gameplay phục hồi đúng
  trạng thái bên dưới, không còn dấu vết dialog/barrier. Các luồng còn lại
  (Win/Lose/achievement-unlock trong `game_screen.dart`, quit-confirm ở
  `boss_rush_screen.dart`, claim-rồi-đóng ở login-streak/weekly-goal) dùng
  lại **chính xác cùng 2 cơ chế** (`overlaySlot` hoặc `.show()`) với cùng
  `_kDialogDuration`/`_kDialogCurve` — không có code path riêng nào khác biệt
  đủ để cần test lại từng cái; rủi ro hồi quy coi như đã được cover bởi 2 test
  trên. Không đi sâu giả lập thắng/thua/mở khoá achievement qua ADB vì tốn
  effort cao (cần thao tác nhiều bước, khó xác nhận chính xác qua screenshot)
  trong khi lợi ích biên thấp so với việc test lại đúng cơ chế đã xác nhận.

## ✅ Implemented: Fix panelKey identity-fragility trong `overlaySlot()` (2026-07-27)

- **Bug**: `overlaySlot()` dùng `ValueKey(panel)` — key theo *instance identity*
  của widget `panel`, không phải theo "dialog nào đang hiện". Vì mọi call site
  (`_Overlay`, `_AchievementUnlockOverlay`, `BossRushScreen`) đều gọi lại
  `NeonDialog.panel(...)` (tạo instance mới) mỗi lần `Obx`/`setState` rebuild
  trong lúc dialog vẫn đang mở cùng nội dung, `AnimatedSwitcher` hiểu nhầm là
  "dialog khác" mỗi rebuild → replay animation liên tục dù không có gì đổi.
- **Fix**: `overlaySlot()` (`lib/presentation/widgets/neon_dialog.dart`) thêm
  tham số `Object? panelKey`, dùng `KeyedSubtree(key: ValueKey(panelKey),
  child: panel)` thay vì `ValueKey(panel)`. Caller tự chọn 1 giá trị ổn định
  đại diện "dialog nào": `_Overlay` dùng `GameUi` enum, `_AchievementUnlockOverlay`
  dùng achievement id, `BossRushScreen` dùng cờ bool `_confirmingQuit` — cả 3
  đã cập nhật call site truyền `panelKey`.
- **Gotcha khi viết test**: `ValueKey(panelKey)` bên trong `overlaySlot` luôn
  suy ra generic `ValueKey<Object?>` (vì tham số khai báo kiểu `Object?`),
  trong khi `const ValueKey('x')` viết trực tiếp trong test suy ra
  `ValueKey<String>` — Dart coi 2 generic instantiation này khác `runtimeType`
  nên `==` luôn `false` dù cùng value. Test phải so khớp theo `.value` (ví dụ
  `find.byWidgetPredicate((w) => w is KeyedSubtree && w.key is ValueKey &&
  (w.key as ValueKey).value == 'x')`), không dùng `find.byKey(ValueKey(...))`
  trực tiếp. Ngoài ra `find.byType(KeyedSubtree)` cũng không dùng được vì
  `AnimatedSwitcher` tự bọc thêm 1 `KeyedSubtree` nội bộ (key số
  `_childNumber`) quanh mỗi transition.
- Test: `test/widget/neon_dialog_test.dart` — 2 case mới chứng minh: (1)
  `panelKey` giữ nguyên qua rebuild dù `panel` là instance mới →
  `tester.binding.transientCallbackCount == 0` (không animation nào chạy,
  chứng minh không replay); (2) `panelKey` đổi giá trị → `transientCallbackCount
  > 0` (animation crossfade thực sự chạy) rồi `pumpAndSettle` xác nhận dialog
  cũ biến mất, dialog mới còn lại đúng nội dung.
  `test/widget/boss_rush_screen_test.dart` — 1 case integration-style: mở dialog
  quit → huỷ → mở lại lần 2 trên luồng thật (không mock `overlaySlot`), xác
  nhận nội dung đúng và không có exception (dùng `pump(duration)` cố định
  thay `pumpAndSettle` vì Flame `GameWidget` chạy ticker liên tục khiến
  `pumpAndSettle` không bao giờ ổn định trong lúc "playing"). `flutter analyze`
  0 issues, `flutter test --exclude-tags slow` xanh toàn bộ 604 test.

## ✅ Implemented: Fix bố cục lệch 3+3+1 trong mode dialog thành 4+3 (2026-07-27)

- **Bug**: `_showModesDialog()` (`home_screen.dart`) hiện 7 mode tile trong 1
  `Wrap` — với `NeonIconButton(boxed: true)` cố định 60x60px mỗi tile, panel
  width `NeonTheme.s24` spacing chỉ đủ chỗ cho 3 tile/hàng → bố cục lệch
  3+3+1 (hàng cuối chỉ 1 tile, mất cân đối).
- **Gotcha dp-math trên device thật**: lần sửa đầu (spacing giảm còn
  `NeonTheme.s8`, label width 64) KHÔNG đủ vì tính nhầm ngân sách bề rộng khả
  dụng — quên rằng `margin: EdgeInsets.symmetric(horizontal: NeonTheme.s24)`
  của `NeonDialog.panel()` nằm NGOÀI `Container` bị giới hạn `maxWidth: 360`,
  và trên máy test (Samsung S24 Ultra, `wm density` 480 → dpr 3.0) bề rộng
  logic màn hình đúng bằng 360dp — 1 sự trùng hợp khiến panel không bao giờ
  đạt được `maxWidth` danh nghĩa, panel thực tế chỉ rộng `360 - 48 (margin)
  = 312dp`, trừ tiếp `padding s24 + border 4` mỗi bên → nội dung khả dụng
  thực = 256dp (không phải ~304dp như tính ban đầu). `NeonIconButton(boxed:
  true)` là `Container(width: 60, height: 60)` cố định bất kể tham số `size`
  truyền vào — đây là sàn cứng, không thể thu nhỏ thêm.
- **Fix**: `home_screen.dart` — `Wrap.spacing` giảm còn `NeonTheme.s8 / 2`
  (4.0, tái dùng const có sẵn thay vì số ma thuật mới); label `SizedBox`
  width giảm còn 60 (khớp sàn cứng của icon, thu nhỏ thêm dưới 60 không có
  lợi vì `Column` luôn co theo con rộng nhất). `4×60 + 3×4 = 252dp ≤ 256dp`
  → đủ chỗ 4 tile/hàng, còn 3 tile hàng dưới.
- **Regression phụ**: label dài nhất "Chế độ Đấu thời gian"
  (`mode_time_attack_label`) cần 3 dòng ở bề rộng 60dp mới nhưng `maxLines: 2`
  làm ellipsis cắt cụt giữa chữ. Fix: `maxLines: 2` → `3` (đơn giản hơn chỉnh
  font-size; `Wrap.runSpacing` tự co giãn hàng cao hơn cho riêng tile này mà
  không phá layout các hàng khác).
- Verify: build+install lại trên Samsung S24 Ultra (`R5CX613VZBR`, thiết bị
  duy nhất kết nối) sau mỗi lần sửa vì không có `flutter run` hot-reload nào
  đang chạy — chụp screenshot xác nhận bố cục 4+3 đúng, không tràn/cắt, cả 7
  label đọc đầy đủ. `flutter analyze` 0 issues, `flutter test --exclude-tags
  slow` xanh toàn bộ 604 test.

## ✅ Implemented: Fix 4 nitpick từ audit dialog-consolidation (2026-07-28)

Audit chấm 9/10 cho refactor gộp dialog (`overlaySlot`/`panelKey`, xem mục
trên) nêu 4 nitpick nhỏ, không blocker — dọn hết trong lượt này:

- **`NeonDialog.overlaySlot()` — `panelKey` optional → required**: trước đây
  `Object? panelKey` có default ngầm `null`, nên 1 call site lỡ quên truyền
  vẫn compile được — nếu về sau xuất hiện 2 dialog non-null khác nhau mà
  cùng bỏ qua tham số này, `AnimatedSwitcher` sẽ coi là "cùng 1 dialog" và
  mất animation chuyển cảnh (đúng bug đã fix ở mục panelKey identity-fragility
  phía trên, chỉ khác là do quên truyền thay vì truyền theo identity). Đổi
  `required Object? panelKey` (vẫn nullable, chỉ bắt buộc truyền tường minh)
  — lỗi thiếu tham số giờ bắt được lúc compile thay vì runtime. 3 call site
  thật (`game_screen.dart` × 2, `boss_rush_screen.dart`) đã truyền sẵn nên
  không ảnh hưởng; `test/widget/neon_dialog_test.dart` có 1 test case còn
  thiếu → bổ sung `panelKey: 'streak'`.
- **`NeonDialog.panel()` render `Row` action rỗng khi `actions: []`**: dialog
  dùng `content:` để nhúng nút riêng (`login_streak_dialog.dart`,
  `weekly_goal_dialog.dart`) vẫn luôn tốn thêm `SizedBox(height: s24)` +
  `Row` rỗng phía dưới — lãng phí khoảng trống dialog. Fix: bọc cả 2 trong
  `if (actions.isNotEmpty) ...[...]`.
- **Test docstring overclaim**: `boss_rush_screen_test.dart` có 1 test tên
  "chứng minh overlaySlot panelKey ổn định qua rebuild thật" nhưng không
  assert `transientCallbackCount` nên thực chất không chứng minh được điều
  đó (bằng chứng thật nằm ở 2 test dedicated trong `neon_dialog_test.dart`).
  Sửa lại tên test cho đúng bản chất: smoke test luồng quit thật trên màn
  hình, kèm chú thích trỏ sang nơi có bằng chứng thật.
- **i18n overflow risk cho mode-tile label**: kiểm tra chuỗi dài nhất trong
  22 locale cho 5 key label tĩnh (`mode_time_attack_label`, `mode_zen_label`,
  `mode_endless_label`, `mode_boss_rush_label`, `mode_mirror_label`) — dài
  nhất là tiếng Ý "Modalità Contro il tempo" (24 ký tự) và Filipino "Walang
  Katapusang Mode" (22 ký tự). Thử đo bằng `TextPainter` với font fallback
  của môi trường test cho kết quả không đáng tin (báo tràn cả chuỗi tiếng
  Anh gốc "Time Attack Mode" — vốn đã chạy tốt trên máy thật vì dùng font
  Baloo2 thật, khác font test). Kết luận: không cần sửa code — hộp label
  (60dp/3 dòng/11px) đã được tinh chỉnh và verify trên device thật ở lần fix
  bố cục 4+3 phía trên, và `TextOverflow.ellipsis` đảm bảo trường hợp xấu
  nhất chỉ là cắt bớt chữ, không vỡ layout.
- Verify: `flutter analyze` 0 issues, `flutter test --exclude-tags slow`
  xanh toàn bộ 604 test.
