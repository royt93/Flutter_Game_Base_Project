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
