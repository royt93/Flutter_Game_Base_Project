import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/cloud_save_provider.dart';
import 'package:roy_casual_kit/core/plugin_adapter_conformance_suite.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/backup_restore_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit_example/screens/save_cloud_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _button(String label) => find.widgetWithText(CommonButton, label);

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  Get.put(
    StorageService(await SharedPreferences.getInstance()),
    permanent: true,
  );
  Get.put<CloudSaveProvider>(FakeCloudSaveProvider(), permanent: true);
}

void main() {
  tearDown(Get.reset);

  testWidgets('renders SaveCloudScreen with empty slots', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SaveCloudScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Save & Cloud'), findsWidgets);
    expect(find.text('No slots yet.'), findsOneWidget);
    expect(find.byType(BackupRestorePanel), findsOneWidget);
    expect(_button('Create slot'), findsWidgets);
    expect(_button('+10 score'), findsWidgets);
    expect(_button('Upload cloud'), findsWidgets);
    expect(_button('Download cloud'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create slot adds slot and score increments', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SaveCloudScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('Create slot').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hero Slot 1'), findsOneWidget);
    expect(find.textContaining('Score: 0 • Active'), findsOneWidget);

    await tester.tap(_button('+10 score').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Score: 10 • Active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud upload and download roundtrip', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SaveCloudScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('Create slot').first);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('+10 score').first);
    await tester.pump(const Duration(milliseconds: 100));

    final uploadBtn = _button('Upload cloud').first;
    await tester.ensureVisible(uploadBtn);
    await tester.tap(uploadBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Uploaded local save to fake cloud.'),
      findsOneWidget,
    );

    final downloadBtn = _button('Download cloud').first;
    await tester.ensureVisible(downloadBtn);
    await tester.tap(downloadBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Downloaded fake cloud save.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export and restore selected slot', (tester) async {
    await _boot();

    await tester.pumpWidget(_wrap(const SaveCloudScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('Create slot').first);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(_button('+10 score').first);
    await tester.pump(const Duration(milliseconds: 100));

    final exportBtn = _button('Export selected').first;
    await tester.ensureVisible(exportBtn);
    await tester.tap(exportBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Exported selected slot backup.'),
      findsOneWidget,
    );

    final restoreBtn = _button('Restore selected').first;
    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Restored 1 slot from backup.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
