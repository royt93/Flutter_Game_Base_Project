---
id: IDEA-79
title: "Sprite atlas memory budget tooling"
type: idea
layer: tooling/performance
priority: P3
effort: M
status: speculative
---

## Giả thuyết

Texture atlas dimensions/format có thể tạo footprint bộ nhớ lớn hơn dự kiến và gây áp lực trên thiết bị hạn chế.

## Ý tưởng

Khảo sát report ước tính footprint atlas từ dimensions/format metadata, kèm budgets theo target profile; phân biệt rõ estimated bytes với runtime GPU residency.

## Discovery gate

- [ ] Thu thập atlas size/format thực từ consumer workloads.
- [ ] Xác định metadata source và texture compression/platform variance.
- [ ] Kiểm tra tool/asset pipeline hiện có trước khi thêm validator.
- [ ] Chỉ đặt threshold sau khi đo trên thiết bị và giải thích sai số.

## Prompt loop feature

Đọc asset/license/performance tooling và atlas sample có quyền sử dụng. Không suy GPU memory thực từ kích thước file nén; report ước tính phải nêu giả định và sai số. Nếu duyệt, unit tests cho format/dimensions, integration fixture và benchmark/device evidence nếu policy có claim về runtime memory. End loop audit/score /10. Không thay threshold hay baseline chỉ từ outlier; commit/push cần user approval và CI xanh.

## Kết quả discovery (2026-10-24)

- Không tìm thấy sprite atlas assets mẫu trong repository; `example/assets/` chỉ có audio và remote-config JSON. Showcase atlas/player entries dùng loader giả lập (`example/lib/screens/widget_showcase_screen.dart:933-969`).
- `AssetPreloadCoordinator` nhận `AssetKind.image` và caller-injected loader; không đọc texture dimensions/format hay theo dõi GPU memory (`lib/core/asset_preload_coordinator.dart:7-10,46-52`).
- Existing performance budget tooling có baseline/measurement-source policy cho metric đã đo (`tool/performance_budget_check.dart`); không có raw atlas/device texture samples để đặt baseline hoặc ngưỡng đáng tin.
- Compressed asset file size không xác định GPU residency; estimate cần dimensions, pixel format, mipmaps, compression/runtime backend. Repo chưa có metadata contract.

## Kết luận

No-go cho tooling/threshold hiện tại. Chưa có asset workload, input metadata contract, hoặc runtime measurement evidence; estimate giả sẽ tạo độ chính xác gây hiểu lầm. Giữ idea trong `inprogress` chỉ khi consumer cung cấp atlas mẫu/format và thiết bị mục tiêu; nếu không, đóng discovery không implement.

## Quyết định

Người dùng duyệt đóng no-go. Discovery không tìm thấy atlas, metadata contract hay device measurements; không tạo tooling/budget. Mở task mới nếu consumer cung cấp workload cụ thể.
