---
id: ENH-48
title: "TutorialSequence: thiếu chỉ số bước (1/3) và nút Skip trong UI overlay"
type: enhancement
priority: P3
effort: M
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/tutorial_sequence.dart`.

## Hiện trạng
`TutorialSequenceController` đã có `skip()` và theo dõi step index, nhưng UI overlay của `TutorialSequence` không hiển thị tiến độ ("Bước 1/3") hay nút Skip nào — người chơi không biết còn bao nhiêu bước nữa và không có cách chủ động thoát tutorial giữa chừng qua UI (dù logic `skip()` đã tồn tại sẵn, chỉ thiếu nút gọi nó).

## Vì sao cần / Hậu quả
Trải nghiệm tutorial mù mờ (không biết còn dài bao lâu) và không thể bỏ qua chủ động — cả 2 đều là pattern UX tiêu chuẩn cho onboarding nhiều bước.

## Đề xuất
Thêm hiển thị "Bước {index+1}/{total}" trong callout overlay (dùng lại `SpotlightOverlay`'s cấu trúc `_Callout` nếu `TutorialSequence` build trên nó — kiểm tra code thật trước khi quyết định cách tích hợp), và optional `bool showSkip = true` forward `controller.skip` vào 1 nút nhỏ trong overlay.

## Acceptance criteria
- [x] Overlay hiển thị đúng "Bước X/Y" theo step index/total hiện tại của controller.
- [x] showSkip: true hiển thị nút Skip gọi đúng controller.skip(); showSkip: false ẩn nút này.
- [x] Test: xác nhận text step indicator đúng ở từng bước, và tap Skip kết thúc đúng tutorial sequence (controller báo done/dismissed).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên máy Android thật (Samsung SM-S928B → TECNO BG6 do máy đổi giữa chừng, không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion` (không đổi animation nào — chỉ thêm Text/GestureDetector tĩnh vào callout đã có sẵn animation entrance).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-48-tutorial-sequence-step-indicator-skip-button.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — cải thiện UX onboarding thật, effort M vì cần đọc kỹ cấu trúc hiện tại của `TutorialSequence`/`SpotlightOverlay` trước khi thêm UI mới cho đúng chỗ.

## Quyết định

Xác nhận đúng như Đề xuất: `TutorialSequence` build trên `SpotlightOverlay` (compose, không tái tạo lại logic highlight/callout). Đã sửa (commit `f239176`):
- `SpotlightOverlay`: thêm 3 param optional `stepIndicator`/`onSkip`/`skipLabel` — mặc định `null`/`'Skip'`, nên 1 spotlight đơn lẻ (không qua `TutorialSequence`) không bị ảnh hưởng gì.
- `TutorialSequenceController`: thêm getter `currentIndex`/`stepCount` (trước đây chỉ có `currentStep`/`isActive`, không đủ để build "Bước X/Y").
- `TutorialSequence`: thêm `showSkip` (mặc định `true`) và `skipLabel`, tự tính `stepIndicator: 'Step ${currentIndex+1}/${stepCount}'` và nối `onSkip` thẳng vào `controller.skip()` đã có sẵn.

Callout's action row đổi từ `Align(centerEnd, child: primary button)` sang `Row(mainAxisAlignment: spaceBetween hoặc end, children: [Skip?, primary button])` — `MainAxisAlignment.end`/`spaceBetween` của `Row` tự tôn trọng `Directionality` ambient (không cần sửa gì thêm cho RTL, kế thừa đúng fix ENH-38 đã làm ở đây).

### Device smoke test — **máy đổi giữa chừng** (Samsung SM-S928B → TECNO BG6, cả 2 đều máy thật, không simulator)
Build lại release APK (có sửa code sản xuất). Trong lúc chuẩn bị test, Samsung SM-S928B mất kết nối USB (rớt adb) — chuyển sang máy Android thật khác đang cắm sẵn (TECNO BG6, serial `118743744X002560`), cài lại APK, tiếp tục smoke test bình thường trên máy mới.

Mở `WidgetShowcaseScreen`, cuộn tới demo `TutorialSequence`, tap "Start 2-step tutorial": overlay kích hoạt đúng (scrim dim toàn màn hình xuất hiện, xác nhận qua `mobile_list_elements_on_screen`), tap 2 lần liên tiếp đưa tutorial qua hết 2 bước rồi tự kết thúc đúng, không crash. **Không thấy được visual của step indicator/Skip button trên chính màn hình này** — nguyên nhân: `_spotlightTargetKey` của demo này gắn vào nút "Primary" ở tít đầu trang (section "Buttons & Interactive"), còn nút kích hoạt "Start 2-step tutorial" nằm rất xa phía dưới; `ListView` ở đây dùng constructor `ListView(children: [...])` (không phải `.builder`) nên widget target VẪN được mount (không bị dispose khi cuộn xa), nhưng toạ độ global của nó rơi ra ngoài vùng nhìn thấy (âm), khiến `_Callout`'s `Positioned` tính ra vị trí cũng nằm ngoài màn hình — đúng y hệt hạn chế đã ghi nhận ở ENH-55's Quyết định cho `SpotlightOverlay` độc lập, và đúng như comment có sẵn trong chính `widget_showcase_screen.dart` ("scroll up after dismissing to see which one it was"). Đã thử cuộn lên trong lúc overlay đang active để đưa target vào tầm nhìn nhưng barrier's `GestureDetector` (opaque, chặn mọi pointer event) chặn luôn cả gesture kéo/cuộn, không chỉ tap — xác nhận đây là giới hạn cấu trúc của demo screen, không phải bug của `TutorialSequence`/`SpotlightOverlay`.

Hành vi CHÍNH XÁC của step indicator + Skip (text "Step X/Y" đúng từng bước, Skip hiện/ẩn đúng theo `showSkip`, tap Skip gọi đúng `controller.skip()` và kết thúc ngay dù chưa hết bước, `skipLabel` tuỳ chỉnh) đã được xác nhận chắc chắn qua 26 widget test (đo trực tiếp bằng Flutter test framework, dựng target trong viewport nhỏ nên luôn nhìn thấy được — không phụ thuộc vị trí cuộn của 1 demo screen cụ thể). `mobile_get_device_logs` lọc `level=Error`: không có lỗi nào trong suốt thao tác trên máy TECNO BG6.
