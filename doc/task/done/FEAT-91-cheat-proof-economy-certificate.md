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
- [x] `EconomyCertificate.issue()` gộp đúng cả 3 nguồn dữ liệu.
- [x] `EconomyCertificate.verify()` phát hiện đúng: save bị tamper (HMAC sai), clock nghi ngờ rewind, hoặc certificate hợp lệ hoàn toàn — trả kết quả typed phân biệt rõ từng trường hợp.
- [x] Test verify từng trường hợp lỗi riêng biệt (tamper only, clock only, cả 2, hợp lệ).
- [x] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.

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

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/economy_certificate.dart` — `EconomyCertificate`
(static-utility class) với `issue()`/`verify()`:
- `issue({wallet, secret, ledger?, ledgerConsumableSkus?, ledgerPermanentSkus?, trustedClock?, nowMs?})`
  gộp `wallet.balances` (bắt buộc), ledger consumable/permanent state (nếu
  có `ledger` — CHỈ với SKU caller tự nêu, vì `PurchaseLedgerService`
  KHÔNG có API "liệt kê mọi SKU đã cấp" theo đúng thiết kế cố ý của nó, đọc
  kỹ file trước khi thiết kế đã phát hiện điều này, tránh sửa
  `PurchaseLedgerService` không cần thiết), và `trustedClock.lastJudgement`
  (nếu có) thành 1 payload, ký qua `save_integrity.dart`'s `signExport` —
  TÁI SỬ DỤNG signing có sẵn.
- `verify(cert, secret)` trả `EconomyCertificateVerification` (status
  `valid`/`tampered`/`clockSuspicious`, kèm `balances`/`clockJudgement` khi
  đọc được). **Thứ tự ưu tiên cố ý**: `tampered` LUÔN được báo trước
  `clockSuspicious` — nếu chữ ký sai thì KHÔNG trường nào trong payload
  (kể cả `clockJudgement`) còn đáng tin, nên không có ý nghĩa để phân biệt
  "vừa tamper vừa clock nghi ngờ" — chỉ cần biết "không tin được" là đủ.
  Never throw — mọi lỗi (thiếu checksum, sai secret, payload hỏng) đều trả
  về `EconomyCertificateVerification(status: tampered)`, không exception.

**TDD**: 9 test unit `test/core/economy_certificate_test.dart` (gộp đúng cả
3 nguồn khi đủ tham số; vẫn hợp lệ khi bỏ qua ledger/trustedClock; tamper
balance sau ký → tampered + balances null; sai secret → tampered; thiếu
checksum hoàn toàn → tampered không throw; rewind → clockSuspicious +
balances vẫn đọc được; suspiciousForwardJump → clockSuspicious; cả 2 cùng
lúc → tampered thắng). Xác nhận fail đúng lỗi biên dịch khi tạm xoá
`economy_certificate.dart`, khôi phục pass 9/9.

Trong lúc viết test tự bắt 1 lỗi thiết kế test (không phải lỗi code): dùng
chung `wallMs` cho cả `wallMs`/`monotonicMs` của `ClockSample` giả lập —
khi lùi `wallMs` để mô phỏng rewind, `monotonicMs` LÙI THEO (vì cùng biến),
khiến `classifyClockSample` báo `reboot` (monotonic đi lùi) thay vì
`rewind` — 2 khái niệm khác nhau bị conflate. Sửa: tách `monotonicMs` thành
biến riêng LUÔN TIẾN (+1s mỗi lần gọi, mô phỏng thời gian thực trôi qua),
chỉ thao túng `wallMs` theo từng kịch bản — đúng cách `TrustedClockService`
được thiết kế để phân biệt.

**Kết quả**: `flutter analyze` sạch ở root. `flutter test --exclude-tags
slow` root: 2153 test, 19 fail — khớp đúng baseline golden-image
macOS-only đã biết, không có fail mới. `dart run tool/api_compatibility.dart
check`: `additive` (thêm `EconomyCertificate`/`EconomyCertificateStatus`/
`EconomyCertificateVerification`) → `snapshot` → lại `unchanged`. Không cần
smoke test device (logic thuần crypto/verify, task tự ghi rõ).
