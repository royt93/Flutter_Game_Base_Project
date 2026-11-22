---
id: FEAT-212
title: "Đưa Match3Engine từ example sang package để mọi game ghép hình dùng lại"
type: feature
layer: lib/core (engine thuần Dart) + example
priority: P2
effort: M
source: "Owner chọn hướng game 2026-11-22; Match3Engine (412 dòng, chỉ import dart:math) và test đã có ở example/lib/game, chưa nằm trong package nên consumer không dùng được"
---

## Hiện trạng đã xác minh

- `example/lib/game/match3_engine.dart`: `Match3Engine`, `Match3Level`, `Match3Swap`, `Match3CascadeStep`, `Match3Status`; chỉ phụ thuộc `dart:math`.
- Test hiện có: `example/test/match3_engine_test.dart`; màn dùng nó: `example/lib/screens/match3_lite_screen.dart` (697 dòng, gồm lưu game, năng lượng, quest, thành tựu, bảng điểm).
- Package có sẵn `SeededRandom`, `ReplayRecorder`, `GameSessionController`: engine hiện nhận `math.Random`, chưa tận dụng được replay xác định.

## Phạm vi đề xuất

- Chuyển engine sang `lib/` (thuần Dart, không import Flutter/Flame), export qua `lib/roy_casual_kit.dart`. Đổi `Match3Engine` nhận `math.Random` (tương thích `SeededRandom` vì nó implement `Random`).
- Chỉ chuyển engine + model, KHÔNG chuyển UI/save của `Match3LiteScreen` (đó là demo, ở lại example).
- Chốt API công khai tối thiểu trước khi export (đây là public API, sai là breaking về sau): ví dụ giữ board dạng `List<int>` hay kiểu tile riêng.
- Bump minor (thêm API), cập nhật `tool/api_snapshot.json` và CHANGELOG.

## Câu hỏi owner cần chốt trước khi code

- Kích thước/số loại tile và luật level có cố định theo `Match3Level.forNumber`, hay consumer tự cấu hình level?
- Có cần booster (bom, line clear) trong engine không, hay để ngoài phạm vi?

## Acceptance criteria

- [ ] Engine ở `lib/`, không phụ thuộc Flutter; `flutter analyze` sạch.
- [ ] Test engine chuyển sang `test/` (cùng độ phủ trở lên), thêm test replay xác định: cùng seed + cùng chuỗi swap cho cùng board/score.
- [ ] `example` import từ package, `Match3LiteScreen` và test màn hình vẫn pass, không đổi hành vi.
- [ ] API snapshot + CHANGELOG cập nhật; `dart run tool/api_compatibility.dart check` xanh.
- [ ] Audit điểm >9/10; docs-only không áp dụng; device smoke Match3 Lite trên thiết bị thật nếu hành vi màn hình có thể đổi.

## Kết quả thực hiện

- Owner decision:
- Audit / điểm:
- Tests/device smoke:
- Commit/push:
