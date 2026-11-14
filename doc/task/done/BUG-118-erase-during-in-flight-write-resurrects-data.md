---
id: BUG-118
title: "eraseAll chạy trong lúc một lần ghi của service đang chờ: ghi đó đáp xuống SAU erase và làm sống lại dữ liệu"
type: bug
layer: lib/core/storage_service + economy_wallet (và mọi service ghi bằng setString)
priority: P1
effort: M
source: "Giới hạn đã biết của BUG-117; tái hiện bằng test tạm 2026-11-14"
---

## Tái hiện (đã chạy, test tạm đã xoá)
Ví có 10 coin. `earn(5)` bị giữ ở bước `storage.setString` (stub chờ), `eraseAll()` chạy và xong, rồi ghi của `earn` được thả. Thứ tự sự kiện đo được: `wallet-write-PARKED -> eraseAll-START -> eraseAll-DONE -> wallet-write-RESUMED -> earn-DONE`. Kết quả trên đĩa: `economy_wallet_v1 = {"balances":{"coin":15},"transactions":["seed","late"]}`: dữ liệu đã xoá (10 coin, giao dịch `seed`) sống lại cộng thêm 5. Bộ nhớ cũng 15.

## Nguyên nhân
`StorageService._guardedWrite` xếp hàng chỉ các lần ghi trực tiếp với nhau (`queueWhenIdle: false` khi rảnh). `_replaceAll` (đường của `importAll`/`eraseAll`) xoá từng key bằng `prefs.remove` và KHÔNG chờ hàng đợi ghi đang chạy, nên một ghi đang treo hoàn tất sau khi erase. `replaceEpoch` (BUG-117) chỉ tải lại SAU erase; không cứu được ghi đến muộn hơn nó.

## Mức độ
Cửa sổ thật nhưng hẹp: cần một lần ghi service đang dang dở đúng lúc người dùng xác nhận xoá dữ liệu (ví dụ nhận thưởng đúng lúc bấm "xoá dữ liệu"). Hậu quả với GDPR nặng: biên lai `DataErasureReceipt` nói đã xoá nhưng dữ liệu có thể quay lại.

## Hướng sửa (đề xuất, cần quyết định)
1. `importAll` / `eraseAll` / `removeAllWithPrefix` / `importWithPrefix` chờ `_pendingWrite` (và các ghi đã được phát) xong trước khi bắt đầu, và chặn ghi mới trong lúc chạy (hàng đợi hai chiều). Ưu: sửa tận gốc ở một chỗ. Nhược: chạm lõi lưu trữ; cần test với ghi đệm (`flush`), và quyết định ghi đến trong lúc erase bị xếp sau hay bị loại.
2. Ngăn ở tầng service: `replaceEpoch` kèm một "thế hệ" (generation); ghi của service so sánh thế hệ trước/sau `await setString` và hoàn tác nếu đã đổi. Ưu: không đổi StorageService. Nhược: phải làm lại ở từng service.

## Đã sửa (2026-11-14), hướng 1
`StorageService` theo dõi mọi lần ghi đã giao cho nền tảng (`_inFlight`, gồm cả đường nhanh lúc rảnh, thứ trước đây không để lại dấu vết nào, cộng `_pendingWrite` của hàng đợi) và `importAll`/`eraseAll`/`removeAllWithPrefix`/`importWithPrefix` gọi `_drainPendingWrites()` trước khi chạy: chờ **ảnh chụp** các ghi đã phát hành trước đó (không vòng lặp, nên ghi đến sau không thể làm đói thao tác thay thế). Đường nhanh của BUG-83 giữ nguyên: không thêm `await`, nên đọc lại đồng bộ vẫn đúng.
Lần thử đầu của tôi sai: chỉ chờ `_pendingWrite`, nhưng ghi lúc rảnh không vào hàng đợi nên vẫn bị vượt mặt; dấu vết sự kiện (`remove` chạy trước `write RESUMED`) chỉ ra điều đó trước khi tôi sửa lại.
Test `BUG-118` trong `storage_replace_reload_test.dart` dùng một `SharedPreferences` giả ở tầng nền tảng để *thật sự* giữ một lần ghi trong `_guardedWrite` (stub ghi đè `StorageService.setString` sẽ không thử được đường này): đỏ khi hoàn nguyên lib, xanh khi có.

## Còn lại
Ghi đệm (`setStringBuffered`/`flush`) vẫn có cửa sổ riêng: `importAll` xoá `_buffer` nhưng một `flush()` đang chạy giữa chừng đã lấy ảnh chụp trước đó; chưa kiểm.
