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

- [x] 1. Đọc `purchase_seam.dart`, `purchase_ledger_service.dart`, `plugin_adapter_conformance_suite.dart`; ghi ma trận kịch bản × đã-có/thiếu vào "Kết quả thực hiện".
- [x] 2. Viết các test thiếu (host, `FakePurchaseSeam` có điều khiển: pending/thất bại/trễ), đỏ trước khi sửa nếu lộ lỗi (lỗi thật tạo task BUG riêng).
- [x] 3. Mở rộng `verifyPurchaseSeam` chỉ khi kịch bản nào đó là hợp đồng mà MỌI adapter phải thoả; ghi quyết định và nếu đổi export thì API snapshot + CHANGELOG.
- [x] 4. Mutation check (bỏ kiểm tra trùng `transactionId`, test đỏ).
- [x] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi rõ "không có cửa hàng thật/ads trong phạm vi"; chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Mua trùng `transactionId` không cộng đôi.
- [x] Kill giữa mua và ghi sổ cái: `restorePurchases` khôi phục đúng một lần.
- [x] Không kịch bản nào làm số dư âm hoặc vượt trần.
- [x] Ghi rõ ngoài phạm vi: cửa hàng thật và quảng cáo.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/purchase_ledger_service_test.dart test/core/purchase_seam_test.dart test/core/plugin_adapter_conformance_suite_test.dart`

## Kết quả thực hiện (2026-11-24)

### Ma trận kịch bản

`test/core/iap_scenarios_test.dart`, 16 test. Fake: `_ScriptedPurchaseSeam` (dùng `NetworkScript` của ENH-125 cho trễ/rớt/pending, có chế độ "đã trừ tiền nhưng `buy` ném lỗi") và `_KillableStorage` (ghi bị treo đúng lúc "kill", không bao giờ được thả).

| Kịch bản | Trước | Sau |
| --- | --- | --- |
| mua bị từ chối/huỷ: không cộng, không audit | thiếu (chỉ UI example) | có |
| `buy` ném lỗi (mất mạng): không cộng, không sở hữu | thiếu | có |
| pending rồi store xác nhận: chỉ cộng sau xác nhận, đúng một lần | thiếu | có |
| cùng `receiptId` hai lần tuần tự: cộng một lần, trả record cũ | có (`grantFromPurchase` một lần) | có (hai lần) |
| cùng `receiptId` giao song song 5 lần: cộng một lần | thiếu (có ở `grant` chung) | có |
| `restorePurchases` mỗi lần mở app mà không bao giờ chốt: cộng một lần | thiếu | có |
| hai receipt KHÁC nhau là hai lần mua | thiếu | có |
| lần giao lại không phát `onGranted` lần hai (toast/analytics một lần) | thiếu | có |
| kill sau khi store trừ tiền, trước khi app ghi gì: restore cộng đúng một lần, restore lần hai không cộng thêm | thiếu | có |
| kill sau khi ghi audit `pending`, trước khi ví đổi: `resumePending` cộng một lần | có (partial, không kill) | có (kill thật) |
| kill sau khi ví đã cộng, trước khi `committed` được ghi: `resumePending` KHÔNG cộng lần hai | thiếu | có |
| xác nhận mất trên đường về (đã trừ tiền nhưng `buy` ném): lần mở sau cộng đúng một lần | thiếu | có |
| mua làm tràn ví: ví không đổi, `retryable`, sau khi tiêu bớt thì `resumePending` cộng | có (overflow ở pipeline) | có (đầu-cuối) |
| hoàn tiền sau khi người chơi đã tiêu: ví không âm (clawback bị từ chối), sổ cái kẹp về 0 | thiếu (có `revoke` kẹp, không kèm ví) | có |
| sổ cái chặn tràn số dư consumable | có | có (qua đường mua) |
| sổ cái KHÔNG biết receipt: cùng grant hai lần thì cộng hai lần | không ghi | có, khoá hành vi đã tài liệu hoá: caller phải chống trùng bằng pipeline |

### Số liệu

- Mutation 9 biến đổi lib, cả 9 bị bắt: ví bỏ chống trùng `transactionId` (1 test), pipeline bỏ chống trùng record đã commit (1 test, xem dưới), cả hai lớp chống trùng cùng tắt (6 test), `resumePending` không làm gì (3), mọi receipt cùng một `transactionId` (2), ví không chặn trần (1), ví cho số dư âm (1), sổ cái cho `revoke` đi âm (1), sổ cái bỏ chặn tràn (1). Lib khôi phục, `cmp` giống hệt.
- Hai mutant sống sót lúc đầu: (1) bỏ chống trùng ở pipeline không đổi số dư vì ví vẫn chống trùng ở tầng của nó, nên cần test về thông báo (`onGranted` một lần) mới thấy lớp pipeline; (2) `revoke` đi âm sống sót vì test dùng đúng số lượng đang có (100/100), nên chỉ đổi thành hoàn 150 trên số dư 100.
- Cổng cuối: analyze sạch, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4232 pass (trước 4216: +16), `api_compatibility` unchanged, 5 quality-gate sạch.

### Quyết định bước 3 (không đổi `verifyPurchaseSeam`)

Owner chọn KHÔNG thêm check vào `PluginAdapterConformanceSuite.verifyPurchaseSeam`. Lý do: `PurchaseSeam` cố ý tối giản (không mô hình consumable/subscription, không receipt), nên kịch bản "pending/kill/trùng receipt" là hợp đồng của lớp consumer + pipeline, không phải của adapter. Ứng viên chưa làm: check "`buy` trả true thì `isOwned` true"; adapter chỉ báo sở hữu sau `restorePurchases` sẽ bị báo lỗi, và đây là Behavior change. Không đổi export, không đổi API snapshot.

### Phát hiện (không đổi mã, báo owner)

- `example/lib/screens/monetization_screen.dart:92` dùng `transactionId: 'iap_${sku}_${DateTime.now().microsecondsSinceEpoch}'` cho `wallet.earn`: id sinh theo giờ, KHÔNG theo receipt. Nếu consumer sao chép mẫu này, restore hoặc giao lại sẽ cộng đôi (đúng kịch bản test đã khoá ở `grantFromPurchase`). `_restorePurchases` của màn đó cũng chỉ khôi phục VIP, không khôi phục consumable. Đây là demo ("demo chỉ cần thô"), nhưng mẫu dạy sai điều mà kit đã giải bằng `grantFromPurchase`. Chưa tạo task BUG: chờ owner quyết.
- Ví và pipeline chống trùng ở HAI lớp độc lập; lớp ví che lớp pipeline về số dư, nên chỉ thông báo/analytics lộ ra lớp pipeline.

### Hạn chế (ghi rõ chưa chứng minh)

- KHÔNG có cửa hàng thật (Google Play, App Store) và KHÔNG có quảng cáo/ad mediation (tính năng quảng cáo đã gỡ ở 0.8.0, FEAT-211 won't-do): test chứng minh hợp đồng seam + sổ nội bộ, không chứng minh xác minh receipt phía máy chủ.
- "Kill" là mô phỏng: ghi bị treo không bao giờ hoàn tất, dựng `StorageService` mới trên cùng `SharedPreferences`; không phải tiến trình thật bị giết.
- Vòng khôi phục `_recover` (restore rồi `grantFromPurchase` cho từng receipt chưa chốt) là mã của test mô tả việc consumer phải làm, không phải API của kit.
