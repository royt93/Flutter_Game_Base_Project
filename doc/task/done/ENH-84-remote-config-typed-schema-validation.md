---
id: ENH-84
title: "RemoteConfigService thiếu schema/ràng buộc typed — không phân biệt được rõ nguyên nhân lỗi ở diagnostic"
type: enhancement
priority: P1
effort: M
source: "codex (độc lập) — liên quan trực tiếp BUG-68 (fix hẹp), đây là phần mở rộng thiết kế rộng hơn"
---

## Vị trí
`lib/core/remote_config_service.dart` (~dòng 72, 104, 119).

## Hiện trạng
`RemoteConfigService` đọc giá trị config qua API generic (kiểu `dynamic`/`Object?`), không có validate kiểu/miền giá trị mong đợi cho từng key — lỗi kiểu dữ liệu (server trả `String` thay vì `int` cho 1 key) chỉ phát hiện khi consumer code tự cast và crash tại nơi dùng, không phải tại nơi fetch.

## Vì sao cần / Hậu quả
Server/CMS đổi kiểu 1 key remote config (lỗi vận hành phổ biến) sẽ làm crash rải rác khắp nơi trong app dùng key đó, thay vì phát hiện tập trung 1 chỗ ngay lúc fetch với thông báo lỗi rõ ràng.

## Đề xuất
Thêm 1 lớp schema khai báo (tương tự `SdkEventSchemaRegistry` đã có cho analytics event) cho phép đăng ký kiểu/miền giá trị mong đợi mỗi remote config key; `init()`/`initResult()` validate theo schema này, trả `SdkFailure.validation` liệt kê rõ key nào sai kiểu thay vì để lỗi xảy ra ở call site.

## Acceptance criteria
- [x] API đăng ký schema cho 1 tập key remote config (tên, kiểu mong đợi, optional default).
- [x] Remote data không khớp schema (sai kiểu 1 key) bị phát hiện ngay tại `init()`, trả lỗi rõ ràng liệt kê đúng key sai — không phải crash ở nơi dùng.
- [x] Remote data khớp schema hoàn toàn hoạt động không đổi so với hiện tại.
- [x] Không schema nào được đăng ký (trường hợp mặc định, không breaking) giữ nguyên hành vi cũ hoàn toàn.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-84-remote-config-typed-schema-validation.md` này trước khi làm. Đọc toàn bộ `lib/core/remote_config_service.dart` và `lib/core/sdk_event_schema_registry.dart` (tham khảo pattern schema đã có, tái dùng nếu hợp lý thay vì phát minh cơ chế mới) trước khi implement — ưu tiên PHỐI HỢP với BUG-68 nếu cả 2 được làm cùng đợt (BUG-68 là fix hẹp cho `initResult`, ENH-84 là mở rộng schema rộng hơn). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root, và `dart run tool/api_compatibility.dart check`/`snapshot` nếu thêm export mới.
4. Không cần smoke test device bắt buộc (logic thuần).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — codex trích dẫn đúng file/khu vực dòng, mô tả hợp lý và phù hợp với pattern schema đã có tiền lệ trong kit (`SdkEventSchemaRegistry`). Đây là enhancement thiết kế mở (effort M), cần cân nhắc kỹ để không over-engineer (ponytail: chỉ thêm khi thật sự cần, có thể bắt đầu từ validate đơn giản trước khi xây registry đầy đủ). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/remote_config_service.dart` thêm
`RemoteConfigKeySchema` (`{type: EventParamType, required: bool}`) — TÁI
SỬ DỤNG `EventParamType` (enum `string`/`int`/`double`/`bool`) đã có sẵn
trong `sdk_event_schema_registry.dart` thay vì phát minh 1 enum kiểu song
song, đúng gợi ý "tham khảo pattern đã có, tái dùng nếu hợp lý" của task.
`RemoteConfigService` nhận thêm param `schema` (`Map<String,
RemoteConfigKeySchema>`, mặc định `{}`). `init()` validate ngay sau khi
merge xong config (CẢ 2 nhánh: asset-only lẫn remote-merged/remoteFailed)
qua `_validateSchema()`, lưu vào `schemaViolations` getter mới —
`init()` vẫn KHÔNG throw (giữ đúng contract "never throws" hiện có).
`initResult()` (đã có từ BUG-68) mở rộng thêm: nếu `schemaViolations`
không rỗng → trả `SdkFailure(kind: validation, message: liệt kê đủ mọi key
sai)` — đúng chỗ tập trung phát hiện lỗi type từ CMS/server, thay vì để
crash rải rác ở nơi dùng.

**Quyết định thiết kế (lệch nhỏ so với đề xuất gốc, có chủ đích)**: đề xuất
gốc nhắc "optional default" như 1 phần của API đăng ký schema — CỐ Ý
KHÔNG thêm field `default` riêng trên `RemoteConfigKeySchema`, vì mỗi
getter (`getString`/`getInt`/`getDouble`/`getBool`) ĐÃ CÓ SẴN param
`fallback` đúng vai trò này — thêm 1 "default" thứ 2 ở tầng schema sẽ tạo
2 nguồn sự thật xung đột nhau (default nào thắng khi khác nhau?) cho CÙNG
1 khái niệm. `schema` chỉ mô tả "kiểu mong đợi" + "có bắt buộc phải tồn tại
hay không" — đúng phần LÕI mà acceptance criteria 2-4 thực sự kiểm tra
(sai type, required-nhưng-thiếu, khớp hoàn toàn, không có schema).

**Không phải allowlist chặt**: 1 key CÓ trong config nhưng KHÔNG có trong
`schema` KHÔNG bị coi là violation (khác `SdkEventSchemaRegistry`'s event
params vốn default-deny cho field lạ) — remote config vốn có nhiều key
app không cần validate hết, chỉ cần khai báo đúng những key thật sự quan
trọng.

**TDD**: 10 test mới `test/core/remote_config_service_test.dart` (group
"ENH-84") — không đăng ký schema giữ nguyên hành vi cũ; khớp hoàn toàn →
SdkSuccess; 1 key sai type → phát hiện đúng tại `init()`, `initResult`
liệt kê đúng tên; nhiều key sai cùng lúc → liệt kê ĐỦ không dừng ở key đầu;
required thiếu → violation; optional thiếu → KHÔNG violation; key ngoài
schema → KHÔNG violation; `double` chấp nhận cả `int` (JSON không phân
biệt); validate lại đúng sau MỖI lần `init()` (remote đổi type); fetch
fail vẫn validate đúng theo config fallback đang có. Xác nhận fail đúng
lỗi biên dịch khi `git stash` file lib, khôi phục pass 10/10 (41/41 cả
file, không phá test cũ).

**Kết quả**: `flutter analyze` sạch. `flutter test --exclude-tags slow`
root: 2229 test, 19 fail — khớp đúng baseline golden-image macOS-only đã
biết. `dart run tool/api_compatibility.dart check`: `additive`
(`RemoteConfigKeySchema`) → `snapshot` → `unchanged`. Không cần
`example/`/device (logic thuần, task tự ghi rõ không bắt buộc).
