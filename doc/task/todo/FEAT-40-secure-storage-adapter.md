---
id: FEAT-40
title: "SecureStorageAdapter — seam lưu token/secret không ép vendor"
type: feature
layer: data/core
priority: P1
effort: S
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app developer, tôi muốn SDK phân biệt preferences thường với token/secret cần secure storage.

## Sprint slices
- Interface stateless `read/write/delete/clear` và capability result.
- GetX registration + `.maybe`; không thêm concrete secure-storage dependency.
- In-memory fake cho test; quy tắc không fallback secret sang SharedPreferences.
- Hướng dẫn adapter cho platform package ở consumer.

## Acceptance criteria
- [ ] Thiếu adapter trả failure rõ, không lưu secret vào storage thường.
- [ ] Read/write/delete/clear và platform error giữ contract typed.
- [ ] Key/value invalid, concurrent write và dispose có test.
- [ ] Health report chỉ hiện capability, không hiện key/value.

## Prompt loop feature
Đọc task và storage/error model; implement seam bằng TDD. End loop: audit code, chấm /10; unit test + widget test + integration test mọi operation/error/concurrency; analyze/test root + example; smoke Android device thật bằng adapter demo và log redacted. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

