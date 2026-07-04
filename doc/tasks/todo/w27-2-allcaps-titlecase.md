---
id: w27-2-allcaps-titlecase
title: Audit chữ ALL-CAPS trong app → viết hoa chữ cái đầu (title case)
wave: 27
phase: 2
status: todo
owner: claude
created: 2026-07-04
---

# Phase 2 — ALL-CAPS → Title case (mọi ngôn ngữ)

Nhiều string hiển thị hiện đang dùng CHỮ IN HOA TOÀN BỘ (ALL-CAPS) — ví dụ đã thấy trên Home/HUD:
nút "CHƠI NGAY", header "THỬ THÁCH" / "PHẦN THƯỞNG", HUD boss "TRÙM NEON 1". Đổi sang **viết hoa chữ
cái đầu** (Title Case / Sentence case) cho tự nhiên hơn, áp dụng cho tất cả 22 ngôn ngữ.

## Bước 1 — Khảo sát (làm trước khi sửa)
- [ ] Grep các key trong `AppTranslations` (`lib/core/app_translations.dart`) có giá trị tiếng Việt
  toàn chữ hoa (heuristic: `RegExp(r'^[A-ZÀ-Ỹ0-9 ·!?]+$')`), liệt kê danh sách key cụ thể.
- [ ] Grep trong `lib/presentation/screens/**/*.dart` và `lib/presentation/controllers/**/*.dart` các
  chỗ dùng `.toUpperCase()` khi render text UI (thủ phạm khả năng cao gây ALL-CAPS bất kể translation
  gốc là gì).
- [ ] Chốt danh sách vị trí cần đổi trước khi sửa hàng loạt — tránh bỏ sót hoặc sửa nhầm chỗ đang
  ALL-CAPS có chủ đích (ví dụ: mã lỗi, tên viết tắt cố định).

## Bước 2 — Câu hỏi cần chốt trước khi thực thi
- [ ] **Dùng `AskUserQuestion`** hỏi cách xử lý viết tắt ngắn xuất hiện giữa câu (nếu có, ví dụ HP/PV/
  LP hoặc tên viết tắt khác từng thấy trong log/HUD): giữ nguyên toàn chữ hoa (vì là acronym) hay đổi
  theo title case như phần còn lại? — không tự quyết định một mình vì ảnh hưởng thẩm mỹ tuỳ chọn.

## Bước 3 — Thực thi
- [ ] Sửa từng giá trị trong `_extraEn`/`_extraVi` (và tương ứng trong mọi `_wXXByLang` map hiện có
  chứa key đó) từ ALL-CAPS → title case, giữ nguyên semantics.
- [ ] Xoá/thay `.toUpperCase()` tại các điểm render nếu phát hiện đó là nguồn gây ALL-CAPS (thay bằng
  hiển thị trực tiếp giá trị translation đã ở dạng title case).
- [ ] Rà lại tỉ lệ khác-English mỗi ngôn ngữ vẫn ≥79-80% sau khi sửa (test `app_translations_test.dart`
  sẽ tự chạy — không cần tính tay).

## Acceptance
- [ ] `flutter analyze` 0 issue.
- [ ] `flutter test --exclude-tags slow` xanh, đặc biệt `app_translations_test.dart`.
- [ ] Device-verify bằng mắt: Home (nút, header), HUD in-game (boss name, mode label) không còn text
  ALL-CAPS ngoài các acronym đã chốt giữ nguyên ở Bước 2.

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Không đổi key/logic, chỉ đổi **giá trị string hiển thị**.
- Nếu Bước 1 phát hiện phạm vi quá lớn (nhiều màn hình), có thể chia nhỏ theo màn hình trong lúc thực
  thi — nhưng không cần thêm task doc riêng, ghi tiến độ ngay trong file này (progress note `>`).
