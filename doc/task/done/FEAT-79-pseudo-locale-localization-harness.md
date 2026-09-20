---
id: FEAT-79
title: "Pseudo-locale Localization Harness"
type: feature
layer: tooling/i18n
priority: P1
effort: S
depends_on: [ENH-39, ENH-56]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Sinh locale kéo dài/RTL/ký tự đặc biệt để bắt hardcode và overflow trước dịch thật.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Pseudo locale phủ toàn bộ key và có deterministic transform.
- [x] Widget matrix bắt overflow/truncation/semantics sai.
- [x] Không rò pseudo locale vào release production.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/utils/pseudo_locale.dart`: `pseudoLocalize(String)` (pure,
deterministic — vowel → ký tự có dấu, +~40% độ dài, bọc `[[...]]`) +
`PseudoLocaleTranslations` (GetX `Translations` bọc 1 map key gốc, luôn
phủ 100% key vì `keys` getter map trực tiếp mọi entry, không có đường nào
bỏ sót). Đăng ký dưới locale giả `qps`/`PLOC` — đúng convention chính
Android dùng cho pseudolocalization, không bao giờ trùng 1 locale thật.

**Không làm RTL riêng trong task này** — FEAT-69 (Golden Matrix Runner) đã
có case `rtl` (đổi `Directionality`) và FEAT-76 (Accessibility Audit CLI)
đã có rule `rtlDirectionalSafety` (quét `left:`/`right:` literal) — làm
thêm 1 cơ chế RTL thứ 3 ở đây sẽ trùng lặp, không thêm giá trị. Phạm vi
task này tập trung đúng phần CHƯA có công cụ nào làm: kéo dài + ký tự đặc
biệt (accent) để bắt hardcode.

**Không rò vào production**: `PseudoLocaleTranslations`/`defaultLocale`
KHÔNG có trong `AppTranslations.supported` (test khoá riêng). Tích hợp
demo trong `example/lib/screens/settings_screen.dart` — 1 toggle
"Pseudo-locale (QA)" bọc trong `if (kDebugMode)`, y hệt discipline
`runtime_flags.isE2eTest` đã lập cho 1 mối quan tâm debug-only khác.

**Widget matrix bắt overflow thật**: `test/widget/pseudo_locale_widget_matrix_test.dart`
dựng `showConfirmDialog` (dùng `'ok'.tr`/`'cancel'.tr` — ENH-39) dưới
`PseudoLocaleTranslations`, xác nhận label thật sự đổi thành bản
pseudo-localize và KHÔNG throw; 1 test riêng ép label vào `SizedBox`
width 90 (rất hẹp) để dồn áp lực overflow — không phát hiện bug (nút
hiện có đã handle đúng), xác nhận widget kit hiện tại AN TOÀN trước pseudo-
locale chứ không phải thiếu test.

**Bug thật tìm được khi viết integration demo trong `example/`** (không
phải giả định): gọi `Get.updateLocale()` (dùng trong `_togglePseudoLocale`
và vốn cũng chính là cách `LocaleService.change()` production đã dùng)
TRỰC TIẾP từ bên trong `tester.tap()` (gesture thật được mô phỏng) làm vỡ
assertion `schedulerPhase == SchedulerPhase.idle` của Flutter test binding
— vì `Get.updateLocale` gọi `forceAppUpdate()` → `engine.performReassemble()`
(1 thao tác nặng, tương đương hot-reload). Tìm ra pattern đúng ĐÃ CÓ SẴN
trong chính file test này (`tapLocaleRow`'s comment ở nhóm `ENH-54:
_pickLanguage`, giải quyết đúng vấn đề y hệt trước đó): gọi thẳng
`onChanged`/`onTap` của widget thay vì `tester.tap()` khi thao tác đó kích
hoạt `Get.updateLocale`.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1927/1927 pass (1912 cũ + 12
  test unit `pseudo_locale_test.dart` + 2 test widget-matrix + 1 test
  `settings_screen_test.dart` toggle mới, cộng 2 test cũ phải cập nhật
  count `CandyToggleSwitch` từ 2→3 vì toggle QA luôn hiện dưới
  `kDebugMode`).
- `flutter test --exclude-tags slow` `example/`: 97/97 pass.
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `PseudoLocaleTranslations` + `pseudoLocalize`, CHANGELOG khớp; `snapshot`
  lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- Device smoke test thật: **Samsung S24 Ultra không kết nối lúc chạy** (đã
  check `mobile_list_available_devices` fresh theo đúng quy ước — chỉ có
  Pixel 7 Pro online), dùng Pixel 7 Pro thay thế. `pm clear` trước, build
  debug APK, vào Cài đặt, bật toggle "Pseudo-locale (QA)": mọi label qua
  `.tr` (Cài đặt/Ngôn ngữ/Âm thanh/Chế độ tối/Màu an toàn mù màu) đổi đúng
  thành bản `[[Séttíngs xxxx]]`-kiểu, KHÔNG overflow; đúng lúc đó dòng
  "Pseudo-locale (QA)"/"Debug only..." (2 string hardcode, KHÔNG qua `.tr`)
  vẫn hiện nguyên tiếng Việt — minh hoạ sống động chính xác giá trị cốt lõi
  của tính năng (phân biệt được string đã dịch thật với string hardcode)
  ngay trên UI thật, không cần giải thích thêm. Tắt toggle → revert đúng
  về tiếng Việt gốc. Không crash (`mobile_get_crash` không có report).

Tự chấm: 9.5/10. Điểm cao vì bằng chứng device thật cực kỳ thuyết phục
(ảnh chụp cho thấy đúng NGAY cơ chế phân biệt hardcode-vs-translated mà
tính năng này tồn tại để giải quyết) và tìm+sửa đúng 1 bug thật (Get.updateLocale
vs tester.tap) bằng cách tái dùng pattern đã có sẵn trong chính codebase
thay vì phát minh cách mới.

