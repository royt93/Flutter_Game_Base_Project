---
id: ENH-123
title: "Golden test đợt F: Chỉ-hoạt-ảnh (nhạy flaky, làm cuối) (13 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P4
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **F**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (13)

- `card_flip_3d`
- `coin_fly_overlay`
- `confetti_overlay`
- `floating_combo_text`
- `floating_emoji_burst`
- `golden_shimmer_text`
- `item_fly_overlay`
- `pooled_particle_burst`
- `radial_action_menu`
- `scene_transition_overlay`
- `screen_shake`
- `shimmer_placeholder`
- `squash_stretch`

## Lưu ý riêng của đợt
Widget hạt/bay/rung cho ảnh khác nhau mỗi lần nếu không cố định thời điểm và seed. BẮT BUỘC chụp ở một mốc thời gian xác định (pump đúng N ms với `Duration` cố định) và có seed; nếu một widget vẫn không ổn định giữa 2 lần workflow thì loại widget đó khỏi golden và ghi lý do (thay bằng test hành vi).

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [x] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (13 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
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

## Kết quả thực hiện (2026-11-28)

- Test: `test/widget/goldens/batch_f_motion_widgets_golden_test.dart`, 11 test x 7 biến thể (baseline, dark, locale-vi, rtl, textScale 1.3 và 2.0, reducedMotion) = 77 PNG, 390x600. `FloatingEmojiBurst` cố định seed=7 và ba origin; `PooledParticleBurst` seed=42; thời điểm mỗi ảnh cố định qua pump bước nhỏ.
- Không phủ có chủ đích: `ConfettiOverlay` gọi `Random()` không seed trong `initState`, không có tham số seed; golden sẽ không ổn định và cần đổi API công khai. Hàm thuần `generateConfettiParticles(random: Random(seed))` đã có unit test; ghi nguyên nhân vào đầu file test. `SceneTransitionOverlay` cần controller chạy future bất đồng bộ; pha được test hành vi, ảnh một frame không thêm giá trị.
- Phát hiện và sửa golden rỗng ngay trong lượt này: `FloatingEmojiBurst` ban đầu ba lần spawn cùng origin nên chồng một hình; dời ba origin sang x=0.2/0.5/0.8. Golden rà lại sau đó có 3 vị trí tách biệt. `RadialActionMenu` tap bằng finder hụt nút ở góc của host, sửa gọi state `.open()` để golden thực sự ở trạng thái mở.
- Phát hiện BUG-144 trong `ItemFlyOverlay`: ở RTL các vật bay khỏi màn hình do `PositionedDirectional(start: 0)` trộn với toạ độ màn hình tính từ trái. Sửa lib riêng, test hồi quy đỏ trước/xanh sau, mutation bị bắt, ghi CHANGELOG và suppression audit có lý do; chi tiết tại `doc/task/done/BUG-144-item-fly-overlay-off-screen-in-rtl.md`. Golden RTL mới cho thấy các vật trên màn hình.
- Baseline Linux: `45429557603` sinh bộ F ban đầu; sau khi đổi ba origin chạy thêm `45431001481` và `46106953476`. Chép CHỈ 77 PNG từ run `46106953476`, không đè file cũ. So ổn định: 70 PNG không đổi (70/70 byte giống với bộ trước); 7 PNG `FloatingEmojiBurst` (6 ảnh thay, ảnh reducedMotion trống đúng thiết kế) giống từng byte giữa hai run sau sửa (`45431001481`/`46106953476`). Tổng 77/77 ổn định theo đúng bản test cuối. Đã xem tận mắt card flip, emoji burst, pooled particles, radial menu, item flight RTL.
- Kiểm đếm màu phát hiện và loại các golden "đánh lừa": 5/7 ảnh ban đầu của `FloatingComboText` và `ItemFlyOverlay` bị chụp sau khi State đã chạy xong ở case đầu; matrix được đổi thành một `runGoldenMatrix` mỗi case và unmount giữa case, giữ đúng frame. `StaggeredAnimatedGrid` cũng cần nhiều pump nhỏ vì một pump dài chỉ chạy Timer nhưng không chạy ticker mới. Sau sửa, chỉ còn 4 ảnh một màu là widgets trả `SizedBox.shrink()` dưới `reducedMotion`, đúng thiết kế.
- Cổng cuối: `flutter analyze` sạch; `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4233 pass; `api_compatibility` unchanged; 5 tool quality-gate sạch.
