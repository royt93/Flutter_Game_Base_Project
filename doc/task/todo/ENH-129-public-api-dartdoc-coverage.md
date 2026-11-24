---
id: ENH-129
title: "Dartdoc cho 32 kiểu công khai còn thiếu; bật lint public_member_api_docs dần theo thư mục (không bật toàn cục)"
type: enhancement
layer: lib
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-24 (dev-experience SDK), owner chọn đưa vào backlog"
---

## Số đo (2026-11-24)

- 305 kiểu công khai được export từ `lib/roy_casual_kit.dart` (class/enum/mixin/typedef/extension); **32 chưa có dòng `///`** ngay trên khai báo (đếm bằng script đọc các file export).
- Bật thử `public_member_api_docs: true` trong `analysis_options.yaml`: **3005 cảnh báo** trên `lib` (gồm thành viên, không chỉ kiểu). Đã khôi phục file cấu hình sau khi đo (`git status` sạch). Vì vậy KHÔNG bật toàn cục; chỉ làm được theo từng thư mục/file.
- 32 kiểu thiếu doc (theo file): `asset_preload_coordinator` (AssetLoaderFn, AssetUnloaderFn), `economy_wallet` (EconomyWallet), `juicy_feedback` (JuicyPreset), `lifecycle_coordinator` (RoyLifecycleState, RoyLifecycleEvent, RoyLifecycleHook, RoyLifecycleHookFailure), `match3_engine` (Match3Status, Match3Swap, Match3Level, Match3CascadeStep, Match3Engine), `persistent_cooldown_service` (CooldownStatus), `asset_license_manifest` (AssetLicenseIssueKind, AssetLicenseIssue), `deprecation_registry` (DeprecationStatus, DeprecationCheckResult), `remote_schema_compiler` (RemoteSchemaFieldType, RemoteSchemaCompilerException), `retry_policy` (RetryAttemptEvent), `save_migration_registry` (SaveMigrationStep, SaveMigrationException), `sdk_result` (SdkErrorKind, SdkResult, SdkSuccess, SdkFailure), `roy_game` (PlayerAttackedEvent), `neon_dialog` (NeonDialog), `spring_scale_transition` (SpringMotionPreset, SpringSimulationController, SpringScaleTransition).

## Phạm vi

1. Viết dartdoc cho 32 kiểu (1-3 câu: làm gì, khi nào dùng, ràng buộc chính); ưu tiên kiểu hay dùng: `SdkResult`/`SdkSuccess`/`SdkFailure`/`SdkErrorKind`, `EconomyWallet`, `NeonDialog`, `Match3Engine`.
2. Bật lint theo file bằng `// ignore_for_file` ngược: thay vì bật toàn cục, thêm test đếm (như `tool/deprecation_check.dart`) kiểm "kiểu công khai mới phải có dartdoc" để không tăng số thiếu; hoặc bật `public_member_api_docs` cho một thư mục nhỏ đã sạch bằng `analysis_options.yaml` lồng nhau (kiểm khả năng này của analyzer trước).
3. Không đổi hành vi; chỉ comment.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chạy lại script đếm, xác nhận 32 kiểu (số có thể đã đổi); lưu danh sách vào "Kết quả thực hiện".
- [ ] 2. Viết dartdoc cho nhóm 1 (`sdk_result`, `economy_wallet`, `neon_dialog`, `match3_engine`); đọc code từng kiểu để mô tả ĐÚNG hành vi, không đoán.
- [ ] 3. Viết dartdoc cho các kiểu còn lại.
- [ ] 4. Chọn cơ chế chặn thiếu mới: (a) test/tool đếm kiểu công khai thiếu doc và so với ngưỡng đã lưu (không tăng), hoặc (b) lint theo thư mục. Đo rồi chọn; ghi lý do.
- [ ] 5. Cổng cuối: `flutter analyze`, `dart run tool/api_compatibility.dart check`. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] 0 kiểu công khai được export còn thiếu dartdoc (cùng script đo ban đầu).
- [ ] Có cơ chế tự động ngăn kiểu công khai mới thiếu doc.
- [ ] Không thay đổi mã nguồn ngoài comment (kiểm `git diff -w` chỉ có dòng `///`).
- [ ] `dart doc` (nếu chạy được) không thêm cảnh báo.

## Lệnh kiểm chứng nhanh

- `flutter analyze`
- `dart doc --dry-run` (kiểm tồn tại lệnh trước khi ghi vào kết quả)
