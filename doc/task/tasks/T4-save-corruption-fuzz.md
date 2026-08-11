# T4 — Fuzz save hỏng + test `resetProgress` xoá đủ key

**Epic:** E7 Test coverage · **SP:** 5 · **Pri:** Must
**Deps:** làm cùng [[X18]] và [[X19]]
**Trạng thái:** 📋 To Do

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
- [ ] Test lặp qua **mọi** `StorageKeys` (dùng reflection trên hằng số, hoặc
      một danh sách khai báo một lần) và với mỗi key, thử các giá trị rác:
      chuỗi rỗng, `"không-phải-json"`, `"{}"`, `"[]"`, `"[1,2,3]"`, số âm
      khổng lồ, chuỗi 1 MB.
- [ ] Với mỗi tổ hợp: `GameController` khởi tạo thành công, `onInit()` không
      ném, app "boot" được.
- [ ] Test **đỏ** nếu ai đó thêm một hydrate không guard — kiểm chứng bằng
      cách tạm bỏ `try/catch` của [[X18]] và xác nhận test bắt được.

### B. Whitelist reset
- [ ] Test: gieo giá trị khác mặc định vào **mọi** key game biết đến →
      `resetProgress()` → `StorageService.exportAll()` chỉ còn key nằm trong
      whitelist đã chốt (xem [[X19]]).
- [ ] Whitelist là hằng số trong test, có comment giải thích vì sao từng key
      được giữ lại (ngôn ngữ, âm lượng, `hasSeen*`…).
- [ ] Test **đỏ** nếu thêm key mới mà không phân loại — đây là điểm chính:
      nó buộc người thêm key phải quyết định.

## Subtask
1. `test/core/storage_service_test.dart` (đã có) hoặc file mới
   `test/presentation/save_resilience_test.dart` — phần A.
2. Phần B: cần một cách liệt kê mọi key. `StorageKeys` là các hằng `static
   const String`; đơn giản nhất là khai báo `StorageKeys.all` (một `List`
   trong chính file đó) và assert trong test rằng nó không sót — hoặc chấp
   nhận danh sách trong test và để chính test đó là nơi buộc cập nhật.
   **Chọn cách nào cũng được, miễn có đúng MỘT chỗ phải cập nhật khi thêm key,
   và quên nó thì test đỏ.**
3. Chạy fuzz, sửa mọi hydrate chưa guard mà nó tìm ra (dự kiến sẽ ra thêm vài
   chỗ ngoài pet).

## Ghi chú kỹ thuật
`StorageService.exportAll()` (`storage_service.dart:337`) đã dùng
`prefs.getKeys()` generic đúng vì lý do "không phải nhớ cập nhật danh sách
tay". Test này dựa thẳng vào nó.

Đừng dùng thư viện property-testing. Một `for` lặp qua ~10 giá trị rác × N
key là đủ và chạy trong vài trăm ms.

DoD chung: `../README.md`.
