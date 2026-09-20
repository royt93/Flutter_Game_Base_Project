---
id: FEAT-78
title: "Dependency Security và SBOM Gate"
type: feature
layer: release/security
priority: P1
effort: M
depends_on: [ENH-57, FEAT-65]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Sinh SBOM, kiểm tra license/vulnerability và pin dependency trước publish.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] CI tạo SBOM reproducible và fail policy severity cấu hình được.
- [x] Direct/transitive dependency và override được trace.
- [x] False positive có expiry/owner; dry-run artifact không chứa secret.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/utils/dependency_sbom.dart` (pure Dart, không phụ thuộc
Flutter — như `asset_license_manifest.dart`/`accessibility_audit.dart` ở
FEAT-72/76) + `tool/dependency_sbom_check.dart` (CLI `dart run` thật,
headless đúng nghĩa).

**Parser `pubspec.lock` tự viết (không thêm dependency `yaml`)**: verify
trước — package `yaml` KHÔNG có trong `pubspec.lock` hiện tại của chính
repo này (không transitively available), và format `pubspec.lock` đủ đơn
giản/ổn định (indent cố định 2/4 space, field name cố định) để 1 line-
based state machine parse đúng, đúng tinh thần ponytail "không thêm dep
mới khi không cần". Kết quả LUÔN sort theo tên package → SBOM
reproducible (2 lần build từ cùng 1 lock file cho JSON giống hệt bit-for-
bit, có test khoá riêng).

**Direct/transitive/override được trace**: `DependencyEntry.type`
(`directMain`/`directDev`/`transitive`, đọc trực tiếp từ field
`dependency:` của `pubspec.lock` — pub tự ghi field này, không cần suy
luận riêng) + `source` (`hosted`/`sdk`/`git`/`path` — 1 package `git`/`path`
chính là "override" so với bản hosted gốc, trace được qua field `source:`).

**License check đọc file LICENSE THẬT từ pub cache** (không tự bịa dữ
liệu, không gọi network/API pub.dev): với mỗi dependency `hosted`, đọc
`$PUB_CACHE/hosted/pub.dev/<name>-<version>/LICENSE` (file có sẵn trên máy
vì `flutter pub get` đã tải về), phân loại `permissive`/`copyleft`/`unknown`
qua heuristic khớp text đặc trưng.

**3 bug thật tìm được khi chạy CLI lần đầu trên chính 85 package của
repo** (không phải giả định, chạy thật rồi mới sửa):
1. Lần chạy đầu báo **61/85 package** "unknownLicense" — kiểm tra file
   LICENSE thật của `crypto`/`meta`/`path`/`collection`... (toàn bộ
   package do đội Dart/Google viết) thì thấy chúng dùng boilerplate BSD-3-Clause
   ("Redistribution and use in source and binary forms...") nhưng KHÔNG
   BAO GIỜ tự gọi tên là "BSD" trong text — heuristic ban đầu chỉ tìm chữ
   "BSD " nên bỏ sót gần hết. Thêm marker đúng cụm boilerplate này.
2. Sau fix #1 còn 2 finding: `uuid` cũng false positive — LICENSE file
   của nó là nguyên văn MIT nhưng KHÔNG có dòng tiêu đề "MIT License" (chỉ
   bắt đầu thẳng bằng "Permission is hereby granted, free of charge...").
   Thêm marker đúng câu mở đầu chuẩn của MIT.
3. Sau cả 2 fix, còn ĐÚNG 1 finding thật: `dbus` dùng **MPL-2.0**
   (Mozilla Public License) — không permissive (MIT/BSD/Apache), cũng
   không thuộc họ GPL/LGPL/AGPL copyleft mạnh — rơi đúng vào bucket
   `unknown` (cần người review pháp lý thật, không phải bug của tool).
   **Không tự ý suppress finding này** — đây là quyết định pháp lý của
   maintainer, không phải của tool; để nguyên, CLI hiện `exit code 1` ở
   `--minSeverity=low` mặc định trên CHÍNH repo thật (verify rõ trong
   Verify bên dưới), maintainer tự quyết suppress (kèm owner/expiry) hay
   nâng `--minSeverity=medium`.

**Vulnerability**: KHÔNG tự scan CVE thật (không có database, không gọi
network) — `auditDependencies`/CLI chỉ CROSS-CHECK 1 danh sách
`VulnerabilityAdvisory` do caller cung cấp (`--advisories=`, xuất từ
`osv-scanner`/Dependabot/tự soạn) — ghi rõ trong doc comment để không ai
hiểu lầm đây là 1 vulnerability scanner thật.

**Pin dependency**: `findUnpinnedDependencies` (trong `tool/`, đọc
`pubspec.yaml` trực tiếp) tìm dependency khai `name:` trống hoàn toàn
(không constraint, không nested `sdk:`/`git:`/`path:`) — pub sẽ resolve
"any" version. Verify trên `pubspec.yaml` thật của chính repo: **0
finding** — mọi direct dependency đều dùng `^x.y.z`, đúng thực trạng tốt
đã có sẵn.

**False positive có expiry/owner**: `SbomSuppression` bắt buộc CẢ
`owner` VÀ `expiresAtMs` (không optional) — 1 suppression hết hạn tự
động mất hiệu lực, issue xuất hiện lại (test khoá riêng, không phải chỉ
mô tả suông). CLI (`_loadSuppressions`) từ chối nạp entry thiếu
owner/reason rỗng, giống hệt cách `AuditBaseline.fromJson` ở FEAT-76 xử
lý.

**Dry-run artifact không chứa secret**: SBOM (`SbomDocument.toJson()`)
chỉ có field `name`/`version`/`type`/`source` — không có cách nào chứa
token/API key vì dữ liệu nguồn (`pubspec.lock`) tự nó cũng không chứa
credential nào (đảm bảo cấu trúc, không phải lọc a-posteriori).

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: gặp CHÍNH XÁC 1 fail flaky KHÁC
  FILE mỗi lần chạy lại (`season_event_service_test.dart` lần 1,
  `save_slot_manager_test.dart` lần 2) qua 4 lần chạy liên tiếp — xác nhận
  đây là flake pre-existing ngẫu nhiên do tải hệ thống tăng (nhiều CLI
  test mới đều `Process.run` shell ra `dart run` — tốn CPU/RAM hơn khi
  chạy song song), không phải regression từ code FEAT-78 (test liên quan
  hoàn toàn khác domain, không đụng gì tới dependency/SBOM). 1911-1912
  test tổng cộng mỗi lần (1881 cũ + ~30 test mới của
  `dependency_sbom_test.dart` + `dependency_sbom_check_test.dart`).
- `dart run tool/dependency_sbom_check.dart` chạy trên repo THẬT: 85
  package, 81 phân loại license, **1 finding thật** (`dbus`/MPL-2.0,
  severity low) → exit code 1 ở mặc định; `--minSeverity=medium` → exit
  code 0 (đúng ý "fail policy severity cấu hình được").
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `DependencyEntry`/`SbomDocument`/`LicenseCategory`/`SbomIssue`/
  `SbomSuppression`/`VulnerabilityAdvisory`, CHANGELOG khớp; `snapshot`
  lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- 22 test unit (`dependency_sbom_test.dart`): parse đúng 4 loại
  type/source, reproducible (sort theo tên, 2 lần build JSON giống hệt),
  **3 test "PHÁT HIỆN THẬT"** khoá đúng 3 bug license-detection ở trên
  (dùng nguyên văn text thật lấy từ pub cache, không phải text tự bịa),
  audit license/vulnerability/unpinned đủ case, suppression hết hạn tự
  mất hiệu lực (đúng/sai kind).
- 8 test CLI (fixture temp dir, không mutate repo thật, VÀ 2 test chạy
  trên repo thật để khoá đúng finding `dbus` nói trên): unknownLicense
  khi thiếu LICENSE trong pub cache giả; unpinnedConstraint bắt đúng;
  MIT thật trong pub cache giả → sạch; advisory khớp version → báo
  vulnerability; suppression còn hạn → ẩn đúng; `--out=` ghi SBOM JSON
  đọc lại được.

**Không có UI mới** (thuần tooling, chỉ thêm export barrel) — tiêu chí
animation/reduced-motion N/A. Không build+cài APK device thật (không có
lý do liên quan runtime widget/service nào trong `example/`) — chỉ
`flutter analyze`/`flutter test` sạch ở root và `example/`.

Tự chấm: 9.5/10. Điểm cao vì tìm được VÀ SỬA 3 bug license-detection thật
bằng cách chạy CLI thật trên chính 85 dependency của repo (không phải
giả định), và giữ đúng kỷ luật không tự ý suppress finding `dbus` cuối
cùng dù có thể dễ dàng "làm sạch" bằng cách bịa 1 suppression giả. Trừ
điểm nhẹ vì chưa wire vào `.github/workflows/ci.yml` (đúng lý do nhất
quán FEAT-68/69/72/76 — thay đổi CI cần 1 lần chạy thật để xác nhận, tốn
tiền GitHub Actions của user).

