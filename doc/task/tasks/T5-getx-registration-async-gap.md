# T5 — `Get.put` trong async helper mất đăng ký qua async gap (chặn test cho `clamped_clock`)

**Epic:** E7 Test coverage · **SP:** 3 · **Pri:** Should
**Deps:** — · **Phát hiện khi làm:** [[T3]]
**Trạng thái:** ✅ Done (2026-08-12) — **tiền đề không tái hiện được**

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

---

## Kết luận (2026-08-12)

**Tiền đề của task này sai.** Chạy lại đúng đoạn mã ở phần "Hiện tượng":

```
REG[trong _boot, ngay sau put] = true
REG[sau await _boot]           = true
```

`Get.isRegistered<StorageService>()` trả `true` ở **cả hai** phía async gap, và
`todayEpochDayClamped()` / `nowMsClamped()` gọi thẳng sau `await _boot()` chạy
bình thường, không ném. Thử thêm biến thể có/không `tearDown(Get.reset)`,
có/không `TestWidgetsFlutterBinding.ensureInitialized()` — đều `true`.

Không sửa gì trong `lib/`: **không có gì để sửa**. Nghi phạm còn lại chính là
thứ mục "Ghi chú" của task này đã cảnh báo — lần chạy đầu sau khi sửa file test
dùng kernel cũ. Đúng cái bẫy đó đã dẫn tới chẩn đoán `SmartManagement`.

Bài học giữ lại: **luôn chạy lại ≥2 lần trước khi kết luận về hạ tầng test**, và
đừng chốt nguyên nhân (ở đây là `SmartManagement`) khi mới chỉ quan sát triệu
chứng. Không thêm workaround nào — nếu có, giờ đã là một đoạn code không ai dám
xoá, để chữa một bệnh không tồn tại.

## Đã làm (phần việc thật của task)

- `test/core/utils/clamped_clock_test.dart` — **14 ca**, đúng nội dung đã phác
  thảo ở [[T3]]: máy sạch ghi mốc; mốc tương lai không bị lùi (kể cả lệch đúng
  1 ngày); mốc quá khứ tiến lên giờ thật; hai đồng hồ dùng key riêng không đè
  nhau; `current > maxSeen` là so sánh **chặt** nên không ghi thừa khi bằng
  nhau; save sai kiểu/âm không ném ([[X28]]).
  Có một ca riêng cho **giới hạn có chủ ý**: nhảy tiến một chiều không bị chặn
  và trạng thái đó không tự hồi — để ai định "vá nốt" thấy ngay vì sao không
  nên áp lớp kẹp cho `isWeekendEvent`.
- `test/core/home_widget_sync_test.dart` — 2 ca ghim hợp đồng "nuốt mọi lỗi"
  của `syncHomeWidget`. Trước đây hợp đồng này chỉ đúng *tình cờ*: cả bộ test
  xanh trong khi log đầy `MissingPluginException`.

## Kiểm chứng

- 14/14 + 2/2 xanh, chạy lại lần hai vẫn xanh (đúng cảnh báo kernel cũ).
- **Mutation-check** trên `clamped_clock.dart`, 3/3 bị bắt: bỏ điều kiện kẹp;
  cho hai đồng hồ dùng chung một key; đổi `>` thành `>=`.

## Rà util còn thiếu test

`lib/core/debug_log.dart` (7 dòng) và `lib/core/runtime_flags.dart` (5 dòng) là
hằng số/one-liner — cố ý **không** viết test. `lib/core/home_widget_sync.dart`
đã có ở trên. Không còn util nào thiếu test vì lý do hạ tầng.
