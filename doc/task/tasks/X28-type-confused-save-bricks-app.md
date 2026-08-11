# X28 — Save sai kiểu làm app không boot được (mọi key, không chỉ pet)

**Epic:** E6 Hardening · **SP:** 3 · **Pri:** Must · **Mức:** P1
**Deps:** — · **Phát hiện bởi:** [[T4]] fuzz · **Mở rộng:** [[X18]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
`StorageService` cast thẳng giá trị đọc từ `SharedPreferences`:

```dart
int getInt(String key, {int def = 0}) =>
    (_buffer[key] as int?) ?? _prefs?.getInt(key) ?? ... ?? def;
```

Cả `_prefs.getInt()` lẫn `as int?` đều **ném `TypeError`** nếu key đang giữ
kiểu khác — ví dụ `coins` là `String` thay vì `int`. Áp dụng cho cả 4 getter
(`getInt`/`getBool`/`getDouble`/`getString`).

`GameController._load()` đọc gần 100 key và chạy trong `onInit()` của một
singleton `permanent: true` dựng ngay trong `main.dart`. **Một key sai kiểu
duy nhất = app không mở được**, và không có đường thoát trong app: người chơi
phải gỡ cài đặt, mất sạch tiến độ.

### Đường vào có thật
`StorageService.importAll()` chỉ kiểm giá trị **thuộc** int/bool/double/String,
**không** kiểm từng key có đúng kiểu mong đợi. Cộng với khoá backup nằm sẵn
trong binary ([[X26]]), bất kỳ ai cũng tạo được mã backup hợp lệ chứa
`"coins": "abc"`. Người nhận import xong là app chết vĩnh viễn.

Ngoài ra: ghi dở khi app bị kill, hoặc hạ version sau khi đổi kiểu một key.

## Quan hệ với [[X18]]
X18 là **cùng lớp lỗi nhưng hẹp hơn**: nó vá `try/catch` cho đúng block
hydrate pet. X28 cho thấy vấn đề rộng hơn nhiều — **mọi** key đều dính, và
cách vá của X18 (bọc try/catch từng chỗ hydrate) không mở rộng được: đã trôi
mất 1 chỗ trong 25, sẽ trôi tiếp.

## Vì sao fuzz tìm ra mà 970 test kia không
Mọi test trước đó gieo dữ liệu **đúng kiểu** — vì người viết test biết key nào
là int. Chỉ có fuzz mù mới thử `coins = 'không-phải-json'`. Đây chính là lý do
[[T4]] tồn tại.

## Acceptance criteria
- [x] Mọi key giữ giá trị sai kiểu → `getX` trả **mặc định**, không ném.
- [x] `GameController` khởi tạo được với bất kỳ key nào chứa rác (98 key ×
      10 giá trị rác = 980 tổ hợp).
- [x] Key động (`highScore(id)`, `star(id)`, `remixBest(id)`) cũng vậy.
- [x] Save hỏng **toàn bộ** (mọi key = chuỗi rác) vẫn boot.
- [x] Không regression: 971 test xanh.

## Đã sửa
`storage_service.dart` — thêm `_raw(key)` đọc giá trị thô (buffer → prefs →
fallback), rồi cả 4 getter kiểm kiểu thay vì cast:

```dart
int getInt(String key, {int def = 0}) {
  final v = _raw(key);
  return v is int ? v : def;
}
```

Sai kiểu được đối xử **y hệt key chưa tồn tại** → trả mặc định. Sửa một chỗ
phủ toàn bộ key, thay vì rải guard ở ~25 chỗ hydrate.

## Kiểm chứng
Trả `getInt` về bản cast cũ → **3/4 test fuzz đỏ**.

## Không làm
Không siết `importAll` để kiểm kiểu từng key. Sẽ cần một bảng "key → kiểu
mong đợi" duy trì bằng tay — đúng loại danh sách đã gây ra [[X19]]. Getter
chịu được dữ liệu xấu là tuyến phòng thủ đúng chỗ hơn.

DoD chung: `../README.md`.
