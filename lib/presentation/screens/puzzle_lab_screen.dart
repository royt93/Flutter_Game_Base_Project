import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/share_helper.dart';
import '../../core/storage_service.dart';
import '../../logic/gift_tile.dart';
import '../../logic/puzzle_code.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import 'game_screen.dart';

/// I42: level editor — người dùng tự vẽ bàn (rows/cols/colorCount/obstacle/
/// gift), lưu tối đa 5 bàn trên máy, chia sẻ/nhập bàn qua 1 mã base64url
/// (xem `logic/puzzle_code.dart`). Dùng thẳng singleton [GameController]
/// (khác `GhostReplayScreen` — bàn ở đây chơi thật, không phải playback).
class PuzzleLabScreen extends StatefulWidget {
  const PuzzleLabScreen({super.key});

  @override
  State<PuzzleLabScreen> createState() => _PuzzleLabScreenState();
}

class _PuzzleLabScreenState extends State<PuzzleLabScreen> {
  static const _maxSaved = 5;

  int _rows = 8;
  int _cols = 6;
  int _colorCount = 4;
  late List<List<int?>> _grid;
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _rebuildGrid();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _rebuildGrid() {
    _grid = List.generate(_rows, (_) => List<int?>.filled(_cols, null));
  }

  void _setRows(int v) => setState(() {
    _rows = v;
    _rebuildGrid();
  });

  void _setCols(int v) => setState(() {
    _cols = v;
    _rebuildGrid();
  });

  void _setColorCount(int v) => setState(() {
    _colorCount = v;
    for (final row in _grid) {
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell != null && cell >= v) row[c] = v - 1;
      }
    }
  });

  void _cycleCell(int r, int c) => setState(() {
    _error = null;
    _grid[r][c] = cyclePuzzleCellValue(_grid[r][c], _colorCount);
  });

  List<String> get _saved =>
      StorageService.to.getStringList(StorageKeys.savedPuzzles);

  void _savePuzzle() {
    if (!hasAnyGem(_grid)) {
      setState(() => _error = 'puzzle_lab_empty_board_msg'.tr);
      return;
    }
    final saved = _saved;
    final wasFull = saved.length >= _maxSaved;
    saved.add(encodePuzzleGrid(_grid));
    while (saved.length > _maxSaved) {
      saved.removeAt(0);
    }
    StorageService.to.setStringList(StorageKeys.savedPuzzles, saved);
    setState(() {
      _error = wasFull ? 'puzzle_lab_saved_limit_msg'.tr : null;
    });
  }

  void _deleteSaved(int index) {
    final saved = _saved;
    saved.removeAt(index);
    StorageService.to.setStringList(StorageKeys.savedPuzzles, saved);
    setState(() {});
  }

  void _shareCode() {
    if (!hasAnyGem(_grid)) {
      setState(() => _error = 'puzzle_lab_empty_board_msg'.tr);
      return;
    }
    shareText(encodePuzzleGrid(_grid));
  }

  void _playCode(String code) {
    final decoded = decodePuzzleGrid(code);
    if (decoded == null || !hasAnyGem(decoded)) {
      setState(() => _error = 'puzzle_lab_invalid_code'.tr);
      return;
    }
    Get.find<GameController>().startPuzzleLevel(fillEmptyCells(decoded));
    Get.to(() => const GameScreen());
  }

  Color _cellColor(int? v) {
    if (v == null) return NeonTheme.card;
    if (v >= 0) return NeonTheme.gemColors[v % NeonTheme.gemColors.length];
    if (v == giftTileValue) return NeonTheme.gold;
    return NeonTheme.inkSoft;
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: NeonTheme.inkSoft),
    filled: true,
    fillColor: NeonTheme.card,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: 12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _stepperRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: NeonTheme.ink,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: NeonTheme.ink,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'puzzle_lab_title'.tr, color: NeonTheme.lime),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stepperRow(
                        'puzzle_lab_rows_label'.tr,
                        _rows,
                        8,
                        11,
                        _setRows,
                      ),
                      _stepperRow(
                        'puzzle_lab_cols_label'.tr,
                        _cols,
                        6,
                        12,
                        _setCols,
                      ),
                      _stepperRow(
                        'puzzle_lab_colors_label'.tr,
                        _colorCount,
                        4,
                        kPuzzleMaxColorCount,
                        _setColorCount,
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _cols,
                          crossAxisSpacing: 3,
                          mainAxisSpacing: 3,
                        ),
                        itemCount: _rows * _cols,
                        itemBuilder: (context, index) {
                          final r = index ~/ _cols;
                          final c = index % _cols;
                          return GestureDetector(
                            onTap: () => _cycleCell(r, c),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _cellColor(_grid[r][c]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NeonButton(
                            label: 'puzzle_lab_save_button'.tr,
                            color: NeonTheme.lime,
                            width: 150,
                            onTap: _savePuzzle,
                          ),
                          NeonButton(
                            label: 'puzzle_lab_share_button'.tr,
                            color: NeonTheme.magenta,
                            width: 150,
                            onTap: _shareCode,
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: NeonTheme.s8),
                        Text(_error!, style: TextStyle(color: NeonTheme.red)),
                      ],
                      const SizedBox(height: NeonTheme.s16),
                      TextField(
                        controller: _codeCtrl,
                        style: TextStyle(color: NeonTheme.ink),
                        maxLines: 3,
                        minLines: 1,
                        decoration: _fieldDecoration(
                          'puzzle_lab_play_code_hint'.tr,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s8),
                      Center(
                        child: NeonButton(
                          label: 'puzzle_lab_play_button'.tr,
                          color: NeonTheme.orange,
                          onTap: () => _playCode(_codeCtrl.text),
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      Text(
                        'puzzle_lab_saved_list_title'.tr,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: NeonTheme.s8),
                      for (var i = 0; i < saved.length; i++)
                        Card(
                          color: NeonTheme.card,
                          child: ListTile(
                            title: Text(
                              saved[i].length > 16
                                  ? '${saved[i].substring(0, 16)}…'
                                  : saved[i],
                              style: TextStyle(color: NeonTheme.ink),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  color: NeonTheme.lime,
                                  onPressed: () => _playCode(saved[i]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: NeonTheme.red,
                                  onPressed: () => _deleteSaved(i),
                                  tooltip: 'puzzle_lab_delete_button'.tr,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
