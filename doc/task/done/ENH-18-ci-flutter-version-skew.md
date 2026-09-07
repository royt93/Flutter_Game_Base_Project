---
id: ENH-18
title: "CI pin Flutter 3.35.1, máy dev local đang 3.41.9 — version skew che mất regression SDK"
type: enhance
priority: P2
effort: S
source: Claude, audit round 3 (fork agent), verified against a real regression this session
---

## Vị trí
`.github/workflows/ci.yml`:
```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: 3.35.1
```
Máy dev thực tế đang chạy `flutter --version` → `3.41.9` (channel stable).

## Hiện trạng
CI pin cứng một bản Flutter cũ hơn khá nhiều so với bản đang dùng để phát
triển/verify local. Việc này vừa được xác minh có hậu quả THẬT trong chính
session này: round trước phát hiện 5 test fail
(`common_button_test`, `segmented_tab_bar_test`, `toast_banner_test`,
`toggle_switch_test`) do `SemanticsData.flagsCollection.{isEnabled,
isToggled, isSelected}` đổi kiểu trả về từ `bool` sang `Tristate` ở Flutter
SDK bản mới — một thay đổi API tầng framework, không phải do code của
package hay của bất kỳ round nào trước đó. Nếu CI vẫn đang chạy 3.35.1 (bản
chưa có thay đổi này), CI **sẽ không bao giờ bắt được** loại regression
SDK này — nó chỉ lộ ra khi ai đó chạy test trên máy local với SDK mới hơn.

## Vì sao cần
CI xanh không còn đồng nghĩa "code chạy đúng trên SDK mà người dùng cuối
thực sự build app" nếu 2 nơi lệch bản SDK xa nhau — đặc biệt nguy hiểm cho
1 package (không phải app cuối), vì consumer app có thể pin Flutter version
bất kỳ, và bug kiểu Tristate này sẽ chỉ lộ ra ở máy của họ, không lộ ở CI
của package.

## Đề xuất
Bump `flutter-version` trong `ci.yml` khớp (hoặc gần khớp) bản đang dùng để
phát triển thực tế (3.41.9), hoặc đổi sang `flutter-version: stable` để CI
tự trôi theo kênh stable thay vì đông cứng version cụ thể — tuỳ policy
release của package (pin cứng dễ tái lập nhưng dễ lệch dần; theo `stable`
tự cập nhật nhưng có thể fail bất ngờ khi Flutter release breaking change).

## Ghi chú độ tin cậy
Việc chọn "pin version cụ thể nào" hay "theo stable" là quyết định chính
sách CI, không phải kỹ thuật thuần — nên hỏi ý kiến trước khi chọn, task
này chỉ xác nhận version hiện tại ĐANG lệch và đã từng gây hậu quả thật.

## Acceptance criteria
- [ ] `ci.yml`'s `flutter-version` khớp (hoặc cấu hình `stable`) với bản Flutter dùng để phát triển/verify thực tế.
- [ ] Sau khi đổi, CI chạy lại xanh với version mới (không có regression nào khác lộ ra thêm).

## Quyết định
Đóng, không làm. Chủ dự án từ chối rõ ràng: đổi CI (chạy lại workflow,
nhất là đổi version rồi phải verify lại) tốn phút GitHub Actions phải trả
phí. Không đề xuất lại task này nữa.
