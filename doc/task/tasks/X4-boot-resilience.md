# X4 — Boot resilience (try/catch khởi động)

**Epic:** Floor/UX · **SP:** 2 · **Pri:** Must · **Deps:** none

## Mục tiêu
Bọc try/catch quanh khởi tạo `SharedPreferences`/`StorageService` trong
`main.dart` — lỗi khởi tạo (thiết bị hiếm, storage hỏng) không được làm app
crash trắng màn hình.

## Vì sao
Gap floor quan trọng — hiện `main.dart` không xử lý lỗi khởi tạo storage,
crash ở bước này là crash không thể phục hồi (mất trải nghiệm hoàn toàn).

## Acceptance criteria
- [x] Lỗi khi khởi tạo `SharedPreferences`/`StorageService` → log qua `dlog`,
      app vẫn chạy tiếp với giá trị mặc định an toàn (không unlock sai, không
      mất tiến độ giả).
- [x] Không nuốt lỗi khác không liên quan tới boot storage (chỉ bọc đúng đoạn
      init).
- [x] Unit/widget test: giả lập init lỗi, xác nhận app không crash, vẫn build
      được `MaterialApp` — `test/widget/boot_resilience_test.dart`: construct
      `StorageService(null)` (nhánh catch thật của `_loadPrefs()`), pump
      `HomeScreen`, assert `takeException()` null + UI render đúng (2026-07-14).

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `_loadPrefs()` (`lib/main.dart:58-63`) bọc try/catch quanh
`SharedPreferences.getInstance()`, log qua `dlog` và trả `null` khi lỗi;
`StorageService(this._prefs)` nhận `SharedPreferences?` và mọi getter/setter
fallback về `_fallback` map in-memory khi `_prefs == null`
(`lib/core/storage_service.dart:80-110`) — không unlock sai/mất tiến độ giả.
Try/catch chỉ bọc đúng đoạn gọi `SharedPreferences.getInstance()`, không lan
ra phần init khác của `main()`. Không tìm thấy test nào construct
`StorageService(null)` hoặc mock throw để verify `MaterialApp` vẫn build khi
boot lỗi — để nguyên chưa tick, ghi chú rõ.

## Subtasks (gợi ý file)
1. `lib/main.dart`: bọc try/catch quanh đoạn init `StorageService`/
   `SharedPreferences`.

## Ghi chú kỹ thuật
Chỉ bọc đúng đoạn init storage — không thêm try/catch lan man khắp
`main.dart`.

DoD chung: `../README.md`.
