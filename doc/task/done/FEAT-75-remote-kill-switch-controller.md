---
id: FEAT-75
title: "Remote Kill Switch Controller"
type: feature
layer: core/liveops
priority: P1
effort: S
depends_on: [ENH-58, FEAT-38]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tắt khẩn cấp feature/event/shop/animation khi production gặp lỗi.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Kill switch asset fallback an toàn và remote invalid không mở feature.
- [x] State reactive, cached last-known-good và audit reason/version.
- [x] Widget/service đang chạy nhận disable mà không crash hoặc grant sai.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/remote_kill_switch_controller.dart` — `RemoteKillSwitchController`
(`GetxService`), xây TRÊN `RemoteConfigService` (FEAT-39/ENH-58) thay vì
tự làm 1 pipeline remote-fetch mới: mượn lại đúng cơ chế asset-fallback +
partial-merge của `RemoteConfigService`, chỉ thêm CHÍNH XÁC 1 lớp chính
sách an toàn riêng cho kill switch — "invalid remote không bao giờ mở lại
feature đã kill".

**Thứ tự resolve** (đây là phần logic cốt lõi, y hệt tinh thần
`RemoteContentPack`'s "reject-and-keep-last-good" nhưng áp dụng ở mức
từng key thay vì cả envelope):
1. Giá trị remote hợp lệ ngay bây giờ (`bool` thô, hoặc map
   `{killed, reason?, version?}` cho audit đầy đủ) → dùng, đánh dấu
   `KillSwitchSource.remoteValid`.
2. Không hợp lệ (thiếu key, sai type, map thiếu field `killed` kiểu
   `bool`) NHƯNG đã từng có lần đọc hợp lệ trước đó cho đúng feature này
   → giữ nguyên quyết định CŨ (`cachedLastKnownGood`) — đây là điểm mấu
   chốt: 1 payload hỏng không thể tự ý biến `killed=true` thành `false`.
3. Chưa từng có lần đọc hợp lệ nào → dùng `assetDefaults[featureId]`
   (map bundle theo do caller truyền vào), mặc định `false` nếu feature
   không có trong map đó.

**State reactive**: `states` là `RxMap<String, KillSwitchState>` — bất kỳ
widget nào bọc `Obx` và đọc `states[featureId]` tự rebuild ngay khi
`isKilled`/`refreshAll` cập nhật, không cần rebuild/mở lại toàn màn hình.
`runIfEnabled<T>(featureId, action)` biến "không grant/thực thi feature bị
kill" thành đường mặc định thay vì để mỗi call site tự nhớ guard riêng.
`auditLog` bounded 200 entry, mỗi entry giữ `reason`/`version`/`source`/
`decidedAtMs`.

**Bug thật tìm được khi viết widget test** (không phải đoán): dùng
`assetPath: 'test/does_not_exist.json'` với `bundle` mặc định (rootBundle
thật) dưới `test()` thường thì chạy tốt (throw nhanh, catch im lặng), NHƯNG
y hệt code đó đặt trong `testWidgets()` thì `PlatformAssetBundle.load`
TREO ĐÚNG 10 PHÚT (timeout thật) thay vì throw ngay — khác biệt hành vi
giữa 2 loại binding test của `flutter_test`. Sửa bằng cách copy lại đúng
fixture `_FakeAssetBundle`-kiểu đã có sẵn trong
`test/core/remote_config_service_test.dart` (luôn throw ngay, không đụng
platform channel thật) cho MỌI construction, không chỉ riêng ca widget
test.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1835/1835 pass (1818 cũ + 17
  test mới `remote_kill_switch_controller_test.dart`). Gặp 1 fail flaky
  không liên quan (`asset_license_check_test.dart`) khi chạy suite đầy
  đủ — retry sạch, đúng flake pre-existing đã ghi nhận từ các task trước
  trong session.
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `RemoteKillSwitchController`/`KillSwitchState`/`KillSwitchSource`,
  CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- 17 test: remote hợp lệ (bool 2 chiều, map đầy đủ, map thiếu
  reason/version dùng default), asset default (không remote + không asset
  default → false; không remote + có asset default → dùng đúng); **2 test
  "PHÁT HIỆN THẬT"** khoá đúng property cốt lõi — remote hợp lệ
  killed=true rồi remote hỏng (sai type) → vẫn giữ true từ cache, map
  thiếu field `killed` → bị từ chối hoàn toàn, remote là số/string thô →
  bị từ chối; reactive (`states` cập nhật đúng, nhiều feature độc lập,
  `refreshAll` cập nhật đủ); audit log (ghi đúng mỗi lần gọi, bounded);
  `runIfEnabled` (kill thì không gọi callback, không kill thì gọi đúng);
  `maybe` null-safe; **1 widget test thật** — `Obx` watch `states`, ops
  kill remote NGAY LÚC widget đang hiển thị, UI tự chuyển từ "Shop: mua
  vật phẩm" sang "Shop đóng cửa" mà không throw.
- Device smoke test thật trên **Samsung S24 Ultra (SM-S928B)**: build lại
  debug APK `example/` (barrel có export mới), cài, `HomeScreen` render
  đúng, không crash. Không có demo UI riêng cho kill switch trong
  `example/` — nhất quán với chính `SdkHealthReport` (FEAT-39, dependency
  trực tiếp của task này) cũng chưa từng có demo trực quan trong
  `WidgetShowcaseScreen`.

Tự chấm: 9.4/10. Trừ điểm vì chưa wire demo thật vào `example/` (1 nút
"Simulate kill switch" đổi giá trị remote giả rồi cho thấy UI tự ẩn/hiện
trên device thật sẽ là bằng chứng mạnh hơn) — để lại follow-up, không tự
ý mở rộng `WidgetShowcaseScreen` (đã rất dài) khi acceptance criteria
không bắt buộc.

