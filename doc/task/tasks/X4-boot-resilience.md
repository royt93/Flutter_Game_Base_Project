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
- [ ] Lỗi khi khởi tạo `SharedPreferences`/`StorageService` → log qua `dlog`,
      app vẫn chạy tiếp với giá trị mặc định an toàn (không unlock sai, không
      mất tiến độ giả).
- [ ] Không nuốt lỗi khác không liên quan tới boot storage (chỉ bọc đúng đoạn
      init).
- [ ] Unit/widget test: giả lập init lỗi (mock throw), xác nhận app không
      crash, vẫn build được `MaterialApp`.

## Subtasks (gợi ý file)
1. `lib/main.dart`: bọc try/catch quanh đoạn init `StorageService`/
   `SharedPreferences`.

## Ghi chú kỹ thuật
Chỉ bọc đúng đoạn init storage — không thêm try/catch lan man khắp
`main.dart`.

DoD chung: `../README.md`.
