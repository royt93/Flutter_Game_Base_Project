import 'package:flutter_test/flutter_test.dart';
import 'package:roy_base_game/core/app_translations.dart';
import 'package:roy_base_game/core/locale_service.dart';
import 'package:roy_base_game/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocaleService', () {
    late StorageService store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
    });

    test('chưa có locale đã lưu → dùng fallback', () {
      final service = LocaleService(store);
      expect(service.current.value, AppTranslations.fallback);
      expect(service.isCurrent(AppTranslations.fallback), true);
    });

    test('có locale đã lưu hợp lệ → nạp đúng locale đó', () async {
      final saved = AppTranslations.supported.last;
      await store.setString(
        StorageKeys.localeCode,
        AppTranslations.codeOf(saved),
      );

      final service = LocaleService(store);
      expect(service.current.value, saved);
    });

    test('locale đã lưu không nằm trong supported → fallback', () async {
      await store.setString(StorageKeys.localeCode, 'zz_ZZ');
      final service = LocaleService(store);
      expect(service.current.value, AppTranslations.fallback);
    });

    test('change() cập nhật current và lưu lại storage', () async {
      final service = LocaleService(store);
      final target = AppTranslations.supported.last;

      await service.change(target);

      expect(service.current.value, target);
      expect(
        store.getString(StorageKeys.localeCode),
        AppTranslations.codeOf(target),
      );
    });
  });
}
