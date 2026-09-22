---
id: BUG-61
title: "widget_showcase_screen.dart: 4 chỗ thiếu mounted-guard sau await + DeepLinkCommandRouter thiếu unregisterHandler gây leak handler permanent"
type: bug
priority: P0
effort: S
source: "agy + Fork nội bộ (audit example/lib + test coverage) — độc lập xác nhận cùng vùng file, gộp thành 1 task; verify lại qua Read trực tiếp"
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart` — `_inventoryGrant` (~dòng 642-653), `_inventoryConsume` (~dòng 654-667), 2 chỗ gọi `_deepLinks.handleUri(uri)` trong demo deep-link (~dòng 1434-1465), và `initState()` nơi `_deepLinks.registerHandler('level', (command) => setState(...))` đăng ký handler `permanent: true` không có cách huỷ đăng ký tương ứng trong `dispose()`.

## Hiện trạng
1. 4 chỗ trong file gọi `setState(...)` ngay sau 1 `await` mà KHÔNG có `if (!mounted) return;` guard đứng trước — mọi async handler KHÁC trong cùng file (dòng 94, 259, 327, 668, 1529, 2484, 2568...) đều có guard này, đây là 4 chỗ hiếm hoi bị bỏ sót (đã xác nhận qua Fork nội bộ đọc trực tiếp so sánh pattern).
2. `DeepLinkCommandRouter` không có API `unregisterHandler` — handler đăng ký từ `initState()` của 1 State cụ thể tồn tại vĩnh viễn trong router kể cả sau khi State đó `dispose()`, giữ tham chiếu tới State đã unmounted.

## Vì sao cần / Hậu quả
(1) nếu người dùng rời màn hình đúng lúc 1 trong 4 await đang chạy, `setState()` trên State đã unmount ném exception "setState() called after dispose()". Rủi ro thực tế thấp (cần rời màn hình đúng thời điểm hẹp) nhưng là bug thật, dễ fix, nhất quán với phần còn lại của file. (2) mỗi lần `WidgetShowcaseScreen` được mở rồi đóng lại (ví dụ do navigate qua lại giữa các tab demo) tích luỹ thêm 1 handler mồ côi giữ tham chiếu State cũ — memory leak thật, tăng dần theo số lần mở lại màn hình.

## Đề xuất
1. Thêm `if (!mounted) return;` trước `setState` ở cả 4 vị trí (đúng pattern đã dùng ở các dòng 668/1529/2484 trong cùng file).
2. Thêm `void unregisterHandler(String type)` vào `DeepLinkCommandRouter` (xoá đúng entry theo `type`), gọi nó trong `dispose()` của `_WidgetShowcaseScreenState` cho handler đã đăng ký trong `initState()`.

## Acceptance criteria
- [x] Cả 4 vị trí (`_inventoryGrant`, `_inventoryConsume`, 2 chỗ deep-link) có `if (!mounted) return;` trước `setState`.
- [x] `DeepLinkCommandRouter.unregisterHandler(String type)` tồn tại, xoá đúng handler đã đăng ký, không ảnh hưởng handler khác đăng ký cho type khác. (Chữ ký thật: `unregisterHandler(String commandType, DeepLinkHandler handler)` — xem `## Quyết định`.)
- [x] `_WidgetShowcaseScreenState.dispose()` gọi `unregisterHandler('level')` (hoặc type tương ứng) dọn dẹp đúng handler đã đăng ký ở `initState`.
- [x] Mở rồi đóng `WidgetShowcaseScreen` nhiều lần — không tích luỹ handler mồ côi trong `DeepLinkCommandRouter` (verify qua test đếm số handler đăng ký).
- [x] Test hiện có của `widget_showcase_screen_test.dart` và `deep_link_command_router_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-61-widget-showcase-missing-mounted-guards-and-handler-leak.md` này trước khi làm. Đọc toàn bộ `example/lib/screens/widget_showcase_screen.dart` (đặc biệt các dòng nêu trên và pattern `mounted`-guard đã đúng ở dòng 668/1529/2484 để copy chính xác) và `lib/core/deep_link_command_router.dart` trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test (`unregisterHandler`) + widget test (`mounted` guard, dispose cleanup) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (mở/đóng `WidgetShowcaseScreen` nhiều lần, verify không crash/leak quan sát được qua DevTools memory) không bắt buộc nếu widget test dispose-cleanup đã đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao cho phần (1) — Fork nội bộ đã tự đọc trực tiếp source quanh mỗi dòng (context ±5-6 dòng), so sánh với pattern `mounted`-guard lặp lại nhiều lần khác trong cùng file, xác nhận không suy đoán. Cao cho phần (2) — agy xác nhận `DeepLinkCommandRouter` thiếu `unregisterHandler` (đã grep xác nhận API này không tồn tại trong `deep_link_command_router.dart`). Không trùng task nào trong `doc/task/done/`.

## Quyết định

