---
id: IDEA-82
title: "2D sprite authoring and integration checklist"
type: idea
layer: docs/assets
priority: P3
effort: S
status: speculative
---

## Giả thuyết

Consumer có thể tiết kiệm thời gian nếu có checklist ngắn về sprite naming, frame dimensions, pivots, scale, atlas references, licensing và preload dependencies.

## Ý tưởng

Tạo checklist/cookbook dựa trên Flame API và asset examples thực tế; không tạo format/framework riêng.

## Discovery gate

- [ ] Hỏi consumer câu hỏi asset nào lặp lại hoặc lỗi integration nào hay gặp.
- [ ] Kiểm tra docs hiện có và Flame official concepts để tránh duplicate.
- [ ] Chỉ viết quy tắc đã được repo/test xác nhận; tách recommendation khỏi requirement.
- [ ] Liên kết với DISC-01 nếu cùng người/goal để tránh hai tài liệu discovery rời.

## Prompt loop feature

Đọc docs/package asset policy, asset preload docs/tests và DISC-01. Xác minh mọi ví dụ với Flame version đang dùng. Không thêm asset binary hoặc documentation framework. Nếu được duyệt, kiểm tra command/API snippets có thể chạy và ghi rõ license/asset ownership. Docs-only change không cần device smoke; kiểm tra phù hợp theo CI. Audit/score /10; user approval trước commit/push, CI xanh trước push.

## Kết quả discovery (2026-10-24)

- Không có sprite image/atlas assets trong package/example để làm ví dụ đã kiểm chứng; example có audio và JSON, với manifests license tương ứng (`example/assets/LICENSES.json`).
- Asset licensing policy và checker đã có, bao gồm generic roots `--asset-roots` (`tool/asset_license_check.dart`; BUG-99), nên không cần checklist riêng để tạo lại format license.
- Asset dependency/preload policy được kiểm tra/test qua `AssetPreloadCoordinator`; nhưng chưa có sprite authoring/atlas format hoặc consumer workflow để kết luận yêu cầu naming, pivot, frame size.
- Docs nên dựa trên API/asset thật; tự viết checklist chung hiện tại sẽ là lời khuyên generic, không mang bằng chứng package-specific.

## Kết luận

Chưa đủ căn cứ cho checklist sprite độc lập. Không thêm docs/code. Gộp câu hỏi asset workflow vào `DISC-01`; nếu consumer cung cấp sprite/atlas use case và lỗi onboarding cụ thể, mở lại checklist nhỏ dựa trên asset/API đã kiểm chứng.

## Quyết định

Người dùng duyệt đóng no-go. Chưa có consumer need hay sprite asset để viết checklist package-specific; nội dung asset workflow được gộp vào `DISC-01`. Mở lại nếu consumer nêu lỗi onboarding cụ thể.
