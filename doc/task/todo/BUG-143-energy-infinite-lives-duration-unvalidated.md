---
id: BUG-143
title: "EnergyService.grantInfiniteLives: duration âm/0 vô nghĩa và duration khổng lồ lưu timestamp phi thực tế"
type: bug
layer: lib/core
priority: P3
effort: S
source: "Survey rủi ro 2026-11-23 (test tạm chạy thật, đã xoá)"
---

## Bằng chứng (đo bằng test tạm trên VM)

- `grantInfiniteLives(Duration(days: 100000000))` thành công và ghi `energyInfiniteUntilMs = 8641795447189222` (~273 triệu năm). Không lỗi, `hasInfiniteLives` true vĩnh viễn; sau này không có cách trừ lại ngoài ghi đè. Nguồn thật: một số từ remote config/IAP sai.
- `grantInfiniteLives(Duration(days: -5))` và `Duration.zero` không ném, không đổi trạng thái (hasInfiniteLives false). Chấp nhận được, nhưng im lặng; một lời gọi sai (đơn vị nhầm, tích âm) không được báo.
- Ngược lại `consumeEnergy` và constructor đã validate bằng `ArgumentError` (BUG-19). `grantInfiniteLives` là chỗ duy nhất lọt, trái quy ước ENH-85 (validate runtime ở biên).

## Đề xuất

`ArgumentError` khi `duration <= Duration.zero`, và trần hợp lý (cùng kiểu ENH-116, vd 100 năm). Behavior change nhỏ, cần test + CHANGELOG. Cần owner chốt: duration <= 0 nên ném, hay coi là no-op có chủ ý (hiện test nào dựa vào hành vi đó thì giữ).

## Đo và thấy ổn (không cần task)

- `EnergyService`: `lastMs` ở tương lai 400 ngày: hồi 0, `timeUntilNextEnergy` 0 ngày (hồi bình thường sau, không khoá). `lastMs` âm: đầy ngay. `count` 999 bị kẹp về max. Phù hợp ClampedClock.
- `DailyQuestService`: đổi kỳ giữa phiên reset đúng (progress 3 -> 0, claimed false); `claim` hai lần trả false lần hai; đăng ký lại với target nhỏ hơn thì quest hoàn thành ngay (hợp lý).
- `ExperimentBucketingService`: phân phối 3 nhóm 20000 mẫu đều (6610/6641/6749), ổn định theo id, đổi số variant (2 -> 3) giữ nhóm 'a' ở ví dụ đo; id rỗng được sinh lại; override không có trong danh sách bị bỏ qua. Không thấy vấn đề.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt với owner: `duration <= 0` nên ném `ArgumentError` hay giữ là no-op có chủ ý. Grep mọi call site của `grantInfiniteLives` (lib, example, test) và đọc doc comment từng nơi (BUG-112) trước khi đổi.
- [ ] 2. Viết test đỏ: `Duration.zero`/âm theo quyết định ở bước 1; duration vượt trần (đề xuất 100 năm, cùng kiểu `SeasonEventService.maxCycleMs`) ném `ArgumentError`; duration hợp lệ vẫn đúng.
- [ ] 3. Cài validate trong `EnergyService.grantInfiniteLives` + hằng trần public (tên theo mẫu ENH-116).
- [ ] 4. Mutation check (bỏ kiểm tra trần, test đỏ).
- [ ] 5. CHANGELOG `## Unreleased` ghi **Behavior change** nếu bước 1 chọn ném; API snapshot nếu thêm hằng public.
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] `grantInfiniteLives(Duration(days: 100000000))` không còn lưu mốc ~273 triệu năm.
- [ ] Quyết định `<= 0` được ghi và có test.
- [ ] Mọi test cũ pass; không call site nào trong repo bị vỡ.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/energy_service_test.dart`
