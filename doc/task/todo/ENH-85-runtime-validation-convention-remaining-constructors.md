---
id: ENH-85
title: "Chuẩn hoá runtime validation cho các constructor config còn lại chỉ dùng assert (ReplayRecorder, LocalScoreboardService...)"
type: enhancement
priority: P1
effort: M
source: "codex (độc lập) — phần còn lại sau khi BUG-49/BUG-53/BUG-54/BUG-69 đã fix riêng lẻ các trường hợp cụ thể nhất"
---

## Vị trí
`lib/core/replay_recorder.dart:160` (`capacity: 0` → modulo 0 khi record), `lib/core/local_scoreboard_service.dart:44` (`capacity: 0` → âm thầm drop mọi submit), và các constructor public khác trong `lib/core/` còn dùng `assert` làm rào chắn duy nhất cho invariant runtime.

## Hiện trạng
Nhiều service public vẫn chỉ dùng `assert` cho invariant constructor — bị strip hoàn toàn ở release build. BUG-49 (AssetPreloadCoordinator)/BUG-53 (ObjectPool)/BUG-54 (GameClock)/BUG-69 (economy_math) đã fix riêng các trường hợp nghiêm trọng nhất phát hiện được; đây là phần còn lại + 1 QUY ƯỚC chung để tránh lặp lại vấn đề này ở service mới trong tương lai.

## Vì sao cần / Hậu quả
`ReplayRecorder(capacity: 0)` sẽ modulo 0 (crash) tại `record()`; `LocalScoreboardService(capacity: 0)` âm thầm drop mọi submit (không crash, nhưng sai hoàn toàn, khó debug vì không có lỗi rõ ràng). Đây là cùng lớp vấn đề như các BUG đã fix — thiếu 1 quy ước chung khiến vấn đề tái diễn ở service mới.

## Đề xuất
Lập convention rõ ràng (ghi vào CLAUDE.md nếu phù hợp): mọi public constructor validate invariant bằng runtime check thật (`ArgumentError` cho lỗi lập trình viên gọi sai API, `SdkFailure.validation` cho input runtime từ nguồn không tin cậy như CMS/JSON), có test chạy dưới `--no-enable-asserts` (hoặc build mode tương đương) xác nhận validate vẫn hoạt động. Áp dụng ngay cho `ReplayRecorder`/`LocalScoreboardService` (2 trường hợp cụ thể nhất được nêu), rà thêm các service khác nếu phát hiện thêm trong lúc làm.

## Acceptance criteria
- [ ] `ReplayRecorder(capacity: 0)` throw runtime rõ ràng, không modulo 0.
- [ ] `LocalScoreboardService(capacity: 0)` throw runtime rõ ràng, không âm thầm drop submit.
- [ ] Test `--no-enable-asserts` (hoặc tương đương) xác nhận validate vẫn chạy cho cả 2 service.
- [ ] Convention được ghi lại rõ ràng (CLAUDE.md hoặc doc comment chung) để service mới trong tương lai theo đúng.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-85-runtime-validation-convention-remaining-constructors.md` này trước khi làm. Đọc toàn bộ `lib/core/replay_recorder.dart`, `lib/core/local_scoreboard_service.dart`, và các task đã fix trước đó (BUG-49/53/54/69) để đồng bộ đúng 1 quy ước duy nhất, tránh 4 cách validate khác nhau cho 4 service. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, cho cả 2 service cụ thể.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (validate constructor thuần).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — codex trích dẫn đúng 2 file/dòng cụ thể, mô tả hậu quả (modulo 0, silent drop) hợp lý theo tên method. Chưa tự Read lại chi tiết implementation. Không trùng task nào trong `doc/task/done/` — bổ sung, không thay thế các BUG đã fix riêng lẻ.
