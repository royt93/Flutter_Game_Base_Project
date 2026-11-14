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

## Việc chưa làm
Chưa sửa. Cần chọn hướng 1 hay 2 (người dùng). Test đã dựng sẵn ở trên có thể chuyển thành test hồi quy.
