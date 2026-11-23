---
id: ENH-126
title: "IAP test: mua bị ngắt giữa chừng, pending, hoàn tiền/khôi phục, trùng giao dịch, mất mạng khi xác nhận"
type: enhancement
layer: test/core
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- `PurchaseSeam` (mua/khôi phục/`isOwned`) không có cài đặt cửa hàng thật; consumer tự cung cấp. `PurchaseLedgerService` lưu kết quả SAU khi consumer đã xác minh. Test hiện có: `purchase_ledger_service_test.dart` (33 test), `purchase_seam_test.dart` (4 test), và `PluginAdapterConformanceSuite.verifyPurchaseSeam` (chạy với `FakePurchaseSeam`).
- **Quảng cáo/ad mediation: KHÔNG áp dụng.** Tính năng quảng cáo đã gỡ ở 0.8.0 (FEAT-211 won't-do), tài liệu `consent_state_service.dart` ghi kit không có mediation seam. Task này ghi rõ ngoài phạm vi để tránh hứa test không có đối tượng.
- Không thể kiểm chứng cửa hàng thật (Google Play/App Store) từ repo; chỉ kiểm hợp đồng seam + sổ cái.

## Phạm vi

Bộ kịch bản gián đoạn cho cặp `PurchaseSeam` giả + `PurchaseLedgerService` + `EconomyWallet`/`InventoryService`: mua thành công rồi app bị kill trước khi ghi sổ cái (khôi phục khi `restorePurchases`), cùng `transactionId` hai lần (idempotent, không cộng đôi), mua đang pending rồi thành công/thất bại, hoàn tiền (nếu seam báo), mất mạng ở bước xác nhận, thứ tự `buy` song song hai lần (chặn đôi), số dư không âm/không vượt trần.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc `purchase_seam.dart`, `purchase_ledger_service.dart`, `plugin_adapter_conformance_suite.dart`; ghi ma trận kịch bản × đã-có/thiếu vào "Kết quả thực hiện".
- [ ] 2. Viết các test thiếu (host, `FakePurchaseSeam` có điều khiển: pending/thất bại/trễ), đỏ trước khi sửa nếu lộ lỗi (lỗi thật tạo task BUG riêng).
- [ ] 3. Mở rộng `verifyPurchaseSeam` chỉ khi kịch bản nào đó là hợp đồng mà MỌI adapter phải thoả; ghi quyết định và nếu đổi export thì API snapshot + CHANGELOG.
- [ ] 4. Mutation check (bỏ kiểm tra trùng `transactionId`, test đỏ).
- [ ] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi rõ "không có cửa hàng thật/ads trong phạm vi"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mua trùng `transactionId` không cộng đôi.
- [ ] Kill giữa mua và ghi sổ cái: `restorePurchases` khôi phục đúng một lần.
- [ ] Không kịch bản nào làm số dư âm hoặc vượt trần.
- [ ] Ghi rõ ngoài phạm vi: cửa hàng thật và quảng cáo.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/purchase_ledger_service_test.dart test/core/purchase_seam_test.dart test/core/plugin_adapter_conformance_suite_test.dart`
