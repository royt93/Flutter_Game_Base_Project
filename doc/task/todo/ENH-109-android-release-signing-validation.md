---
id: ENH-109
title: "Gradle báo lỗi sớm khi thiếu Android release signing config"
type: enhancement
layer: example/android
priority: P1
effort: S
source: "Full source audit 2026-11-21; release signing fields default empty and keystore path optional"
---

## Bằng chứng cần xác nhận

`release` build type gắn signing config nhưng cấu hình cho phép thiếu `KEYSTORE_PATH`, passwords hoặc alias rồi mới lỗi ở bước ký. Cần xác minh hành vi với Gradle hiện tại và expected release flow trước khi kết luận mức lỗi.

- `example/android/app/build.gradle.kts:44-60`
- `example/android/app.properties.example`

## Phạm vi

Nếu xác minh lỗi thực sự không rõ hoặc build có thể đi sai signing path, fail fast với thông báo setup cụ thể cho release build. Debug build phải tiếp tục chạy không cần private signing config. Không thêm secret/key vào repo, không đổi keystore, alias hay signing policy.

## Acceptance criteria

- [ ] Fresh checkout thiếu `app.properties`: debug assemble thành công; release task thất bại sớm với hướng dẫn chính xác.
- [ ] Release config hợp lệ từ external private config vẫn ký đúng certificate hiện hành.
- [ ] Task không đọc/in secret values trong log, không thay đổi `.gitignore` safety boundary.
- [ ] Gradle/unit validation test phù hợp; integration build verification Android; widget test không áp dụng vì không đổi UI (ghi lý do).
- [ ] Audit diff, điểm >9/10 theo correctness 4, configuration/security 3, tests 1, maintainability 1, device/build evidence 1.
- [ ] Smoke trên physical Android device bằng debug build; không cài release build nếu chưa xác minh ad/test-device an toàn. Ghi model/OS/build/commit/log. Không simulator.

## Prompt loop

Đọc task, Gradle DSL, Flutter Android build types, local setup docs và CI build commands. Trước khi sửa, tái hiện fresh-config debug/release behavior mà không in secret. Nếu intended release signing semantics chưa rõ, dừng hỏi owner. Nếu confirmed, viết kiểm tra nhỏ nhất chỉ áp dụng release tasks, giữ debug độc lập. Thêm regression validation cho missing/valid properties, chạy Android integration build, analyze/tests phù hợp và smoke debug trên device thật. Audit diff và chấm /10 theo rubric; lặp tới >9/10 và mọi acceptance đạt. Dừng nếu thay đổi có thể ảnh hưởng ad safety, certificate, hoặc cần secret/CI thay ngoài scope; không push khi gate thiếu. Khi mọi gates đạt và điểm >9/10, ghi kết quả rồi push code theo yêu cầu owner.

## Kết quả thực hiện

- Kết quả xác minh: lỗi thật. Thiếu `app.properties`, `flutter build apk --release` chạy ~2 phút rồi mới fail ở `:app:packageRelease` với `SigningConfig "release" is missing required property "storeFile"`.
- Fix: `example/android/app/build.gradle.kts` thêm check trong `gradle.taskGraph.whenReady`, chỉ chạy khi graph có `packageRelease`/`packageReleaseBundle`. Thiếu `KEYSTORE_PATH`/`KS_ALIAS`/`KS_PW` hoặc keystore không tồn tại thì fail sớm, chỉ in tên key, không in value. Signing config, `.gitignore` không đổi.
- Tests/build: debug apk build OK cả khi xoá tạm `app.properties`. Release thiếu config: fail sớm với hướng dẫn đúng. Release với `app.properties` hiện có: build OK 69.4MB, cùng signing config.
- Audit / điểm: ~9.3/10. Certificate: SHA-256 của keystore khớp apk release (`30:98:3F:E2:...:3B:9C`, fingerprint công khai, không lộ secret). Điểm trừ: check Gradle chưa có test tự động, chỉ verify tay 3 case. Check dùng cùng cách resolve path `file(KEYSTORE_PATH)` với signingConfig nên không lệch.
- Device smoke: không áp dụng (chỉ đổi Gradle build logic, không đổi runtime app).
