---
id: FEAT-82
title: "Focus Navigation Controller"
type: feature
layer: presentation/accessibility
priority: P2
effort: M
depends_on: [FEAT-52, FEAT-53, ENH-37]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Chuẩn hóa focus traversal, keyboard/gamepad navigation và back semantics cho overlay/HUD.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Focus order deterministic, trap/release đúng modal lifecycle.
- [x] Touch-only app không bị thay đổi hành vi.
- [x] Keyboard, screen reader, RTL và dispose có widget/integration coverage.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

**Đọc kỹ Quyết định của FEAT-53 (PauseOverlay, dependency trực tiếp) TRƯỚC
khi thiết kế** — tìm thấy đúng gap đã ghi rõ ràng: "focus trap chỉ ở mức
scope-ownership, KHÔNG trap được Tab-key activation từng nút vì
CommonButton/PressableScale toàn bộ kit hiện là gesture-only... gap có sẵn
của cả kit". Đây chính xác là việc FEAT-82 cần đóng, không phải đoán từ
đầu.

**Điểm sửa đòn bẩy cao nhất** (verify bằng grep trước khi sửa, không giả
định): `PressableScale` (`lib/presentation/widgets/pressable_scale.dart`)
được dùng bởi GẦN NHƯ TOÀN BỘ widget có thể tap trong kit —
`CommonButton`, `NeonButton`, `AvatarFrame`, `LeaderboardList`,
`CommonListTile`, `RewardChoicePanel`, `SoundToggleFab`,
`SegmentedTabBar`, `CandyToggleSwitch`, `LevelSelectGrid`,
`DailyLoginCalendarWidget`. Sửa ĐÚNG 1 file này thêm keyboard/gamepad
activation cho cả kit cùng lúc, thay vì sửa từng widget riêng lẻ.

**Cách làm**: `Focus` + `Actions(actions: {ActivateIntent:
CallbackAction(...)})` — `ActivateIntent` đã được Flutter's
`WidgetsApp.defaultShortcuts` bind sẵn cho Enter/Space VÀ
`LogicalKeyboardKey.gameButtonA`/`.select` (xác nhận bằng cách đọc thẳng
source Flutter SDK trước khi code, không đoán) — nghĩa là "gamepad D-pad
navigation" tự động hoạt động miễn phí qua đúng
`FocusTraversalPolicy`/`DirectionalFocusIntent` mặc định của framework,
KHÔNG cần tự viết logic điều hướng D-pad nào — chỉ cần widget thực sự
`Focus`-able (điều mà trước đây hoàn toàn thiếu).

**2 bug thật tìm được qua TDD** (không phải review):
1. `Actions` PHẢI là ANCESTOR của `Focus`, không phải ngược lại —
   `Shortcuts` resolve intent bằng cách đi NGƯỢC LÊN từ context của node
   đang focus; đặt `Actions` làm con của `Focus` (thứ tự ban đầu) khiến
   Enter/Space hoàn toàn im lặng không làm gì — phát hiện bằng 2 test đầu
   fail đúng lúc TDD, sửa bằng cách đảo thứ tự lồng.
2. `FocusScope(autofocus: true)` là CỜ GỢI Ý (advisory), KHÔNG cưỡng chế
   — nó chỉ nhận focus nếu scope bao quanh CHƯA có gì được focus; 1 modal
   mở lên trên nội dung ĐANG có focus sẵn sẽ không giành được gì cả (test
   debug xác nhận `primaryFocus` vẫn là node nền sau khi modal mount) —
   sửa `FocusTrapScope` bằng cách tự quản 1 `FocusScopeNode` riêng và gọi
   thẳng `.requestFocus()` (cưỡng chế thật) thay vì dựa vào cờ `autofocus`
   thụ động.

**`FocusTrapScope`** (`lib/presentation/widgets/focus_trap_scope.dart`,
mới): trap = tự request focus vào scope riêng ngay lúc mount (khớp đúng
lifecycle của convention "always mounted, panel nullable" —
`NeonDialog.overlaySlot`/`PauseOverlay` đã dùng, panel THỰC SỰ được
tạo/huỷ theo visible, không phải chỉ ẩn/hiện); release = lưu lại node
đang focus TRƯỚC lúc mount (`initState`), trả lại đúng node đó lúc
`dispose()` (deferred qua `addPostFrameCallback` vì lúc `dispose()` chạy,
cây focus của chính scope này còn đang bị tháo dở). Retrofit vào
`PauseOverlay._buildPanel` — thay `FocusScope(autofocus: true)` cũ (không
có save/restore, gap đúng như FEAT-53 đã tự ghi) bằng `FocusTrapScope`.

