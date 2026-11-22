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

## Kết quả thực hiện

- Owner decision:
- Audit / điểm:
- Tests/device smoke:
- Commit/push:
