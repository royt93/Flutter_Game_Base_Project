# Test Coverage Audit — 2026-06-24

**Kết luận:** Bộ test case cũ cover tốt happy path gameplay, nhưng chưa đủ chuẩn release mobile. QC phàn nàn đúng: nhiều vùng rủi ro cao từng thiếu hoặc chỉ test rất mỏng.

**Trạng thái sau hardening:** đã thêm TC-12 và release-gate automation để chặn doc stale, asset/package sai, i18n placeholder lệch, Home/Boss font-scale overflow, Boss duplicate-key crash.

---

## Điểm mạnh hiện có

| Nhóm | Trạng thái |
|------|------------|
| Campaign core | Có swap, special gem, win/lose, lives, booster cơ bản |
| Side modes | Đã liệt kê 13 challenge entries |
| Animation/gameplay smoke | Đã có TC-11, gồm Boss crash regression |
| Economy/meta | Có Battle Pass, Season, Achievement, Collection, Temple, Piggy, Wheel |
| Regression known bugs | Có dialog, jelly reactive, side-mode isolation, overflow |

---

## Gap P0/P1 QC Có Thể Bắt Lỗi

| Severity | Gap | Tại sao nguy hiểm | File cần cover |
|----------|-----|-------------------|----------------|
| P0 | App update/migration chưa có test | Update từ bản cũ có thể mất progress/xu/booster/records | TC-12 |
| P0 | Lifecycle chưa đủ | Background/resume khi đang chơi có thể làm timer/audio/state lỗi | TC-12 |
| P0 | Android back stack/double tap chưa đủ | Tap nhanh có thể mở nhiều route hoặc kẹt overlay | TC-12 |
| P0 | Logcat gate chưa bắt buộc cho từng release pass | Crash Flutter/native có thể lọt qua manual test | TC-12 |
| P1 | Font scale/accessibility/RTL thiếu | Arabic/Thai/Bengali/large font dễ overflow | TC-12 |
| P1 | World Map + Story Overlay test mỏng | Story/pre-game overlay cùng Stack dễ che nhau hoặc route sai | TC-12 |
| P1 | Side-mode records/milestones thiếu | Badge record/coin milestone có thể sai, farm reward | TC-12 |
| P1 | Economy negative paths thiếu | Không đủ xu, spam buy, re-open app, duplicate claim | TC-12 |
| P1 | Asset/audio missing fallback thiếu | Audio/image asset fail có thể crash hoặc silent broken UX | TC-12 |
| P1 | Performance/memory chỉ định tính | Cần test matrix cụ thể 10/30 phút + device low-end | TC-12 |
| P2 | Localization coverage chỉ check vài mẫu | Cần sweep 22 locale + placeholder + layout | TC-12 |
| P2 | Data reset chưa cover mọi controller | Có thể còn stale in-memory sau reset | TC-12 |

---

## Test Case Sai/Lệch So Với Code Hiện Tại

| File | Vấn đề | Hướng xử lý |
|------|--------|-------------|
| TC-05 Piggy | Mô tả “đập heo tốn xu nhỏ”, code hiện tại smash cộng `saved` và reset | Đã sửa TC-05, thêm negative/persistence ở TC-12 |
| TC-06 Collection | Mô tả “mảnh sưu tập/skin”, code hiện tại là points + stickers, không cộng xu khi claim | Đã sửa TC-06, thêm duplicate/persistence ở TC-12 |
| TC-08 Ghost | Mô tả ghost “reenact”, code hiện là ghost hint/recorded move overlay theo support hiện tại | Cần test behavior thực tế, không dùng wording quá mạnh |
| TC-10 small screen | Chưa chỉ định device/DPR/font scale/logcat | Bổ sung matrix TC-12 |

---

## Coverage Score

Hai cột tách bạch: **checklist** = độ phủ thủ công của tài liệu QC; **automated** = phần
được test/script chặn tự động (dẫn chứng ở mục "Automation Gates").

| Tiêu chí | Checklist | Automated | Dẫn chứng automation |
|----------|-----------|-----------|----------------------|
| Gameplay happy path | 9/10 | 7/10 | `all_modes_smoke_test.dart` render-guard 14 mode |
| Side mode breadth | 9/10 | 8/10 | smoke 14 mode + Versus entry |
| Animation smoke | 8/10 | 5/10 | chỉ guard render/exception, chưa drive board |
| Release/mobile hardening | 9/10 | 8/10 | `release_device_gate.sh`, `doc_test_cases_test.dart` |
| Data persistence/migration | 9/10 | 6/10 | reset sweep ở unit test; migration vẫn cần device |
| Localization/accessibility | 9/10 | 8/10 | `app_translations_test.dart` placeholder + font-scale widget test |
| Lifecycle / back-stack / resume | 8/10 | 7/10 | `integration_test/app_test.dart` (TC-12) trên device thật |

**Tự đánh giá tổng:** checklist ~8.8/10, automation ~7/10. Đây là ước lượng nội bộ, không
phải điểm tuyệt đối — các case lifecycle/update/logcat phụ thuộc thiết bị/OS nên còn khoảng
trống ngoài unit-widget test. Để tiệm cận 10/10 automation cần device-farm (CI có thiết bị
thật) chạy `integration_test` + `release_device_gate.sh` mỗi release candidate.

---

## Automation Gates Đã Thêm

| Gate | Test |
|------|------|
| Doc index khớp file thật, không stale 11 mode, bảng Markdown hợp lệ | `test/doc_test_cases_test.dart` |
| TC-12/audit bắt buộc tồn tại | `test/doc_test_cases_test.dart` |
| Asset audio/font/icon/shader tồn tại | `test/doc_test_cases_test.dart` |
| Android package id ổn định | `test/doc_test_cases_test.dart` |
| Placeholder i18n khớp English cho mọi locale | `test/app_translations_test.dart` |
| Home 13 cards không crash ở font scale 1.5 | `test/widget/screens_test.dart` |
| Boss HUD không duplicate-key/overflow ở màn hẹp + font scale 1.5 | `test/widget/screens_test.dart` |
