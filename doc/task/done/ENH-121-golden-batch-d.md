---
id: ENH-121
title: "Golden test đợt D: Phần thưởng / shop / sự kiện (14 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **D**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (14)

- `reward_popup`
- `reward_choice_panel`
- `reward_sequence_coordinator`
- `tiered_reward_chest`
- `piggy_bank_vault`
- `mystery_chest_opening`
- `battle_pass_road`
- `flash_sale_offer_card`
- `season_event_banner`
- `daily_login_calendar`
- `scratch_card`
- `wheel_spinner`
- `coin_multiplier_wheel`
- `achievement_unlock_listener`

## Lưu ý riêng của đợt
`wheel_spinner`/`coin_multiplier_wheel`/`scratch_card` ngẫu nhiên: dùng `SeededRandom`/góc cố định. `season_event_banner`, `flash_sale_offer_card` có đếm ngược: truyền thời điểm cố định, không dùng đồng hồ thật.

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [x] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (14 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
- [x] 3. Chạy cục bộ để kiểm test dựng được và không có ngoại lệ khác ngoài "thiếu golden": `flutter test test/widget/goldens/<file>`. KHÔNG commit PNG nào sinh từ máy local (macOS).
- [x] 4. Commit + push các file test (CI `analyze-test` sẽ đỏ tới khi có baseline: đúng quy trình trong CLAUDE.md).
- [x] 5. Chạy `gh workflow run regenerate-goldens.yml --ref main`, chờ xong, tải artifact: `gh run download <run-id> -n regenerated-goldens -D /tmp/goldens-<đợt>`.
- [x] 6. Chép CHỈ các PNG của widget trong đợt vào `test/widget/goldens/goldens/` (lọc theo tiền tố tên); đếm: số PNG chép = số widget × số biến thể đã chốt ở bước 1; `git status` chỉ có PNG mới của đợt, `cmp` xác nhận không PNG cũ nào đổi.
- [x] 7. Kiểm ổn định: chạy workflow lần 2, so hai artifact cho đúng các PNG của đợt (byte-identical hoặc trong tolerance). Widget nào không ổn định: loại khỏi golden, thay bằng test hành vi, ghi lý do.
- [x] 8. Commit + push PNG; xác nhận `analyze-test` xanh. Ghi kích thước thư mục goldens trước/sau (`du -sh`), và kết quả vào "Kết quả thực hiện"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Mỗi widget trong đợt có golden test và PNG cho các biến thể đã chốt (hoặc có lý do ghi rõ khi loại).
- [x] Không PNG ngoài đợt bị đổi.
- [x] Hai lần chạy workflow cho ảnh giống nhau (hoặc trong tolerance 1%).
- [x] Tất cả đều sinh từ Linux workflow, không từ macOS.
- [x] `analyze-test` xanh sau khi chép baseline.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/goldens (trên Linux/CI; trên macOS sẽ đỏ theo thiết kế)`
- `gh workflow run regenerate-goldens.yml --ref main`

## Kết quả thực hiện (2026-11-24)

- Test: `test/widget/goldens/batch_d_reward_widgets_golden_test.dart`, 14 test, 15 tên golden x 7 biến thể (baseline, dark, locale-vi, rtl, textScale 1.3 và 2.0, reducedMotion) = 105 PNG, 390x760. Phủ 13 trong 14 widget của đợt (thiếu `AchievementUnlockListener`, xem dưới); `ScratchCard` có 2 ảnh phủ/đã cào, `RewardChoicePanel` có 2 ảnh đủ/rỗng.
- Baseline: workflow Linux `45385127047`, chép CHỈ 105 file của đợt, từ chối ghi đè, 0 PNG cũ đổi, không PNG nào từ macOS. Thư mục goldens 17M -> 19M. Đã xem `scratchcard_scratched_baseline`, `seasoneventbanner_states_baseline`, `rewardpopup_states_baseline`, `flashsaleoffercard_states_baseline`, `battlepassroad_states_rtl`.
- Ổn định (bước 7): lần 2 `45385547063`, so từng byte: 105/105 giống hệt, kể cả `FlashSaleOfferCard` và `SeasonEventBanner` (deadline dựng từ `DateTime.now()` cộng lề, chữ đếm ngược không đổi giữa hai lần).
- Sửa fixture (không sửa widget), phát hiện nhờ chạy `--update-goldens` cục bộ để lộ mọi ca ma trận: `RewardPopup` khung 560 (tràn 91px ở 2.0x), `FlashSaleOfferCard` width 280 (tràn ở 2.0x), nhãn milestone `SeasonEventBanner` rút còn "Chest" (tràn 55px ở 1.3x).
- Không phủ có chủ đích: `AchievementUnlockListener` (chỉ render child; toast của nó đã có golden `ToastBanner` đợt B), các hoạt ảnh (quay vòng, cào, mở rương, nhận thưởng), `WheelSpinner`/`CoinMultiplierWheel` chỉ chụp trạng thái nghỉ (không quay nên không cần `SeededRandom`).
- Lưu ý rủi ro: `FlashSaleOfferCard`/`SeasonEventBanner` phụ thuộc đồng hồ thật. Nếu sau này đỏ, nghi trước chỗ giây của `FlashSaleOfferCard` (cộng 30s lề, làm tròn lên) khi runner chậm hơn 30s giữa dựng và chụp.
