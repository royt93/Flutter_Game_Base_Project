---
id: ENH-03
title: LoadingOverlay trả thẳng Positioned.fill, dễ vỡ nếu đặt ngoài Stack
type: enhance
priority: P2
effort: S
source: agy, verify lại code thật
---

## Hiện trạng
`lib/presentation/widgets/common/loading_overlay.dart` — `build()` return
thẳng `Positioned.fill(...)`. Doc comment đã ghi rõ pattern dùng đúng
("caller đặt trong `Stack` của chính mình"), nhưng không có safety net: nếu
dev mới đặt nhầm `LoadingOverlay` trong `Container`/`Center`/`Column`, Flutter
ném lỗi đỏ màn hình "Positioned widgets must be placed directly inside Stack".

## Đề xuất
Cân nhắc 1 trong 2 hướng (không đổi API công khai nếu chọn hướng 1):
1. Thêm `assert` debug-only kiểm tra ancestor gần nhất là `Stack` khi build (an toàn, không đổi behavior).
2. Đổi sang `SizedBox.expand` + `ColoredBox` (không cần `Positioned`), tự
   full-screen mà không phụ thuộc ancestor — nhưng cần audit lại các nơi đang
   dùng đúng pattern cũ để chắc không đổi layout.

## Acceptance criteria
- [ ] Đặt nhầm `LoadingOverlay` ngoài `Stack` cho lỗi rõ ràng dễ hiểu (nếu chọn hướng 1) hoặc không còn crash (nếu chọn hướng 2).
