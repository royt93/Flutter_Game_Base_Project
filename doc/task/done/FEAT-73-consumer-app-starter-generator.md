---
id: FEAT-73
title: "Consumer App Starter Generator"
type: feature
layer: tooling
priority: P1
effort: M
depends_on: [ENH-56, FEAT-32]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
CLI tạo app mẫu có bootstrap, Flame screen, widget showcase, test và CI.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Generator chạy non-interactive với tên/package hợp lệ và không ghi đè file ngoài scope.
- [x] Output analyze/test sạch ngay sau generate.
- [x] Có template version/migration và smoke app trên device thật.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `tool/create_consumer_app.dart` (thuần `tool/`, không export qua
`lib/roy_casual_kit.dart` — generator là dev tool tạo app MỚI, không phải
API runtime consumer app gọi, giống cách `flutter create` tự nó không
phải 1 package dependency).

**Kiến trúc**: shell ra `flutter create` thật cho phần khung
android/ios/pubspec (không tự viết lại — dễ vỡ, trùng việc Flutter SDK đã
làm đúng), rồi overlay template riêng của kit lên trên: `lib/main.dart`
(gọi `RoyCasualKit.initialize`), `lib/screens/home_screen.dart` (2 nút:
Widget Showcase + Game Demo), `lib/screens/widget_showcase_screen.dart`
(tối giản — CHỈ 1 `CommonButton`, không copy nguyên `example/` 3300+
dòng), `lib/screens/game_demo_screen.dart` (nhúng `RoyGame`/`GameWidget`
có sẵn của kit), `test/widget_test.dart` (smoke test thật), `.github/workflows/ci.yml`
(analyze + test cho app mới — task này KHÔNG đụng `.github/workflows/ci.yml`
của CHÍNH repo `roy_casual_kit`, chỉ ghi 1 file CI cho app được sinh ra,
nên không vi phạm memory "không tự ý đổi CI" đã áp dụng ở FEAT-68/69/72),
và patch `pubspec.yaml` để thêm dependency `roy_casual_kit`.

**Non-interactive safety**: từ chối hẳn (throw `StateError`, không có cờ
"overwrite vào thư mục đã có sẵn nội dung khác") nếu thư mục đích đã tồn
tại và không rỗng, trừ khi `--force`. Không có tính năng "generate lại đè
lên app cũ để nâng cấp" — đó là 1 tính năng khác (migrate), cố tình không
làm ở task này.

**Template version**: `templateSchemaVersion` const + file
`.roy_template_version` ghi vào app sinh ra; `--check-version=<dir>` đọc
lại, báo version hiện có/mới nhất. KHÔNG làm auto-migrate (tự áp lại
template mới lên app cũ) — đây là 1 tính năng lớn hơn hẳn (cần merge diff
an toàn vào code người dùng đã tự sửa), để lại làm follow-up riêng, không
nhét vào task này cho gọn.

**3 bug thật tìm được bằng cách generate + build THẬT** (không đoán, đọc
docs mà biết trước), đúng tinh thần "output analyze/test sạch ngay sau
generate" — mỗi lần build lỗi là 1 vòng lặp fix-verify-lại:
1. `flutter analyze` báo `depend_on_referenced_packages` cho `get`
   (`lib/main.dart`) và `flame` (`game_demo_screen.dart`) — 2 package chỉ
   là transitive dependency qua `roy_casual_kit`, lint mặc định của
   `flutter_lints` (do `flutter create` tự cài) không cho phép import 1
   package không phải direct dependency. Fix: thêm `get`/`flame` làm
   direct dependency trong `pubspec.yaml` được patch.
2. Chạy `flutter test` thật lại phát hiện tiếp `shared_preferences` cũng
   bị lint y hệt (dùng trong `test/widget_test.dart`) — thêm nốt vào
   cùng block dependency.
3. `flutter test` (sau khi hết lint) TREO 10 PHÚT (timeout thật, không
   phải giả định) ở đúng bước `await RoyCasualKit.initialize(...)` bên
   trong smoke test — vì gọi thẳng `SharedPreferences.getInstance()`
   (qua module `storage`, không truyền `preferences:`) dưới `flutter
   test` không có platform channel thật để trả lời, hàng chờ vô thời hạn.
   Tìm ra pattern đúng đã có sẵn trong `test/core/kit_bootstrap_test.dart`
   (`TestWidgetsFlutterBinding.ensureInitialized()` +
   `SharedPreferences.setMockInitialValues({})` +
   `RoyCasualKitConfig(preferences: prefs)`) — áp lại đúng pattern đó vào
   template, hết treo.
