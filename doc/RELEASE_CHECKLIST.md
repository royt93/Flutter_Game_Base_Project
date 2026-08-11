# Release Checklist — Pop Star Blast

Campaign 260 màn (13 world) + shop booster + 14 side mode + lớp meta-progression
(prestige, achievement, weekly goal, login streak, season pass, cosmetics...).

**Xác nhận verify thật gần nhất: 2026-08-08, version `2026.08.08+20260808`**,
sau khi Round-8 (World 13, Ice Tile/Frost Rush, Combo Rush, Remix Levels,
Sticker Album, Daily Quest reminder) hoàn tất. Build release APK + AAB **thật**
(không phải debug) đã build, cài, và smoke test trên thiết bị Android thật
(Oppo CPH1989) trong phiên này — không phải suy đoán từ debug build trước đó.

⚠️ **Rủi ro bảo mật đã biết, chấp nhận có chủ đích**: `android/keystore.jks` +
`android/gradle.properties` (chứa mật khẩu ký release) từng bị commit vào git
history. Theo quyết định của chủ repo (repo private, chỉ một mình biết), **không
rotate keystore, không purge git history** — chỉ chặn rò rỉ thêm về sau bằng
`.gitignore` + untrack khỏi index. Xem `CLAUDE.md`/ghi chú phiên làm việc nếu
cần lý do đầy đủ.

## A. Tự động

- [x] `flutter analyze` → 0 issue
- [x] `flutter test --exclude-tags slow` → all pass (749 test tại thời điểm Round-8)
- [x] `flutter test integration_test/ -d <device>` → pass (cần `--dart-define=E2E_TEST=true`)
- [x] Build release: `flutter build apk --release` **và** `flutter build appbundle --release`
      → pass, không lỗi minify/R8 (2026-08-08)
- [x] Smoke release APK thật trên device thật (Oppo CPH1989, `adb install -r`)
      → không crash, không lộ raw i18n key, không quảng cáo (2026-08-08)

## B. Kiểm tay

### B1. Gameplay
- [x] Tap nhóm ≥2 ô cùng màu → nổ (animation pop + hạt), điểm đúng `5*n*(n-1)`
- [x] Cột rơi/dồn trái mượt (tween), không refill từ trên
- [x] Dọn sạch bàn → +1000 bonus, không crash
- [x] Bàn kẹt (không còn nhóm ≥2) → dialog thua
- [x] Đạt/vượt target → dialog thắng + confetti, tính sao đúng (1/2/3)
- [x] Booster bomb/shuffle/undo: mua đúng giá, dùng đúng, trừ đúng số lượng
- [x] Thắng → mở khoá màn kế; quay lại Level Select thấy cập nhật ngay

### B2. Localization
- [x] Đổi ngôn ngữ trong Settings → app đổi ngay, không crash
- [x] Không lộ raw translation key trên bất kỳ màn nào (22 ngôn ngữ)

### B3. Lifecycle
- [x] Background ↔ Resume giữa ván không mất tiến trình/crash
- [x] Reset Progress → Cancel không đổi; Reset → xoá sạch coin/level/star/booster về mặc định

### B4. UI / Store sanity
- [x] Style bright-casual nhất quán mọi screen; label đọc rõ (stroke)
- [x] Version footer khớp `pubspec.yaml` + build number
- [x] App icon / splash đúng brand
- [x] Package id = `com.galaxyjoy.pop_star_blast` (Android), `com.galaxyjoy.popStarBlast*` (iOS)
- [x] Không còn tham chiếu `neon_jewels`: `grep -r neon_jewels lib android ios pubspec.yaml`
- [x] Không có ad SDK / quyền AD_ID thừa
- [x] Version footer hiển thị đúng bản mới nhất (`v2026.08.08+20260808`, xác nhận
      trên màn home của **bản release thật**, không phải debug)

### B5. Round-8 — side mode & meta-progression (smoke trên bản release thật)
Bao phủ tối thiểu để bắt lỗi riêng của release build (R8/ProGuard minify) mà
QA debug-build trước đó (Round-8 code-review + fix, xem `feat.md`) không phơi
bày. Không lặp lại toàn bộ regression suite — chỉ đường đi chính:
- [x] Home → vào 1 level campaign, tap pop 1 nhóm → điểm cộng đúng, không crash
- [x] Trophy Room (Phòng Vinh Danh) mở qua menu → render đúng (Thăng Hạng,
      Thành Tựu, Trang Phục), không lộ raw key
- [x] Sticker Album mở từ Trophy Room → hiển thị đúng số lượng sưu tầm
- [x] Mode Select ("Chọn chế độ") mở từ home → toàn bộ mode hiện đúng nhãn
      tiếng Việt, không raw i18n key
- [x] Frost Rush (I76b, dùng chung Ice Tile core với I76) chơi thật: board có
      ice tile, tap-to-pop nhóm hợp lệ → điểm cộng, ice tile hiện icon
      chip/nứt khi nhóm liền kề nổ (`chipAdjacentIceTiles`), gravity/collapse
      animate đúng
- [x] Thoát Frost Rush giữa ván → dialog "Thoát Màn?" hiện đúng, xác nhận
      Thoát → quay về home ổn định, không crash, không kẹt màn hình
- [ ] Combo Rush, Remix Levels, Daily Quest reminder thực bắn — đã QA trên
      debug build (Round-8 code review pass), **chưa** re-verify riêng trên
      bản release thật; rủi ro thấp (không đổi logic đặc thù release-mode so
      với các mode đã test ở trên) nhưng nên làm nếu có thời gian trước khi
      submit closed/internal testing track
