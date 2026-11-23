---
id: FEAT-214
title: "Demo game hoàn chỉnh trong example: menu, chọn level, thắng/thua, thưởng, lưu"
type: feature
layer: example
priority: P2
effort: L
source: "Owner chọn hướng game 2026-11-22 và còn support game/app nên cần demo dựng game/app đủ vòng chơi từ widget sẵn có"
---

## Mục tiêu

Một game mẫu đủ vòng chơi để đối tác thấy kit dựng được game nhanh: menu -> chọn level -> chơi -> thắng/thua -> thưởng -> lưu tiến độ -> quay lại. Ghép từ widget/service CÓ SẴN, không thêm API vào package.

## Tài nguyên đã có (không viết lại)

- Widget: `LevelSelectGrid`, `LevelPathMapTile`, `GameOverCardTemplate`, `VictoryCardTemplate`, `PauseOverlay`, `RewardPopup`, `StarRating`, `ComboMeterBar`, `BoosterSlotBar`, `TutorialSequence`, `EnergyBar`, `CurrencyCounter`.
- Service: `PlayerProgressionService`, `EnergyService`, `EconomyWallet`, `DailyQuestService`, `AchievementService`, `VersionedJsonStore`, `GameSessionController`.
- Màn hiện có để tham chiếu: `level_progression_screen.dart`, `match3_lite_screen.dart`.

## Câu hỏi owner cần chốt trước khi code

- Thể loại game demo: ghép hình (dùng Match3Engine, liên quan FEAT-212), arcade Flame (dùng Sprite Arena), hay game mới đơn giản (vd. memory/tap)?
- Demo có phải app độc lập (tách thư mục) hay thêm vào Home của `example`?

## Acceptance criteria

- [ ] Vòng chơi đầy đủ chạy được, tiến độ + năng lượng + ví lưu và khôi phục sau khi khởi động lại.
- [ ] Chỉ dùng API công khai của kit; nếu phát hiện thiếu hụt, ghi thành task riêng, không sửa package trong task này.
- [ ] Widget test cho từng chặng (menu, thắng, thua, thưởng); integration test golden path chạy tay trên thiết bị thật với `E2E_TEST=true`.
- [ ] Cập nhật `example/README.md`; audit >9/10; device smoke trên S24U, không simulator.

## Quyết định owner (2026-11-23)

- Thể loại: Match-3 hoàn chỉnh, nâng cấp ngay trong Home của `example` (màn Match3 Lite hiện có), không làm app riêng.
- Chia 4 lát, mỗi lát commit riêng và tự kiểm thử, theo thứ tự: (1) UI booster, (2) chọn level `LevelSelectGrid`, (3) thắng/thua + thưởng + sao, (4) tutorial + pause.
- Booster (lát 1): mua bằng coins, giá cố định 30, tặng sẵn 1 mỗi loại lúc đầu, kho dùng chung 1 catalog ở `example/lib/game/match3_boosters.dart` (Shop và Showcase dùng cùng catalog để không xung đột `InventoryService` singleton).

## Kết quả thực hiện

### Lát 1: UI booster (xong, 2026-11-23)

- Thay đổi: thanh `BoosterSlotBar` giữa lưới và nút hành động của `Match3LiteScreen`; chạm slot có hàng thì vào chế độ chọn ô (chạm lại để hủy, miễn phí), chạm ô thì `Match3Engine.useBooster`; slot hết hàng thì mua bằng coins (`EconomyWallet.trySpend`, grant thất bại thì hoàn coins). Booster bị khóa khi chưa bắt đầu ván hoặc ván đã kết thúc. `exampleInventoryCatalog` dùng chung cho Shop, Showcase, Match3. Thêm 10 key i18n (en + vi).
- Tests: 6 widget test mới (quà tặng đầu một lần, bom xoá đúng và không tốn lượt, hủy miễn phí, khóa khi chưa chạy, mua bằng coins gồm thiếu coins, hai booster mỗi cái trừ một). Mutation check: sai giá, hủy không bỏ armed, id dùng booster cố định đều làm test đỏ; mutant id cố định ban đầu sống sót và đã bổ sung test. Example 441 pass, root core 2026 pass, analyze sạch, API gate không đổi.
- Device: Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: `Match-3 Lite opens and runs one valid swap on device` pass sau khi đổi layout; log `doc/task/evidence/FEAT-214-slice1-pixel7pro-match3-boosters.log`. Chỉ chứng minh màn mở và 1 swap hợp lệ, chưa đi qua booster trên thiết bị.
- Chưa làm: lát 2, 3, 4; chưa có integration test booster trên thiết bị thật.

### Lát 2: Chọn level + lưu sao (xong, 2026-11-23)

