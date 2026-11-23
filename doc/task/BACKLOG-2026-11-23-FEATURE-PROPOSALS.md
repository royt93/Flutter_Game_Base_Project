# Backlog 2026-11-23: đề xuất tính năng owner đã chọn (24 task tính năng + 12 task kiểm thử)

Nguồn: owner chọn từng đề xuất qua hỏi đáp ngày 2026-11-23. Mỗi task nằm ở `doc/task/todo/` và có sẵn 3 mục để làm theo: **Các bước** (checklist có thứ tự, mỗi bước một commit), **Tiêu chí nghiệm thu** và **Lệnh kiểm chứng nhanh** (đường dẫn test đã kiểm tồn tại; riêng lệnh của BUG-143 đã chạy thử, pass). File này chỉ là chỉ mục: thứ tự gợi ý, phụ thuộc, cỡ việc. Chưa task nào được bắt đầu.

Định hướng owner: trọng tâm là SDK game + widget common + hàm/helper dùng chung; demo chỉ cần sơ sơ; chỉ hỗ trợ Android và iOS.

## Bảng task

| ID | Việc | Lớp | Cỡ | Ưu tiên |
|---|---|---|---|---|
| BUG-143 | `EnergyService.grantInfiniteLives` không validate duration | core | S | P3 |
| FEAT-232 | `fmtRelative` thời gian tương đối | core/utils | S | P3 |
| FEAT-216 | `UndoStack<T>` | core (+example tuỳ chọn) | S | P3 |
| FEAT-219 | Gacha/pity table | core | S | P3 |
| FEAT-215 | Grid + pathfinding BFS/A* | core | M | P3 |
| FEAT-220 | Replay player | core | M | P3 |
| FEAT-230 | Swipe 4 hướng (logic + widget bọc) | core + widget | M | P3 |
| FEAT-223 | `CandyBottomNavBar` | widget | M | P3 |
| FEAT-224 | `SettingsSection` + tile | widget | M | P3 |
| FEAT-226 | `OnboardingCarousel` | widget | M | P3 |
| FEAT-225 | `QuantityStepper` | widget | S | P4 |
| FEAT-227 | `CandyDropdown<T>` | widget | S | P4 |
| FEAT-228 | `StatBar` | widget | S | P4 |
| FEAT-231 | `PodiumWidget` | widget | M | P4 |
| FEAT-229 | `DialogueBox` | widget | M | P4 |
| FEAT-217 | FSM nhỏ | core | M | P4 |
| FEAT-221 | Wave/spawn scheduler | core | M | P4 |
| FEAT-233 | `playSfxVariant` | core | S | P4 |
| FEAT-222 | Thêm ngôn ngữ cho `AppTranslations` | core | M | P4 |
| FEAT-218 | Demo game thứ hai | example | M | P4 |
| FEAT-234 | `WhatsNewSheet` (hiện một lần mỗi bản) | widget | M | P3 |
| FEAT-237 | `DynamicDifficulty` | core | S | P3 |
| FEAT-235 | `StepProgressIndicator` | widget | S | P4 |
| FEAT-236 | `FeedbackSheet` (UI + callback, không gửi gì) | widget | M | P4 |

## Thứ tự gợi ý và lý do

1. **BUG-143** trước: sửa nhỏ, cùng họ lỗi đã đóng (ENH-116), không cần quyết định thiết kế ngoài việc duration <= 0 ném hay no-op.
2. **Đợt helper thuần Dart nhỏ** (FEAT-232, 216, 219): độc lập, không đụng UI hay golden, test host đủ.
3. **Đợt nền cho game** (FEAT-215, 220, 230): 215 và 230 là nền cho puzzle/lưới; 220 hoàn tất vòng ghi/phát replay.
4. **Đợt widget** (FEAT-223, 224, 226, rồi 225, 227, 228, 231, 229): mỗi widget cần golden Linux qua workflow `regenerate-goldens.yml`, nên gom commit widget + test trước, sinh baseline một lượt cho cả đợt để đỡ vòng chờ.
5. **Cuối**: FEAT-217, 221, 233, 222, 218 (giá trị thấp hơn hoặc có rủi ro đã ghi trong từng task).

## Phụ thuộc và xung đột cần nhớ

- **FEAT-234 (đợt 3)**: `OnboardingCoordinatorService` chỉ hiểu `version` là số nguyên; app truyền `releaseNumber` (int), widget không tự so chuỗi phiên bản. Dùng chung coordinator với FEAT-226, nên làm 226 trước hoặc cùng đợt.
- **FEAT-236**: kit không gửi gì; đính kèm chẩn đoán mặc định tắt vì `DiagnosticsExportBundle` có phần đầu vào không được redact. Cần xem `consent_state_service`.
- **FEAT-237**: công cụ cân bằng thuần Dart, README phải ghi không dùng để ép chi tiêu.
- **FEAT-235**: ranh giới với `paginated_dots_indicator`; nếu chỉ cần thêm tham số cho dots thì dừng và báo owner.

