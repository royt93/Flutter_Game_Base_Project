# X18 — `star_owned_pets` JSON hỏng → `onInit` throw → app không boot được

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Must · **Mức:** P1
**Deps:** — · **Liên quan:** [[I65]] [[T4]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
`GameController._load()` (`game_controller.dart:1165-1176`):

```dart
final storedPetsJson = StorageService.to.getString(StorageKeys.starOwnedPets);
if (storedPetsJson != null && storedPetsJson.isNotEmpty) {
  final decoded = jsonDecode(storedPetsJson) as List<dynamic>;   // ← không try/catch
  starOwnedPets.assignAll(
    decoded
        .map((e) => PetInstance.fromJson(e as Map<String, Object?>))  // ← cast trần
        ...
  );
}
```

Hai chỗ ném exception không được bắt:
1. `jsonDecode` ném `FormatException` nếu chuỗi không phải JSON hợp lệ.
2. `as List<dynamic>` / `as Map<String, Object?>` ném `TypeError` nếu JSON hợp
   lệ nhưng sai hình dạng (object thay vì list, phần tử là number/string).

`PetInstance.fromJson` (`star_pets.dart:81-86`) **đã** null-safe đúng cách —
lỗ hổng nằm ở 2 cast bên ngoài nó.

## Vì sao Must
`GameController` được `Get.put(..., permanent: true)` trong `main.dart`.
`_load()` gọi từ `onInit()`. Exception ở đây = **app không khởi động được**,
và không có đường thoát trong app: người chơi phải gỡ cài đặt, mất toàn bộ
tiến độ.

Đường vào dữ liệu hỏng có thật, không giả định:
- Import backup code (`backup_code.dart`) từ nguồn không tin cậy — và khoá
  backup đang hard-code nên ai cũng tạo được backup hợp lệ (xem [[X26]]).
- Ghi dở dang khi app bị kill giữa `setString`.
- Xuống cấp version app sau khi format `PetInstance` đổi.

Đối lập: block hydrate ngay trên nó (`achievementUnlockDays`, dòng 1125-1136)
**có** `try/catch` với đúng lý do này. Pet chỉ là chỗ bị bỏ sót.

## User story
*As a* người chơi *I want* app vẫn mở được kể cả khi 1 mẩu save bị hỏng
*so that* tôi không mất toàn bộ tiến độ vì 1 record pet lỗi.

## Acceptance criteria
- [x] `star_owned_pets` = `"không-phải-json"` → app boot bình thường, danh
      sách pet rỗng, mọi state khác nguyên vẹn.
- [x] `'{"a":1}'` (object thay vì list) → như trên.
- [x] `'[1, 2, "x"]'` (list sai phần tử) → như trên.
- [x] Thêm 3 case nữa ngoài kế hoạch: JSON cụt, `null` literal, list rỗng.
- [x] List nửa hợp lệ → giữ phần tử đúng, bỏ phần tử hỏng (test dùng list có
      **4** phần tử: 1 hợp lệ, 1 sai kiểu, 1 thiếu field, 1 `typeId` không còn
      trong `kStarPetTypes`).
- [x] Ghi đè key bằng dữ liệu sạch sau khi bỏ record hỏng.
- [x] Test: `test/presentation/save_resilience_test.dart` (file mới, gộp cùng
      [[X19]] và phần A của [[T4]] — cả ba là cùng một lớp vấn đề).

## Đã sửa
1. `game_controller.dart` — `try/catch` quanh block hydrate pet, đúng khuôn
   `achievementUnlockDays` ở trên nó. Bắt trần (`catch (_)`) nên phủ cả
   `FormatException` lẫn `TypeError`.
2. `e as Map<String, Object?>` → vòng `for` + `if (entry is! Map) continue`,
   nên 1 phần tử hỏng không giết cả list.
3. `_persistOwnedPets()` sau khi lọc.
4. **Sửa thêm (ngoài spec):** `starOwnedPets.clear()` **vô điều kiện** trước
   khi nạp. Trước đó `assignAll` nằm trong nhánh "có dữ liệu", nên sau
   [[X19]] (key đã bị xoá) list Rx vẫn giữ nguyên pet cũ trong bộ nhớ — pet
   "ma" tiếp tục sinh coin idle tới lần khởi động lại. Phát hiện lúc làm X19.

## Rà root cause (subtask 4)
`grep -rn jsonDecode lib/` → **4** call site, chỉ **1** thiếu guard:

| Vị trí | Trạng thái |
|---|---|
| `storage_service.dart:317` (`getStringList`) | đã có `try/catch` |
| `game_controller.dart:1127` (`achievementUnlockDays`) | đã có `try/catch` |
| `game_controller.dart:1169` (pet) | **thiếu** → đã sửa |
| `backup_code.dart:95` | đường import, không nằm trên đường boot |

`decodeGemColorOverrides` (`pigments.dart:57`) không dùng JSON (CSV) và đã
phòng thủ sẵn bằng `int.tryParse` + `continue`.

Nghĩa là đây **không** phải khiếm khuyết diện rộng — đúng 1 chỗ bị bỏ sót.
Đã cân nhắc thêm helper `getJsonList`/`getJsonMap` vào `StorageService` và
**bỏ**: chỉ 2 call site thật, mà chúng cần hai kiểu khác nhau (List vs Map)
với logic lọc khác nhau → helper sẽ mỏng tới mức chỉ gói được đúng câu
`try/catch`. Lưới an toàn thật là fuzz test, không phải abstraction.

## Kiểm chứng
Tạm gỡ `try/catch` (trả về `as List<dynamic>` như bản cũ) → 4 test đỏ.

DoD chung: `../README.md`.
