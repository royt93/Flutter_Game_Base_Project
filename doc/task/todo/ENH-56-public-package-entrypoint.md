---
id: ENH-56
title: "Tạo public entrypoint lib/roy_casual_kit.dart và khóa API surface"
type: enhancement
priority: P0
effort: M
source: Codex + agy audit
depends_on: []
---

## User story
Là consumer của package, tôi muốn import một URI chuẩn và biết API nào được support thay vì phụ thuộc hàng chục deep import nội bộ.

## Hiện trạng và bằng chứng
Không có file Dart nào trực tiếp dưới `lib/`; toàn bộ `example/` và test dùng deep import `package:roy_casual_kit/core/...` hoặc `presentation/...`. Đây là khoảng trống đã được `agy` nêu trong raw opinion nhưng chưa từng được chuyển thành task.

## Scope
- Tạo `lib/roy_casual_kit.dart` export API public có chủ đích theo nhóm core/game/widgets.
- Dogfood entrypoint trong example; chỉ giữ deep import khi cố ý là advanced API.
- Thêm API-surface test để export mới không vô tình mất ở lần refactor sau.

## Acceptance criteria
- [ ] Consumer tối thiểu compile chỉ với `package:roy_casual_kit/roy_casual_kit.dart`.
- [ ] Không export implementation private/debug-only ngoài chủ đích; không tạo vòng import.
- [ ] README dùng entrypoint chuẩn và có migration note cho deep imports.
- [ ] Unit, widget, integration và device smoke test chứng minh các nhóm API chính dùng được.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; chạy `dart pub publish --dry-run`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.

