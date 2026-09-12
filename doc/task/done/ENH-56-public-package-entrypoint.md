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
- [x] Consumer tối thiểu compile chỉ với `package:roy_casual_kit/roy_casual_kit.dart`.
- [x] Không export implementation private/debug-only ngoài chủ đích; không tạo vòng import.
- [x] README dùng entrypoint chuẩn và có migration note cho deep imports.
- [x] Unit, widget, integration và device smoke test chứng minh các nhóm API chính dùng được.

## Implementation evidence

- Added `lib/roy_casual_kit.dart` with deliberate exports for core services/contracts, utility APIs, Flame starter APIs, top-level widgets and the complete common widget barrel.
- Added compile/API-surface and widget tests importing only the public entrypoint.
- Migrated the example Home, Settings and Game Demo screens to the stable entrypoint import.
- README usage now recommends the entrypoint and documents deep imports as advanced migration-only APIs.
- Root and `example/` passed `flutter analyze` and `flutter test --exclude-tags slow`.
- `dart pub publish --dry-run` completed with the existing package-hygiene warnings only (plural `docs` layout and clean-git check before commit).
- Device smoke `app boots to HomeScreen` passed on Samsung SM S928B (`R5CX613VZBR`, Android 16/API 36) using the migrated example.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; chạy `dart pub publish --dry-run`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.
