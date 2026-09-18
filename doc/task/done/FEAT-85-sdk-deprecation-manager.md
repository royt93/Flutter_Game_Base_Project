---
id: FEAT-85
title: "SDK Deprecation Manager"
type: feature
layer: SDK release
priority: P1
effort: S
depends_on: [FEAT-65, ENH-56]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Quản lý API deprecated, migration hint, grace period và removal release theo semver.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Deprecated API có annotation/doc/target removal version.
- [ ] CI cảnh báo consumer usage và fail đúng khi quá grace period. (xem Quyết định — cố ý chưa wire vào `ci.yml`)
- [ ] Migration example compile/test trước khi API bị remove. (chưa có API nào thật sự bị deprecate trong package này — xem Quyết định)
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved. (N/A — task này thuần logic/tooling, không có UI)

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

**Phạm vi cố ý bị bó hẹp — đã hỏi và được user xác nhận trước khi code**: acceptance criteria #2 gốc ("CI cảnh báo consumer usage và fail đúng khi quá grace period") đòi sửa `.github/workflows/ci.yml`, vi phạm quy tắc cứng đã có từ trước trong phiên này ("không bao giờ đề xuất sửa CI, tốn tiền thật"). User chọn option: chỉ build core logic + tool script, KHÔNG đụng `ci.yml` — CI wiring để user tự làm khi muốn.

Kiến trúc:
- `DeprecatedApi` (constructor validate ngay, KHÔNG const được vì có logic — throw `ArgumentError` nếu semver sai định dạng HOẶC `removeInVersion` không sau `deprecatedInVersion`, tức "grace period vô nghĩa" bị chặn ngay lúc khai báo, không đợi tới lúc check mới phát hiện).
- `DeprecationRegistry.checkAll(currentVersion)` so sánh semver thuần tay (không thêm dependency `pub.dev` mới cho việc này — 3 số nguyên so từng phần, đủ dùng, không cần package `pub_semver`) — biên `currentVersion == removeInVersion` tính LÀ pastGrace (inclusive), vì "tới đúng version remove" nghĩa là API đã hết hạn, không phải "còn 1 version nữa mới hết".
- `tool/deprecation_check.dart`: script `dart run` độc lập, tự đọc `version:` trong `pubspec.yaml` bằng regex (giống cách `tool/api_compatibility.dart` đã đọc export list — không thêm dependency `yaml` mới), check `kPackageDeprecations` (khai trong CHÍNH file tool, không export ra `lib/` — đây là danh sách API CỦA PACKAGE NÀY, không phải cơ chế dùng chung), exit code 1 nếu có entry pastGrace. Sẵn sàng để wire vào CI (`dart run tool/deprecation_check.dart` là toàn bộ lệnh cần) nhưng KHÔNG tự ý sửa `ci.yml`.
- `kPackageDeprecations` hiện RỖNG vì package chưa từng deprecate API thật nào — đây là lý do acceptance criteria "Migration example compile/test" chưa tick: không có gì để làm ví dụ migration cả. Cơ chế đã sẵn sàng cho lần đầu tiên có API bị deprecate thật.

**Test:** `test/core/utils/deprecation_registry_test.dart` (11 case, TDD — RED xác nhận qua lỗi biên dịch "Undefined name" trước khi viết `deprecation_registry.dart`): validate semver hợp lệ/sai, validate grace period vô nghĩa, active/pastGrace đúng theo từng entry độc lập, biên inclusive, `pastGraceOnly()` lọc đúng, `currentVersion` sai định dạng throw, registry rỗng không throw. `test/tool/deprecation_check_test.dart` (1 case, cùng pattern `Process.run` đã có ở `test/tool/economy_sim_test.dart`/`test/api_compatibility_test.dart`): script chạy qua `dart run`, registry rỗng hiện tại → exit code 0.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1404/1404 pass (1 lần chạy gặp lại flaky pre-existing đã biết `season_event_service_test.dart`, pass khi chạy riêng lẻ). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass. `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit, như thường lệ). CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài lại app, boot thành công tới HomeScreen (3 nút Cài đặt/Bộ Widget/Demo Flame hiện đúng), không crash — xác nhận export mới trong `lib/roy_casual_kit.dart` không phá compile/boot runtime. Không có widget/UI mới nên không cần smoke tương tác sâu hơn — toàn bộ hành vi thật (semver compare, validate/check) đã được cross-check kỹ ở tầng unit test.

**Tự chấm điểm: 9/10** — validation ở tầng construct (fail sớm nhất có thể) đúng nguyên tắc "grace period vô nghĩa" bị chặn ngay, không đợi runtime; không thêm dependency mới cho semver compare/YAML parse dù có thể tiện hơn (đúng tinh thần ponytail — dùng lại pattern regex đã có trong `tool/api_compatibility.dart`); tách rõ "cơ chế dùng chung" (`lib/core/utils/deprecation_registry.dart`, export public) khỏi "dữ liệu riêng của package này" (`kPackageDeprecations` trong `tool/`, không export) — đúng layering. Trừ 1 điểm vì 2/5 acceptance criteria gốc không đạt trọn vẹn (CI wiring bị hoãn có chủ đích theo yêu cầu user; migration example chưa có do chưa có API nào thật sự cần deprecate) — đây là đánh đổi phạm vi đã được xác nhận trước, không phải thiếu sót kỹ thuật.

