# X30 — Sky Shrine: gắn hào quang xong UI không đổi, không tháo ra được

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Phát hiện bởi:** `test/widget/sky_shrine_screen_test.dart`
**Liên quan:** [[I64]] Sky Shrine
**Trạng thái:** ✅ Done (2026-08-12)

## Bug

`_ConstellationCard` đọc `activeSkyAura` và `claimedStarSeedMask` trong `build`
của **chính nó**, trong khi `Obx` duy nhất nằm ở màn cha:

```dart
Obx(() => ListView(children: [ ... _ConstellationCard(...) ... ]))
```

`Obx` chỉ đăng ký observable được đọc **trong closure của nó** — ở đây là
`totalStars` (dòng header) và `starSeedCount` (chip app bar). `build` của thẻ
chạy sau, ngoài phạm vi theo dõi, nên `activeSkyAura` đổi **không** kích hoạt
rebuild nào.

### Người chơi thấy gì

1. Bấm "Gắn hào quang" → state đổi, xu hiệu ứng đổi, nhưng nhãn vẫn là "Gắn",
   không có dấu hiệu nào cho biết đã ăn.
2. Bấm lần hai để tháo → `isActiveAura` trong bản build cũ vẫn `false`, nên
   nhánh chạy là `setActiveSkyAura(constellation.auraVariant)`: **gắn lại**
   chính nó. Không có đường tháo trong màn hình.
3. Muốn thấy trạng thái đúng phải thoát màn rồi vào lại.

Không mất dữ liệu, nhưng là một nút bấm không phản hồi và một chức năng (tháo)
không dùng được.

## Đã sửa

`lib/presentation/screens/sky_shrine_screen.dart` — tách thân `build` thành
`_card(context)` và bọc `Obx(() => _card(context))`, để mọi observable thẻ đọc
đều được đăng ký.

Không gộp vào `Obx` của cha: thẻ vẫn cần `Obx` riêng thì đổi 1 hào quang mới
chỉ dựng lại 1 thẻ thay vì cả `ListView`.

## Kiểm chứng

- `test/widget/sky_shrine_screen_test.dart` — 19 ca; 3 ca nhóm "hào quang"
  khoá đúng lỗi này (gắn đổi nhãn, bấm lại là tháo, gắn chòm khác thì chòm cũ
  nhả).
- **Mutation-check:** bỏ lớp `Obx` → `+13 -3`, đúng 3 ca đó đỏ.
- Nhóm "phát Star Seed" (7 ca) canh phần rủi ro của lớp `Obx` mới: `build`
  phát thưởng qua `addPostFrameCallback` và sửa `claimedStarSeedMask` — chính
  observable mà `Obx` mới đăng ký. Ca "rebuild nhiều lần vẫn đúng 1 hạt/chòm"
  chứng minh guard `isSeedClaimed` cắt được vòng lặp.

## Chưa vá, đã ghi lại

`activeSkyAura` **không** được đối chiếu với chòm đã sáng: `_load()` nạp thẳng
từ storage và `setActiveSkyAura` nhận mọi chuỗi. Sửa tay save là dùng được hào
quang chưa mở khoá — khác hẳn `activeBoardFrame` ([[I73]]) vốn có getter
revalidate và fallback.

Chưa vá vì thuần cosmetic **và** cần quyết định sản phẩm: fallback về
`default` như khung viền, hay giữ id lại như khung theo mùa để mùa sau hiện
lại. Hai ca cuối trong file test chốt hành vi hiện tại để lần sửa sau là thay
đổi có chủ ý, không phải hồi quy im lặng.