- Quyết định owner: lưu sao tốt nhất mỗi level (save v3, migrate từ v2); sao theo lượt còn lại (>= 40% là 3 sao, >= 15% là 2, còn lại 1); chọn level là panel ngay trong Match3 Lite (không thêm route).
- Số liệu ngưỡng sao (sim 200 ván/level/bot, seed cố định; ngưỡng được đo trước khi chốt): bot ngẫu nhiên thắng L1 được 28/78/60 ván 1/2/3 sao, L5 38/46/21; bot greedy L1 3/35/162, L5 23/76/93. Hợp lý: người chơi giỏi 3 sao nhiều nhất, người chơi kém vẫn có 2 sao phổ biến.
- Thay đổi: `LevelSelectGrid` dưới các nút hành động (khóa khi đang chạy ván); save schema v3 có `bestStars` (migrate v2 thêm map rỗng, đọc phòng thủ bằng `match3ReadBestStars`); thắng chỉ nâng sao, không bao giờ hạ; cloud sync gộp sao theo max từng level; `_startLevel` từ chối level bị khóa hoặc ngoài khoảng, không trừ năng lượng. Logic sao/đọc/gộp nằm trong `example/lib/game/match3_boosters.dart`.
- Tests: 10 test mới (luật sao và biên, đọc/gộp phòng thủ, grid hiện khóa/hoàn thành/sao, chọn level trừ năng lượng đúng một lần, level khóa không chạy, bỏ qua chạm khi đang chơi, thắng lưu sao, thắng tệ không hạ sao, migrate v2->v3, sync cloud gộp max). Mutation check 7 lỗi cố ý: ngưỡng, ghi đè sao, bỏ guard khóa, merge min, không lưu sao, đọc nhận sao 9 đều làm test đỏ; mutant ghi đè sao ban đầu sống sót và đã bổ sung test. Example 451 pass, root core 2026 pass, analyze và API gate sạch. Sửa 1 test cũ (`cascade animation blocks another swap`) vì layout dài hơn nên cần `ensureVisible` ô trước khi chạm.
- Device: Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: `Match-3 Lite opens and runs one valid swap on device` pass, log `doc/task/evidence/FEAT-214-slice2-pixel7pro-match3-level-select.log`. Chỉ chứng minh màn mở và 1 swap hợp lệ, chưa tương tác với panel chọn level trên thiết bị.
- Chưa làm: lát 3 và 4; sao mới chỉ hiện ở lưới, chưa có màn thắng/thua dùng sao (lát 3).

### Lát 3: Thẻ thắng/thua + sao + chia sẻ (xong, 2026-11-23)

- Quyết định owner: hiện thẻ overlay khi kết thúc ván và giữ nguyên các nút cũ bên dưới; thẻ thắng có nút Chia sẻ.
- Thay đổi: thắng hiện `VictoryCardTemplate` (sao của chính ván này, điểm, lượt còn, điểm cao nhất) kèm nút Level tiếp, Chia sẻ (`shareScoreCard` qua `RepaintBoundary`), Đóng; thua hiện `GameOverCardTemplate` với Chơi lại và Đóng. Thẻ chỉ hiện một lần mỗi ván, đóng bằng nút hoặc chạm nền, và tự biến mất khi vào level mới (điều kiện hiển thị còn kèm `_game.isTerminal`). 9 key i18n (en + vi).
- Tests: 12 test mới và sửa 2 test cũ (`Next Level` và `Copy Playtest Report` phải đóng thẻ trước vì thẻ chặn tương tác phía sau). Mutation check 6 lỗi cố ý: không hiện thẻ, sao sai, đóng không có tác dụng, thua dùng thẻ thắng đều làm test đỏ. Hai mutant (thẻ sống qua level mới, thẻ sống sau Chơi lại) sống sót vì mỗi cái đã được che bởi điều kiện `_game.isTerminal` nên cờ reset là code thừa; đã xoá hai chỗ reset thừa thay vì giữ test giả. Example 461 pass, root core 2026 pass, analyze và API gate sạch.
- Device: Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: `Match-3 Lite opens and runs one valid swap on device` pass, log `doc/task/evidence/FEAT-214-slice3-pixel7pro-match3-result-card.log`. Chỉ chứng minh màn mở và 1 swap hợp lệ, KHÔNG phủ thẻ kết quả, sao hay nút Chia sẻ trên thiết bị.
- Chưa chứng minh: nút Chia sẻ mới chỉ được test là không làm vỡ thẻ khi không có nền tảng; share sheet thật và ảnh thẻ chưa chạy trên thiết bị. Lát 4 chưa làm.

