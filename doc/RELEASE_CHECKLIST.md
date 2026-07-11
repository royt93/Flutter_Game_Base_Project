# Release Checklist — Pop Star Blast

Fork mới từ Neon Jewels, MVP tap-to-pop (campaign 200 màn + shop booster).
Chưa có bản release nào — toàn bộ mục dưới đây cần verify lại từ đầu.

## A. Tự động

- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test --exclude-tags slow` → all pass
- [ ] `flutter test integration_test/ -d <device>` → pass
- [ ] Build release: `flutter build apk --release` **và** `flutter build appbundle --release` → pass
- [ ] Smoke AAB (bundletool → install-apks) trên device thật → không crash, không lộ raw i18n key

## B. Kiểm tay

### B1. Gameplay
- [ ] Tap nhóm ≥2 ô cùng màu → nổ (animation pop + hạt), điểm đúng `5*n*(n-1)`
- [ ] Cột rơi/dồn trái mượt (tween), không refill từ trên
- [ ] Dọn sạch bàn → +1000 bonus, không crash
- [ ] Bàn kẹt (không còn nhóm ≥2) → dialog thua
- [ ] Đạt/vượt target → dialog thắng + confetti, tính sao đúng (1/2/3)
- [ ] Booster bomb/shuffle/undo: mua đúng giá, dùng đúng, trừ đúng số lượng
- [ ] Thắng → mở khoá màn kế; quay lại Level Select thấy cập nhật ngay

### B2. Localization
- [ ] Đổi ngôn ngữ trong Settings → app đổi ngay, không crash
- [ ] Không lộ raw translation key trên bất kỳ màn nào (22 ngôn ngữ)

### B3. Lifecycle
- [ ] Background ↔ Resume giữa ván không mất tiến trình/crash
- [ ] Reset Progress → Cancel không đổi; Reset → xoá sạch coin/level/star/booster về mặc định

### B4. UI / Store sanity
- [ ] Style bright-casual nhất quán mọi screen; label đọc rõ (stroke)
- [ ] Version footer khớp `pubspec.yaml` + build number
- [ ] App icon / splash đúng brand
- [ ] Package id = `com.galaxyjoy.pop_star_blast` (Android), `com.galaxyjoy.popStarBlast*` (iOS)
- [ ] Không còn tham chiếu `neon_jewels`: `grep -r neon_jewels lib android ios pubspec.yaml`
- [ ] Không có ad SDK / quyền AD_ID thừa
