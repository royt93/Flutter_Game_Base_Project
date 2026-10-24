---
id: IDEA-73
title: "Sprite atlas preflight validator"
type: idea
layer: tooling/assets
priority: P2
effort: M
status: speculative
---

## Giả thuyết

Asset naming/frame metadata mismatch có thể chỉ lộ ra lúc game chạy, làm chậm quá trình tích hợp sprite sheet/atlas.

## Nền tảng

`AssetPreloadCoordinator` quản lý dependency preload; showcase khai báo `atlas` trước `player_sprite`. Chưa thấy validator chuyên sprite metadata.

## Ý tưởng

Khảo sát validator/CLI test để kiểm tra referential integrity giữa manifest và atlas/frame names; không buộc consumer đổi asset format nếu Flame đã cung cấp cơ chế tương đương.

## Discovery gate

- [ ] Xác nhận lỗi atlas/frame mapping từng xảy ra hoặc yêu cầu tooling cụ thể.
- [ ] Xác định format(s) thật sự dùng; tránh hỗ trợ speculative nhiều formats.
- [ ] So sánh validator với Flame/asset-pipeline tooling đã có.
- [ ] Định nghĩa lỗi actionable và kiểm thử fixture hợp lệ/không hợp lệ trước khi đề xuất FEAT.

## Prompt loop feature

Đọc manifest/preload implementation, tests, example assets và task `DISC-01`. Chỉ đề xuất format và validator sau khi có consumer use case; không thêm dependency trước khi chứng minh stdlib hiện có không đủ. Nếu được duyệt thành feature, viết fixture test cho valid, missing frame, duplicate/invalid mapping và CI command integration. End loop: audit/score /10, unit/integration tests phù hợp, analyzer; device smoke không áp dụng cho validator thuần trừ khi kèm runtime UI. Xin approval trước commit/push; push chỉ sau approval + CI xanh, không tự động do score.

## Quyết định

Người dùng duyệt đóng no-go. Chưa có consumer atlas format, naming contract hoặc tái hiện lỗi frame mapping; không tạo validator. Mở lại khi có atlas/use case cụ thể.
