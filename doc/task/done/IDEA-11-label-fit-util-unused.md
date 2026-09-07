---
id: IDEA-11
title: "fitFontSizeForLongestWord (label_fit.dart) không được widget nào trong kit dùng"
type: idea
priority: exclusive (độ tin cậy thấp — xem ghi chú)
effort: S
source: Claude, audit round 3 (fork agent)
---

## Ý tưởng
`lib/core/utils/label_fit.dart` — `fitFontSizeForLongestWord` có doc comment
kể lại 1 bug cụ thể: màn "German Mode Select" bị vỡ chữ giữa từ
("Doppelspiege" + "l"). Nhưng màn hình đó (và cả game "Pop Star Blast" nó
thuộc về) đã bị xoá khỏi repo từ đợt strip-to-base-game
(`docs/superpowers/plans/2026-09-05-strip-to-base-game.md`) — hiện
`grep -rln fitFontSizeForLongestWord lib/ example/` chỉ khớp đúng file định
nghĩa nó, không widget/screen nào trong kit hiện tại gọi hàm này.

## Ghi chú độ tin cậy
THẤP — có 2 khả năng, không tự quyết định được cái nào đúng:
1. Đây là dead utility sót lại từ game cũ, nên xoá (cùng test của nó) để
   giảm surface area không ai dùng.
2. Đây là utility CỐ Ý public cho consumer app tự dùng ở label/button của
   HỌ (giống `fmtNum`/`fmtDur` trong `utils/format.dart` — cũng là utils
   thuần không có widget nào trong kit gọi trực tiếp, nhưng KHÔNG bị coi
   là vấn đề vì rõ ràng là "tiện ích cho consumer app dùng"). Nếu đúng ý
   đồ ban đầu là vậy thì không cần làm gì — chỉ là doc comment tham chiếu
   1 bug/màn hình không còn tồn tại, hơi gây hiểu lầm, có thể update lại
   ví dụ cho khớp bối cảnh hiện tại (package thuần, không phải app cụ thể).

## Đề xuất
Hỏi ý kiến trước: giữ làm public util (chỉ sửa doc comment bớt tham chiếu
màn hình đã xoá) hay xoá hẳn vì không ai dùng. Không tự xoá code có test
đang pass mà chưa xác nhận ý đồ.

## Acceptance criteria
- [x] Quyết định rõ: giữ (sửa doc) hay xoá (kèm test + mọi tham chiếu).
- [x] Nếu giữ: doc comment không còn nhắc tên màn hình/game cụ thể đã không còn tồn tại trong repo.

## Quyết định
Giữ, cùng lý do `fmtNum`/`fmtDur`: public util hợp lệ cho consumer app tự
dùng, không cần widget nào trong kit gọi trực tiếp để chứng minh giá trị.
Sửa doc comment ở cả `lib/core/utils/label_fit.dart` và
`test/core/utils/label_fit_test.dart` — bỏ nhắc "Mode Select"/"đợt dịch"
(màn hình/ngữ cảnh game cũ đã xoá), giữ nguyên ví dụ tiếng Đức
("Doppelspiegel"/"Zitronenwüste") vì vẫn minh hoạ đúng vấn đề kỹ thuật, chỉ
không còn gắn với 1 màn hình cụ thể không tồn tại. Không đổi code/test logic.
Verify: `flutter analyze` sạch, `flutter test test/core/utils/label_fit_test.dart` 14/14 pass.
