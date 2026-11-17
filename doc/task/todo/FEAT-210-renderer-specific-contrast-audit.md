---
id: FEAT-210
title: "Renderer-specific contrast audit for StrokeText and canvas-painted labels"
type: feature
layer: test/support + test/widget/common
priority: P2
effort: M
source: "FEAT-205 confirmed gaps: auditRenderedTextContrast sees RichText only; custom-painted labels are skipped"
---

## Vấn đề
FEAT-205 harness đo `RichText`/`TextSpan` trên nền phẳng. Prototype xác nhận fill của `StrokeText` dùng `TextStyle.color` và đã được audit; riêng chữ do `TextPainter` vẽ trực tiếp lên `Canvas` chưa được đo. `flutter_test` dùng Ahem mặc định: goldens bắt layout, stroke và màu nhưng glyph hiện thành khối, không xác minh hình dạng font/nội dung ký tự render thật.

## Phạm vi
- `StrokeText` fill: đã xác nhận harness hiện tại bắt fill contrast; giữ semantics label và xem stroke là outline trang trí, không foreground text. Không thêm xử lý production khi chưa có lỗi.
- [x] Đo foreground và nền thực cho nhãn trong `CoinMultiplierWheel` (`xN`) và `WheelSpinner` (segment label), light/dark, gồm màu segment tuỳ biến, với background opaque bắt buộc được painter vẽ dưới vùng sector.
- [x] Dùng helper alpha/composite chung với painter; report `<4.5:1` bằng `contrastFindings`, không sửa màu. Shadow đen của `CoinMultiplierWheel` không tính vào ratio (WCAG foreground/background).
- [x] Tests cho alpha composition, nền opaque bắt buộc, màu segment tối/sáng, palette built-in ở win (alpha 1)/unwin (alpha 0.85). Test WheelSpinner kiểm `shouldRepaint` khi nền đổi. Call sites cập nhật; API snapshot/CHANGELOG cập nhật cho source-breaking required parameter.
- Nền wheel được cố ý tô trong circle/annular sectors; vùng ngoài giữ trong suốt. Pixel readback `toImage` trong widget test vượt timeout 200s, nên verification geometry hiện qua painter code review và input tests, không raster golden.

## Không làm
- Không audit mọi `CustomPaint` hay mọi shader/gradient trong SDK.
- Không đổi màu hiện hành trước khi có số đo thật và quyết định riêng cho từng lỗi.
- Không thay đổi icon accent đã được ghi nhận theo quyết định người dùng trong FEAT-205.
- Không coi pixel golden Ahem là bằng chứng WCAG.

## Tiêu chí xong
- [x] `StrokeText` fill audit được bằng harness hiện hành, đúng semantics; prototype tests pass.
- [x] `WheelSpinner` và `CoinMultiplierWheel` có required opaque background thật sự được vẽ dưới sectors, contrast findings dùng chính sector color/alpha của painter, reporting-only.
- [x] Contrast tính theo nền/alpha thực và ghi nhận production findings dưới 4.5:1; màu không bị tự đổi theo quyết định người dùng.
- Regression fixture cố tình dưới ngưỡng bị phát hiện; fixture đạt ngưỡng qua.
- Bất kỳ vi phạm production nào được liệt kê kèm tỷ lệ light/dark và mở BUG riêng trước khi sửa giao diện.
- Docs phân biệt rõ kiểm tra text semantics, contrast, và hình dạng glyph/font.

## Rủi ro / giới hạn
`Canvas` compositing, alpha, anti-aliasing và nền có nhiều lớp làm lấy mẫu pixel khó ổn định; phép đo màu cấu hình phải theo đúng paint inputs thực tế và không được quảng cáo là WCAG certification cho toàn cây render.

## Bằng chứng hiện có (2026-11-17)
- `StrokeText` có 5 call-site trong `common/`: `CommonButton`, `GameOverCardTemplate`, `GoldenShimmerText`, `HoldToConfirmButton`, `VictoryCardTemplate`; hai card template truyền accent làm fill.
- Hai custom `TextPainter` trong `common/`: `CoinMultiplierWheel` (nhãn multiplier màu trắng trên wedge) và `WheelSpinner` (segment labels màu trắng trên wedge màu tuỳ chỉnh).
- `StrokeText` dùng `Semantics(label: text)`; Flutter test font Ahem mặc định được xác nhận trong `flutter_test` binding tại `/Users/LoiTP/development/flutter/packages/flutter_test/lib/src/binding.dart:2364`.

## Prototype StrokeText hoàn tất (2026-11-17)
- Thêm hai test trong `test/widget/common/contrast_audit_test.dart`: fill vàng 1.22:1 trên trắng tạo đúng một finding (fill là `TextStyle.color`; outline đen `TextStyle.foreground` không bị tính nhầm thành chữ); semantics chỉ expose một label `Warning` và không có semantics node con trùng.
- `contrast_audit.dart` và `stroke_text.dart` không cần sửa. `CoinMultiplierWheel`/`WheelSpinner` TextPainter labels vẫn là phần renderer-specific còn lại.
- `flutter test --no-pub test/widget/common/contrast_audit_test.dart`: 26 tests pass.


## API/verification (2026-11-17)
- `WheelSpinner`/`CoinMultiplierWheel` yêu cầu `backgroundColor` opaque; background đó được vẽ dưới segment fill thật. Nền ngoài geometry giữ nguyên trong suốt.
- `contrastFindings` đo trắng trên segment đã composite đúng alpha, ngưỡng AA 4.5:1; report-only, không auto-adjust.
- `CHANGELOG.md` có BREAKING Behavior change; `tool/api_snapshot.json` regenerate, `dart run tool/api_compatibility.dart check` pass.

## Implementation / audit result (2026-11-17)
- Added required opaque `backgroundColor` to both wheel widgets; each painter paints it only under sector geometry (circle for `WheelSpinner`, annular path per sector for `CoinMultiplierWheel`), preserving transparency outside geometry. `WheelSpinner` loses `const`; call sites updated.
- Shared `wheel_label_contrast.dart` performs exact sector-fill alpha compositing then WCAG ratio against white. The same `wheelPaintedSectorColor` helper supplies CoinMultiplierWheel painter alpha (1.0 winning, 0.85 other) and findings. The black 0.6 shadow is excluded by the user-approved WCAG foreground/background definition.
- `contrastFindings` on each widget reports indexes/labels/multiplier and ratios below 4.5; no colors are changed. Background alpha must equal 1.0.
- Tests: caller alpha composition, bad/good WheelSpinner segment findings, CoinMultiplierWheel built-in palette branches + win/unwin alpha behavior, opaque background validation. The pixel readback (`toImage`) geometry test exceeded 200 seconds in Flutter test binding and was removed at user choice; geometry currently reviewed in painter implementation, with background passed through painter test on WheelSpinner.
- **Measured report-only findings on matching default theme background:** white labels on WheelSpinner supplied built-in accents: 2.04 (cyan), 1.92 (lime), 1.79 (gold), 2.04 (orange). CoinMultiplierWheel: light/unwinning (alpha .85) 1.85, 1.75, 1.66, 1.84 for multipliers 2/3/5/10; dark/unwinning 2.66, 2.52, 2.38, 2.68. All below 4.5. Winning sectors have higher ratios due alpha 1.0 but remain below 4.5 in probe. No color auto-adjusted by user choice; open one remediation BUG per widget/design decision before changing appearance.
- `WheelSpinner` required `backgroundColor` is source-breaking (`const` removed); `CoinMultiplierWheel` adds required parameter. `CHANGELOG.md` BREAKING Behavior change added; `tool/api_snapshot.json` regenerated and API check passes.
- Verification: analyzer clean; `accessibility_audit_check.dart` clean; API compatibility check clean; `flutter test --no-pub --exclude-tags slow test/widget/common` 1904 pass; focused wheel tests 41 pass.

## Production findings follow-up (2026-11-17)
- `WheelSpinner`: built-in showcase segment colors on light background yield 1.79–2.04:1; caller-supplied colors can vary. Tracked separately as BUG-130; no auto-fix in audit task.
- `CoinMultiplierWheel`: built-in sectors below 4.5:1 in both win/non-win alpha states on light/dark declared backgrounds (dark non-winning 2.38–2.68:1; light non-winning 1.66–1.85:1). Tracked as BUG-131; no auto-fix in audit task.
- FEAT-210 audit scope complete; BUG-130/131 own UI remediation decisions.
