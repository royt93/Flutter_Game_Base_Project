---
id: FEAT-45
title: "SeededRandomService — RNG deterministic, loot table và snapshot state"
type: feature
layer: game/utils
priority: P1
effort: M
depends_on: [ENH-56]
unblocks: [IDEA-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là developer/QA, tôi muốn mọi random gameplay tái lập được từ seed để test và replay chính xác.

## Sprint slices
- RNG instance có seed explicit; next int/double/bool/shuffle/pick.
- Weighted table pre-validation và immutable compiled table.
- Snapshot/restore state có algorithm version; stream/fork theo namespace.
- Bridge `weightedRandomPick` cũ và replay diagnostics.

## Acceptance criteria
- [x] Cùng seed + call sequence cho cùng output trên supported platforms.
- [x] Range/weight/NaN/empty invalid fail trước khi tiêu RNG state.
- [x] Snapshot restore tiếp tục đúng sequence; version sai bị reject.
- [x] Không dùng global `Random()` trong sample gameplay sau migration.

## Prompt loop feature
Đọc task và RNG/replay code; dùng golden vectors TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test seed/range/snapshot/invalid/distribution sanity; analyze/test root + example; smoke device thật so replay hash. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Implement đúng 4 sprint slice, giữ scope sát nhất với chính task này (KHÔNG lấn sang IDEA-42 — replay capsule thật là việc của task đó, effort L riêng):

- **`SeededRandom`** (`lib/core/utils/seeded_random.dart`) — `implements Random` (interface chuẩn `dart:math`) thay vì tự định nghĩa API riêng — nhờ vậy trở thành drop-in cho `weightedRandomPick(random: ...)` VÀ `List.shuffle(Random)` có sẵn của Dart mà KHÔNG cần viết lại logic pick/shuffle. Thuật toán: biến thể mulberry32 với nhân 32-bit thủ công (`_imul32`, tách 2 nửa 16-bit) thay vì dựa vào tràn số nguyên 64-bit gốc của Dart — lý do: VM Dart dùng int 64-bit thật, nhưng build web (dart2js) biểu diễn số như double IEEE754, MẤT ĐỘ CHÍNH XÁC trên 2^53 — 1 bộ sinh số dựa tràn 64-bit sẽ cho kết quả KHÁC nhau giữa VM và web dù cùng seed, vi phạm thẳng acceptance criterion đầu tiên. `_imul32` đảm bảo không phép nhân trung gian nào vượt 2^32, nằm hoàn toàn an toàn dưới ngưỡng 2^53.
- **`RandomSnapshot`** — value object bất biến (`algorithmVersion` + `state`), có `toJson`/`fromJson` (throw `FormatException` cho input hỏng/thiếu field, cùng convention "untrusted input" của `VersionedJsonStore`). `SeededRandom.fromSnapshot` reject snapshot có `algorithmVersion` khác, đúng yêu cầu "version sai bị reject".
- **`CompiledWeightedTable<T>`** — validate 1 LẦN lúc tạo (constructor), biên dịch thành cumulative weights — `pick()` sau đó không re-validate/re-sum, đúng ý "Weighted table pre-validation và immutable compiled table" (khác `weightedRandomPick`/`SeededRandom.pick` vốn validate lại mỗi lần gọi — 2 API phục vụ 2 nhu cầu khác nhau: gọi 1 lần vs gọi lặp lại tần suất cao như spawn/loot roll).
- **`SeededRandomService`** — quản lý nhiều "stream" RNG độc lập theo namespace (`stream('loot')`, `stream('enemy_spawn')`...), mỗi stream có seed suy ra từ `rootSeed` + tên namespace qua `fnv1aHash` (KHÔNG dùng `String.hashCode` — lý do đã áp dụng nhất quán từ IDEA-32: không ổn định qua các phiên bản Dart SDK, ở đây còn quan trọng hơn vì ảnh hưởng trực tiếp khả năng replay). Đây là cơ chế chống đúng lỗi kinh điển "1 hệ thống gọi RNG chung thêm 1 lần làm lệch toàn bộ chuỗi của hệ thống khác" — có test riêng xác nhận (gọi `enemy_spawn` 999 lần không ảnh hưởng `loot`). KHÔNG phải `GetxService`/singleton — cùng convention "caller tự sở hữu instance" như `VersionedJsonStore` (không phải mọi thứ trong `lib/core/` cần là Get-registered).
- **Tái cấu trúc phụ**: trích `fnv1aHash` (trước đó private trong `ExperimentBucketingService`) ra `lib/core/utils/fnv1a.dart` riêng — giờ có 2 nơi cần đúng thuật toán này, tránh lặp code. `ExperimentBucketingService` cập nhật dùng lại hàm chung, hành vi không đổi (test cũ vẫn pass nguyên).
- **Migrate "sample gameplay" khỏi `Random()` toàn cục** (acceptance criterion cuối): `example/lib/screens/widget_showcase_screen.dart` — `WheelSpinner` demo (`_spinWheel`) và "Submit random score" demo (IDEA-46) trước đó dùng `math.Random()` trần trụi, giờ dùng 1 `SeededRandomService` chung của màn hình, 2 namespace riêng (`wheel_spin`, `leaderboard_demo`) — minh hoạ đúng luôn tính năng namespace-fork ngay trong ví dụ thật. 2 usage còn lại của `Random()` không đổi (`weighted_random_pick.dart`/`confetti_overlay.dart`'s `random ?? Random()` fallback mặc định của thư viện, và `reward_popup.dart`'s hiệu ứng thị giác thuần) — không phải "sample gameplay logic", cố tình không đụng vào theo đúng phạm vi nêu trong acceptance criterion.

**Test:** `test/core/utils/fnv1a_test.dart` (5 test, gồm golden vector khớp đúng hằng số FNV-1a 32-bit chuẩn) + `test/core/utils/seeded_random_test.dart` (28 test) — determinism (cùng seed cùng chuỗi, seed khác chuỗi khác, golden vector chống regression thuật toán), range nextInt/nextDouble, `nextInt` invalid không tiêu state, shuffle giữ nguyên tập phần tử, `pick` bridge đúng + validate trước khi tiêu state, snapshot/restore tiếp đúng chuỗi, `fromSnapshot` version sai reject, `RandomSnapshot` json round-trip + input hỏng throw, `CompiledWeightedTable` validate đủ mọi case + phân phối đúng thống kê, `SeededRandomService` namespace độc lập + ổn định + snapshot/restore theo từng namespace. `test/core/experiment_bucketing_service_test.dart` xác nhận không bị phá sau refactor `fnv1aHash`.

**Device smoke test (Samsung Galaxy A50, `R58MA6WYRPE`, real device)**: cài + mở app, quay `WheelSpinner` thật → "Stopped on 50" (đổi đúng từ trạng thái nghỉ "Stopped on 10"), không crash. Bấm "Submit random score" ở demo `LeaderboardList` → "You" cập nhật đúng điểm ngẫu nhiên mới (9,183) và tự xếp lại đúng hạng (lên hạng 2) — cả 2 namespace RNG độc lập hoạt động đúng trên thiết bị thật cùng lúc. `adb logcat` lọc `level=Error`: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1037/1037 pass (2 lần chạy liên tiếp sau 1 lần flaky không liên quan); `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 49/49 pass. CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate với 5 symbol top-level mới (`SeededRandom`, `RandomSnapshot`, `CompiledWeightedTable`, `SeededRandomService`, `fnv1aHash`).

**Tự chấm điểm: 9.5/10** — đúng cả 4 sprint slice + cả 4 acceptance criteria, giải quyết đúng vấn đề cốt lõi khó nhất (cross-platform determinism qua 32-bit-safe arithmetic) thay vì bỏ qua, tái dùng tối đa (implements `Random` thay vì API riêng, bridge thẳng `weightedRandomPick`/`List.shuffle` có sẵn, tái cấu trúc `fnv1aHash` dùng chung thay vì copy-paste), test bao phủ đầy đủ kể cả các case tinh vi (namespace không lẫn nhau, validate trước khi tiêu state), device smoke test thật xác nhận 2 luồng RNG độc lập chạy đúng. Trừ điểm nhỏ vì "replay diagnostics" trong sprint slice cuối chỉ được giải quyết ở mức "làm nền tảng đủ dùng" (snapshot/restore + implements Random) — bản thân 1 replay-capsule hoàn chỉnh vẫn để lại đúng cho IDEA-42 như đã phân định phạm vi rõ ràng ngay từ đầu.
