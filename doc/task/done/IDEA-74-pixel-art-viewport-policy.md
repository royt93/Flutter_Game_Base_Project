---
id: IDEA-74
title: "Pixel-art viewport and scaling policy"
type: idea
layer: presentation/game
priority: P3
effort: S
status: speculative
---

## Giả thuyết

Pixel-art consumers có thể gặp blur hoặc scale không nhất quán khi viewport thay đổi giữa thiết bị.

## Ý tưởng

Khảo sát cookbook/example về logical resolution, integer scaling, camera viewport và letterboxing; helper chỉ được đề xuất nếu nhiều consumer cùng cần policy chung.

## Discovery gate

- [ ] Xác nhận art style và resolution target từ use case thật.
- [ ] Đo/quan sát trên aspect ratios và pixel densities đại diện.
- [ ] Nêu trade-off giữa integer scaling, crop và letterboxing.
- [ ] Ưu tiên docs/example thay vì public API nếu native Flame camera đủ.

## Prompt loop feature

Rà Flame camera/viewport APIs, RoyGame và test setup. Không áp đặt pixel-art assumptions lên toàn bộ casual games. Nếu consumer xác nhận nhu cầu, đề xuất cookbook/demo trước; API chỉ khi dùng lặp lại và có lợi ích rõ. Với mọi implementation đã duyệt: audit diff, score /10, tests cho viewport/resolution cases, screenshot/device smoke trên nhiều kích cỡ phù hợp; score >9 không tự cho phép push, cần approval và CI xanh.

## Quyết định

Người dùng duyệt đóng no-go. Chưa có pixel-art consumer, target art style hay resolution để đặt policy chung; dùng Flame viewport native. Mở lại khi có target/resolution cụ thể.
