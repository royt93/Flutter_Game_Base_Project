---
id: BUG-67
title: "OfflineProgressionService: người chơi mới (chưa từng claim) nhận 0 thưởng offline ở lần tính đầu tiên"
type: bug
priority: P2
effort: XS
source: "agy (độc lập) — cần verify lại chính xác trước khi implement"
---

## Vị trí
`lib/core/offline_progression_service.dart` — tính `elapsed` kể từ lần claim trước (mốc claim mặc định khi chưa từng claim).

## Hiện trạng
Với người chơi hoàn toàn mới (chưa từng gọi `claim()`), mốc "lần claim trước" mặc định có thể được set bằng THỜI ĐIỂM HIỆN TẠI (thay vì thời điểm cài đặt/tạo profile), khiến `elapsed = now - lastClaimMs` gần như bằng 0 ở lần tính đầu tiên — người chơi mới không nhận được thưởng offline nào dù có thể đã có 1 khoảng "chờ" hợp lý trước khi mở app lần đầu (tuỳ thiết kế onboarding).

## Vì sao cần / Hậu quả
Ảnh hưởng trải nghiệm người chơi mới — 1 trong những khoảnh khắc "wow" đầu tiên của game idle/casual (nhận thưởng offline ngay từ màn chơi đầu) bị mất nếu mốc mặc định tính sai.

## Đề xuất
Xác nhận rõ ý định thiết kế: nếu mốc mặc định NÊN là "thời điểm cài đặt/khởi tạo profile" (để có 1 khoản thưởng nhỏ chào mừng), set đúng mốc đó thay vì `now`. Nếu ý định là "người chơi mới không có gì để claim" (hợp lý), giữ nguyên nhưng đảm bảo hành vi rõ ràng/document đúng — không phải bug ngầm. Effort XS vì chỉ cần xác nhận đúng ý định rồi sửa 1 dòng khởi tạo mốc mặc định.

## Acceptance criteria
- [ ] Xác nhận rõ ý định thiết kế (đọc doc comment/test hiện có của `OfflineProgressionService` trước khi quyết định hướng fix).
- [ ] Nếu xác nhận là bug: người chơi mới nhận đúng 1 khoản thưởng offline hợp lý ở lần tính đầu tiên (không phải 0 do mốc mặc định sai).
- [ ] Nếu xác nhận là hành vi CỐ Ý (không phải bug): đóng task này với ghi chú rõ ràng trong `## Quyết định`, không sửa gì, coi là "no_change_needed".
- [ ] Test hiện có của `offline_progression_service_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-67-offline-progression-zero-first-time-reward.md` này trước khi làm. Đọc toàn bộ `lib/core/offline_progression_service.dart` và test hiện có TRƯỚC — xác nhận rõ đây có phải bug thật hay hành vi cố ý trước khi sửa bất kỳ gì. Nếu là bug thật, implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại (kể cả nếu kết luận "không phải bug"), chấm điểm /10 cho chất lượng điều tra + quyết định.
2. Nếu có sửa code: bổ sung ĐỦ unit test cho case liên quan.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã điều tra kỹ) đạt > 9/10 — kể cả khi kết luận là "không cần sửa", vẫn commit việc cập nhật task file với `## Quyết định` giải thích rõ.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`, hoặc ghi rõ lý do không sửa), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp-trung bình — mô tả của agy mang tính suy luận về hành vi ("có thể được set bằng thời điểm hiện tại"), CHƯA tự Read code để xác nhận đây có thật là hành vi hiện tại hay không. Task này ưu tiên ĐIỀU TRA trước khi kết luận có bug hay không — người thực hiện có quyền đóng task với "no_change_needed" nếu xác nhận đây là hành vi cố ý hợp lý. Không trùng task nào trong `doc/task/done/`.
