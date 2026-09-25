---
id: BUG-80
title: "API compatibility gate bỏ sót public symbol và hiểu sai major release"
type: bug
priority: P1
effort: L
source: "claude audit vòng 3 — fixture CLI độc lập"
---

## Vị trí
`tool/api_compatibility.dart`, `tool/api_snapshot.json`, test CLI.

## Hiện trạng và hậu quả
Parser bỏ sót sealed/final class cùng typed top-level functions, đồng thời ghi nhầm private declarations. Snapshot hiện bỏ sót public API lõi như `SdkResult` và `compareAppVersions`. Major gate coi mọi `1.x.y` trở lên là major, nên removal tại patch/minor có thể bypass `BREAKING` changelog.

## Acceptance criteria
- [x] Snapshot gồm public class/enum/mixin/typedef/extension và modifier Dart hiện dùng; không gồm private `_` symbol.
- [x] Snapshot gồm typed top-level block/arrow functions và public top-level const/final.
- [x] Removal ở stable patch/minor bị từ chối khi không có `BREAKING`.
- [x] Major bump được so với baseline snapshot version; snapshot cũ có migration/backward-compatible behavior rõ ràng.
- [x] Fixture tests chứng minh các regression trên và gate repo thật pass.

## Quyết định kỹ thuật
- Nâng cấp bộ parser trong `tool/api_compatibility.dart`:
  - Hỗ trợ đầy đủ các modifier Dart 3 hiện đại: `abstract`, `sealed`, `final`, `base`, `interface` cho `class`, `enum`, `mixin`, `typedef`, `extension`, `extension type`.
  - Thu thập các typed top-level block và arrow functions (như `compareAppVersions`, `dlog`, `nowMsClamped`, `fmtDur`, `asStringOr`), getters/setters, cũng như các hằng số/biến `const`/`final` ở cấp top-level.
  - Loại bỏ hoàn toàn 44 private symbols (bắt đầu bằng `_`) khỏi snapshot bằng cách ràng buộc tên định danh bắt đầu bằng `[A-Za-z]`.
  - Lưu trường `'version'` vào snapshot JSON để làm mốc baseline so sánh.
- Sửa đổi logic Semver Major Release Gate:
  - Thay thế hàm `_isMajor(version)` kiểm tra sai lệch trước đây bằng `_isMajorBump(String currentVersion, String? baselineVersion)`.
  - Một bản release chỉ được coi là major bump nếu `current.major > baseline.major`.
  - Mọi trường hợp removal ở patch/minor (kể cả phiên bản >= 1.0.0 hay pre-1.0) đều bắt buộc phải có `BREAKING` trong changelog section của phiên bản đó.
  - Nếu baseline snapshot cũ không có trường `version` (backward-compatible), mặc định coi là không phải major bump để đảm bảo an toàn tuyệt đối.
- Tái tạo snapshot chuẩn `tool/api_snapshot.json` trên repo thật và bổ sung 4 test case fixture TDD trong `test/tool/api_compatibility_check_test.dart`.


## Prompt
Làm TDD qua CLI fixture `--root`. Không dùng parser regex quá rộng tạo false positive; cân nhắc parser nhẹ nhưng phải cover cú pháp package đang public-export. Giữ compatibility cho snapshot hiện tại hoặc cập nhật snapshot có kiểm soát và changelog phù hợp.
