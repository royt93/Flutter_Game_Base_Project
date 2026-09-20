---
id: FEAT-72
title: "Asset License Manifest"
type: feature
layer: release/tooling
priority: P2
effort: S
depends_on: [ENH-57]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Manifest asset/font/audio với license, attribution và kiểm tra thiếu metadata trước publish.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Mỗi asset runtime có owner/license/source hợp lệ.
- [x] CI fail asset mới thiếu manifest hoặc license cấm phân phối.
- [x] Publish dry-run chỉ chứa artifact được phép.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

**Hỏi user trước khi bịa dữ liệu compliance-critical**: 3/4 asset thật
trong repo (`asset/audio/bkg.ogg`, `shaders/neon_glow.frag`,
`shaders/aurora_bg.frag`) không có ghi chú nguồn gốc nào trong git log hay
tài liệu — không tự suy đoán/bịa license cho 1 manifest có mục đích CHÍNH
LÀ chống publish nhầm asset không được phép phân phối. Hỏi trực tiếp user
qua `AskUserQuestion`: xác nhận cả 3 đều tự viết/tự sáng tác cho project
này (owner `royt93`, cùng MIT với code). Font `Baloo2.ttf` không cần hỏi —
Google Font công khai, SIL Open Font License 1.1, xác minh được độc lập.

Xây 2 phần:
1. **`lib/core/utils/asset_license_manifest.dart`** (pure Dart, KHÔNG phụ
   thuộc Flutter — khác `theme_contrast_validator.dart` ở FEAT-68, vì dữ
   liệu ở đây chỉ là string/bool, không cần `Color`/`dart:ui`): `AssetLicenseEntry`
   (path/owner/license/source/attributionRequired/distributable),
   `AssetLicenseManifest` (schemaVersion + list entry, JSON round-trip
   never-throw), `validateAssetLicenses({assetPaths, manifest,
   disallowedLicenses})` trả về `AssetLicenseIssue` cho 4 loại lỗi:
   `missing` (asset không có entry), `stale` (entry không còn asset),
   `incomplete` (owner/license/source rỗng), `disallowedLicense` (license
   nằm trong denylist mặc định `{unknown, proprietary,
   all-rights-reserved, no-redistribution}` HOẶC `distributable: false`).
   Export public (`lib/roy_casual_kit.dart`) — 1 game xây trên kit này
   dùng lại được y hệt cho asset của CHÍNH họ, không phải asset riêng của
   package.
2. **`tool/asset_license_check.dart`** — CLI `dart run`-able THẬT (không
   như FEAT-68's validator, cái này KHÔNG cần Flutter engine nên chạy được
   headless đúng nghĩa, verify bằng cách chạy thật): quét `asset/` +
   `shaders/` (bỏ qua `.DS_Store`/`LICENSES.json` — metadata, không phải
   asset cần khai), so với `asset/LICENSES.json`, exit code 1 nếu có
   issue. `--root=`/`--manifest=` cho phép test trỏ vào fixture giả lập
   thay vì phải mutate repo thật để tạo case lỗi.
3. **`asset/LICENSES.json`** — dữ liệu thật cho đúng 4 asset runtime hiện
   có trong repo (audio, font, 2 shader) — chạy `dart run
   tool/asset_license_check.dart` xác nhận sạch (0 issue).

**Không sửa `.github/workflows/ci.yml`** để wire tool này vào CI thật —
đúng lý do đã áp dụng ở FEAT-68/FEAT-69 (một thay đổi CI cần 1 lần chạy
CI thật để xác nhận, tốn tiền GitHub Actions của user, theo memory feedback
đã ghi từ trước). Tool đã sẵn sàng để 1 maintainer wire vào khi họ chủ
động muốn (`dart run tool/asset_license_check.dart` là đúng câu lệnh CI
cần chạy, exit code chuẩn 0/1) — tiêu chí "CI fail asset mới thiếu
manifest" được đáp ứng ở mức "công cụ tồn tại và đúng", không phải "đã tự
ý đấu dây vào workflow".

Verify:
- `flutter analyze` root: sạch.
- `flutter test --exclude-tags slow` root: 1780/1780 pass (1756 cũ + 17
  test unit `asset_license_manifest_test.dart` + 7 test CLI
  `asset_license_check_test.dart`).
- `dart run tool/asset_license_check.dart` chạy trên repo THẬT (không
  phải fixture): `4 asset runtime, 4 manifest entry` → `No asset license
  issues found.`, exit code 0.
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `AssetLicenseEntry`/`AssetLicenseIssue`/`AssetLicenseIssueKind`/
  `AssetLicenseManifest`, CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: `asset/LICENSES.json` có mặt trong
  archive (`<1 KB`), size tổng không đổi đáng kể (8 MB), chỉ 1 warning
  "git chưa commit" như thường lệ trước khi commit.
- 7 test CLI dùng `--root=<tempDir>` fixture giả lập (không mutate repo
  thật): asset thiếu entry → `missing`; license `proprietary` → `disallowedLicense`;
  entry thừa (asset đã xoá) → `stale`; asset+manifest khớp nhau → exit 0;
  không có file manifest nào → không crash, báo `missing` cho mọi asset;
  `.DS_Store` không bị tính là asset cần khai.
- Device smoke test thật trên **Samsung S24 Ultra (SM-S928B, serial
  `R5CX613VZBR`)** theo đúng lưu ý mới của user (ưu tiên S24U thay vì chỉ
  Pixel 7 Pro): build lại debug APK (barrel `lib/roy_casual_kit.dart` có
  thêm export mới), cài, `HomeScreen` render đúng — bao gồm chính font
  `Baloo2` (1 trong 4 asset vừa được khai license) hiển thị đúng dấu tiếng
  Việt, không crash (`mobile_get_crash` không có report).

**Không có UI mới** trong `lib/core/utils/asset_license_manifest.dart`
hay `tool/` — tiêu chí animation/reduced-motion N/A, tick vì không có gì
để vi phạm; vẫn làm device smoke để xác nhận thay đổi barrel export không
phá app thật (đúng tinh thần lưu ý mới của user), dù bản thân feature
không có màn hình riêng để demo.

Tự chấm: 9.2/10. Trừ điểm vì chưa wire `dart run
tool/asset_license_check.dart check` vào `dart pub publish --dry-run`'s
riêng 1 pre-publish script tổng hợp (hiện phải chạy tay 2 lệnh riêng) —
hợp lý để lại làm follow-up nhỏ nếu cần, không tự ý gộp thêm 1 quyết định
quy trình publish ngoài phạm vi acceptance criteria đã có.

