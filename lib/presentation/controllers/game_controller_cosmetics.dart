part of 'game_controller.dart';

/// Cửa hàng trang trí (Wave 9): nạp/áp + mua/chọn skin gem & theme bàn.
extension GameControllerCosmetics on GameController {
  /// Nạp trang trí đã sở hữu + đang chọn từ đĩa rồi áp vào [ActiveCosmetics].
  void _loadCosmetics() {
    ownedSkins.clear();
    for (final s in kGemSkins) {
      if (s.price == 0 || _store.getInt(StorageKeys.ownedSkin(s.id)) == 1) {
        ownedSkins.add(s.id);
      }
    }
    ownedThemes.clear();
    for (final t in kBoardThemes) {
      if (t.price == 0 || _store.getInt(StorageKeys.ownedTheme(t.id)) == 1) {
        ownedThemes.add(t.id);
      }
    }
    var sel = _store.getString(StorageKeys.selectedSkin) ?? kGemSkins.first.id;
    if (!ownedSkins.contains(sel)) sel = kGemSkins.first.id;
    selectedSkin.value = sel;
    var selT =
        _store.getString(StorageKeys.selectedTheme) ?? kBoardThemes.first.id;
    if (!ownedThemes.contains(selT)) selT = kBoardThemes.first.id;
    selectedTheme.value = selT;
    _applyCosmetics();
  }

  /// Đưa lựa chọn hiện tại vào holder tĩnh để tầng render (Flame) đọc.
  void _applyCosmetics() {
    ActiveCosmetics.gemSkin = gemSkinById(selectedSkin.value);
    ActiveCosmetics.boardTheme = boardThemeById(selectedTheme.value);
  }

  bool isSkinOwned(String id) => ownedSkins.contains(id);
  bool isThemeOwned(String id) => ownedThemes.contains(id);

  /// Mua skin (nếu đủ xu & chưa sở hữu) rồi tự trang bị. Cộng quyền sở hữu
  /// TRƯỚC khi trừ xu (giống [_buy]) — kill giữa chừng thì giữ skin, không mất xu trắng.
  bool buySkin(String id) {
    final skin = gemSkinById(id);
    if (ownedSkins.contains(id) || coins.value < skin.price) return false;
    ownedSkins.add(id);
    unawaited(_store.setInt(StorageKeys.ownedSkin(id), 1));
    _setCoins(coins.value - skin.price);
    selectSkin(id);
    return true;
  }

  /// W18.2: mở khoá skin MIỄN PHÍ (thưởng hoàn tất Album) — không trừ xu, không
  /// tự trang bị. Trả false nếu đã sở hữu. Idempotent (an toàn gọi lại).
  bool grantSkin(String id) {
    if (ownedSkins.contains(id)) return false;
    ownedSkins.add(id);
    unawaited(_store.setInt(StorageKeys.ownedSkin(id), 1));
    return true;
  }

  void selectSkin(String id) {
    if (!ownedSkins.contains(id)) return;
    selectedSkin.value = id;
    unawaited(_store.setString(StorageKeys.selectedSkin, id));
    _applyCosmetics();
  }

  bool buyTheme(String id) {
    final th = boardThemeById(id);
    if (ownedThemes.contains(id) || coins.value < th.price) return false;
    ownedThemes.add(id);
    unawaited(_store.setInt(StorageKeys.ownedTheme(id), 1));
    _setCoins(coins.value - th.price);
    selectTheme(id);
    return true;
  }

  void selectTheme(String id) {
    if (!ownedThemes.contains(id)) return;
    selectedTheme.value = id;
    unawaited(_store.setString(StorageKeys.selectedTheme, id));
    _applyCosmetics();
  }
}