### Lát 4: Tutorial + pause (xong, 2026-11-23)

- Quyết định owner: nút Pause + khóa bàn + tự pause khi app xuống nền; tutorial 3 bước (đổi 2 ô, thanh booster, chọn level) hiện đúng một lần.
- Thay đổi: `GameSessionController` (Get.put để hook lifecycle chạy, Get.delete khi dispose) đồng bộ theo vòng đời ván qua `_syncSession` (ready, playing, won/lost, restore từ save); nút Pause trong hàng hành động khi đang chạy; `PauseOverlay` (Tiếp tục, Chơi lại, Thoát) với `showForSystemPause: true`; khi pause khóa lưới và các slot booster; Chơi lại từ menu trừ năng lượng như nút New Run. Tutorial dùng `TutorialSequence` + `OnboardingCoordinatorService` (cờ `match3_tutorial_v1` được lưu, đánh dấu đã xem ngay khi hiện) với 3 `GlobalKey` đo mục tiêu sau khi cuộn vào tầm nhìn. 12 key i18n mới (en + vi), dùng lại key `pause_*` và `tutorial_skip` sẵn có của kit.
- Tests: 12 test mới (session theo ván, tutorial hiện lần đầu và 3 bước tới hết, bỏ qua không quay lại, người đã xem không thấy, pause mở menu và khóa bàn, pause khóa booster/mua, resume mở khóa, restart từ menu, nền/tiền cảnh tự pause/resume, rời màn gỡ session, handler ô gọi khi đang pause không làm gì). `setUp` mặc định coi người chơi đã xem tutorial vì spotlight che màn. Mutation check 8 lỗi cố ý: khóa booster, tutorial không đánh dấu đã xem, không gỡ session, session không start, pause không làm gì, restart không thoát pause đều làm test đỏ; mutant bỏ guard pause trong `_swap` sống sót vì overlay nuốt tap nên đã thêm test gọi thẳng handler của ô; mutant guard pause trên chạm level là mã thừa (`_running` đã chặn) nên đã gỡ khỏi code thay vì giữ test giả. Example 472 pass, root core 2026 pass, analyze và API gate sạch.
- Device: Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: `Match-3 Lite opens and runs one valid swap on device` ban đầu ĐỎ vì tutorial thật sự che bàn chơi lần đầu trên máy thật (xác nhận tutorial hoạt động); đã sửa test để bỏ qua tutorial nếu có, rồi pass; log `doc/task/evidence/FEAT-214-slice4-pixel7pro-match3-pause-tutorial.log`. Smoke này chỉ mở màn và 1 swap; luồng đầy đủ (tutorial, booster, pause) được phủ riêng ở mục "Smoke sâu" bên dưới.

### Smoke sâu trên thiết bị thật (2026-11-23)

- Thêm `example/integration_test/match3_game_flow_test.dart`: người chơi mới (xoá cờ tutorial và save), mở Match3 Lite, Start, tutorial hiện đúng và đi hết 3 bước, dùng booster bom (trừ đúng 1 booster, không trừ lượt), Pause (session `paused`, menu hiện), Resume (`playing`), Pause rồi Restart từ menu (ván mới, `playing`).
- Chạy trên Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: pass 1/1, log `doc/task/evidence/FEAT-214-pixel7pro-match3-game-flow.log`. Mutation check trên máy thật: đổi pause thành no-op thì test đỏ. Lệnh chạy tay ghi trong `example/README.md`.
- Vẫn chưa chứng minh trên thiết bị: thẻ kết quả thắng/thua, nút Chia sẻ và share sheet, tự pause khi app xuống nền thật (chỉ lifecycle giả lập), mua booster bằng coins.

## Tổng kết FEAT-214 (4 lát)

- Vòng chơi Match-3 trong Home đã đủ: bắt đầu (trừ năng lượng), chơi, booster (mua bằng coin), chọn level + sao lưu save v3, thẻ thắng/thua + chia sẻ, pause, tutorial. Chỉ dùng API công khai của kit; nếu thấy thiếu hụt thì ghi thành task riêng.
- Điểm tự chấm ~9.0/10. Trừ điểm: chưa có integration test đi qua booster/thẻ kết quả/pause/tutorial trên thiết bị thật (chỉ smoke mở màn + 1 swap); chia sẻ chưa chạy share sheet thật; máy thật là Pixel 7 Pro chứ không phải S24U; tự pause khi xuống nền chỉ kiểm bằng lifecycle giả lập.
- Chưa làm trong phạm vi: không có âm thanh/haptic riêng cho booster, không có animation riêng khi mua.

### Còn lại
- Commit/push: `901536de`, `e9e4eb96`, `88af66c0` và lát 4.
