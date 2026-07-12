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
- **G8 burst ring + idle shimmer**: `_BurstRing` — mỗi nhóm nổ bung 1 vòng
  tròn viền tại tâm nhóm (bán kính theo bounding box) rồi mờ dần 0.32s, cap
  tối đa 3 ring đồng thời (`_maxRings`, huỷ ring cũ nhất nếu vượt) để nhẹ khi
  combo dồn dập. `_ShimmerSweep` — bàn rảnh ≥4s (không tap/kéo/diễn hoạt, theo
  dõi qua `_idleTime` trong `update`) thì quét 1 tia sáng chéo qua bàn 1 lượt
  rồi tự dọn, reset đợi rảnh tiếp mới quét lượt sau (không lặp liên tục).
  Hoàn tất toàn bộ Wave 4 (G5, G3, G6, G4, G7, G8).

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

## 🟡 In progress / tiếp theo (xem doc/task/tasks/)

- Mở rộng test coverage thêm (theo `doc/task/tasks/README.md`, wave tiếp
  theo) — các widget/screen còn lại chưa có test trực tiếp.
- `settings_screen_test.dart`: chỉ smoke-test render, KHÔNG test hành vi tap
  đổi ngôn ngữ qua UI — `Get.updateLocale()` gọi
  `engine.performReassemble()` nội bộ, không tương thích với
  `AutomatedTestWidgetsFlutterBinding` của `flutter_test` (ném lỗi
  `schedulerPhase == idle` ngay trong `tester.tap()`, không phải do pump
  sau đó). Muốn test hành vi đổi ngôn ngữ thật sự cần tách logic khỏi
  `Get.updateLocale`/`performReassemble`, hoặc test qua tầng khác (không
  phải widget test dựng UI thật).

## 💭 Ideas (ngoài scope hiện tại)

- Daily reward / login streak · leaderboard/social · cosmetic skins cho block
  · âm thanh pop/win. (Rainbow/bomb booster đã xong — F3/F5b/F5c.)
- Gán `LevelObjective.clearColor/clearObstacle` cho các màn cụ thể trong
  `kLevels` (cơ chế đã xong + có test qua `objective_test.dart`, nhưng chưa
  màn campaign nào thực sự dùng objective khác score).
- 10 ý tưởng thêm chưa chốt: xem `doc/task/tasks/IDEAS.md` (I1-I10).
