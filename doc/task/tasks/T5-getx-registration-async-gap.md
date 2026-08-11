# T5 — `Get.put` trong async helper mất đăng ký qua async gap (chặn test cho `clamped_clock`)

**Epic:** E7 Test coverage · **SP:** 3 · **Pri:** Should
**Deps:** — · **Phát hiện khi làm:** [[T3]]
**Trạng thái:** 📋 To Do

## Hiện tượng
Đăng ký `StorageService` bên trong một hàm helper `async` rồi dùng sau khi
`await` thì **mất đăng ký**:

```dart
Future<StorageService> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  return Get.put(StorageService(store), permanent: true);   // reg = true ở đây
}

test('...', () async {
  await _boot();
  print(Get.isRegistered<StorageService>());   // ← FALSE
  todayEpochDayClamped();                      // ← ném "StorageService not found"
});
```

Đo được: `Get.isRegistered` trả `true` khi gọi **bên trong** `_boot` (trước
async gap), `false` ngay sau khi `await _boot()` trả về. Lặp lại 3/3 lần.

## Vì sao các test khác không dính
Mọi test hiện có vô tình "hâm nóng" lookup ngay sau khi put, trong cùng block
đồng bộ:

- `raid_boss_controller_test.dart`, `treasure_map_controller_test.dart`, …:
  `_boot` gọi tiếp `Get.put(GameController(), permanent: true)`, mà
  `GameController.onInit()` → `_load()` → `StorageService.to`.
- `storage_service_test.dart`: không dùng GetX, giữ instance trực tiếp.

Nên đây **không phải bug mới xuất hiện** — nó luôn ở đó, chỉ chưa lộ vì chưa
ai viết test cần `StorageService` mà không kèm `GameController`.

## Vì sao đáng sửa
`lib/core/utils/clamped_clock.dart` (thêm ở [[X22]]) là lớp **chống gian lận
đồng hồ** dùng chung cho pet idle và Raid Boss. Nó là code bảo mật-nhẹ và
hiện **không có test riêng** — chỉ được cover gián tiếp qua
`raid_boss_controller_test`. Không viết được test trực tiếp vì đúng cái vướng
ở trên.

Rộng hơn: bất kỳ util nào đọc `StorageService.to` mà không đi kèm
`GameController` đều sẽ vấp cùng chỗ này. Đó là thuế đặt lên mọi test tương
lai.

## Việc cần làm
- [ ] Xác định **nguyên nhân thật**. Nghi ngờ đầu tiên: `SmartManagement` mặc
      định của GetX dọn dependency chưa từng được `find`. Kiểm bằng cách đặt
      `Get.smartManagement = SmartManagement.onlyBuilder` (hoặc `keepFactory`)
      ở đầu test và xem có hết không. **Đừng sửa gì trước khi biết nguyên
      nhân** — workaround kiểu "gọi `Get.find` một phát cho chắc" là loại code
      không ai dám xoá về sau.
- [ ] Nếu đúng là `SmartManagement`: chốt cấu hình cho test (đặt 1 chỗ dùng
      chung, ví dụ `test/flutter_test_config.dart`) thay vì rải từng file.
- [ ] Viết `test/core/utils/clamped_clock_test.dart` — nội dung đã phác thảo
      xong khi làm [[T3]], chỉ chờ hạ tầng: mốc `maxSeen` ở tương lai không bị
      lùi về giờ thật (đúng bước "chỉnh đồng hồ về" của vòng farm), mốc quá
      khứ thì tiến lên giờ thật, và 2 đồng hồ (ngày/mili-giây) dùng key riêng
      không đè nhau.
- [ ] Rà xem có util nào khác đang thiếu test vì cùng lý do.

## Ghi chú
Trong lúc điều tra có gặp một hiện tượng gây nhiễu khác: lần chạy **đầu tiên**
ngay sau khi sửa file test có thể cho kết quả khác lần chạy thứ hai (kernel
build cũ). Khi kiểm chứng, luôn chạy lại ≥2 lần trước khi kết luận.

DoD chung: `../README.md`.