- **FEAT-224 và FEAT-227 cùng sửa `example/lib/screens/settings_screen.dart`** (settings tile, và thay `_pickLanguage` bằng `CandyDropdown`). Làm liền nhau hoặc cùng một người để khỏi xung đột; 227 nên sau 224.
- **FEAT-221 sau FEAT-215 và FEAT-217** (tránh thành engine trùng); **FEAT-218 sau 215/216/217**, và chỉ khi một trong số đó cần demo.
- **FEAT-232 và FEAT-222**: mỗi key dịch mới của `fmtRelative` phải có ở mọi locale được thêm sau.
- **FEAT-226** dùng `OnboardingCoordinatorService` (đã có), ranh giới với `tutorial_sequence` ghi trong task; **FEAT-229** bổ sung cho `tutorial_sequence`, không thay thế.
- **FEAT-217** phải giữ `GameSessionController` là nguồn sự thật phase phiên (ranh giới ghi trong task).
- **FEAT-233 phần đổi cao độ chưa kiểm chứng** (API `audioplayers` chưa đọc), chỉ phần chọn biến thể làm được ngay.
- Mọi task thêm export công khai cần `dart run tool/api_compatibility.dart snapshot`, CHANGELOG, và (task widget) golden qua workflow, không sinh trên macOS.

## Đợt kiểm thử (ENH-117..128): "chứng minh mọi case"

Owner yêu cầu bổ sung unit, widget, integration, golden, interruption, network conditioning, memory-leak/profiling, frame-rate/jank và IAP/ad test. Đã ĐO hiện trạng trước khi rã (không đoán):

- Độ phủ dòng **97.0%** (21272/21941, 4137 test host): `lib/core` 97.9%, `widgets/common` 96.8%, `widgets` 89.7%, `presentation/game` 89.0%.
- Mọi widget trong `widgets/common` đã có test và fixture `runViewportSweep`; **87/164 chưa có golden** (hiện 64 file golden, 1397 PNG; chia 19+15+13+14+13+13 = 87, đã đối chiếu từng widget không sót/trùng).
- 71 file widget giữ Ticker/Controller/Stream, 68 có `dispose`; chưa bật leak tracking ở đâu.
- Không có đối tượng test cho **ad mediation** (tính năng quảng cáo đã gỡ ở 0.8.0): ENH-126 ghi rõ ngoài phạm vi.

| ID | Việc | Nơi chạy | Cỡ | Ưu tiên |
|---|---|---|---|---|
| ENH-117 | Bật leak tracking cho `test/widget` | host | M | P3 |
| ENH-118 | Golden đợt A: input/form (19 widget) | workflow Linux | M | P3 |
| ENH-119 | Golden đợt B: overlay/dialog/toast (15) | workflow Linux | M | P3 |
| ENH-120 | Golden đợt C: game HUD/tiến độ (13) | workflow Linux | M | P3 |
| ENH-121 | Golden đợt D: thưởng/shop/sự kiện (14) | workflow Linux | M | P3 |
| ENH-122 | Golden đợt E: level/bảng xếp hạng/danh sách (13) | workflow Linux | M | P4 |
| ENH-123 | Golden đợt F: chỉ-hoạt-ảnh, nhạy flaky (13 widget) | workflow Linux | M | P4 |
| ENH-124 | Interruption (vòng đời, kill giữa ghi) | host + emulator/lịch tuần | M | P3 |
| ENH-125 | Network conditioning (fake có điều khiển) | host | M | P3 |
| ENH-126 | IAP gián đoạn/trùng giao dịch | host | M | P3 |
| ENH-127 | Jank + memory trên S24U (chạy tay, ghi docs/qa) | S24U | M | P3 |
| ENH-128 | Nâng 9 file phủ thấp nhất lên >= 90% | host | S | P4 |

Nơi chạy theo lựa chọn của owner: logic (interruption, network, IAP) ở host/emulator lịch tuần; jank và memory CHỈ trên S24U vì emulator dùng GPU giả lập nên số không đáng tin; không thêm cổng CI. Golden đợt A-F làm tuần tự, mỗi đợt một lần chạy workflow; đợt F nhạy flaky nên làm cuối và cho phép loại widget không ổn định.

## Việc đã kiểm khi lập backlog (không phải giả định)

- Mỗi khẳng định "kit chưa có X" được kiểm bằng grep theo từng tên lớp trong `lib/`. Một lần sai đã được sửa: FEAT-227 ban đầu nói kit thiếu checkbox, nhưng `CandyCheckboxTile` đã có trong `candy_radio_group.dart`; chỉ còn thiếu dropdown. Task ghi rõ đính chính.
- Đề xuất `AnimatedNumberTicker` KHÔNG vào backlog: `CurrencyCounter` đã có số chạy (`duration`, `curve`, `enableTapToSkip`).
- Đã đo và thấy ổn (không tạo task): `DailyQuestService` đổi kỳ giữa phiên, `ExperimentBucketingService` phân phối và ổn định, `EnergyService` với `lastMs` xa tương lai/âm/count quá max, `PersistentCooldownService` với dữ liệu hỏng. Chi tiết trong BUG-143 và ENH-116.

## Chưa làm

- Chưa bắt đầu code task nào ở bảng trên.
- Chưa có ước lượng thời gian; cỡ S/M chỉ là phân loại tương đối.
