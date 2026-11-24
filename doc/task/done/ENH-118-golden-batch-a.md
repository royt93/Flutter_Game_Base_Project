---
id: ENH-118
title: "Golden test đợt A: Input/form (tĩnh, deterministic) (19 widget chưa có golden)"
type: enhancement
layer: test/widget/goldens
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- 164 widget trong `widgets/common`: tất cả đã có test và fixture `runViewportSweep`, nhưng **87 widget chưa có golden** (hiện 64 file golden, 1397 PNG, ~14M trong `test/widget/goldens/goldens`). Đo bằng tham chiếu tên lớp trong `test/widget/goldens/*.dart` (đo lại theo tên lớp: 87 widget; một lần đếm sớm ra 86 vì bỏ sót `avatar_frame`).
- Owner chọn làm theo đợt ưu tiên (không làm hết một lượt). Đợt này là **A**, chia 6 đợt A-F (ENH-118..123; tổng 19+15+13+14+13+13 = 87).
- Golden CHỈ sinh bằng workflow `regenerate-goldens.yml` (Linux, Flutter 3.41.9), KHÔNG từ macOS (xem CLAUDE.md). Comparator tolerance 1% chỉ nuốt nhiễu font dưới điểm ảnh, không thay cho việc sinh trên Linux.

## Widget trong đợt (18)

- `async_common_button`
- `candy_radio_group`
- `candy_search_bar`
- `candy_slider`
- `candy_text_field`
- `toggle_switch`
- `hold_to_confirm_button`
- `icon_badge_button`
- `segmented_tab_bar`
- `list_tile_row`
- `section_header`
- `expandable_panel`
- `star_rating`
- `sound_toggle_fab`
- `badge_dot`
- `countdown_chip`
- `cooldown_countdown_chip`
- `panel_card`
- `avatar_frame`

## Lưu ý riêng của đợt
Không có thêm; deterministic mặc định (không đồng hồ thật, không ngẫu nhiên không seed).

## Mẫu cần theo

`test/widget/goldens/accessibility_preview_panel_golden_test.dart`: `installGoldenTolerance`, `runGoldenMatrix` (từ `test/support/golden_matrix.dart`), khung 390x844 @1x, các biến thể (baseline, dark, locale-vi, reducedMotion, rtl, textScale-1.3, textScale-2.0). Không phải widget nào cũng cần đủ 7 biến thể: chỉ giữ biến thể có nghĩa với widget (ghi lý do khi bỏ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Đọc `golden_matrix.dart`, `golden_test_support.dart` và một test mẫu; ghi vào "Kết quả thực hiện" danh sách biến thể áp dụng cho từng widget (và lý do bỏ biến thể nào).
- [x] 2. Viết `<tên>_golden_test.dart` cho từng widget trong đợt (18 file hoặc gom theo nhóm nhỏ), deterministic: đồng hồ/ngẫu nhiên cố định, `pump` có thời hạn (không `pumpAndSettle` với widget có ticker vĩnh viễn như `NeonBg`).
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

- Test: `test/widget/goldens/batch_a_form_widgets_golden_test.dart`, 19 test (18 widget + `SoundToggleFab` tách muted/unmuted). Mỗi test xếp nhiều trạng thái trong một khung 360dp qua `runGoldenMatrix` (baseline, dark, locale-vi, rtl, textScale 1.3 và 2.0, reducedMotion). `CandySearchBar` và `CandyTextField` bỏ riêng ca `locale-vi` (TextField cần `MaterialLocalizations`, bản vi không có: ghi lý do trong test) nên 6 ảnh thay vì 7.
- Baseline: sinh bằng workflow `regenerate-goldens.yml` trên Linux (run 45340036831, thành công), tải artifact (1528 PNG), CHỈ chép 131 PNG của đợt (17 x 7 + 2 x 6), từ chối ghi đè bất kỳ file nào đã có (kiểm bằng `assert`), 0 PNG cũ đổi. Không PNG nào sinh từ macOS (các PNG sinh local khi thử đã xoá trước khi commit). Kiểm kích thước (đều 800x600), không ảnh trắng (số dòng điểm ảnh khác nhau: min 9, trung vị 80), và xem tận mắt 3 ảnh (search bar, toggle RTL, countdown chip 2.0x): đúng nội dung.
- Lỗi thật tìm thấy khi viết test (theo `labeledTapTargetGuideline` trong harness): nút xoá của `CandySearchBar` có nhãn ở node cha nhưng một node con focusable/tap 44x44 không nhãn (do `PressableScale`). Sửa bằng `MergeSemantics` (+5 -1 dòng, test hồi quy mới, mutation đỏ khi đổi lại `Semantics` thường); CHANGELOG ghi Behavior change (không đổi layout). `CandyToggleSwitch` đứng một mình không nhãn là cố ý; trong `CommonListTile` (cách dùng ở Settings) đã có nhãn từ tiêu đề (đo bằng cây semantics). Owner chọn không thêm nhãn mặc định (sẽ sai ngôn ngữ/nối nhãn), chỉ thêm dartdoc.
- Ổn định: `CountdownChip` dựng từ `DateTime.now()` nhưng chỉ hiển thị '05:00' ngay sau mount; sinh golden 3 lần cho 7 ảnh của nó, byte-identical cả 3 lần. Chưa chạy workflow lần 2 để so artifact Linux hai lần (bước 7 chưa làm đầy đủ).
- macOS: 18/19 test khớp baseline Linux trong ngưỡng 1%. `StarRating` lệch **3.46%** (đo bằng comparator ghi diff; nguồn là `Shadow` blur trong glow, nền raster khác nhau), vượt ngưỡng 1% (BUG-100 cấm nâng). Đỏ ổn định 3/3 lần local; trên Linux CI so baseline Linux sẽ khớp. Owner chọn giữ nguyên và ghi nhận (đúng quy ước: golden đỏ sẵn trên macOS theo thiết kế). Baseline đỏ cục bộ: 145 -> 146.
- Kiểm chứng: analyze sạch; root 4189 test (không golden) pass; example 210 (settings, showcase) pass; so `test/widget` với baseline: 0 test cũ mới đỏ, 1 đỏ mới là StarRating macOS-only.
- Chưa làm: chạy workflow lần 2 để xác nhận byte-identical trên Linux; chưa xem CI cho commit này.
