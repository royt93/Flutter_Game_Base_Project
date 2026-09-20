---
id: BUG-38
title: "IDEA-38 device integration test giả định colorBlindSafe luôn bắt đầu false — không idempotent trên device thật có state cũ"
type: bug
priority: medium
effort: S
source: Claude (phát hiện lúc chạy device smoke test thật trên Pixel 7 Pro sau khi đóng FEAT-80/83/81, 2026-09-20)
---

## Vị trí
`example/integration_test/app_boot_test.dart` — test `'IDEA-38: color-blind-safe setting changes palette on device'` (dòng ~426-446).

## Hiện trạng
Test tap 1 lần vào toggle accessibility rồi `expect(NeonTheme.colorBlindSafe, isTrue)` — giả định
CỨNG rằng giá trị bắt đầu luôn là `false`. Nhưng `StorageService` ghi thật vào
`SharedPreferences` trên device thật, và **không tự xoá giữa các lần chạy
`flutter test` khác nhau** (khác hẳn 1 emulator/CI job dùng state sạch mỗi
lần) — nếu 1 phiên smoke test TRƯỚC ĐÓ đã từng chạy test này và để lại
`colorBlindSafe = true` trên máy, lần chạy sau tap toggle sẽ TẮT nó
(`true` → `false`), làm assertion `isTrue` sai với lỗi thật:

```
Expected: true
  Actual: <false>
```

Xác nhận: chạy solo qua `--plain-name="IDEA-38: ..."` trên Pixel 7 Pro (đã
từng bật `colorBlindSafe` ở phiên trước) vẫn fail y hệt — không phải
flakiness ngẫu nhiên do nhiều `app.app()` chạy chung binary (khác với
`FEAT-33` fail cùng lần chạy đó, cái đó pass lại khi chạy solo).

## Vì sao cần / Hậu quả
Bất kỳ ai chạy lại đúng test này lần thứ 2 trên cùng 1 device thật (không
reinstall app giữa 2 lần) sẽ thấy fail giả — tưởng nhầm là regression thật
trong khi chỉ là do thứ tự chạy trước đó để lại state. Làm mất niềm tin
vào bằng chứng device smoke test.

## Đề xuất
Đọc giá trị `NeonTheme.colorBlindSafe` HIỆN TẠI trước khi tap (thay vì giả
định `false`), assert tap LÀM ĐẢO GIÁ TRỊ (`!before`), rồi tap thêm 1 lần
nữa để trả về đúng giá trị ban đầu — vừa hết phụ thuộc vào state cũ, vừa
không để lại state mới cho lần chạy sau (idempotent cả 2 chiều).

## Acceptance criteria
- [x] Test không còn giả định giá trị bắt đầu của `colorBlindSafe`; đọc giá trị thật trước khi tap.
- [x] Assert tap làm giá trị ĐẢO NGƯỢC (không phải cứng `isTrue`).
- [x] Test tự trả `colorBlindSafe` về đúng giá trị ban đầu trước khi kết thúc (không để lại state cho lần chạy sau).
- [x] Verify: chạy lại chính test này 2 LẦN LIÊN TIẾP trên cùng device thật (không reinstall) đều pass — chứng minh idempotent thật, không chỉ đọc code.
- [x] Không phá bất kỳ test khác nào trong `app_boot_test.dart`.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; sửa đúng chỗ, tối thiểu diff. Verify: chạy `flutter analyze` + `flutter test --exclude-tags slow` ở example, rồi chạy CHÍNH device integration test này 2 lần liên tiếp trên device thật (Pixel 7 Pro hoặc S24U nếu kết nối được) để chứng minh idempotent. Tự chấm điểm >9/10 mới commit + push. Sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Root cause KHÔNG phải chỉ "device giữ state cũ" như giả thuyết ban đầu —
đào sâu bằng debug print thật trên device mới lộ ra: `find.byType(CommonListTile).last`
không còn trỏ đúng row "Màu an toàn mù màu" nữa. FEAT-79 (cùng session
này) thêm row "Pseudo-locale (QA)" (`if (kDebugMode)`, LUÔN hiện khi chạy
`flutter test`) NGAY SAU row accessibility trong `SettingsScreen` — in
thật ra list tile lúc chạy trên Pixel 7 Pro:
`[Ngôn ngữ, Chế độ tối, Màu an toàn mù màu, Pseudo-locale (QA)]`. Test cũ
tap NHẦM toggle pseudo-locale, không đụng `NeonTheme.colorBlindSafe` chút
nào — đây là 1 REGRESSION thật do FEAT-79 gây ra (không có test nào bắt vì
`app_boot_test.dart` chỉ chạy trên device, không nằm trong
`flutter test --exclude-tags slow` của CI).

Sửa 2 lớp:
1. **Target đúng widget theo title, không theo vị trí**: `find.widgetWithText(CommonListTile, 'color_blind_safe'.tr)`
   thay `find.byType(CommonListTile).last` — bền với việc thêm/bớt row
   khác trong tương lai, và tự đúng theo locale hiện tại của device (dùng
   `.tr`, không hardcode string tiếng Anh/Việt).
2. **Không giả định giá trị bắt đầu, tự trả lại state cũ**: đọc
   `before = NeonTheme.colorBlindSafe` trước, assert tap đảo giá trị
   (`!before`), tap lần 2 để trả về đúng `before` — test không còn phụ
   thuộc lịch sử chạy trước đó VÀ không để lại state mới cho lần chạy
   sau, dù có sửa xong bug (1) hay chưa.

**Verify KHÔNG chỉ đọc code**: chạy solo qua `--plain-name` trên Pixel 7
Pro (S24U vẫn không kết nối được, fallback đúng quy ước đã ghi trong
memory) 3 LẦN LIÊN TIẾP không reinstall app — cả 3 lần đều pass, chứng
minh idempotent thật trên chính device đã từng để lại state cũ gây ra
bug này. Chạy lại TOÀN BỘ `app_boot_test.dart` trên cùng device: IDEA-38
pass; `FEAT-33` vẫn fail đúng y hệt kiểu flakiness đã biết trước (nhiều
`app.app()` chung 1 binary liên tục, pass lại khi chạy solo) — xác nhận
KHÔNG liên quan sửa lần này, đúng phạm vi BUG-38.

- `flutter analyze` example: sạch.
- `flutter test --exclude-tags slow` example: 98/98 pass (không đụng gì
  ngoài `app_boot_test.dart`, file này vốn không nằm trong suite CI chạy
  tự động).
- Device: IDEA-38 solo x3 liên tiếp pass; full file 1 lần chỉ còn đúng
  `FEAT-33` fail (pre-existing, đã xác nhận không liên quan).

Tự chấm: 9.5/10. Điểm cao vì không dừng lại ở giả thuyết ban đầu ("chắc
là do state cũ") mà đào tới tận root cause thật bằng debug print trực
tiếp trên device — phát hiện ra đây là 1 regression thật do FEAT-79 gây
ra chứ không chỉ là "test không idempotent", rồi sửa đúng cả 2 lớp
(target sai widget + giả định state) thay vì chỉ vá triệu chứng. Trừ 0.5
vì lỗ hổng gốc (test integration_test device-only không nằm trong CI/
suite chạy thường xuyên) khiến regression này ẩn suốt từ lúc FEAT-79
đóng tới giờ mới lộ ra — không có cách rẻ nào để CI bắt sớm hơn nếu không
chạy `app_boot_test.dart` trên device mỗi lần đổi `SettingsScreen`.
