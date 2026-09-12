---
id: BUG-33
title: "VictoryCardTemplate: mã QR không đọc được khi NeonTheme.dark bật (module đen trên nền trong suốt)"
type: bug
priority: P2
effort: S
source: Gemini (agy CLI, audit widget enhancement — tái phân loại thành bug)
---

## Vị trí
`lib/presentation/widgets/common/victory_card_template.dart` — `QrImageView(data: qrData!, size: 96)`.

## Hiện trạng
`QrImageView` vẽ module QR màu đen trên nền TRONG SUỐT mặc định. Khi `NeonTheme.dark == true`, card nền tối khiến module đen gần như không phân biệt được với nền — mã QR mất tương phản nghiêm trọng, khả năng cao KHÔNG QUÉT ĐƯỢC bằng camera thật.

## Vì sao cần / Hậu quả
Đây là bug chức năng thật: tính năng "Scan to play" (chia sẻ kết quả kèm QR để bạn bè quét chơi lại) có thể HOÀN TOÀN không dùng được ở theme tối — không phải vấn đề thẩm mỹ, mà là mã QR không quét được = tính năng hỏng.

## Đề xuất
Bọc `QrImageView` trong 1 `Container` nền trắng cố định (không phụ thuộc `NeonTheme.dark`) — mã QR CẦN tương phản cao tuyệt đối bất kể theme app, đây là yêu cầu kỹ thuật của QR code chứ không phải lựa chọn thẩm mỹ. Cân nhắc thêm padding nhỏ quanh QR bên trong nền trắng đó để vùng yên tĩnh (quiet zone) đủ theo chuẩn QR.

## Acceptance criteria
- [ ] QrImageView luôn có nền trắng đủ tương phản bất kể NeonTheme.dark bật hay tắt.
- [ ] Widget test xác nhận Container bọc QrImageView có màu nền trắng cố định (không đọc theo NeonTheme.dark).
- [ ] Device smoke test: chụp ảnh QR ở cả 2 theme (sáng/tối), xác nhận bằng mắt module QR luôn tương phản rõ với nền — thử quét thật bằng app camera nếu tiện.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-33-victory-card-template-qr-dark-mode-contrast.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đây là bug chức năng thật ảnh hưởng trực tiếp tới 1 tính năng chia sẻ đã được xây dựng (VictoryCardTemplate + share_helper), không phải suy đoán; dễ verify bằng mắt qua screenshot ở theme tối.
