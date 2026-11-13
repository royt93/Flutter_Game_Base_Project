---
id: BUG-112
title: "BUG-109 làm ba đường verify 'không bao giờ throw' ném ArgumentError khi secret rỗng"
type: bug
layer: lib/core (economy_certificate, replay_recorder, utils/remote_schema_compiler)
priority: P2
effort: S
source: "Scan SDK 2026-11-13 (fork); tự tái hiện độc lập trước khi sửa. Hồi quy do chính BUG-109."
---

## Vấn đề
BUG-109 cho `verifyAndStrip` ném `ArgumentError` với secret rỗng. Ba hàm ghi rõ trong doc là không bao giờ throw chỉ bắt `FormatException` nên giờ ném ra ngoài:
- `EconomyCertificate.verify` (`economy_certificate.dart`, doc "never throws"),
- `ReplayCapsule.importSigned` (`replay_recorder.dart`, trả `null`),
- `verifySignedFixture` (`utils/remote_schema_compiler.dart`, doc "never throws", trả `SdkFailure`).

## Tái hiện (đã chạy)
Test tạm: cả ba ném `ArgumentError: secret must not be empty` (đỏ).

## Đã sửa
Mỗi hàm bắt thêm `ArgumentError` và trả kết quả đúng hợp đồng (`tampered` / `null` / `SdkFailure.validation`). Test `BUG-112` trong `save_integrity_test.dart` (đỏ khi bỏ sửa, xanh khi có). Hai đường còn lại gọi `verifyAndStrip` (`DiagnosticsBundleView.fromSignedJson`, `ReproductionCapsule` verify) **không** hứa không-throw (doc ghi `FormatException`), nên giữ nguyên ném `ArgumentError`: đó là lỗi cấu hình của người gọi, không phải dữ liệu xấu.

## Bài học
Khi thêm validation ném lỗi vào một hàm dùng chung, grep mọi nơi gọi để xem có nơi nào hứa "không throw". Lần này không làm ở BUG-109 nên sinh ra lỗi này.
