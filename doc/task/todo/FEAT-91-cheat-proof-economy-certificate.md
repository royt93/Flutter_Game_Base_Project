---
id: FEAT-91
title: "Cheat-Proof Economy Certificate — API duy nhất gộp TrustedClockService + SaveIntegrity + EconomyWallet/PurchaseLedgerService"
type: feature
priority: P1
effort: L
source: "codex + Fork nội bộ (brainstorm exclusive features) — 2 đề xuất chồng lấn cao, gộp thành 1"
---

## Vị trí
Mới — dựa trên `lib/core/utils/trusted_clock.dart`, `lib/core/save_integrity.dart`, `lib/core/economy_wallet.dart`, `lib/core/purchase_ledger_service.dart`.

## Hiện trạng
Cả 4 mảnh ghép tồn tại độc lập, có test riêng, nhưng không có 1 API duy nhất "chứng nhận" 1 save VỪA chưa bị tamper (HMAC) VỪA nhất quán về thời gian (trusted clock) VỪA có số dư kinh tế hợp lệ — backend/consumer phải tự ráp cả 3 cơ chế rời rạc mỗi khi cần verify 1 save từ xa.

## Vì sao cần / Hậu quả
2 nguồn độc lập (codex, Fork nội bộ) cùng đề xuất tổ hợp gần giống nhau — tín hiệu mạnh. Backend chỉ cần verify 1 "certificate" thay vì hiểu và ráp đúng 3 cơ chế riêng biệt — giảm đáng kể rủi ro tích hợp sai ở phía consumer.

## Đề xuất
Thêm `EconomyCertificate.issue(...)` gộp: HMAC signature của save (`SaveIntegrity`), `ClockJudgement` snapshot tại thời điểm issue (`TrustedClockService`), và số dư/lịch sử giao dịch gần nhất (`EconomyWallet`/`PurchaseLedgerService`) thành 1 payload duy nhất, cùng `EconomyCertificate.verify(cert)` trả về 1 kết quả typed rõ ràng (valid / tampered / clock-suspicious / ...).

## Acceptance criteria
- [ ] `EconomyCertificate.issue()` gộp đúng cả 3 nguồn dữ liệu.
- [ ] `EconomyCertificate.verify()` phát hiện đúng: save bị tamper (HMAC sai), clock nghi ngờ rewind, hoặc certificate hợp lệ hoàn toàn — trả kết quả typed phân biệt rõ từng trường hợp.
- [ ] Test verify từng trường hợp lỗi riêng biệt (tamper only, clock only, cả 2, hợp lệ).
- [ ] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-91-cheat-proof-economy-certificate.md` này trước khi làm. Đọc toàn bộ 4 file liệt kê ở "Vị trí" trước khi thiết kế certificate. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root, `dart run tool/api_compatibility.dart check` pass.
4. Không cần smoke test device bắt buộc (logic thuần crypto/verify).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (codex, Fork nội bộ) cùng đề xuất tổ hợp gần giống nhau mà không tham khảo nhau. Không trùng task nào trong `doc/task/done/`.
