---
id: BUG-11
title: "ci.yml nhắc tới nightly.yml nhưng file không tồn tại"
type: bug
priority: P2
effort: S
verified: true
source: Claude, phát hiện khi audit bổ sung (ls .github/workflows/ chỉ có ci.yml)
---

## Vị trí
`.github/workflows/ci.yml:4` — comment: "BỎ QUA nhóm 'slow' của integration
vì cần thiết bị thật — chạy ở nightly.yml)."
`.github/workflows/` thực tế chỉ có đúng 1 file: `ci.yml`. `nightly.yml`
không tồn tại.

## Vấn đề
Comment trỏ tới 1 workflow không có thật — nếu sau này có test tag `slow`
thật (`dart_test.yaml` đã khai sẵn tag này chờ dùng), sẽ không có nơi nào
chạy chúng cả, dễ gây ảo giác "đã có nightly lo việc này rồi" trong khi thực
tế không có.

## Đề xuất fix
Chọn 1 trong 2:
1. Tạo `nightly.yml` thật (cron schedule, chạy `flutter test` không loại trừ
   tag `slow`) — cần thiết khi có integration test tag `slow` đầu tiên.
2. Nếu chưa cần ngay, sửa comment trong `ci.yml` cho khớp thực tế (bỏ nhắc
   tới file chưa tồn tại, hoặc ghi rõ "TODO: tạo nightly.yml khi có test slow đầu tiên").

## Acceptance criteria
- [ ] Comment trong `ci.yml` khớp đúng với những gì thực sự tồn tại trong `.github/workflows/`.