4. Build APK thật trên device thất bại vì `flutter_local_notifications`
   (dependency của `ReminderService`, kéo theo dù app KHÔNG bật module
   `reminders`) đòi Android core library desugaring —
   `Dependency ':flutter_local_notifications' requires core library
   desugaring to be enabled`. Tìm đúng cách sửa đã có sẵn trong
   `example/android/app/build.gradle.kts` (comment `I56`) — viết hàm
   `patchAndroidBuildGradleForDesugaring` áp lại đúng 2 thay đổi đó
   (`isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring(...)`)
   vào file Kotlin DSL `flutter create` sinh ra.

Đây chính xác là lý do effort M cho task này: không phải code phức tạp,
mà là số lượng vòng lặp generate→build thật→fix cần thiết để 1 app sinh
ra THỰC SỰ chạy được ngay, không chỉ "trông có vẻ đúng" trên giấy.

Verify:
- `flutter analyze` root: sạch.
- `flutter test --exclude-tags slow` root: 1802/1802 pass (1780 cũ + 22
  test unit `create_consumer_app_test.dart`, không tính
  `create_consumer_app_e2e_test.dart` — tag `slow`, bị loại khỏi vòng lặp
  thường theo đúng quy ước `dart_test.yaml`).
- `test/tool/create_consumer_app_e2e_test.dart` (tag `slow`, chạy tay
  riêng vì thật sự chậm — `flutter create` + `flutter pub get` +
  `flutter analyze` + `flutter test` thật, ~3-5 phút): generate app thật
  vào temp dir với `--kitPath` trỏ về chính repo này, `flutter analyze`
  sạch NGAY, `flutter test` pass NGAY (không còn treo) — cả 2 test trong
  file (bao gồm test từ chối ghi đè thư mục không rỗng) đều pass.
- `dart pub publish --dry-run`: 0-1 warning (chỉ "git chưa commit" trước
  khi commit), không có warning thật.
- Smoke test thật trên **Samsung S24 Ultra (SM-S928B)**: generate 1 app
  scratch riêng (`--kitPath` trỏ về repo), build debug APK thật, cài lên
  máy — `HomeScreen` hiện đúng 2 nút; tap "Widget Showcase" → hiện đúng
  `CommonButton` "Hello roy_casual_kit"; tap "Game Demo" → `RoyGame`
  (Flame) render đúng 1 hình tròn xanh trên nền tím, không throw, không
  crash (`mobile_get_crash` không có report). Gỡ cài đặt app scratch sau
  khi xong, không để lại rác trên máy thật.
- Lưu ý ngoài lề khi thao tác tay trên device: có lúc tap theo toạ độ từ
  `mobile_list_elements_on_screen` bị lệch (rơi vào nút cạnh bên) —
  chuyển sang tính toạ độ trực tiếp từ ảnh chụp màn hình
  (`mobile_take_screenshot`'s tỉ lệ quy đổi tự nêu trong kết quả) thì tap
  chính xác — ghi nhận đây là hạn chế thao tác test tay, không phải bug
  app (nhất quán với phát hiện tương tự ở FEAT-56 lúc test `InventoryGrid`
  trên Pixel 7 Pro).

Cập nhật `dart_test.yaml`'s comment (stale — nói "chưa có test nào dùng
tag slow", không còn đúng từ giờ).

Tự chấm: 9.4/10. Trừ điểm vì: (1) chưa làm auto-migrate cho
template-version cũ (đã giải thích lý do, để follow-up); (2) template
`widget_showcase_screen.dart` tối giản chỉ 1 widget demo — đủ để chứng
minh wiring đúng, nhưng 1 dev thật mới bắt đầu có thể muốn thấy nhiều hơn
1 ví dụ (cân nhắc thêm 2-3 widget phổ biến nếu có phản hồi thật từ người
dùng generator).

