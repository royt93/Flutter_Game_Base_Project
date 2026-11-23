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

- Owner decision (2026-11-23): cấu hình bàn/tile/level qua constructor, mặc định giữ 6x6/5/5 level; thêm booster do người chơi chủ động dùng, không tốn lượt (line clear, bom).
- Thay đổi: engine chuyển `example/lib/game/match3_engine.dart` -> `lib/core/match3_engine.dart` (export từ `roy_casual_kit.dart`); thêm `Match3Config` (validate bằng `ArgumentError`, theo ENH-85) và `Match3Booster`/`useBooster` (rowClear, columnClear, bomb 3x3). Bỏ board dự phòng 6x6 cứng, thay bằng thử sinh lại (ném `StateError` nếu config không sinh nổi board chơi được). `example` (screen, 2 test, `tool/match3_sim.dart`) chuyển sang `Match3Config.classic`; `MatchLite` chỉ bỏ `const` ở grid delegate.
- Bằng chứng không đổi hành vi: `tool/match3_sim.dart` (4 bot x 5 level x 200 ván, seed cố định) cho output giống hệt 20 dòng giữa HEAD và bản mới; 12 test engine cũ pass nguyên.
- Tests: 9 test mới (config hợp lệ/không hợp lệ, 8x8 6 tile, độ dài initialBoard, booster không tốn lượt, vùng xoá đúng, biên/góc, từ chối index sai và ván đã kết thúc, booster thắng/thua, replay xác định với `SeededRandom`). Mutation check: sửa bán kính bom và cho booster tốn lượt đều làm test đỏ. Root 4097 pass, example 435 pass, analyze 2 package sạch, API gate/accessibility/deprecation/license/perf/SBOM xanh.
- API: chỉ thêm (Added 20 symbol, Removed rỗng), ghi vào mục 0.8.0 chưa tag, không bump thêm. Snapshot cập nhật.
- Chưa làm: device smoke Match3 Lite trên thiết bị thật (screen đổi rất ít, widget test pass); chưa có UI nối `BoosterSlotBar` với `useBooster` (ngoài phạm vi, thuộc demo FEAT-214).
- Audit / điểm: ~9.2/10. Trừ điểm: chưa smoke thiết bị thật; booster chưa có luật tạo từ match 4/5; `Match3Level.levels` vẫn là static trong API công khai.
- Commit/push:
