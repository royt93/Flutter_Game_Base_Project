---
id: BUG-144
title: "ItemFlyOverlay bay ra ngoài màn hình khi Directionality là RTL (neo start:0 với toạ độ tuyệt đối)"
type: bug
layer: lib/presentation/widgets/common
priority: P3
effort: S
source: "Phát hiện khi làm golden đợt F (ENH-123), 2026-11-24: ảnh rtl của itemflyoverlay trống"
---

## Bằng chứng (probe tạm chạy thật, đã xoá)

`ItemFlyOverlay(from: Offset(60, 500), to: Offset(330, 60), icon: Icons.star, itemCount: 2)` trong cửa sổ 390x600, sau 300ms:

- LTR: tâm hai ngôi sao ở `(195, 250)` và `(141, 342.8)` (trên đường bay `from` -> `to`).
- RTL: cùng tham số, tâm ở `(553, 250)` và `(499, 342.8)`: lệch đúng `+358` (bề rộng màn hình 390 trừ cạnh vật 32), tức ngoài màn hình. Mọi vật bay biến mất khỏi khung nhìn, người chơi RTL không thấy hiệu ứng.

Nguyên nhân: `item_fly_overlay.dart:271` dựng mỗi vật bằng `PositionedDirectional(start: 0, top: 0)` rồi `Transform.translate(offset: pos - itemSize/2)`, trong đó `pos` (từ `itemArcOffsetAt(widget.from, widget.to, ...)`) là toạ độ màn hình tuyệt đối từ mép TRÁI. Ở RTL `start` là mép phải nên gốc neo bị dời sang phải một bề rộng.

`CoinFlyOverlay` cùng họ dùng `Positioned(left: ...)` nên đúng ở RTL (ảnh golden `coinflyoverlay_midflight_rtl` có đủ năm đồng xu).

## Đề xuất

Đổi `PositionedDirectional(start: 0, ...)` thành `Positioned(left: 0, ...)` (một dòng). Test hồi quy: ở RTL, tâm vật giữa chuyến bay bằng đúng tâm ở LTR. CHANGELOG `## Unreleased`: **Fixed** (không phải Behavior change: chỉ sửa vị trí sai ở RTL). Không đổi API công khai.

Cần kiểm trước (BUG-112): grep mọi nơi gọi `ItemFlyOverlay`/`ItemFlyOverlay.show` trong lib và example; xem có nơi nào đang tự bù lệch RTL (nếu có, sửa này làm họ lệch ngược).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Grep call site, đọc doc comment từng nơi, kiểm có nơi nào bù RTL thủ công.
- [x] 2. Test đỏ: ở RTL, `tester.getCenter` của vật sau N ms bằng giá trị ở LTR (cùng `from`/`to`).
- [x] 3. Sửa một dòng ở `item_fly_overlay.dart`.
- [x] 4. Mutation check (đổi lại `PositionedDirectional`, test phải đỏ).
- [x] 5. CHANGELOG `## Unreleased` mục Fixed.
- [x] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Ở RTL, vị trí bay trùng vị trí ở LTR cho cùng `from`/`to`.
- [x] Golden `itemflyoverlay_midflight_rtl` (đợt F) chụp được các vật trên màn hình.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common/item_fly_overlay_test.dart`

## Kết quả thực hiện (2026-11-24)

- Call site (BUG-112): `ItemFlyOverlay` chỉ được gọi từ `example/lib/screens/widget_showcase_screen.dart:2139` (`ItemFlyOverlay.show` với `box.localToGlobal`, toạ độ màn hình tuyệt đối) và từ test; không nơi nào bù RTL thủ công, nên sửa không làm ai lệch ngược. Doc của lớp không hứa "mirror theo RTL".
- Sửa: `item_fly_overlay.dart` đổi `PositionedDirectional(start: 0, ...)` thành `Positioned(left: 0, ...)` kèm comment lý do (cùng cách `CoinFlyOverlay` đã làm).
- Test: `item_fly_overlay_test.dart`, `BUG-144: right-to-left flies along the same screen path as left-to-right`: đỏ trước khi sửa với đúng số đo (RTL `(553, 250)` so với LTR `(195, 250)`), xanh sau khi sửa. Mutation (quay lại `PositionedDirectional`) làm đúng test đó đỏ; lib khôi phục.
- Hệ quả ngoài dự kiến: `tool/accessibility_audit_check.dart` (job `quality-gate`) báo `rtlDirectionalSafety` cho `item_fly_overlay.dart` vì file giờ có `Positioned(left:)` literal; `test/tool/accessibility_audit_check_test.dart` chạy audit trên repo thật nên đỏ theo. Thêm một mục vào `tool/accessibility_audit_baseline.json` với lý do (cùng nhóm "physics-driven motion" như `coin_fly_overlay.dart`, 5 dòng thêm). Audit sạch và test xanh sau đó.
- CHANGELOG `## Unreleased`: mục Fixed (không phải Behavior change: LTR không đổi, không đổi API; API gate unchanged).
- Kiểm chứng: analyze sạch; `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` chỉ đỏ đúng một test (audit, đã sửa bằng baseline); example `widget_showcase_screen_test.dart` 190 pass; các tool quality-gate khác sạch.
