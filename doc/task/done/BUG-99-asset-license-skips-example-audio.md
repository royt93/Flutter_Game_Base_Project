---
id: BUG-99
title: "Asset license checker bỏ sót example audio"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`tool/asset_license_check.dart:21,27-42`; `example/pubspec.yaml:34-36`.

## Hiện trạng

Checker chỉ quét root `asset/`, `shaders/` (const `_assetRoots`). `example/pubspec.yaml` ship `assets/audio/` (`demo_sfx.mp3`, `error.ogg`, `tap.ogg`, `victory.ogg`) và `assets/remote_config/`, không manifest license tương ứng, CI không audit phần này.

## Vì sao cần / Hậu quả

Asset ship thật (audio demo) không qua license gate — rủi ro pháp lý/attribution bị bỏ sót.

## Đề xuất

Mở rộng checker (hoặc script riêng `--root=example`) quét `example/assets/**`, cross-check `example/asset/LICENSES.json` hoặc manifest tương ứng; CI fail khi thiếu entry. Không trùng FEAT-72 (phạm vi 4 root asset).

## Acceptance criteria

- [x] Fixture mp3 trong example không có manifest entry → check fail.
- [x] Asset root example có manifest hợp lệ → pass.
- [x] CI gate chạy cho cả root và example (rõ trong workflow).

## Quyết định

Đã chọn (qua `AskUserQuestion`) mở rộng `tool/asset_license_check.dart` theo hướng generic thay vì hardcode path `example/` vào checker — tái dùng được cho bất kỳ consumer app nào có cấu trúc asset khác `asset/`/`shaders/`.

- `_assetRoots` đổi tên `_defaultAssetRoots` (giữ nguyên `['asset', 'shaders']`, hành vi cũ không đổi khi không truyền cờ mới). Thêm CLI option `--asset-roots=<a,b,...>` (comma-separated, trim khoảng trắng, bỏ giá trị rỗng, dedupe qua `.toSet()`, exit code 64 nếu rỗng sau khi lọc).
- `_walkAssetPaths(root, assetRoots)` nhận danh sách root thay vì đọc const toàn cục.
- Bỏ qua thêm `LICENSES.md` (cùng nhóm `.DS_Store`/`LICENSES.json`) — file attribution dạng đọc-được-cho-người, không phải asset runtime cần khai license cho chính nó.
- File mới `example/assets/LICENSES.json` (6 entry: 4 audio khớp `example/assets/audio/LICENSES.md` đã có sẵn từ trước — nguồn Google Actions Sound Library CC-BY-4.0 cho 3 file, MIT/derived cho `demo_sfx.mp3` — + 2 file JSON trong `assets/remote_config/`, MIT, "original configuration data").
- `.github/workflows/ci.yml`: mở rộng `paths-filter` của job `quality-gate` để bắt luôn thay đổi ở `asset/**`, `shaders/**`, `example/assets/**`, `example/pubspec.yaml` (trước đó chỉ bắt `lib/**`/`tool/**`/`pubspec.yaml`, nghĩa là đổi asset/manifest thuần tuý sẽ không kích hoạt gate — 1 lỗ hổng khác cùng họ với chính BUG-99, tiện sửa luôn). Thêm bước `Asset license manifest gate (example)` chạy `dart run tool/asset_license_check.dart --root=example --asset-roots=assets --manifest=assets/LICENSES.json` song song với bước gốc (đổi tên `(package)` cho rõ).

**Audit fork độc lập tìm 1 gap thật** (vòng 1, 8.5/10): `--asset-roots=assets,assets` (trùng lặp, ví dụ do CI config nối nhầm) không dedupe, double-count mọi asset path (báo "12 asset runtime" thay vì "6") — không gây false pass/fail ngay lúc đó vì `validateAssetLicenses` vẫn so khớp theo path, nhưng là gap robustness thật cho 1 CLI option dùng chung cho CI/consumer. Đã fix bằng `.toSet()` chèn ngay sau bước lọc rỗng, trước `.toList()`. Rescore vòng 2 từ CÙNG fork: **9.5/10** — "Gap fully resolved... fix is minimal and exactly targets the confirmed gap."

TDD: viết test đỏ trước cho từng case (fixture thiếu manifest entry, fixture hợp lệ, repo thật example/assets, dedupe), verify fail đúng lý do, rồi implement tới khi xanh.

Test coverage: unit/CLI (`test/tool/asset_license_check_test.dart`, nhóm `BUG-99: example/assets dùng --asset-roots=assets` — 4 case mới: fixture thiếu manifest entry → exit 1 báo đúng path, fixture hợp lệ → pass, **repo thật** `--root=example` quét đúng 6 asset runtime + "No asset license issues found", `--asset-roots=assets,assets` dedupe không double-count; cập nhật 1 test cũ để cùng verify bỏ qua `LICENSES.md`). Task này thuần tooling/CI (không đổi hành vi runtime app, không có UI) — không áp dụng widget/device test theo đúng tinh thần "khi task đổi hành vi quan sát được"; verify thay bằng chạy trực tiếp CLI thật (`dart run tool/asset_license_check.dart` + biến thể `--root=example`) trên máy dev, kết quả khớp kỳ vọng ("No asset license issues found" cho cả 2 root).

Kết quả: `flutter analyze` sạch root + `example/`. `flutter test --exclude-tags slow` sạch root (2495/2496 hoặc 2496/2496 tuỳ lần chạy — 1 flake tiền-tồn-tại ở `haptic_choreographer_test.dart` khi chạy chung cả suite, xác nhận qua chạy riêng file đó `25/25 pass`, không liên quan file BUG-99 chạm) + sạch `example/`. `dart run tool/api_compatibility.dart check` báo `unchanged` (thay đổi thuần `tool/`, không đụng public export `lib/roy_casual_kit.dart`). `dart pub publish --dry-run` không phát sinh warning/hint mới so với baseline (baseline "0 warnings, 1 hint" về version bump — hint này pre-existing, không liên quan).

Tự chấm ban đầu 9/10 (đã có đủ fix + test trước khi audit) → audit fork độc lập vòng 1 tìm 1 gap thật (dedupe `--asset-roots`) → fix → rescore vòng 2: **9.5/10**.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify `_assetRoots = ['asset', 'shaders']` dòng 21 (chỉ root), `example/pubspec.yaml` dòng 34-36 ship `assets/audio/` + `assets/remote_config/`, và `example/assets/audio` chứa `demo_sfx.mp3`, `error.ogg`, `tap.ogg`, `victory.ogg` + `LICENSES.md` (không phải `.json` manifest checker đọc được).
