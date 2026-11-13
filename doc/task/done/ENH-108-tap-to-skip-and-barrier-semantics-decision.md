---
id: ENH-108
title: "Chạm-để-bỏ-qua và barrier: quyết định có cần Semantics và thao tác dismiss"
type: enhancement
layer: lib/widgets
priority: P3
effort: S
source: "ENH-107 / FEAT-202: 6 vị trí không phải nút nhưng có GestureDetector"
---

## Phạm vi
- Chạm-để-bỏ-qua animation trên nội dung: `currency_counter.dart:204`, `offline_earnings_popup.dart:244`, `reward_sequence_coordinator.dart:277`.
- Barrier chạm-ra-ngoài-để-đóng: `spotlight_overlay.dart:115`, `neon_dialog.dart:179` và `:238`.

## Quyết định (2026-11-13, người dùng)
Chạm-để-bỏ-qua animation chỉ là cử chỉ phụ trang trí, KHÔNG cần Semantics; barrier dùng cử chỉ back của hệ điều hành. Việc còn lại: gỡ 6 mục khỏi `tool/accessibility_audit_baseline.json` bằng cách giữ chúng trong baseline với lý do mới ghi rõ quyết định này (không sửa mã). Chấp nhận hệ quả: người dùng switch-access không bỏ qua được animation đếm số; animation phải tự kết thúc trong thời gian ngắn và tôn trọng `reducedMotion`.

## (giữ nguyên) Câu hỏi ban đầu
1. Người dùng screen reader có cần thao tác "bỏ qua animation" không? Nếu animation chỉ trang trí và kết quả vẫn đọc được thì không cần.
2. Barrier có nên có thao tác dismiss cho screen reader (Android TalkBack có cử chỉ back nên có thể thừa) hay không.

## Hướng sửa nếu cần
`Semantics(onTap: ..., label: ...)` với nhãn qua `AppTranslations`, test kiểm có action `tap`. Giữ nguyên layout, không thêm vùng chạm vì đây không phải nút.

## Tiêu chí xong
Mỗi vị trí hoặc có Semantics hợp lý hoặc ghi lý do không cần, gỡ khỏi baseline `tapTargetSite`.

## Kết quả (2026-11-13)
Không đổi mã. 5 mục baseline `tapTargetSite` (currency_counter, offline_earnings_popup, reward_sequence_coordinator, spotlight_overlay, neon_dialog) giữ lại với lý do ghi đúng quyết định thiết kế. Audit vẫn xanh.
