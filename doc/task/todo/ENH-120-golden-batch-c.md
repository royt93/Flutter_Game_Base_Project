---
id: ENH-120
title: "Golden test đợt C: Game HUD / tiến độ (13 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **C**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (13)

- `adaptive_game_hud`
- `combo_meter_bar`
- `combo_heat_background`
- `circular_progress_ring`
- `progress_bar_stars`
- `energy_bar`
- `currency_counter`
- `level_goal_tracker`
- `star_chest_progress_hud`
- `streak_counter`
- `live_frame_graph`
- `game_joystick`
- `tap_hint_pointer`

## Lưu ý riêng của đợt
`currency_counter` và `live_frame_graph` có animation/đồng hồ: chụp ở trạng thái đã dừng (duration 0 hoặc pump đủ), `live_frame_graph` nạp mẫu frame cố định.

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [ ] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (13 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
- [ ] 3. Chạy cục bộ để kiểm test dựng được và không có ngoại lệ khác ngoài "thiếu golden": `flutter test test/widget/goldens/<file>`. KHÔNG commit PNG nào sinh từ máy local (macOS).
- [ ] 4. Commit + push các file test (CI `analyze-test` sẽ đỏ tới khi có baseline: đúng quy trình trong CLAUDE.md).
- [ ] 5. Chạy `gh workflow run regenerate-goldens.yml --ref main`, chờ xong, tải artifact: `gh run download <run-id> -n regenerated-goldens -D /tmp/goldens-<đợt>`.
- [ ] 6. Chép CHỈ các PNG của widget trong đợt vào `test/widget/goldens/goldens/` (lọc theo tiền tố tên); đếm: số PNG chép = số widget × số biến thể đã chốt ở bước 1; `git status` chỉ có PNG mới của đợt, `cmp` xác nhận không PNG cũ nào đổi.
- [ ] 7. Kiểm ổn định: chạy workflow lần 2, so hai artifact cho đúng các PNG của đợt (byte-identical hoặc trong tolerance). Widget nào không ổn định: loại khỏi golden, thay bằng test hành vi, ghi lý do.
- [ ] 8. Commit + push PNG; xác nhận `analyze-test` xanh. Ghi kích thước thư mục goldens trước/sau (`du -sh`), và kết quả vào "Kết quả thực hiện"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mỗi widget trong đợt có golden test và PNG cho các biến thể đã chốt (hoặc có lý do ghi rõ khi loại).
- [ ] Không PNG ngoài đợt bị đổi.
- [ ] Hai lần chạy workflow cho ảnh giống nhau (hoặc trong tolerance 1%).
- [ ] Tất cả đều sinh từ Linux workflow, không từ macOS.
- [ ] `analyze-test` xanh sau khi chép baseline.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/goldens (trên Linux/CI; trên macOS sẽ đỏ theo thiết kế)`
- `gh workflow run regenerate-goldens.yml --ref main`
