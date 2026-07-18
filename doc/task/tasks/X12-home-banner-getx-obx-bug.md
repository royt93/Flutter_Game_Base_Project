# X12 — Fix bug GetX "improper use of Obx" ở banner ưu tiên Home Screen

**Epic:** bugfix · **SP:** 1 · **Pri:** Must · **Deps:** none

## Mục tiêu
Trong lúc audit hiệu suất theo yêu cầu user, chạy `flutter test --exclude-tags
slow` phát hiện 2 test fail có vẻ "flaky" (mỗi lần chạy fail 1 file khác
nhau: `boot_resilience_test.dart` + `swap_freeze_test.dart` lần này,
`boot_resilience_test.dart` + `home_screen_test.dart` lần khác). Điều tra
kỹ cho thấy đây KHÔNG phải flaky mà là 1 bug thật, xảy ra tất định vào
đúng những ngày cuối tuần.

## Vì sao
`home_screen.dart` → `_buildPriorityBanner` bọc logic trong `Obx(() {...})`
nhưng nhánh đầu tiên:
```dart
if (isWeekendEvent(DateTime.now())) {
  return _bannerContainer(...);
}
```
return sớm mà KHÔNG đọc bất kỳ giá trị `Rx` nào — `isWeekendEvent` là hàm
thuần theo `DateTime.now()` thật, không phụ thuộc state reactive nào cả.
GetX yêu cầu `Obx` phải đọc ít nhất 1 `Rx` trong quá trình build để đăng ký
subscription; khi nhánh này chạy, GetX ném lỗi framework "the improper use
of a GetX has been detected...". Lỗi này sau đó kéo theo `RenderFlex
overflowed by 99777 pixels` ở `Column` gốc — chỉ là triệu chứng, không
phải nguyên nhân.

Bug này tất định theo ngày: **thứ Bảy/Chủ nhật** rơi vào khung
`isWeekendEvent` → nhánh 1 luôn trả về sớm → luôn crash. Bất kỳ test nào
render `HomeScreen` trong khung này đều fail
(`home_screen_test.dart`, `boot_resilience_test.dart`), còn
`swap_freeze_test.dart` fail "lây" chỉ vì GetX global state bị lỗi này làm
hỏng, không liên quan gì tới logic swap/freeze — chạy riêng file đó luôn
xanh 100%. Đây là bug thật sẽ xảy ra trên máy user thật vào cuối tuần
(đúng lúc banner sự kiện cuối tuần lẽ ra phải hiện), không phải "test-canvas
artifact" như ghi chú cũ từng nghĩ.

## Đã sửa
Thêm 1 dòng đọc Rx vô điều kiện ngay đầu callback, trước mọi nhánh return
sớm:
```dart
Widget _buildPriorityBanner(GameController gameCtrl) {
  return Obx(() {
    gameCtrl.seasonPoints.value; // luôn đọc Rx trước mọi nhánh return sớm
    if (isWeekendEvent(DateTime.now())) {
      ...
```
`seasonPoints` vốn đã là Rx được đọc ở nhánh season phía dưới — chỉ nâng
lên đầu callback để đảm bảo Obx luôn có ít nhất 1 dependency bất kể nhánh
nào chạy trước.

## Acceptance criteria
- [x] `_buildPriorityBanner` luôn đọc `gameCtrl.seasonPoints.value` trước
      khi kiểm tra `isWeekendEvent`.
- [x] `flutter analyze` 0 issues.
- [x] `flutter test --exclude-tags slow` xanh toàn bộ (261 test) — xác
      nhận cả `home_screen_test.dart` lẫn `boot_resilience_test.dart`
      cùng pass sau 1 fix duy nhất (đúng như giả thuyết chung 1 root
      cause).

## Ghi chú kỹ thuật
Không phải bug do fix throttle animation ([[X11]]) gây ra — khác file,
không chung code path, và bug này có sẵn từ trước (dựa vào ngày hệ thống,
không phụ thuộc thay đổi gần đây nào). Bài học chung: mọi `Obx` phải đảm
bảo đọc Rx ở MỌI nhánh có thể return, kể cả nhánh đầu tiên/sớm nhất — nên
soát lại các `Obx` khác trong app có pattern early-return tương tự trong
lần rà soát tiếp theo (chưa nằm trong scope task này).

DoD chung: `../README.md`.
