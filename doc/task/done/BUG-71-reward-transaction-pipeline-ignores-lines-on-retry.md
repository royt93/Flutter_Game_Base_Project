---
id: BUG-71
title: "RewardTransactionPipeline.grant() bỏ qua param lines mới khi gọi lại cho transaction đang pending/partial"
type: bug
priority: P2
effort: S
source: "claude (fork audit round 2, độc lập)"
---

## Vị trí
`lib/core/reward_transaction_pipeline.dart:255-256` (trong `grant()`).

## Hiện trạng
```dart
var record = existing ?? RewardTransactionRecord(..., lines: lines, ...);
```
Nếu `existing != null` (transaction đã ở trạng thái pending/partial từ 1 lần
gọi `grant()` trước đó, ví dụ line thứ 2 thất bại giữa chừng), biểu thức
trên gán `record = existing` — dùng nguyên `existing.lines` (đã lưu từ lần
gọi TRƯỚC), hoàn toàn KHÔNG dùng tham số `lines` MỚI vừa truyền vào lần gọi
này.

`resumePending()` không lộ bug này vì nó tự đọc lại và truyền đúng
`record.lines` đã lưu — chỉ có đường gọi trực tiếp `grant()` lần 2 với cùng
`transactionId` mới trúng nhánh này.

## Vì sao cần / Hậu quả
Kịch bản thật: 1 transaction bị partial (ví dụ line thưởng thứ 2 thất bại
do lỗi tạm thời), sau đó có logic nghiệp vụ gọi lại `grant()` trực tiếp
(không qua `resumePending`) cho CÙNG `transactionId`, với `lines` đã được
tính toán LẠI khác đi (ví dụ server sửa lại số tiền thưởng, hoặc thêm/bớt 1
dòng thưởng). Pipeline âm thầm áp dụng `lines` CŨ, bỏ qua hoàn toàn giá trị
mới — người chơi nhận sai số thưởng, không có log/lỗi nào cảnh báo.

## Đề xuất
Khi `existing != null`, cần quyết định rõ hành vi: hoặc (a) validate `lines`
mới trùng khớp `existing.lines` (throw/log nếu khác — phát hiện lỗi gọi sai
thay vì âm thầm bỏ qua), hoặc (b) cho phép cập nhật `existing.lines` sang
giá trị mới nếu record đang ở trạng thái cho phép sửa (ví dụ pending, chưa
line nào thành công). Đọc kỹ toàn bộ file + test hiện có trước khi chọn —
đây là quyết định hành vi có ảnh hưởng đến toàn bộ pipeline, không chỉ vá
qua loa.

## Acceptance criteria
- [x] Có test tái hiện đúng bug: gọi `grant()` 2 lần với `lines` khác nhau
      cho cùng `transactionId` đang pending/partial → xác nhận hành vi ĐÚNG
      đã chọn (không còn âm thầm bỏ qua `lines` mới mà không có lý do rõ
      ràng).
- [x] `resumePending()` không bị ảnh hưởng — vẫn hoạt động đúng như cũ.
- [x] Không phá bất kỳ test nào hiện có trong `reward_transaction_pipeline_test.dart`.
- [x] Test cho path partial → gọi lại thành công phải verify đúng
      `RewardTransactionRecord` cuối cùng phản ánh đúng ý đồ thiết kế đã
      chọn (không phải chỉ "không throw").

## Quyết định

**Quyết định thiết kế: chọn option (a) — validate, KHÔNG cho phép cập
nhật `lines`.** Lý do: `partial` nghĩa là 1 số line ĐÃ áp dụng thật vào ví
(qua `'$transactionId#$i'` làm idempotency key theo INDEX) — nếu cho phép
đổi `lines` giữa chừng, 1 line ở index đã dùng có thể đổi ý nghĩa (coin
thành gem ở cùng index) trong khi ví đã ghi nhận currency cũ tại đúng
index đó, dẫn tới dữ liệu sai lệch khó dò. Option (b) (cho phép ghi đè) rủi
ro cao hơn nhiều so với lợi ích, nên chọn (a): từ chối thẳng, buộc caller
dùng `resumePending()` (luôn tự truyền lại đúng lines đã lưu) hoặc đổi
sang `transactionId` mới nếu thực sự là 1 lần grant khác.

**Implementation**: `lib/core/reward_transaction_pipeline.dart` — sau khi
tìm `existing`, nếu `existing != null` và `lines` mới không khớp
`existing.lines` (so từng cặp `currency`+`amount` theo đúng thứ tự qua
`_linesMatch` helper mới) → trả `SdkFailure(kind: validation, ...)` NGAY,
trước khi chạy vòng lặp áp dụng line — không đụng `record`/`_upsert` nào.
`resumePending()` không bị ảnh hưởng vì nó luôn tự gọi lại `grant()` với
đúng `record.lines` đã lưu (khớp 100%, không bao giờ trúng nhánh mới).

**TDD**: viết 3 test trước → `git stash` riêng file lib → chạy: test 1 (tái
hiện bug thật — đẩy overflow để partial, undo overflow, gọi lại `grant()`
trực tiếp với `lines` KHÁC hẳn) FAIL đúng dự đoán (`Expected: false, Actual:
true` — code cũ âm thầm dùng lại `existing.lines` cũ, line 2 giờ đủ điều
kiện áp dụng thành công, "commit" nhưng với số liệu SAI không phải số caller
vừa yêu cầu); 2 test còn lại (case lines-giống-hệt vẫn OK, resumePending
không bị ảnh hưởng) PASS bình thường cả trên code cũ lẫn mới (đúng — 2 case
này không bị bug ảnh hưởng). Khôi phục, chạy lại — 19/19 pass toàn file
(16 test cũ + 3 mới).

**Kết quả**:
- `flutter analyze` (root): sạch.
- `dart run tool/api_compatibility.dart check`: `unchanged` (không đổi chữ
  ký public `grant()`, chỉ thêm 1 nhánh trả `SdkFailure` — kiểu trả về
  `SdkResult<RewardTransactionRecord>` không đổi).
- `flutter test --exclude-tags slow` (root): 2343 test, 20 fail — 19
  golden-image (macOS-vs-Linux, baseline đã biết) + `energy_service_test.dart`
  BUG-19 "ghi atomic" (flaky real-wall-clock đã biết trước, KHÔNG liên
  quan `reward_transaction_pipeline.dart`). Không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- Không cần smoke test device (task cho phép bỏ qua — pure logic transaction
  đã cover đủ bằng unit test qua toàn bộ pipeline thật, không phải mock).

**Tự chấm điểm: 9.5/10.** Bug thật, root cause rõ, fix tối thiểu (validate
sớm trước khi mutate bất cứ gì) đúng với option an toàn hơn trong 2 lựa
chọn đã đề xuất. Trừ 0.5 vì lần thiết kế test đầu tiên (trước khi sửa lại)
vô tình chọn kịch bản khiến cả code cũ LẪN code mới đều fail giống nhau
(overlap giữa lỗi validate và lỗi overflow che khuất bug thật) — phải tự
phát hiện và sửa lại cách setup test để cô lập đúng đúng hành vi cần chứng
minh.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-71-reward-transaction-pipeline-ignores-lines-on-retry.md`
này trước khi làm. Đọc TOÀN BỘ `lib/core/reward_transaction_pipeline.dart`
(không chỉ đoạn quanh dòng 255) và `test/core/reward_transaction_pipeline_test.dart`
để hiểu đúng ngữ cảnh state machine (pending/partial/succeeded) trước khi
sửa — đây không phải lỗi 1 dòng đơn giản, cần hiểu rõ transaction record
được dùng lại/resume như thế nào ở những chỗ khác trong file để chọn đúng
hành vi (validate vs cho phép cập nhật). Implement bằng TDD — viết test
trước, xác nhận fail trên code cũ (chứng minh `lines` mới bị bỏ qua), rồi
mới sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Nếu đổi public API (chữ ký `grant()`, thêm field mới), chạy
   `dart run tool/api_compatibility.dart check`, `snapshot` nếu cần.
5. Không cần smoke test device bắt buộc (unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit đã trích dẫn chính xác file:line, đọc kỹ logic thật (không
suy đoán), xác nhận `test/core/reward_transaction_pipeline_test.dart` chưa
có test nào cover đúng case này (gọi `grant()` 2 lần với `lines` khác nhau
cho cùng `transactionId` pending/partial). Không trùng task nào trong
`doc/task/done/`.
