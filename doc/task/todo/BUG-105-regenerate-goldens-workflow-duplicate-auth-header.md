---
id: BUG-105
title: "regenerate-goldens: bước create-pull-request lỗi Duplicate header Authorization (HTTP 400)"
type: bug
layer: ci/github-actions
priority: P2
effort: S
source: "Run 43225790287 (2026-11-12): sinh ảnh thành công, bước PR thất bại"
---

## Hiện trạng
Run `43225790287`: các bước checkout, pub get, `flutter test --update-goldens` đều thành công. Bước `peter-evans/create-pull-request@v6` lỗi: `remote: Duplicate header: "Authorization"` rồi `fatal: unable to access ... returned error: 400`. Không có PNG nào được đẩy ra. Nhánh `chore/regenerate-goldens` trên remote là bản cũ 2026-10-24, lệch hàng trăm file so với `main`, không được dùng.

## Nguyên nhân nghi ngờ (chưa xác nhận)
`actions/checkout@v7` lưu sẵn header `AUTHORIZATION` trong git config; `create-pull-request@v6` thêm header thứ hai khi chạy `git remote prune`. Repo cũng chặn Actions tự tạo PR (xem memory CI infra gaps), nên có thể bước này cũng không tạo được PR ngay cả khi hết lỗi header.

## Phương án (cần chọn trước khi sửa workflow)
1. Nâng `create-pull-request` lên bản mới hơn tương thích checkout v7.
2. Bỏ bước PR, thay bằng `actions/upload-artifact` chứa `test/widget/goldens/goldens/`; người dùng tải artifact và commit PNG mới. Ưu: không phụ thuộc quyền tạo PR. Nhược: thêm thao tác tay.
3. Thêm `persist-credentials: false` vào checkout. Ưu: sửa nhỏ nhất cho lỗi header. Nhược: có thể vẫn bị chặn tạo PR.

## Tiêu chí xong
- Dispatch workflow trên `main` cho ra PNG nhận được (PR hoặc artifact) mà không lỗi.
- Quy trình trong `CLAUDE.md` (mục golden baselines) cập nhật nếu đổi từ PR sang artifact.

## Ràng buộc
Sửa workflow cần người dùng duyệt phương án; không đổi Flutter 3.41.9.
