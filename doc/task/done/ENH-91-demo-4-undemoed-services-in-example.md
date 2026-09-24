---
id: ENH-91
title: "Demo trong example/ cho 4 service chưa từng được gọi (BatterySaverCoordinator/EconomyCertificate/ReproductionCapsule/ShadowActivationController)"
type: enhancement
priority: P3
effort: M
source: "claude (fork audit round 2, độc lập)"
---

## Vị trí
- `lib/core/battery_saver_coordinator.dart` (`BatterySaverCoordinator`, IDEA-63)
- `lib/core/economy_certificate.dart` (`EconomyCertificate`, FEAT-91)
- `lib/core/reproduction_capsule.dart` (`ReproductionCapsule`, FEAT-89)
- `lib/core/shadow_activation_controller.dart` (`ShadowActivationController`)

## Hiện trạng
`grep -rn "<TênClass>" example/` cho cả 4 class trên đều trả về KHÔNG có
kết quả nào trong `example/lib/` lẫn `example/test/`. Cả 4 chỉ tồn tại qua
unit test mock trong `test/core/`, chưa từng được chứng minh hoạt động
trong 1 app thật — khác với hầu hết service khác trong kit (đều có ít nhất
1 tile/nút demo trong `CookbookScreen`/`WidgetShowcaseScreen`).

## Vì sao cần / Hậu quả
Người dùng kit đọc `example/` để học cách tích hợp sẽ không có nơi nào thấy
4 service này hoạt động cùng nhau với các service khác đã đăng ký sẵn
(`PerformanceTierService`, `EconomyWallet`, `PurchaseLedgerService`,
`TrustedClockService`, `ReplayRecorder`, `SeededRandomService`,
`RemoteKillSwitchController`) — đặc biệt `EconomyCertificate` và
`ReproductionCapsule` đều là những feature GHÉP nhiều service lại, chỉ demo
thật mới chứng minh việc ghép nối đó không có lỗi tích hợp.

## Đề xuất
Thêm 4 tile mới vào `example/lib/screens/cookbook_screen.dart` (đúng
convention "1 tile, 1 nút, 1 toast" file này đã dùng cho hàng chục service
khác):
- `BatterySaverCoordinator`: 1 tile giả lập % pin thấp, gọi `check(...)`,
  hiện `PerformanceTierService` có bị ép xuống `low` không.
- `EconomyCertificate`: 1 tile "issue certificate" + 1 tile "verify", hiện
  đúng `EconomyCertificateStatus`.
- `ReproductionCapsule`: 1 tile "capture" rồi 1 tile "replay", hiện đúng
  `ReproductionReplayResult.matches`.
- `ShadowActivationController`: 1 tile đăng ký 1 guardrail, 1 tile giả lập
  giá trị vi phạm, hiện có bị kill switch kích hoạt không.

## Acceptance criteria
- [x] Cả 4 tile gọi đúng API thật (không mock), không throw ở trạng thái
      bình thường.
- [x] Mỗi tile hiện kết quả có ý nghĩa (không chỉ "đã chạy", phải hiện
      đúng giá trị trả về/trạng thái thay đổi).
- [x] Test widget cho cả 4 tile trong `example/test/cookbook_screen_test.dart`
      (đúng convention file test hiện có) — thực tế đặt trong
      `example/test/cookbook_screen_more_test.dart` (đúng file phù hợp hơn,
      xem Quyết định bên dưới).
- [x] Không phá bất kỳ tile/demo nào có sẵn trong `cookbook_screen.dart`.

## Quyết định

**Implementation**: thêm 1 section mới `'Live-ops guardrails & anti-cheat'`
vào `example/lib/screens/cookbook_screen.dart`, ngay sau section
`'App/session infrastructure'` (trước section `'i18n, audio, haptics,
theme'`), gồm đúng 4 tile:
- **BatterySaverCoordinator**: dùng biến `batteryLevel` mutable trong
  closure để demo CẢ 2 chiều (force low ở 10%, rồi release khi phục hồi
  80%) qua 1 instance duy nhất — chứng minh đúng cả `check()`'s 2 nhánh
  tài liệu đã mô tả, không chỉ nhánh force.
- **EconomyCertificate**: tái dùng `EconomyWallet` đã đăng ký (cùng pattern
  `.maybe ?? Get.put` các tile khác dùng), `earn()` 50 coins thật, `issue()`
  + `verify()` round-trip, hiện đúng `status`/`balances`.