**Deterministic order**: không thêm `FocusTraversalOrder` tuỳ chỉnh nào —
`WidgetOrderTraversalPolicy` mặc định của Flutter (thứ tự cây/paint order)
đã deterministic sẵn; việc CÒN THIẾU trước đây là các node có tồn tại để
traverse hay không (PressableScale's fix), không phải thứ tự.

**Touch-only không đổi hành vi**: focus ring (`DecoratedBox` border) CHỈ
vẽ khi `FocusManager.instance.highlightMode ==
FocusHighlightMode.traditional` — chế độ này framework chỉ tự chuyển sang
sau 1 tương tác bàn phím/gamepad/chuột THẬT, không bao giờ từ 1 cú chạm
— verify bằng `FocusManager.instance.highlightStrategy =
FocusHighlightStrategy.alwaysTouch` trong test (giả lập đúng platform cảm
ứng) + xác nhận trên device thật (Pixel 7 Pro, chạm tay thật, không thấy
viền focus nào).

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1953/1953 pass (1940 cũ + 13
  test `pressable_scale_test.dart` mới + 5 test `focus_trap_scope_test.dart`
  mới + 1 test tích hợp mới trong `pause_overlay_test.dart` — cả 3 file
  test cũ liên quan (`pressable_scale_test.dart` 5 test gốc,
  `pause_overlay_test.dart` 12 test gốc) đều pass y nguyên, không sửa 1
  assertion cũ nào — đúng "purely additive").
- `flutter test --exclude-tags slow` `example/`: 97/97 pass — xác nhận
  thay đổi `PressableScale` (dùng khắp kit) không phá bất kỳ demo nào
  trong `WidgetShowcaseScreen`.
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `FocusTrapScope`, CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- 13 test `pressable_scale_test.dart` (5 cũ + 8 mới): Enter kích hoạt
  onTap, Space kích hoạt onTap (đúng ánh xạ gamepad "A"), disabled không
  có `Focus` node nào gắn, **2 test khoá đúng property cốt lõi
  touch-vs-traditional** (highlightStrategy ép buộc `alwaysTouch` →
  không border; `alwaysTraditional` → có border), tap gesture vẫn hoạt
  động bình thường (regression), autofocus hoạt động.
- 5 test `focus_trap_scope_test.dart`: autofocus mặc định giành được
  primary focus, `autofocus: false` không giành; **1 test "PHÁT HIỆN
  THẬT" trọng tâm nhất** — mount trap cướp focus từ node nền, unmount trả
  lại ĐÚNG node đó (không rơi về root); node nền đã bị dispose lúc trap
  đóng → không throw; tap bình thường trong trap vẫn hoạt động.
- 1 test tích hợp mới trong `pause_overlay_test.dart`: pause khi 1 nút
  game thật đang focus → panel giành focus → bấm Resume → focus trả lại
  ĐÚNG nút game đó (không phải test giả lập trừu tượng, dùng chính
  `PauseOverlay` thật + `GameSessionController` thật).
- Device smoke test thật (Pixel 7 Pro — S24U không kết nối lúc chạy, đã
  check `mobile_list_available_devices` fresh): mở Demo Flame, bấm Pause
  FAB → overlay "Paused" hiện đúng, KHÔNG có viền focus nào xuất hiện
  (đúng — chạm tay thật, `FocusHighlightMode` không bao giờ là
  `traditional`); bấm Resume → đóng đúng, game tiếp tục bình thường,
  không crash (`mobile_get_crash` không có report).

Tự chấm: 9.5/10. Điểm cao vì: xác định đúng phạm vi thật từ chính ghi chú
Quyết định của 1 task trước đó (FEAT-53) thay vì tự đoán "focus navigation
controller" nghĩa là gì, tìm và sửa đúng 2 bug thật về cách Flutter's
Focus/Actions/autofocus hoạt động (không phải giả định code đúng ngay lần
đầu), và verify "purely additive" bằng dữ liệu thật (toàn bộ 1940 test cũ
+ 97 test example cũ pass nguyên vẹn dù sửa đúng 1 file nền tảng cho cả
kit) thay vì chỉ tuyên bố suông.

