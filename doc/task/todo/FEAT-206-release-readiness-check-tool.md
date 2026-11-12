---
id: FEAT-206
title: "tool/release_readiness_check.dart: một lệnh kiểm trước khi tag"
type: feature
layer: tool
priority: P3
effort: M
source: "Phiên 2026-11-12: bump 0.6.8 cần nhớ tay CHANGELOG, snapshot API, lockfile example, CI ba job, task todo mở"
---

## Vấn đề
Điều kiện tag/publish nằm rải ở CLAUDE.md, trí nhớ và từng task. Dễ quên một bước (ví dụ `example/pubspec.lock` đổi theo version, snapshot API lệch).

## Phạm vi
`dart run tool/release_readiness_check.dart` (chỉ đọc, không tag/publish) in bảng đạt/chưa đạt:
1. `pubspec.yaml` version khớp mục đầu `CHANGELOG.md`, và chưa có tag `v<version>`.
2. `dart run tool/api_compatibility.dart check` sạch.
3. `dart pub publish --dry-run` chỉ cảnh báo cây git bẩn khi chưa commit.
4. Working tree sạch, `main` đồng bộ `origin/main`.
5. CI run mới nhất trên HEAD: cả ba job xanh (dùng `gh`, bỏ qua nếu không có).
6. Liệt kê task P0/P1 còn trong `doc/task/todo` (cảnh báo, không chặn).
7. `example/pubspec.lock` khớp version package.

## Tiêu chí xong
Chạy trên repo hiện tại cho kết quả đúng; test đơn vị cho phần parse version/CHANGELOG. Không tự tag hay publish.

## Không làm
Không tự động hoá tag/publish: vẫn cần người dùng yêu cầu riêng.
