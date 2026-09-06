---
id: ENH-04
title: AuroraBgLayer và NeonAuraLayer trùng lặp gần như 1:1
type: enhance
priority: P2
effort: M
source: Claude (fork nội bộ), verify lại code thật
---

## Hiện trạng
`lib/presentation/widgets/aurora_bg_layer.dart` và
`lib/presentation/widgets/neon_aura_layer.dart` gần như giống hệt nhau: cùng
throttle ticker ~30fps, cùng logic load shader try/catch, cùng cấu trúc
painter — kể cả bug BUG-02 (thiếu dispose shader) cũng lặp lại y hệt ở cả 2
file, chứng minh 2 nơi đang phải sửa song song mỗi khi có bug chung.

## Đề xuất
Rút 1 base class chung (ví dụ `ShaderTickerLayer`) chứa phần load/dispose/
throttle dùng chung, mỗi file con chỉ còn phần shader uniform riêng.

## Acceptance criteria
- [ ] Sửa 1 bug chung (ví dụ BUG-02) chỉ cần sửa ở 1 nơi.
- [ ] Golden test hiện có (`test/widget/aurora_bg_layer_test.dart`,
      `test/widget/neon_aura_layer_test.dart`) vẫn pass không đổi ảnh output.
