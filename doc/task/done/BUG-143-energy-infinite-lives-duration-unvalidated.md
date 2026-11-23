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

- [x] 1. Chốt với owner: `duration <= 0` nên ném `ArgumentError` hay giữ là no-op có chủ ý. Grep mọi call site của `grantInfiniteLives` (lib, example, test) và đọc doc comment từng nơi (BUG-112) trước khi đổi.
- [x] 2. Viết test đỏ: `Duration.zero`/âm theo quyết định ở bước 1; duration vượt trần (đề xuất 100 năm, cùng kiểu `SeasonEventService.maxCycleMs`) ném `ArgumentError`; duration hợp lệ vẫn đúng.
- [x] 3. Cài validate trong `EnergyService.grantInfiniteLives` + hằng trần public (tên theo mẫu ENH-116).
- [x] 4. Mutation check (bỏ kiểm tra trần, test đỏ).
- [x] 5. CHANGELOG `## Unreleased` ghi **Behavior change** nếu bước 1 chọn ném; API snapshot nếu thêm hằng public.
- [x] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] `grantInfiniteLives(Duration(days: 100000000))` không còn lưu mốc ~273 triệu năm.
- [x] Quyết định `<= 0` được ghi và có test.
- [x] Mọi test cũ pass; không call site nào trong repo bị vỡ.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/energy_service_test.dart`

## Kết quả thực hiện (2026-11-23)

- Quyết định (dùng mặc định đề xuất, owner chọn "dùng mặc định đề xuất, ghi rõ"): `duration <= 0` NÉM `ArgumentError` (không còn no-op im lặng); trần 100 năm (`EnergyService.maxInfiniteLivesDuration`, cùng kiểu `SeasonEventService.maxCycleMs`). Đây là Behavior change, đã ghi trong CHANGELOG `## Unreleased`; nếu owner muốn giữ no-op cho `<= 0` thì chỉ cần bỏ nhánh đầu và một nửa test.
- Call site đã kiểm (BUG-112): 2 trong example (`level_progression_screen.dart:100` 15 phút, `widget_showcase_screen.dart:1525` 20 giây), test hiện có (10 phút, 1 giờ, 5 phút, 2 giờ), `smart_reminder_scheduling_test.dart` (1 giờ). Tất cả dương và nhỏ hơn trần, không vỡ. Doc của hàm không ghi "không bao giờ ném".
- Test mới: 2 test trong nhóm `BUG-143` (zero/âm; trên 100 năm và đúng 100 năm vẫn nhận). Mutation: bỏ nhánh trần làm 1 test đỏ, bỏ nhánh `<= 0` làm 1 test đỏ.
- Kiểm chứng: `flutter analyze` sạch (root và example), API gate unchanged (static const không nằm trong snapshot export), example 196 test pass cho 2 màn gọi hàm. Root: 4138 pass, 1 đỏ là `performance_budget_check_test` (benchmark object-pool 23ms so với baseline 7ms, dung sai 200%) chỉ khi chạy trong cả bộ song song; chạy riêng pass 9/9, và pass cả trên cây sạch không có thay đổi này: nhiễu thời gian, không do thay đổi.
