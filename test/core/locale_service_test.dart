import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocaleService', () {
    late StorageService store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
    });

    tearDown(Get.reset);

    test('maybe trả về null khi chưa Get.put', () {
      expect(LocaleService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = LocaleService(store);
      Get.put(service, permanent: true);
      expect(LocaleService.maybe, same(service));
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

    test('BUG-26: change() với locale không nằm trong supported → '
        'ArgumentError, current/storage giữ nguyên', () async {
      final service = LocaleService(store);
      final before = service.current.value;

      await expectLater(
        service.change(const Locale('xx')),
        throwsArgumentError,
      );

      expect(service.current.value, before);
      expect(store.getString(StorageKeys.localeCode), isNull);
    });

    test('BUG-26: change() với locale cùng languageCode đã supported nhưng '
        'khác country code → được chấp nhận, chuẩn hoá về đúng entry trong '
        'AppTranslations.supported', () async {
      final service = LocaleService(store);
      final supportedEn = AppTranslations.supported.firstWhere(
        (l) => l.languageCode == 'en',
      );

      await service.change(const Locale('en', 'GB'));

      expect(service.current.value, supportedEn);
      expect(
        store.getString(StorageKeys.localeCode),
        AppTranslations.codeOf(supportedEn),
      );
    });
  });
}
