# T4 — Fuzz save hỏng + test `resetProgress` xoá đủ key

**Epic:** E7 Test coverage · **SP:** 5 · **Pri:** Must
**Deps:** làm cùng [[X18]] và [[X19]]
**Trạng thái:** ✅ Done (2026-08-11)

## Mục tiêu
Biến 2 bug đã tìm được ([[X18]] crash boot, [[X19]] reset không sạch) thành
2 lưới an toàn không cho chúng quay lại — và bắt luôn những anh em cùng loại
chưa ai tìm ra.

## Vì sao Must
Cả hai bug đó **không phải bug logic** — chúng là bug **bảo trì**:

- [[X18]]: `_load()` hydrate ~25 hệ thống từ storage. 24 chỗ có guard, 1 chỗ
  quên. Không có gì bắt được chỗ thứ 26 nếu người sau lại quên.
- [[X19]]: `resetProgress()` là danh sách tay ~55 key. Round 4-8 thêm ~20 hệ,
  danh sách trôi lại phía sau. Nó sẽ trôi tiếp ở Round 10.

Sửa từng bug lẻ không giải quyết gì. Test ở đây **là** phần sửa thật.

## User story
*As a* dev thêm hệ meta thứ 21 *I want* test đỏ ngay nếu tôi quên guard hoặc
quên thêm key vào reset *so that* tôi không phát hành một bug chặn boot.

## Acceptance criteria

### A. Fuzz hydrate
- [x] Test lặp qua **mọi** `StorageKeys` × 10 giá trị rác (chuỗi rỗng, JSON
      hỏng/cụt/sai kiểu, `null` literal, số âm khổng lồ, bool).
- [x] Với mỗi tổ hợp: `GameController` khởi tạo thành công, `onInit()` không ném.
- [x] Test **đỏ** khi hydrate mất guard — kiểm chứng ở [[X28]] (trả getter về
      bản cast cũ → 3/4 test đỏ).
- [x] Thêm ngoài AC: key động (`highScore`/`star`/`remixBest`), và ca "save
      hỏng toàn bộ" (mọi key = rác cùng lúc).

### B. Whitelist reset
- [x] Đã làm sẵn ở [[X19]] — `save_resilience_test.dart` so `exportAll()` của
      profile-vừa-reset với profile-cài-mới. Tự đúng cho key tương lai.
- [x] Whitelist là `GameController.keepOnReset`, có comment phân loại.
- [x] Đỏ khi thêm key mới mà không phân loại (đã mutation-check ở X19).

## Cách liệt kê key — chọn đường tự phát hiện
Subtask 2 để mở 2 lựa chọn. Chọn **đọc chính source**: test parse
`lib/core/storage_service.dart` bằng regex, rút mọi `static const String`.

Lý do: yêu cầu bắt buộc là *"quên thì test đỏ"*. Danh sách chép tay trong test
không đạt — thêm key mà quên cập nhật danh sách thì fuzz vẫn xanh, tức là im
lặng bỏ sót đúng thứ nó sinh ra để bắt. Đọc source thì key mới **tự động** vào
vòng fuzz. Cùng thủ pháp với `campaign_total_sweep_test.dart`.

Đánh đổi: phụ thuộc cách viết source. Đã chặn bằng một test riêng assert rút
được ≥90 key — nếu `StorageKeys` đổi sang enum/codegen làm regex mục, test đỏ
ngay thay vì biến fuzz thành no-op âm thầm.

## Kết quả: tìm ra bug P1 mới
Fuzz **đỏ ngay lần chạy đầu**, và không phải lỗi nhỏ: mọi key giữ sai kiểu đều
làm `getInt`/`getBool`/`getDouble`/`getString` ném `TypeError` → `onInit()`
ném → **app không boot được**. Xem [[X28]] (đã sửa).

Đây đúng là thứ [[X18]] bỏ sót: X18 vá try/catch cho riêng block pet, còn lỗ
thật rộng bằng toàn bộ bảng key. 970 test trước đó không bắt được vì tất cả
đều gieo dữ liệu **đúng kiểu** — người viết test biết key nào là int.

Phụ: fuzz cũng lộ `widgetCoinsKey` trùng chuỗi `'coins'` với `StorageKeys.coins`.
Kiểm lại thì **cố ý** (namespace riêng của home widget, Kotlin đọc) — đã loại
2 widget key khỏi phép kiểm trùng kèm giải thích.

## Subtask 3 — sửa mọi hydrate chưa guard
Không cần sửa từng chỗ. Sửa ở tầng getter ([[X28]]) phủ toàn bộ một lượt; sau
đó fuzz xanh, không còn hydrate nào hở.

## Ghi chú kỹ thuật
`StorageService.exportAll()` (`storage_service.dart:337`) đã dùng
`prefs.getKeys()` generic đúng vì lý do "không phải nhớ cập nhật danh sách
tay". Test này dựa thẳng vào nó.

Đừng dùng thư viện property-testing. Một `for` lặp qua ~10 giá trị rác × N
key là đủ và chạy trong vài trăm ms.

DoD chung: `../README.md`.

## Bổ sung: integration test (2026-08-11)
`integration_test/save_resilience_test.dart` — 3 case, chạy trên thiết bị thật.

Vì sao cần dù đã có fuzz unit test: fuzz dựng `GameController` **trực tiếp**,
nên nó chỉ chứng minh controller chịu được dữ liệu xấu. Đường khởi động thật
(`app.main()`) còn có `AudioManager`, `ReminderService`, `LocaleService`,
`HomeWidgetSync` và thứ tự `Get.put` — một key hỏng có thể làm gãy ở đó mà
unit test không thấy.

Gieo save sai kiểu bằng `SharedPreferences.setString(StorageKeys.coins, 'abc')`
**trước** khi gọi `app.app()` — đúng tình huống người chơi mở app sau khi
import mã backup giả mạo, và làm được hoàn toàn ở tầng Dart (không cần root
hay sửa file XML như lúc kiểm tay).

Kiểm chứng trên Pixel 7 Pro (Android 17):
- Bản có fix: **3/3 xanh**.
- Gỡ fix [[X28]] rồi chạy lại: **3/3 đỏ**, đúng lỗi
  `type 'String' is not a subtype of type 'int?'`.

Chạy: `flutter test integration_test/save_resilience_test.dart -d <device>`
