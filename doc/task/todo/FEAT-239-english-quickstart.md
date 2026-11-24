---
id: FEAT-239
title: "Bản 'Getting started' tiếng Anh một trang, có code chạy được kiểm bằng test"
type: feature
layer: doc
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-24 (dev-experience SDK), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

- `doc/INTEGRATION_GUIDE.md` (315 dòng) là tài liệu hướng dẫn tích hợp, viết tiếng Việt (các mục: thêm package, bootstrap một lần, core gameplay loop, Flame, save và offline earnings, service tuỳ chọn, audio/haptics, adapter nền tảng, checklist trước release). `.pubignore` loại `doc/` khỏi gói xuất bản, nên người dùng pub.dev KHÔNG thấy nó; họ chỉ thấy README (tiếng Anh).
- - **README đã có phần tiếng Anh:** `## Install` (`flutter pub add roy_casual_kit`, cấu hình Android cho thông báo), `## Usage` (đoạn `RoyCasualKit.initialize` với 4 module, giải thích lỗi module không làm vỡ boot, một đoạn `main` mẫu), `## See it live`, `## Commands`, kèm `## Integration guide` (dòng ~779) trỏ tới tài liệu tiếng Việt; README dài ~920 dòng. `.pubignore` có dòng `doc/` nên INTEGRATION_GUIDE KHÔNG vào gói xuất bản; liên kết tới nó từ README có thể là liên kết GitHub.
- **Khoảng trống thật** (cần xác nhận ở bước 1, không giả định): README dài và đặt `## Install` ở dòng ~783 sau rất nhiều nội dung; chưa chắc có một "đường ngắn 5 phút" liền mạch từ cài đặt đến một màn chơi đầu tiên có test. Nếu bước 1 thấy README đã đủ, kết luận đúng là KHÔNG viết thêm và đóng task won't-do.
- Mục tiêu: người dùng toàn cầu (kit nhắm khán giả toàn cầu, BUG-94) có lối vào tiếng Anh ngắn, không phải cuộn qua ~780 dòng.

## Phạm vi

Một trang ngắn (cho README hoặc `doc/QUICKSTART.md` nếu README đã dài): cài đặt, `RoyCasualKit.initialize`, một màn tối thiểu dùng vài widget, một test. KHÔNG dịch toàn bộ INTEGRATION_GUIDE.

## Rủi ro

Nhân đôi nội dung với README và INTEGRATION_GUIDE rồi lệch khi API đổi. Giảm bằng cách mỗi đoạn code trong trang là code đã được một test chạy (chép từ file test), và trang ghi rõ nguồn chuẩn là README/`example/`.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc README (phần cài đặt/bootstrap hiện có) và `example/lib/main.dart` để biết đã có gì; ghi khoảng trống thật vào "Kết quả thực hiện" (nếu README đã đủ, báo owner thay vì viết thêm).
- [ ] 2. Viết một test (`test/core/quickstart_snippets_test.dart` hoặc `example/test/`) chạy đúng các đoạn code sẽ đưa vào trang; đoạn nào test chạy được mới đưa vào.
- [ ] 3. Viết trang tiếng Anh từ chính các đoạn đó; liên kết từ README.
- [ ] 4. Kiểm: `dart pub publish --dry-run` (nếu đặt trong README) không cảnh báo; liên kết hoạt động.
- [ ] 5. Chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mọi đoạn code trong trang được một test chạy.
- [ ] Trang không quá một màn hình cuộn (~80 dòng), có liên kết tới INTEGRATION_GUIDE và `example/`.
- [ ] Không nhân đôi nội dung đã có trong README.

## Lệnh kiểm chứng nhanh

- `flutter test` (file test snippet)
- `dart pub publish --dry-run`
