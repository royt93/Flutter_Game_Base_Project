---
id: FEAT-231
title: "PodiumWidget: bục top-3 bảng xếp hạng có avatar, tên, điểm, hiệu ứng lên bục"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm (bằng đọc code)

`LeaderboardList` + `LeaderboardEntry(rank, name, score, avatar, highlighted, onTap)` là danh sách PHẲNG; `TieredLeaderboardRow` là một hàng có tier/zone; `CommunityLeaderboardCard` là thẻ cộng đồng. Không widget nào là bục vinh danh. Task này tái dùng `LeaderboardEntry` làm kiểu dữ liệu để không nhân đôi mô hình.

## Phạm vi đề xuất

- `PodiumWidget(entries)` lấy 3 mục đầu theo `rank` (ba bục cao khác nhau: 2-1-3), avatar, tên, điểm; hiệu ứng lên bục tôn trọng reduced motion.
- Trường hợp biên phải chốt và có test: 0, 1, 2 mục (bục trống hiển thị trạng thái rỗng, không ném), điểm bằng nhau (giữ thứ tự `rank` đầu vào, không tự xếp lại), tên rất dài (cắt, không tràn), `entries` > 3 (chỉ lấy 3).
- Semantics: đọc "hạng 1: <tên>, <điểm>" theo thứ tự hạng (không theo thứ tự trái-phải trực quan 2-1-3).
- RTL: thứ tự 2-1-3 đối xứng nên không đổi, nhưng kiểm lại.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `PodiumWidget` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `PodiumWidget` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Tái dùng `LeaderboardEntry` (không tạo kiểu mới). Test 0/1/2/3/>3 mục, điểm bằng nhau giữ thứ tự `rank` đầu vào, tên rất dài bị cắt.
- [ ] 4. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 5. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 6. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 7. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 8. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 9. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 10. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] 0-2 mục hiển thị bục trống, không ném.
- [ ] Semantics đọc theo thứ tự hạng, không theo thứ tự trái-phải 2-1-3.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