Fix cả 2 phần đúng như đề xuất.

1. **4 chỗ thiếu `mounted` guard**: thêm `if (!mounted) return;` ngay trước `setState` ở `_inventoryGrant`, `_inventoryConsume`, và 2 chỗ deep-link demo — đúng pattern đã dùng nhất quán ở phần còn lại của file.

2. **Handler leak**: `unregisterHandler` thêm với chữ ký `unregisterHandler(String commandType, DeepLinkHandler handler)` — KHÁC với đề xuất gốc `unregisterHandler(String type)`. Lý do: `DeepLinkCommandRouter` cho phép NHIỀU handler cùng đăng ký cho 1 `commandType` (dispatch theo priority, đã có sẵn trong class doc + test "priority cao chạy trước priority thấp") — nếu `unregisterHandler` chỉ nhận `type` và xoá SẠCH list của type đó, 2 consumer khác nhau cùng đăng ký cho cùng 1 type (ví dụ 2 màn hình khác nhau cùng lắng nghe `'level'`) sẽ vô tình xoá NHẦM handler của nhau. Chữ ký nhận thêm đúng `handler` (match theo function identity, `==`) mới xoá đúng 1 đăng ký, không đụng handler khác của cùng type — an toàn hơn đề xuất gốc, vẫn thoả mãn đúng tinh thần acceptance criteria (`không ảnh hưởng handler khác`). `_WidgetShowcaseScreenState` đổi 2 closure inline (`'level'`/`'shop'`) thành 2 method đặt tên (`_onLevelDeepLink`/`_onShopDeepLink`) để có function reference ổn định truyền lại đúng y hệt vào `unregisterHandler` trong `dispose()` — cả 2 type đều được dọn (đề xuất gốc chỉ nhắc `'level'`, nhưng `'shop'` bị leak giống hệt nên sửa luôn).

Thêm `@visibleForTesting int handlerCountFor(String commandType)` vào `DeepLinkCommandRouter` — cần thiết để viết được test "không tích luỹ handler mồ côi" (đếm được, không chỉ suy đoán qua việc "không crash").

**Race window thật không tái hiện được qua UI** (đáng chú ý, ghi rõ để không ai tưởng nhầm là bỏ sót): đã thử tái hiện "dispose đúng lúc `_inventoryGrant`/`_inventoryConsume`/deep-link `handleUri` đang await" bằng cách gọi thẳng `onTap!()` (không qua `tester.tap()`) rồi swap widget tree ngay — verify bằng thực nghiệm (in log thứ tự) cho thấy Future luôn hoàn tất TRƯỚC khi câu lệnh kế tiếp kịp chạy, dù không có `await` nào chen giữa, vì toàn bộ chuỗi `await` bên trong chỉ chạm `StorageService` trên `SharedPreferences` đã mock trong test — không có khoảng hở thời gian thật để dispose xen vào. Thay bằng 2 lớp bằng chứng bổ trợ nhau, mạnh hơn không suy đoán:
- **Structural**: đọc thẳng source thật (`File(...).readAsStringSync()`), regex xác nhận `if (!mounted) return;\s*setState\(` xuất hiện ≥ 7 lần trong file (3 chỗ cũ + 4 chỗ BUG-61) — verify đúng fix có mặt trong code thật, không phải trong 1 bản sao/mock.
- **Pattern proof bằng gap controllable**: 2 widget tối giản (`_UnguardedAsyncWidget`/`_GuardedAsyncWidget`) dùng `Completer` tự kiểm soát khoảng hở async thật (không phụ thuộc timing plugin nào) — chứng minh 2 chiều: (a) không có guard THẬT SỰ throw `"setState() called after dispose()"` khi dispose xen giữa await (proof race window này có thật, không phải suy đoán lý thuyết), (b) có đúng guard thì không throw gì. TDD verify: viết trước, chạy trên `_UnguardedAsyncWidget` xác nhận throw thật (đã thấy full stack trace `FlutterError` khớp chính xác), `_GuardedAsyncWidget` xác nhận không throw.

**Không phá gì:** `flutter analyze` root + `example/` sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: 2038 pass / 19 fail (đúng 19 golden có sẵn, không tăng, không có flaky lần này). `example/`: 129/129 pass (125 cũ + 4 mới).

Không cần smoke test device — task tự cho phép ("widget test đã đủ mạnh"); race thật đã được chứng minh tồn tại (không phải giả định) qua pattern-proof test, mạnh hơn 1 smoke test không thể chủ động ép đúng thời điểm.

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 2 phần, cải tiến chữ ký `unregisterHandler` an toàn hơn đề xuất gốc (tránh 1 lớp bug tiềm ẩn khác — xoá nhầm handler của consumer khác cùng type), minh bạch giải thích tại sao race không tái hiện được qua UI thay vì viết 1 test giả (luôn pass bất kể có fix hay không) rồi coi là xong. Trừ 0.5 vì không smoke test device thật.
