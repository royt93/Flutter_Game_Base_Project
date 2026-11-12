---
id: BUG-106
title: "RoyCasualKit.resetForTesting không phục hồi palette đã importPalette"
type: bug
layer: lib/core/kit_bootstrap + neon_theme
priority: P2
effort: S
source: "Scan SDK 2026-11-12; đã tái hiện bằng test tạm"
---

## Vị trí
`lib/core/kit_bootstrap.dart:202-211` (`resetForTesting` chỉ đặt `NeonTheme.dark` và `colorBlindSafe`).

## Tái hiện (đã chạy)
`NeonTheme.importPalette({'cyan': '#123456', 'lockedBorderLight': '#010203'})` rồi `await RoyCasualKit.resetForTesting()`: `NeonTheme.exportPalette()` vẫn khác giá trị ban đầu. Test hỏng ở dòng `expect(exportPalette(), before)`.

## Hậu quả
Test của consumer rò màu giữa các test khi dùng reskin. Test nội bộ (`neon_theme_test.dart`, `theme_contrast_validator_test.dart`) tự phục hồi bằng `importPalette(original)` trong `tearDown`; consumer không biết phải làm vậy.

## Hướng sửa
Thêm `NeonTheme.resetPalette()` (giữ bản mặc định làm const/snapshot lúc khởi tạo) và gọi trong `resetForTesting`. Thêm test tái hiện ở `test/core/kit_bootstrap_test.dart`. Thêm vào API công khai nên cần regenerate `api_snapshot.json` và ghi CHANGELOG.

## Kết quả (2026-11-12)
Thêm `NeonTheme.resetPalette()` với bảng mặc định `const` tường minh (một bản chụp lazy sẽ lấy sau khi reskin đã chạy nên không dùng được). `resetForTesting` gọi nó. Test chống lệch hai bản mặc định (`neon_theme_test.dart`: `exportPalette()` sau reset bằng giá trị chụp ở `setUp`, đủ 32 key) và test tái hiện ở `kit_bootstrap_test.dart`; đã chứng minh test đỏ khi bỏ dòng `resetPalette()`. API gate: additive (`NeonTheme.resetPalette()`), snapshot cập nhật, CHANGELOG 0.6.9.

## Tiêu chí xong
Test tái hiện xanh; test nội bộ có thể bỏ `tearDown` thủ công (tuỳ chọn).
