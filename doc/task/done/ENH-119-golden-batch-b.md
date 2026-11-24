---
id: ENH-119
title: "Golden test đợt B: Overlay/dialog/toast (15 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **B**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (15)

- `app_version_gate_overlay`
- `bottom_sheet_panel`
- `loading_overlay`
- `pause_overlay`
- `spotlight_overlay`
- `toast_banner`
- `tooltip_bubble`
- `tutorial_sequence`
- `streak_repair_dialog`
- `level_up_overlay`
- `review_prompt_trigger`
- `retry_error_state`
- `consent_banner`
- `network_status_banner`
- `empty_state_placeholder`

## Lưu ý riêng của đợt
Nhiều widget là overlay route/in-tree (xem mẫu `NeonDialog.overlay`): dựng bằng `NeonDialog.overlay`/`Stack`, không dùng `showDialog`. Overlay có `BlockSemantics` không ảnh hưởng ảnh.

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [x] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (15 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
- [x] 3. Chạy cục bộ để kiểm test dựng được và không có ngoại lệ khác ngoài "thiếu golden": `flutter test test/widget/goldens/<file>`. KHÔNG commit PNG nào sinh từ máy local (macOS).
- [x] 4. Commit + push các file test (CI `analyze-test` sẽ đỏ tới khi có baseline: đúng quy trình trong CLAUDE.md).
- [x] 5. Chạy `gh workflow run regenerate-goldens.yml --ref main`, chờ xong, tải artifact: `gh run download <run-id> -n regenerated-goldens -D /tmp/goldens-<đợt>`.
- [x] 6. Chép CHỈ các PNG của widget trong đợt vào `test/widget/goldens/goldens/` (lọc theo tiền tố tên); đếm: số PNG chép = số widget × số biến thể đã chốt ở bước 1; `git status` chỉ có PNG mới của đợt, `cmp` xác nhận không PNG cũ nào đổi.
- [ ] 7. Kiểm ổn định: chạy workflow lần 2, so hai artifact cho đúng các PNG của đợt (byte-identical hoặc trong tolerance). Widget nào không ổn định: loại khỏi golden, thay bằng test hành vi, ghi lý do.
- [x] 8. Commit + push PNG; xác nhận `analyze-test` xanh. Ghi kích thước thư mục goldens trước/sau (`du -sh`), và kết quả vào "Kết quả thực hiện"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mỗi widget trong đợt có golden test và PNG cho các biến thể đã chốt (hoặc có lý do ghi rõ khi loại).
- [ ] Không PNG ngoài đợt bị đổi.
- [ ] Hai lần chạy workflow cho ảnh giống nhau (hoặc trong tolerance 1%).
- [ ] Tất cả đều sinh từ Linux workflow, không từ macOS.
- [ ] `analyze-test` xanh sau khi chép baseline.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/goldens (trên Linux/CI; trên macOS sẽ đỏ theo thiết kế)`
- `gh workflow run regenerate-goldens.yml --ref main`

## Kết quả thực hiện (2026-11-24)

- Test: `test/widget/goldens/batch_b_overlay_widgets_golden_test.dart`, 15 test x 7 biến thể (baseline, dark, locale-vi, rtl, textScale 1.3 và 2.0, reducedMotion) = 105 PNG, tất cả 390x600 hoặc 390x900. Overlay dựng TRONG cây widget (không `showDialog`), reduced motion cho animation vào.
- Baseline: workflow Linux chạy 3 lần (45367461389 thất bại, 45368390472 thành công, 45376679245 thành công). PNG chép từ artifact của lần 3 (1633 PNG), CHỈ 105 file của đợt, từ chối ghi đè bất kỳ file nào đã có, 0 PNG cũ đổi, không PNG nào từ macOS. Đã xem tận mắt Spotlight, Tutorial (RTL), LevelUp (2.0x), pause, version gate, consent (dark).
- Bài học 1 (lần chạy Linux đầu thất bại): trên macOS mỗi test dừng ở lỗi "thiếu baseline" của ca đầu nên các ca `locale-vi`/`textScale-2.0` không chạy tới; chỉ `flutter test --update-goldens` chạy đủ ma trận. Từ đó chạy `--update-goldens` cục bộ TRƯỚC khi push và xoá ngay PNG sinh ra (một lần suýt ghi đè 84 PNG Linux bằng ảnh macOS: đã so byte và xoá).
- Bài học 2 (golden đánh lừa người đọc): bản đầu `SpotlightOverlay`, `TutorialSequence`, `LevelUpOverlay` chỉ chụp trạng thái rảnh (spotlight không lớp phủ/lỗ/callout). Sửa bằng hook `afterPump` (tuỳ chọn) mới ở `runGoldenMatrix`: Spotlight pump thêm sau post-frame và chờ 400ms; Tutorial `start()` hai bước; LevelUp `show()` rồi dừng ở pha level pop, `skip()` timer trước mỗi ca và cuối test. Đổi tên PNG: `tutorialsequence_step1`, `levelupoverlay_levelpop`.
- Hạn chế đã biết: (1) `ConsentBanner` dùng `NeonDialog.show` (route) bị ma trận dựng lại cây làm lỗi GetX Obx, nên golden chụp PANEL (`NeonDialog.panel`) cùng tiêu đề/thông điệp/nút, còn hành vi banner do `consent_banner_test`. (2) `NetworkStatusBanner` ném "RenderAnimatedSize mutated in its own performLayout" khi harness bơm lại CÙNG cây qua các ca liên tiếp; probe các tình huống thật (đổi cỡ chữ, ngôn ngữ, kết nối khi banner hiện; có/không Column) đều KHÔNG ném, nên dùng `freshTreePerCase` (một lần gọi ma trận mỗi ca, dỡ cây giữa các ca). NGUYÊN NHÂN GỐC CHƯA TÌM RA. (3) `EmptyStatePlaceholder` đổi sang cột cuộn khung 390x900 vì tràn 26px khi chia hai `Expanded` trong khung 600px (lỗi bố cục của test, widget không đổi).
- Phát hiện ngoài lề: khi làm đợt này lộ HỒI QUY do chính ENH-117 đợt 1 gây ra (đóng Rx của `LevelUpOverlayController`/`SceneTransitionController` làm `Obx` ném `TypeError` nếu controller dispose trước widget); đã sửa ở `b0aa2f8b`, ghi trong ENH-117.
- Kiểm chứng: analyze sạch; chạy lại cả `test/widget` sau khi sửa file dùng chung `golden_matrix.dart`: 0 test cũ mới đỏ (chỉ `StarRating` macOS-only đã biết). Ổn định trên Linux (bước 7): so từng byte artifact của lần chạy 2 và lần 3 cho 84 ảnh của 11 widget không bị sửa giữa hai lần: 84/84 giống hệt. 21 ảnh còn lại (Spotlight, Tutorial, LevelUp) chỉ có một lần chạy sau khi đổi test nên chưa có phép so hai lần.
