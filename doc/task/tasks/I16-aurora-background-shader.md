# I16 — Aurora background shader (world cao)

**Epic:** Neon/Glow · **SP:** 8 · **Pri:** Could · **Deps:** G5 (tái dùng hạ tầng `FragmentProgram`)

## Mục tiêu
World cuối (khó nhất) có nền aurora chuyển sắc bằng shader riêng, dùng chung
hạ tầng `FragmentProgram.fromAsset` + fallback đã có ở `neon_aura_layer.dart`.

## Vì sao
Ý tưởng độc quyền — phần thưởng thị giác cho người chơi tới world cao, tái
dùng hạ tầng shader đã chứng minh hoạt động (G5) thay vì viết engine mới.

## Acceptance criteria
- [ ] Shader mới `shaders/aurora_bg.frag`, load qua `FragmentProgram.fromAsset`
      giống pattern `neon_glow.frag`.
- [ ] Fallback non-shader (gradient animation `AnimationController`) khi thiết
      bị không hỗ trợ — theo đúng pattern `neon_aura_layer.dart` đã làm.
- [ ] Chỉ áp dụng ở world cuối (theo `id` range), không đổi nền các world khác.
- [ ] Golden/manual check: không giật khung hình so với `NeonBg` hiện tại.

## Subtasks (gợi ý file)
1. `shaders/aurora_bg.frag` mới.
2. `lib/presentation/widgets/neon_bg.dart` hoặc file mới: nhánh world cuối
   dùng aurora layer, tái dùng khung `neon_aura_layer.dart`.
3. Đăng ký asset trong `pubspec.yaml`.

## Ghi chú kỹ thuật
Copy cấu trúc fallback try/catch của `neon_aura_layer.dart` — không viết lại
logic phát hiện hỗ trợ shader từ đầu.

DoD chung: `../README.md`.