- **ReproductionCapsule**: copy chính xác pattern worked-example từ
  `test/core/reproduction_capsule_test.dart` (`ReplayRecorder` + real RNG
  draws qua `SeededRandomService.stream(...)`, `expectedOutcome` convention)
  — `capture()` 3 event thật rồi `replay()` với handler tái tạo đúng cùng
  draw, verify `result.matches`.
- **ShadowActivationController**: tái dùng `_killSwitch` đã đăng ký sẵn
  trong `initState`, đăng ký 1 guardrail `error_rate <= 0.05`, report
  0.5 (vi phạm) → verify `_killSwitch.isKilled(...)` chuyển `false ->
  true`.

**Vị trí file test**: task đề xuất `cookbook_screen_test.dart`, nhưng đọc
kỹ thấy file này đã bị TÁCH làm 3 (`cookbook_screen_test.dart`/
`cookbook_screen_more_test.dart`/`cookbook_screen_remote_config_test.dart`)
từ trước — comment đầu file giải thích: chạy hết ~24 test tương tác tile
trong 1 file để lại 1 `AnimationController`/`Ticker` của `ToastBanner` bị
leak ở test cuối. 4 tile mới của task này thuộc đúng nhóm "service
infrastructure" mà `RoyLifecycleCoordinator`/`AssetPreloadCoordinator` (2
tile liền kề trong `cookbook_screen.dart`) đã có sẵn test trong
`cookbook_screen_more_test.dart` — thêm vào ĐÚNG file đó thay vì file gốc
task đề xuất, để giữ đúng convention nhóm-theo-vị-trí-tile đã thiết lập.

**TDD**: viết 4 test trước → `git stash` riêng file lib (không stash file
test) → chạy cả file `cookbook_screen_more_test.dart`: 4 test mới FAIL
đúng lý do (tile không tồn tại, `scrollUntilVisible` không tìm thấy) →
khôi phục, chạy lại — 18/18 pass (14 test cũ + 4 mới).

**Kết quả**:
- `flutter analyze` (`example/`): sạch.
- `flutter test --exclude-tags slow` (`example/`): 153/153 pass, 0
  regression.
- Không đụng `lib/` root nên không cần chạy root analyze/test/
  api_compatibility (xác nhận qua `git status --short` chỉ có 2 file
  `example/` thay đổi).
- Không cần smoke test device (task cho phép bỏ qua — widget test đã tap
  qua UI thật, gọi API thật, đủ chứng minh).

**Tự chấm điểm: 9.5/10.** Cả 4 tile đều dùng API THẬT (không mock nào),
`ReproductionCapsule`'s test copy đúng pattern worked-example đã có sẵn
trong `test/core/` thay vì tự nghĩ ra cách khác. Trừ 0.5 vì đặt test vào
file khác với đường dẫn task đề xuất ban đầu (dù có lý do chính đáng,
task gốc nên tự audit lại cấu trúc file test hiện tại trước khi đề xuất
đường dẫn cụ thể).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-91-demo-4-undemoed-services-in-example.md`
này trước khi làm. Đọc TOÀN BỘ cả 4 file lib liệt kê ở trên (đặc biệt kỹ
`EconomyCertificate`/`ReproductionCapsule` vì chúng ghép nhiều dependency
qua constructor) VÀ đọc kỹ `example/lib/screens/cookbook_screen.dart` bản
MỚI NHẤT (`initState()` để biết những service nào đã đăng ký sẵn có thể tái
dùng thay vì tạo mới) trước khi thêm demo. Việc này khá lớn (4 service khác
nhau) — có thể chia làm 4 commit riêng hoặc gộp nếu thấy hợp lý, tự quyết
định dựa trên độ phức tạp thực tế của từng service sau khi đọc code.
Implement bằng TDD cho phần test — viết test trước cho từng tile, xác nhận
fail (tile/text chưa tồn tại), rồi mới thêm code.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở
   `example/` (không đụng `lib/` root nên không cần chạy root, TRỪ KHI cần
   đọc thêm API — verify lại sau khi đọc code thật).
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit đã liệt kê ~85 class public, grep từng cái trong
`example/lib/`, xác nhận đúng 4 class này có 0 hit (dán kết quả grep vào
báo cáo). Đã loại trừ đúng những trường hợp KHÔNG phải gap thật (ví dụ
`AssetLicenseManifest`/`DeprecationRegistry` đã cố ý không demo theo đúng
comment có sẵn trong `cookbook_screen.dart`). Không trùng task nào trong
`doc/task/done/`.
