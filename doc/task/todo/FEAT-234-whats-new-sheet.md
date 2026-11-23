---
id: FEAT-234
title: "WhatsNewSheet: bảng 'có gì mới' hiện một lần cho mỗi phiên bản, lưu 'đã xem' qua OnboardingCoordinatorService"
type: feature
layer: lib/presentation/widgets/common
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm (bằng đọc code)

- `app_version_gate.dart` có `compareAppVersions(String a, String b) -> int?` (semver, `null` khi không so được) và `AppVersionGateOverlay` bắt buộc cập nhật; không có thông báo tính năng mới (grep "whats_new/release_notes" không ra gì).
- `OnboardingCoordinatorService` đã theo dõi "đã xem" bằng số nguyên: `registerFlow(flowId, {priority, version})`, `isFlowSeen(flowId, {version=1})` (true khi đã lưu `>= version`), `markFlowSeen(flowId, {version})` (ném `ArgumentError` khi `version <= 0`).
- `kAppVersion` mặc định là chuỗi NGÀY (`'2026.06.15'`), không phải semver; app thật nạp từ `pubspec.yaml` qua `package_info_plus`.

## Ràng buộc thiết kế rút ra từ đó

Coordinator chỉ hiểu số nguyên `version`, còn phiên bản app là chuỗi. Nên widget KHÔNG tự so chuỗi: app truyền `releaseNumber` (int tăng dần cho mỗi bản có nội dung mới) và widget dùng `isFlowSeen('whats_new', version: releaseNumber)`. Nhảy nhiều bản (đã bỏ qua 3 bản): chỉ hiện bản mới nhất `releaseNumber`, `markFlowSeen` đánh dấu một lần là đủ (vì `isFlowSeen` dùng `>=`).

## Phạm vi đề xuất

- `WhatsNewSheet.showIfUnseen(context, flowId, releaseNumber, items)` mở `showCommonBottomSheet` với danh sách `WhatsNewItem(icon, title, description)`, tự `markFlowSeen` khi đóng; không hiện nếu đã xem; `items` rỗng không hiện (không ném).
- Nội dung do app cấp (kit không giữ văn bản); `releaseNumber <= 0` hoặc `flowId` rỗng là `ArgumentError`.
- Không dùng `compareAppVersions` trong widget (tránh hai nguồn sự thật); có thể ghi trong tài liệu cách app suy ra `releaseNumber` từ semver nếu muốn.

## Câu hỏi mở

App muốn hiện lại thủ công từ màn Cài đặt ("Xem có gì mới"): cung cấp `WhatsNewSheet.show` không kiểm tra đã xem. Đề xuất: có, vì rẻ.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape @1x text; 568x320 @2x text).
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: semantics đúng, vùng chạm >= 44-48dp, RTL, `tool/accessibility_audit_check.dart` pass.
- Invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `WhatsNewSheet` (3-5 dòng) trong "Kết quả thực hiện" trước khi code.
- [ ] 2. Viết `WhatsNewSheet` + export trong `common_widgets.dart` + `ArgumentError` cho invariant.
- [ ] 3. Test với `OnboardingCoordinatorService` thật (`StorageService` bộ nhớ trong): hiện lần đầu, không hiện lần hai, hiện lại khi `releaseNumber` tăng, nhảy nhiều bản chỉ hiện một lần.
- [ ] 4. Test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0; mutation check (bỏ logic chính, test đỏ).
- [ ] 5. Fixture `runViewportSweep`; thêm vào `widget_showcase_screen.dart`; `cd example && flutter test` pass.
- [ ] 6. Accessibility: semantics, vùng chạm, `dart run tool/accessibility_audit_check.dart`.
- [ ] 7. Commit + push widget và test (chưa golden); `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, CHỈ chép PNG của widget này vào `test/widget/goldens/goldens/`, commit + push.
- [ ] 8. API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 9. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/` (kiểm staged diff trước commit).

## Tiêu chí nghiệm thu

- [ ] Hiện đúng một lần cho mỗi `releaseNumber`; tăng số thì hiện lại.
- [ ] Đóng bằng nút hoặc vuốt xuống đều đánh dấu đã xem.
- [ ] `items` rỗng không hiện và không ném.
- [ ] Có lối `show` thủ công không kiểm tra đã xem.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common test/core/onboarding_coordinator_service_test.dart`
