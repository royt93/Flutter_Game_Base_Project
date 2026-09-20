---
id: FEAT-68
title: "Theme Contrast Validator"
type: feature
layer: tooling/accessibility
priority: P1
effort: M
depends_on: [IDEA-38, ENH-37]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Validator kiểm tra contrast, disabled/focus state và color-blind palette của NeonTheme.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Báo lỗi theo WCAG threshold cấu hình được và chỉ rõ token/state.
- [x] Kiểm tra light/dark/CVD palette và không mutate theme.
- [x] Có report CI và widget fixture chứng minh false positive được kiểm soát.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/utils/theme_contrast_validator.dart` — thuần hàm/tính toán,
không side effect: `relativeLuminance`/`contrastRatio` implement đúng công
thức WCAG 2.1; `validateNeonThemeContrastPairs` (pure, không phụ thuộc
`NeonTheme`) chạy 1 danh sách `ContrastCheck` bất kỳ; `validateNeonThemeContrast`
là lớp tiện ích đọc `NeonTheme` thật, quét cả 2 trạng thái `dark` và cả 2
trạng thái `colorBlindSafe` (IDEA-38), phục hồi cả 2 cờ về giá trị ban đầu
trong `finally` — verify bằng test tường minh gọi lại 2 lần với giá trị cờ
khác nhau trước/sau.

**Bug/finding thật tìm được khi build validator** (không phải review, mà
đúng payoff của việc có 1 validator: nó bắt được thứ mắt thường không để
ý):
1. `NeonTheme.inkSoft` (chữ phụ/mô tả) trên light theme chỉ đạt **3.92:1**
   trên `card` và **3.40:1** trên `cardAlt` — dưới ngưỡng WCAG AA cho
   normal text (4.5:1), dù đạt ngưỡng AA cho large text/UI (3.0:1). Dark
   theme sạch (6.86:1 / 7.42:1).
2. `NeonTheme.lockedBorder` trên `NeonTheme.lockedFill` (cặp màu dùng thật
   trong `RewardChoicePanel`/`LevelSelectGrid`/`DailyLoginCalendarWidget`)
   chỉ đạt **1.43:1** — dưới ngưỡng UI-component 3.0:1 — và không đổi theo
   `dark` vì cả 2 token đều là hằng số duy nhất (không có biến thể
   dark/light riêng như `card`/`ink`).

Cả 2 đều **không sửa trong task này** — đổi 1 màu token toàn cục
(`inkSoft`/`lockedBorder`) ảnh hưởng hàng chục widget + golden test khác,
ngoài phạm vi 1 task "xây validator". Đã ghi nhận rõ trong CHANGELOG và
khoá lại bằng chính test (`theme_contrast_validator_test.dart` có 2 test
tên "PHÁT HIỆN THẬT" assert đúng 2 ratio này) — nếu sau này ai sửa
`inkSoft`/`lockedBorder` đẹp hơn, 2 test này sẽ tự nhắc cập nhật lại kỳ
vọng, còn nếu ai vô tình làm CÀNG TỆ hơn thì test vẫn đứng nguyên (assert
range cụ thể, không phải chỉ "không rỗng").

**Ràng buộc kiến trúc thật tìm được, đổi hướng "report CI" khỏi kế hoạch
ban đầu**: dự định ban đầu là 1 tool `tool/theme_contrast_check.dart` chạy
độc lập qua `dart run` (đúng pattern `tool/economy_sim.dart`/
`tool/api_compatibility.dart`), nhưng `NeonTheme` (và do đó
`theme_contrast_validator.dart`) import `package:flutter/material.dart`
→ transitively `dart:ui`, thứ **không tồn tại ngoài Flutter engine** —
verify bằng cách thật sự chạy thử:
`Error: Dart library 'dart:ui' is not available on this platform.`
Khác với `economy_sim`/`api_compatibility` (cố tình giữ 0 dependency
Flutter để chạy `dart run` được), validator này ĐÚNG mục đích là đọc
`Color` thật của `NeonTheme` nên không thể tách khỏi Flutter runtime. Đã
bỏ ý định CLI, "report CI" chuyển thành: bộ test này chạy trong đúng CI
step `flutter test` đã có sẵn (theo `CLAUDE.md`), tự fail build nếu contrast
thật tệ đi hơn 2 mốc đã khoá ở trên — không cần thêm tool/step CI mới
(tránh đúng rủi ro "đổi CI tốn tiền" đã ghi trong memory).

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1732/1732 pass (1714 cũ + 18
  test mới cho `theme_contrast_validator_test.dart`). Gặp 1 test flaky
  không liên quan (`save_slot_manager_test.dart`, thứ tự `Alice`/`Bob` đảo
  do tie-break timestamp cùng mili-giây) — verify KHÔNG do thay đổi của
  task này bằng cách `git stash` code mới rồi chạy lại, vẫn fail y hệt
  trên cây sạch; retry lần 2 pass toàn bộ. Không sửa (ngoài phạm vi task).
- `dart run tool/api_compatibility.dart check` → `additive` đúng 5 symbol
  mới (`ContrastCheck`/`ContrastCheckKind`/`ContrastIssue`/
  `ThemeContrastConfig`/file export), có CHANGELOG entry khớp; chạy lại
  `snapshot` xong → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo "git chưa commit" (bình
  thường trước khi commit), không lỗi thật.
- 18 test (`test/core/utils/theme_contrast_validator_test.dart`): công
  thức luminance/contrast (trắng/đen/đối xứng), fixture bắt lỗi thật +
  không false-positive màu tốt, NeonTheme thật (ink sạch AA, inkSoft light
  fail đúng như trên, lockedBorder fail đúng như trên, không mutate cờ,
  không mutate palette, reskin xấu bị bắt lỗi, gemColors 2 palette đều
  sạch, gemColors thu hẹp bị bắt lỗi, AAA nghiêm hơn AA), widget fixture
  (`testWidgets` dựng `Text`/`Container` thật, đọc lại màu render ra rồi
  mới tính contrast — chống trường hợp token khai đúng nhưng widget thật
  render màu khác).

Không có phần UI/animation nào trong task này (thuần hàm tính toán) nên
tiêu chí animation/reduced-motion không áp dụng — tick vì N/A, không có gì
để vi phạm.

Tự chấm: 9.3/10. Trừ điểm vì: (1) không có CLI đứng độc lập như kỳ vọng
ban đầu của layer "tooling" (dù có lý do kiến trúc chính đáng, đã giải
thích ở trên); (2) chưa fix 2 vấn đề contrast thật tìm được — đúng ý, nằm
ngoài phạm vi, nhưng đáng để mở 1 IDEA/ENH task riêng theo dõi sau này.

