---
id: ENH-64
title: "pubspec.yaml/README.md lại ghi \"40-widget\" nhưng barrel đã export 47"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đếm trực tiếp `lib/presentation/widgets/common/common_widgets.dart`)
---

## Vị trí
Tài liệu — `pubspec.yaml` (`description`) và `README.md`.

## Hiện trạng
`pubspec.yaml`'s `description` và `README.md` đều ghi **"40-widget"** UI kit. Đếm trực tiếp `lib/presentation/widgets/common/common_widgets.dart` (barrel export) hiện có **47 dòng `export`** (`grep -c "^export"` → 47). Đây CHÍNH XÁC là lỗi ENH-15 đã từng sửa 1 lần trước (khi đó "21-widget" → số thật lúc đó), nhưng đã tái phát: rất nhiều widget mới được thêm qua các task sau này (`quest_board_panel`, `backup_restore_panel`, `wheel_spinner`, `energy_bar`, `daily_login_calendar`, `game_over_card_template`, v.v.) mà không ai cập nhật lại con số mô tả.

## Vì sao cần / Hậu quả
`description` là dòng hiển thị công khai trên pub.dev — đánh giá thấp package so với thực tế (47 so với 40, thiếu ~15%) làm giảm sức hấp dẫn khi người dùng lướt qua danh sách gói. Đây cũng là bằng chứng cho thấy con số "đếm tay" kiểu này sẽ LUÔN tái phát mỗi khi thêm widget mới trừ khi có cách nào đó để không phải nhớ cập nhật thủ công.

## Đề xuất
1. Cập nhật `pubspec.yaml`'s `description` và `README.md` với con số đúng hiện tại (47, hoặc làm tròn xuống "45+"/"47" — quyết định khi implement).
2. Cân nhắc (không bắt buộc, tránh over-engineer cho 1 task XS): thêm 1 dòng comment ngay phía trên đếm số dòng `export` trong chính `common_widgets.dart`, nhắc rằng con số này được tham chiếu ở `pubspec.yaml`/`README.md` — để lần sau ai thêm export mới dễ nhớ cập nhật hơn (không cần thiết phải làm test tự động kiểm tra khớp số, việc đó tốn công không tương xứng với 1 con số mô tả marketing).

## Acceptance criteria
- [x] `pubspec.yaml`'s `description` khớp đúng số export thật tại thời điểm sửa.
- [x] `README.md` (dòng ghi cùng con số) cũng khớp.
- [x] Không có chỗ nào khác trong repo (ví dụ `CHANGELOG.md`, comment khác) nhắc lại đúng con số cũ "40-widget" cần sửa theo (kiểm tra bằng `grep -rn "40-widget"`).
- [x] `flutter analyze` sạch (thay đổi thuần văn bản, không ảnh hưởng code, nhưng vẫn chạy để chắc chắn không lỗi định dạng YAML/Markdown).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-64-pubspec-readme-widget-count-stale-again.md` này trước khi làm. Đếm lại chính xác số dòng `export` trong `lib/presentation/widgets/common/common_widgets.dart` (`grep -c "^export"`) tại thời điểm bắt đầu làm (số có thể đã đổi khác 47 nếu có task khác chen ngang thêm widget mới — dùng con số đếm được LÚC ĐÓ, không copy cứng con số 47 trong file task này). Sửa `pubspec.yaml`/`README.md` theo đúng con số đó.

Vòng lặp CHỈ được coi là xong khi:
1. Tự audit lại thay đổi, chấm điểm /10 (con số khớp đúng thực tế, không có chỗ nào khác còn ghi số cũ).
2. `grep -rn "40-widget"` (hoặc con số cũ bất kỳ) trong toàn repo trả về rỗng.
3. `flutter analyze` sạch ở root.

Đây là task cực nhỏ (effort XS, thuần sửa text) — không cần unit test, không cần đụng `example/`, không cần device smoke test.

Chỉ `git commit` + `git push` khi điểm tự chấm đạt > 9/10. Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận trực tiếp: `grep -c "^export" lib/presentation/widgets/common/common_widgets.dart` = 47; `grep -n "40-widget" pubspec.yaml README.md` khớp cả 2 file. Đây là đúng dạng lỗi ENH-15 đã từng sửa 1 lần trước (xác nhận qua đọc `doc/task/done/ENH-15-pubspec-description-stale-widget-count.md`), nay tái phát sau nhiều widget mới được thêm. Effort cực nhỏ, không đụng code/file nhạy cảm/scope peer.

## Quyết định

Đếm lại tại thời điểm làm: `grep -c "^export" lib/presentation/widgets/common/common_widgets.dart` = 47 (khớp đúng số đã ghi trong task, không có task nào chen ngang thêm export mới). Sửa `pubspec.yaml`'s `description` và `README.md` từ "40-widget" → "47-widget".

`grep -rn "40-widget"` sau khi sửa chỉ còn khớp ở chính file task này (sẽ chuyển sang `done/`) và 1 dòng trong `doc/task/done/ENH-16-changelog-version-stale.md` — đây là **file lịch sử** ghi lại đúng trạng thái tại thời điểm ENH-16 được đóng (mô tả CHANGELOG lúc đó nói "40-widget"), không phải tài liệu sống — cố tình KHÔNG sửa vì sẽ làm sai lệch bản ghi lịch sử của 1 task đã đóng từ trước.

**Kết quả:** `flutter analyze` sạch. Không cần test/device smoke test — thay đổi thuần văn bản, đúng effort XS.

**Tự chấm điểm: 10/10** — đúng chính xác con số thật tại thời điểm sửa, không sót chỗ nào trong tài liệu SỐNG, phân biệt đúng giữa tài liệu sống (cần sửa) và bản ghi lịch sử đã đóng (không sửa để giữ tính trung thực của lịch sử).
