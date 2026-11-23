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

### Còn lại
- Audit / điểm tổng:
- Commit/push:
