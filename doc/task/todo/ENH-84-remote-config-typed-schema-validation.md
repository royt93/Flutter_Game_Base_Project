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
- [ ] API đăng ký schema cho 1 tập key remote config (tên, kiểu mong đợi, optional default).
- [ ] Remote data không khớp schema (sai kiểu 1 key) bị phát hiện ngay tại `init()`, trả lỗi rõ ràng liệt kê đúng key sai — không phải crash ở nơi dùng.
- [ ] Remote data khớp schema hoàn toàn hoạt động không đổi so với hiện tại.
- [ ] Không schema nào được đăng ký (trường hợp mặc định, không breaking) giữ nguyên hành vi cũ hoàn toàn.

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
