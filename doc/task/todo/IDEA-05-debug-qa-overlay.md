---
id: IDEA-05
title: Debug/QA overlay nội bộ (Flipper thu nhỏ built-in)
type: idea
priority: exclusive
effort: M
source: agy + claude-CLI (cùng đề xuất)
---

## Ý tưởng
1 overlay bật bằng gesture ẩn (long-press góc màn hình, chỉ hoạt động
debug/profile build theo đúng pattern `dlog`), hiển thị real-time: toàn bộ
key trong `StorageService` (`exportAll()` nếu có), trạng thái mute/locale,
haptic level hiện tại, số lần `ClampedClock` chặn tua giờ — giúp QA tự debug
tại chỗ không cần cắm thêm DevTools ngoài.

## Vì sao khác biệt
Không kit nào khác có sẵn overlay quan sát đúng các cơ chế nội bộ đặc thù của
chính kit này (buffer chưa flush, clamp clock, mute state) — vì đây là cơ chế
riêng của package, chỉ package tự làm overlay cho chính nó mới hợp lý.
