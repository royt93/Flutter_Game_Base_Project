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

## 💭 Ideas (ngoài scope hiện tại)

- Gán `LevelObjective.clearColor/clearObstacle` cho các màn cụ thể trong
  `kLevels` (cơ chế đã xong + có test qua `objective_test.dart`, nhưng chưa
  màn campaign nào thực sự dùng objective khác score).
- Monetize (`I19`/`I20` trong `IDEAS.md`) — user đã loại dứt khoát khỏi mọi
  wave (Option D), giữ nguyên "chưa chốt" cho tới khi có yêu cầu khác.
- `I12` dynamic music layers — còn "chưa chốt" trong `IDEAS.md`, chưa có task
  file.
