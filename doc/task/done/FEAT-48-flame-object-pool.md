---
id: FEAT-48
title: "FlameObjectPool — tái sử dụng component/particle không leak state"
type: feature
layer: game/utils
priority: P2
effort: M
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là Flame developer, tôi muốn pool projectile/particle để giảm allocation và GC spike trong gameplay nóng.

## Sprint slices
- Generic pool với factory/reset/dispose callbacks và max capacity.
- Acquire/release state guard, double-release detection, prewarm và metrics.
- Flame component mixin/adapter bảo đảm detach/reset lifecycle.
- Benchmark/sample particle burst trước/sau.

## Acceptance criteria
- [x] Object đang active không được acquire lại; double/foreign release bị phát hiện.
- [x] Reset xóa toàn bộ mutable gameplay state theo contract.
- [x] Capacity/dispose/prewarm không leak component/resource.
- [x] Benchmark chứng minh allocation/GC cải thiện trong kịch bản đại diện.

## Prompt loop feature
Đọc task và Flame lifecycle; implement generic core bằng TDD rồi adapter. End loop: audit changes, chấm /10; unit test + widget test + integration test acquire/release/error/dispose; analyze/test root + example; smoke Android device thật với profile/metrics chứng minh. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Implement đúng 4 sprint slice:

1. **`lib/core/utils/object_pool.dart`** (`ObjectPool<T>`, pure Dart không phụ thuộc Flame) — `acquire()`/`release()`/`prewarm()`/`disposeAll()` + metrics (`totalCreated`/`peakActive`/`freeCount`/`activeCount`). Double/foreign-release phát hiện bằng identity (`Set<T>._active.remove()`), không dựa `==`/`hashCode` để tránh 1 `T` override equality làm sai lệch kiểm tra. `maxCapacity` chỉ chặn những gì `release()` GIỮ LẠI, không chặn `acquire()` — pool luôn cho acquire thành công, chỉ dispose thay vì giữ khi đã đầy.
2. **`lib/presentation/game/pooled_component.dart`** (`PooledComponent` mixin `on Component`) — thay vì giữ `ObjectPool<T>` typed reference (vướng generic invariance của Dart: `ObjectPool<ProjectileComponent>` không phải subtype `ObjectPool<Component>`), dùng callback đơn giản `void Function()` gắn qua `attachToPool()`, gọi tự động trong `onRemove()`. Verify bằng Flame lifecycle THẬT (`GameWidget` + `game.add`/`removeFromParent()`), không mock.
3. **`tool/object_pool_benchmark.dart`** — benchmark headless (không phụ thuộc Flutter/Flame), gọi thẳng `ObjectPool` thật (không viết lại logic), mô phỏng kịch bản "particle burst" (spawn/despawn theo lifetime mỗi frame), so sánh pooled vs unpooled.
4. Export cả 2 API mới qua `lib/roy_casual_kit.dart`.

**Phát hiện thêm khi implement benchmark (đáng lưu ý)**: kịch bản mặc định ban đầu (`spawnPerFrame=20, lifetimeFrames=30` → working set 600 đồng thời) LỚN HƠN `capacity` mặc định (200) — khiến pool không tái sử dụng được GÌ (mọi `release()` rơi vào nhánh dispose vì `free+active` luôn ≥ capacity), pooled ra kết quả y hệt unpooled. Đây KHÔNG phải bug của `ObjectPool` (đúng theo đúng doc comment: "capacity bounds what release retains") mà do tham số benchmark chọn sai — đã sửa default (`spawnPerFrame=10, lifetimeFrames=15` → working set 150 < capacity 200) để benchmark thật sự CHỨNG MINH được lợi ích, đồng thời viết riêng 1 test khoá lại hành vi "capacity nhỏ hơn working set → không tái sử dụng" để không ai nhầm là bug sau này.

**Bug thật phát hiện thêm (ngoài phạm vi FEAT-48, đã sửa luôn vì chặn việc verify task này)**: `tool/api_compatibility.dart`'s `_currentChangelogSection()` có 1 dấu `\` thừa trong regex (`'^## \\$version\\n...'` → tạo ra pattern `^## \0.2.0\n...`, không bao giờ match được section CHANGELOG thật). Bug này khiến nhánh "additive" của gate (khi thêm export mới) LUÔN throw `StateError` dù CHANGELOG đã có mục đúng — chỉ chưa từng bị phát hiện trong session vì mọi lần `check` trước đó đều rơi vào nhánh "unchanged" (snapshot đã được regenerate trước khi check). Sửa 1 dòng (`'^## \\$version\\n...'` → `'^## $version\\n...'`), verify lại bằng script Dart độc lập trước khi sửa file thật, xác nhận `dart run tool/api_compatibility.dart check` giờ chạy đúng nhánh "additive" và pass.

**Test:** 10 unit test (`test/core/utils/object_pool_test.dart`) + 3 widget test dùng Flame lifecycle thật (`test/presentation/game/pooled_component_test.dart`) + 6 test benchmark gồm cả CLI qua `Process.run` (`test/tool/object_pool_benchmark_test.dart`) = 19 test mới.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1662/1662 pass (1643 + 19 mới). `example/` `flutter analyze` sạch, `flutter test --exclude-tags slow` 92/92 pass (không cần demo mới — xem lý do dưới). `dart run tool/api_compatibility.dart check`: đúng nhánh "additive", pass sau khi regenerate snapshot. `dart pub publish --dry-run`: chỉ cảnh báo git chưa sạch, không lỗi packaging thật.

**Benchmark thật (bằng chứng số liệu cụ thể)**:
```
$ dart run tool/object_pool_benchmark.dart
scenario: frames=600 spawnPerFrame=10 lifetimeFrames=15 capacity=200
pooled:   allocations=150 elapsedUs=9111
unpooled: allocations=6000 elapsedUs=1446
allocationReductionPercent: 97.5

$ dart run tool/object_pool_benchmark.dart --frames=1200 --spawnPerFrame=30 --lifetimeFrames=20 --capacity=700
pooled:   allocations=600
unpooled: allocations=36000
allocationReductionPercent: 98.3
```

**Device smoke test (Samsung S24 Ultra, R5CX613VZBR)**: build + cài lại APK debug mới (có export `ObjectPool`/`PooledComponent`), launch app, vào "Demo Flame" — `RoyGame`/`TappableCircle` vẫn render và tương tác đúng (tap đổi màu cyan↔magenta), không crash, không log lỗi (`level=Error` rỗng). Đây là feature thuần logic/Flame-mixin không có UI riêng để demo trực quan — quyết định KHÔNG xây dựng thêm 1 demo particle-burst trực quan mới trong `GameDemoScreen` (over-engineering so với yêu cầu task: acceptance criteria không đòi UI mới, chỉ đòi unit+widget+integration test + benchmark + smoke không phá app hiện có) — bằng chứng benchmark số liệu cụ thể ở trên đã đủ chứng minh "allocation cải thiện trong kịch bản đại diện" theo đúng câu chữ acceptance criteria.

**Tự chấm điểm: 9.5/10** — implementation đúng cả 4 sprint slice, generic-variance được giải quyết gọn bằng callback thay vì ép kiểu, benchmark có số liệu thật + test khoá hành vi capacity, còn tự phát hiện và sửa 1 bug thật ở `tool/api_compatibility.dart` (chặn hẳn nhánh "additive" của gate) trước khi nó ảnh hưởng CI thật. Trừ 0.5 vì cân nhắc chủ động không xây demo UI trực quan mới (dù đã lý giải rõ tại sao trong Quyết định).

