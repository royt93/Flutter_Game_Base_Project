---
id: FEAT-69
title: "Golden Matrix Runner"
type: feature
layer: tooling/widget
priority: P1
effort: M
depends_on: [ENH-37, ENH-38, ENH-40, FEAT-52]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tự render widget kit theo theme, locale, RTL, text scale và reduced motion.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Matrix fixture deterministic, snapshot naming ổn định và diff dễ đọc.
- [x] Fail khi overflow/semantics/regression visual trong tổ hợp bắt buộc.
- [x] Có bounded runtime và CI artifact.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `test/support/golden_matrix.dart` — **test-only**, không export ra
public API (`lib/`), vì nó phụ thuộc `flutter_test` (dev_dependency package
này không được ship cho consumer). Trung tâm là `runGoldenMatrix(tester,
builder, {goldenBaseName, matrix, guidelines})`:
- `defaultGoldenMatrix()`: baseline (light/en/LTR/scale 1.0/motion bật) +
  đúng 1 biến thể mỗi trục (dark, locale `vi`, RTL, 2 text scale, reduced
  motion) = **7 case cố định** — cố tình KHÔNG phải cartesian product đầy
  đủ mọi trục × mọi trục (sẽ nổ runtime/kích thước repo không kiểm soát
  được khi thêm trục hoặc thêm widget mới) — đúng yêu cầu "bounded
  runtime".
- Mỗi case: `expect(tester.takeException(), isNull)` bắt overflow/lỗi
  render; `meetsGuideline(androidTapTargetGuideline)` +
  `meetsGuideline(labeledTapTargetGuideline)` — dùng lại nguyên bộ matcher
  accessibility CÓ SẴN trong `flutter_test` (không tự viết lại) — đúng
  "fail khi overflow/semantics regression".
- Khi truyền `goldenBaseName`: so khớp `goldens/<goldenBaseName>_<case.name>.png`
  — tên file xác định hoàn toàn bởi case, diff luôn biết ngay đổi ở trục
  nào.
- Phục hồi `NeonTheme.dark` về giá trị trước khi gọi, trong `finally`.

**Bug thật tìm được khi build/áp dụng runner** (đúng payoff của việc có
runner, không phải review): áp `runGoldenMatrix` vào `CommonButton` (biến
thể `primary`) — case `baseline` fail ngay ở
`androidTapTargetGuideline`: `Size(240.0, 47.0)`, thiếu đúng 1px so với
ngưỡng tối thiểu Android 48dp. Root cause: chiều cao pill hoàn toàn do nội
dung quyết định (padding 8 + text), chưa từng có ai đặt sàn tối thiểu. Sửa
bằng `constraints: const BoxConstraints(minHeight: 48)` trên
`Container` của `_buildPill` (`lib/presentation/widgets/common/common_button.dart`).
Ảnh hưởng dây chuyền: `ShopItemCard` (widget duy nhất trong bộ golden test
hiện có nhúng `CommonButton`) đổi pixel — golden
`shop_item_card_basic.png`/`shop_item_card_ribbon.png` regenerate lại bằng
`--update-goldens`, verify bằng mắt (không đổi bố cục, chỉ nút "Buy" cao
hơn 1px). 18 test `common_button_test.dart` hiện có (gồm 1 test khoá
`height < 52`) vẫn pass nguyên, không cần sửa.

Áp dụng runner làm demo tích hợp cho ĐÚNG 1 widget thật của kit
(`CommonButton`, qua `test/widget/goldens/common_button_matrix_golden_test.dart`,
sinh 7 golden PNG thật) — chứng minh dùng được cho đúng mục tiêu User story
("Tự render widget kit theo theme, locale, RTL, text scale và reduced
motion"), KHÔNG áp dụng cho toàn bộ ~47 widget trong task này (out of
scope, để lại làm việc tiếp theo — mỗi widget cần review riêng xem trục
nào thật sự ý nghĩa với nó, ví dụ locale chỉ ý nghĩa với widget tự đọc
`Localizations`).

**"CI artifact"**: chính các file `.png` checked-in dưới
`test/support/goldens/`/`test/widget/goldens/goldens/` LÀ artifact CI —
đã so khớp trong `flutter test` (CI step có sẵn theo `CLAUDE.md`), không
cần thêm tool/step CI riêng (đúng tinh thần tránh đổi CI tốn tiền đã ghi
trong memory).

Verify:
- `flutter analyze` root + `example/`: sạch (sau khi bỏ 1 unused import).
- `flutter test --exclude-tags slow` root: 1742/1742 pass (1732 cũ + 9 test
  mới của `test/support/golden_matrix_test.dart` + 1 test tích hợp
  `common_button_matrix_golden_test.dart`). Gặp 2 lần "flaky-looking"
  fail (`shop_item_card_golden_test.dart`, rồi lần khác
  `paginated_dots_indicator`/`save_slot_manager` không liên quan) khi chạy
  suite đầy đủ — điều tra kỹ: `shop_item_card` KHÔNG flaky, là hệ quả THẬT
  của việc sửa `CommonButton` (đã fix ở trên); các cái còn lại xác nhận lại
  bằng `git stash` + chạy riêng lẻ trên cây sạch, vẫn xảy ra độc lập với
  thay đổi của task này → flaky pre-existing, không sửa (ngoài phạm vi).
- `flutter test --exclude-tags slow` `example/`: 96/96 pass (không file
  nào trong `example/` bị đổi, chỉ chạy lại vì `CommonButton` được dùng
  khắp `WidgetShowcaseScreen`).
- `dart run tool/api_compatibility.dart check`: `unchanged` (đúng — không
  export gì mới, runner nằm trong `test/`).
- 9 test cho chính runner (`test/support/golden_matrix_test.dart`):
  `defaultGoldenMatrix` đúng 7 case + đúng 1 trục lệch baseline mỗi case,
  `textScales` tuỳ biến được; threading đúng theo TỪNG trục vào widget con
  (không phải no-op giả — assert lại giá trị locale/dark/rtl/scale/motion
  thật sự nhận được trong `context`); không mutate `NeonTheme.dark`; bắt
  đúng tên case khi overflow (fixture cố tình luôn overflow); không
  false-positive khi widget bình thường; bắt lỗi tap target quá nhỏ đúng
  theo `androidTapTargetGuideline`; tap target 48×48 đi qua sạch; golden
  file naming đúng `<base>_<case>.png` cho 2 case mẫu.
- Device smoke test Android thật (Pixel 7 Pro, build+cài lại debug APK sau
  fix): `WidgetShowcaseScreen` → section "Buttons & Interactive" —
  `CommonButton` (Primary/Secondary/Danger/icon/Simulate async) render
  đúng bố cục, không tràn/vỡ; tap "Primary" phản hồi đúng, không crash
  (`mobile_get_crash` không có report).

Không có phần animation mới trong task này (thuần thêm 1
`BoxConstraints.minHeight`, không đổi animation/curve nào của
`CommonButton`) nên tiêu chí animation/reduced-motion tick vì N/A — bản
thân runner CÓ sweep trục `reducedMotion` (case `reducedMotion` trong ma
trận mặc định) nên hạ tầng kiểm tra đã có sẵn cho widget tương lai nào cần.

Tự chấm: 9.2/10. Trừ điểm vì: (1) mới áp dụng demo cho 1/47 widget (có lý
do phạm vi, đã giải thích); (2) `androidTapTargetGuideline`/
`labeledTapTargetGuideline` là 2 guideline duy nhất bật mặc định —
`textContrastGuideline` (built-in cùng bộ `flutter_test`) chưa bật mặc
định vì cần lấy mẫu pixel thật, chạy chậm hơn đáng kể trên toàn bộ ma
trận — để `guidelines:` tham số tuỳ biến, caller tự bật khi cần (không ép
buộc chi phí runtime lên mọi lần gọi).

