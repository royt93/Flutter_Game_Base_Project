---
id: FEAT-06
title: Achievement/Badge system nội bộ (local, không cần Game Center)
type: feature
priority: P1
effort: M
source: agy
---

## Vì sao cần
UI đã có sẵn (`BadgeDot`, `StarRating`) nhưng chưa có logic điều kiện mở khoá +
persist đứng sau. Mọi game cần hệ thống achievement/quest cơ bản.

## Đề xuất phạm vi
1 service quản lý danh sách achievement (id, điều kiện, đã mở khoá chưa):
- `incrementProgress(String achievementId, int amount)`
- `isCompleted(String achievementId)`
- Persist qua `StorageService` (JSON qua FEAT-05 nếu đã có, hoặc key-value đơn giản trước).
- Không cần tích hợp Game Center/Play Games ở bản đầu — chỉ local.

## Acceptance criteria
- [ ] Tăng progress đủ ngưỡng → `isCompleted` trả `true`, persist qua restart.
- [ ] Test cho cả trường hợp tăng progress vượt ngưỡng nhiều lần (không unlock lại/không lỗi).
