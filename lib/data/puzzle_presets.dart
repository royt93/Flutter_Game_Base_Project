/// F18 — bộ bàn dựng sẵn cho "Bàn hôm nay".
///
/// Tồn tại vì AC bắt buộc: người chơi **chưa lưu bàn nào** vẫn phải dùng được
/// đầy đủ tính năng. Preset là phần ai cũng có, bàn tự vẽ chỉ là phần thêm.
///
/// Mã sinh bằng `tool/gen_puzzle_presets.dart` — chạy qua **chính**
/// `encodePuzzleGrid` rồi decode lại để tự kiểm, nên không có mã nào chết.
/// Sửa/thêm preset thì chạy lại script, đừng gõ tay base64.
///
/// Không phải preset nào cũng chơi được: `checker` xen kẽ hoàn toàn nên không
/// có nhóm >= 2 nào, và bị bộ lọc trong `puzzle_daily.dart` loại ra. Giữ lại
/// trong bảng làm ca kiểm thử sống cho chính bộ lọc đó.
class PuzzlePreset {
  const PuzzlePreset({required this.id, required this.code});

  final String id;
  final String code;
}

const List<PuzzlePreset> kPuzzlePresets = [
  PuzzlePreset(id: 'stripes_h', code: 'OXw4fDAsMCwwLDAsMCwwLDAsMDswLDAsMCwwLDAsMCwwLDA7MSwxLDEsMSwxLDEsMSwxOzEsMSwxLDEsMSwxLDEsMTsyLDIsMiwyLDIsMiwyLDI7MiwyLDIsMiwyLDIsMiwyOzMsMywzLDMsMywzLDMsMzszLDMsMywzLDMsMywzLDM7MCwwLDAsMCwwLDAsMCww'),
  PuzzlePreset(id: 'stripes_v', code: 'OXw4fDAsMCwxLDEsMiwyLDMsMzswLDAsMSwxLDIsMiwzLDM7MCwwLDEsMSwyLDIsMywzOzAsMCwxLDEsMiwyLDMsMzswLDAsMSwxLDIsMiwzLDM7MCwwLDEsMSwyLDIsMywzOzAsMCwxLDEsMiwyLDMsMzswLDAsMSwxLDIsMiwzLDM7MCwwLDEsMSwyLDIsMywz'),
  PuzzlePreset(id: 'checker', code: 'OXw4fDAsMSwwLDEsMCwxLDAsMTsxLDAsMSwwLDEsMCwxLDA7MCwxLDAsMSwwLDEsMCwxOzEsMCwxLDAsMSwwLDEsMDswLDEsMCwxLDAsMSwwLDE7MSwwLDEsMCwxLDAsMSwwOzAsMSwwLDEsMCwxLDAsMTsxLDAsMSwwLDEsMCwxLDA7MCwxLDAsMSwwLDEsMCwx'),
  PuzzlePreset(id: 'blocks', code: 'OXw4fDAsMCwwLDEsMSwxLDAsMDswLDAsMCwxLDEsMSwwLDA7MCwwLDAsMSwxLDEsMCwwOzIsMiwyLDMsMywzLDIsMjsyLDIsMiwzLDMsMywyLDI7MiwyLDIsMywzLDMsMiwyOzQsNCw0LDUsNSw1LDQsNDs0LDQsNCw1LDUsNSw0LDQ7NCw0LDQsNSw1LDUsNCw0'),
  PuzzlePreset(id: 'diamond', code: 'OXw4fDMsMywzLDIsMiwyLDMsMzszLDMsMiwyLDEsMiwyLDM7MywyLDIsMSwxLDEsMiwyOzIsMiwxLDEsMCwxLDEsMjsyLDEsMSwwLDAsMCwxLDE7MiwyLDEsMSwwLDEsMSwyOzMsMiwyLDEsMSwxLDIsMjszLDMsMiwyLDEsMiwyLDM7MywzLDMsMiwyLDIsMywz'),
  PuzzlePreset(id: 'cross', code: 'OXw4fDEsMSwxLDIsMCwyLDMsMzsxLDEsMiwyLDAsMywzLDM7MSwyLDIsMiwwLDMsMywxOzIsMiwyLDMsMCwzLDEsMTswLDAsMCwwLDAsMCwwLDA7MiwzLDMsMywwLDEsMSwyOzMsMywzLDEsMCwxLDIsMjszLDMsMSwxLDAsMiwyLDI7MywxLDEsMSwwLDIsMiwz'),
  PuzzlePreset(id: 'zigzag', code: 'OXw4fDAsMCwxLDEsMiwyLDMsMzswLDAsMSwxLDIsMiwzLDM7MCwxLDEsMiwyLDMsMywwOzAsMSwxLDIsMiwzLDMsMDsxLDEsMiwyLDMsMywwLDA7MSwxLDIsMiwzLDMsMCwwOzEsMiwyLDMsMywwLDAsMTsxLDIsMiwzLDMsMCwwLDE7MiwyLDMsMywwLDAsMSwx'),
  PuzzlePreset(id: 'corners', code: 'OXw4fDAsMCwwLDAsMSwxLDEsMTswLDAsMCwwLDEsMSwxLDE7MCwwLDAsMCwxLDEsMSwxOzAsMCwwLDAsMSwxLDEsMTsyLDIsMiwyLDMsMywzLDM7MiwyLDIsMiwzLDMsMywzOzIsMiwyLDIsMywzLDMsMzsyLDIsMiwyLDMsMywzLDM7MiwyLDIsMiwzLDMsMywz'),
  PuzzlePreset(id: 'rings', code: 'OXw4fDAsMCwwLDAsMCwwLDAsMDswLDMsMywzLDMsMywzLDM7MCwzLDIsMiwyLDIsMiwzOzAsMywyLDEsMSwxLDIsMzswLDMsMiwxLDAsMSwyLDM7MCwzLDIsMSwxLDEsMiwzOzAsMywyLDIsMiwyLDIsMzswLDMsMywzLDMsMywzLDM7MCwwLDAsMCwwLDAsMCww'),
  PuzzlePreset(id: 'columns_pair', code: 'OXw4fDAsMCwxLDEsMiwyLDAsMDswLDAsMSwxLDIsMiwwLDA7MCwwLDEsMSwyLDIsMCwwOzAsMCwxLDEsMiwyLDAsMDswLDAsMSwxLDIsMiwwLDA7MCwwLDEsMSwyLDIsMCwwOzAsMCwxLDEsMiwyLDAsMDswLDAsMSwxLDIsMiwwLDA7MCwwLDEsMSwyLDIsMCww'),
  PuzzlePreset(id: 'wave', code: 'OXw4fDAsMCwwLDAsMSwyLDMsMDswLDAsMCwxLDIsMywwLDE7MSwxLDEsMSwyLDMsMCwxOzEsMSwxLDIsMywwLDEsMjsyLDIsMiwyLDMsMCwxLDI7MiwyLDIsMywwLDEsMiwzOzMsMywzLDMsMCwxLDIsMzszLDMsMywwLDEsMiwzLDA7MCwwLDAsMCwxLDIsMyww'),
  PuzzlePreset(id: 'quads', code: 'OXw4fDAsMCwxLDEsMiwyLDMsMzswLDAsMSwxLDIsMiwzLDM7MSwxLDIsMiwzLDMsMCwwOzEsMSwyLDIsMywzLDAsMDsyLDIsMywzLDAsMCwxLDE7MiwyLDMsMywwLDAsMSwxOzMsMywwLDAsMSwxLDIsMjszLDMsMCwwLDEsMSwyLDI7MCwwLDEsMSwyLDIsMywz'),
];
