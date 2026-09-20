import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/backup_restore_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = 'test-secret';

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en'),
  fallbackLocale: AppTranslations.fallback,
  home: Material(child: child),
);

void main() {
  tearDown(() => Get.reset());

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  Future<void> confirmRestore(WidgetTester tester) async {
    await tester.tap(find.text('Restore save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện đúng title và 2 nút, chưa có status message ban đầu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BackupRestorePanel(
          secret: _secret,
          storage: storage,
          onExport: (_) async {},
          onImport: () async => null,
        ),
      ),
    );

    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Export save'), findsWidgets);
    expect(find.text('Restore save'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('BackupRestorePanel: export', () {
    testWidgets(
      'tap Export gọi onExport với JSON đã ký hợp lệ, hiện đúng success message',
      (tester) async {
        await storage.setInt('coins', 42);
        String? captured;

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (json) async => captured = json,
              onImport: () async => null,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();
        await tester.pump();

        expect(captured, isNotNull);
        final decoded = jsonDecode(captured!) as Map<String, Object?>;
        final verified = verifyAndStrip(decoded, _secret);
        expect(verified['coins'], 42);
        expect(find.text('Save exported.'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('onExport throw → hiện error message, không crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupRestorePanel(
            secret: _secret,
            storage: storage,
            onExport: (_) async => throw Exception('disk full'),
            onImport: () async => null,
          ),
        ),
      );

      await tester.tap(find.text('Export save').last);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Export failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'trong lúc onExport đang chờ (working): hiện spinner, 2 nút bị vô hiệu hoá',
      (tester) async {
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) => completer.future,
              onImport: () async => null,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final exportButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Export save').first,
        );
        final importButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Restore save').first,
        );
        expect(exportButton.onTap, isNull);
        expect(importButton.onTap, isNull);

        completer.complete();
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('BackupRestorePanel: import', () {
    testWidgets('tap Restore hiện confirm dialog với đúng title/message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupRestorePanel(
            secret: _secret,
            storage: storage,
            onExport: (_) async {},
            onImport: () async => null,
          ),
        ),
      );

      await tester.tap(find.text('Restore save').last);
      await tester.pumpAndSettle();

      expect(find.text('Restore save?'), findsOneWidget);
      expect(
        find.textContaining('replaces all current progress'),
        findsOneWidget,
      );
    });

    testWidgets('bấm Cancel trên confirm dialog: onImport KHÔNG được gọi', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        _wrap(
          BackupRestorePanel(
            secret: _secret,
            storage: storage,
            onExport: (_) async {},
            onImport: () async {
              called = true;
              return null;
            },
          ),
        ),
      );

      await tester.tap(find.text('Restore save').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
    });

    testWidgets(
      'onImport trả về null (người dùng huỷ file picker): không lỗi, không thay đổi trạng thái',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => null,
            ),
          ),
        );

        await confirmRestore(tester);
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byIcon(Icons.error), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'round trip đúng: export rồi sửa storage, import lại phục hồi đúng giá trị cũ',
      (tester) async {
        await storage.setInt('coins', 42);
        String? exported;

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (json) async => exported = json,
              onImport: () async => exported,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();
        await tester.pump();
        expect(exported, isNotNull);

        // Mô phỏng dữ liệu bị thay đổi SAU khi export (progress mới, hoặc bug).
        await storage.setInt('coins', 999);

        await confirmRestore(tester);
        await tester.pump();
        await tester.pump();

        expect(storage.getInt('coins'), 42);
        expect(find.text('Save restored.'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'onImport trả về JSON bị chỉnh sửa (checksum sai): hiện đúng error message, KHÔNG import',
      (tester) async {
        await storage.setInt('coins', 42);
        final signed = signExport(storage.exportAll(), _secret);
        final tampered = {...signed, 'coins': 99999};

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => jsonEncode(tampered),
            ),
          ),
        );

        await confirmRestore(tester);
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('checksum không khớp'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
        // Dữ liệu gốc không bị ghi đè bởi bản đã chỉnh sửa.
        expect(storage.getInt('coins'), 42);
      },
    );

    testWidgets(
      'onImport trả về JSON thiếu checksum: hiện đúng error message, không crash',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => jsonEncode({'coins': 1}),
            ),
          ),
        );

        await confirmRestore(tester);
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('thiếu checksum'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'onImport trả về chuỗi không phải JSON hợp lệ: hiện error, không crash',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => 'not valid json {{{',
            ),
          ),
        );

        await confirmRestore(tester);
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.error), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'onImport trả về JSON hợp lệ nhưng không phải Map (vd 1 List): hiện error, không crash',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => jsonEncode([1, 2, 3]),
            ),
          ),
        );

        await confirmRestore(tester);
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.error), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ENH-67: đúng nút hiện loading, không phải cả 2 cùng lúc', () {
    testWidgets(
      'đang export: CHỈ nút Export loading, nút Import không loading (nhưng vẫn bị disable)',
      (tester) async {
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) => completer.future,
              onImport: () async => null,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();

        final exportButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Export save').first,
        );
        final importButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Restore save').first,
        );
        expect(exportButton.loading, isTrue);
        expect(importButton.loading, isFalse);
        expect(
          importButton.onTap,
          isNull,
        ); // vẫn bị disable, chỉ không hiện spinner riêng

        completer.complete();
        await tester.pump();
        await tester.pump();
      },
    );

    testWidgets(
      'đang import: CHỈ nút Import loading, nút Export không loading',
      (tester) async {
        final completer = Completer<String?>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () => completer.future,
            ),
          ),
        );

        await tester.tap(find.text('Restore save').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pump();
        await tester.pump();

        final exportButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Export save').first,
        );
        final importButton = tester.widget<CommonButton>(
          find.widgetWithText(CommonButton, 'Restore save').first,
        );
        expect(importButton.loading, isTrue);
        expect(exportButton.loading, isFalse);

        completer.complete(null);
        await tester.pump();
        await tester.pump();
      },
    );

    testWidgets(
      'bấm Export nhiều lần trong lúc đang export: onExport chỉ chạy đúng 1 lần (không double-tap)',
      (tester) async {
        var callCount = 0;
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) {
                callCount++;
                return completer.future;
              },
              onImport: () async => null,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();
        await tester.tap(find.text('Export save').last, warnIfMissed: false);
        await tester.pump();

        expect(callCount, 1);

        completer.complete();
        await tester.pump();
        await tester.pump();
      },
    );

    testWidgets('sau khi export xong (success), spinner tắt trên cả 2 nút', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupRestorePanel(
            secret: _secret,
            storage: storage,
            onExport: (_) async {},
            onImport: () async => null,
          ),
        ),
      );

      await tester.tap(find.text('Export save').last);
      await tester.pump();
      await tester.pump();

      final exportButton = tester.widget<CommonButton>(
        find.widgetWithText(CommonButton, 'Export save').first,
      );
      final importButton = tester.widget<CommonButton>(
        find.widgetWithText(CommonButton, 'Restore save').first,
      );
      expect(exportButton.loading, isFalse);
      expect(importButton.loading, isFalse);
      expect(find.text('Save exported.'), findsOneWidget);
    });
  });

  group('BackupRestorePanel: reducedMotion', () {
    testWidgets('ENH-20 style: reducedMotion bật → AnimatedSize duration = 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) async {},
              onImport: () async => null,
            ),
          ),
        ),
      );

      final animatedSize = tester.widget<AnimatedSize>(
        find.byType(AnimatedSize),
      );
      expect(animatedSize.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    });
  });

  group('ENH-78: workingAnnouncement', () {
    Semantics liveRegion(WidgetTester tester) => tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );

    testWidgets(
      'không truyền workingAnnouncement: announcement y hệt hiện tại "Working…"',
      (tester) async {
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) => completer.future,
              onImport: () async => null,
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();

        expect(liveRegion(tester).properties.label, 'Working…');
        completer.complete();
        await tester.pump();
      },
    );

    testWidgets(
      'truyền workingAnnouncement tuỳ chỉnh: Semantics.label dùng đúng chuỗi mới',
      (tester) async {
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            BackupRestorePanel(
              secret: _secret,
              storage: storage,
              onExport: (_) => completer.future,
              onImport: () async => null,
              workingAnnouncement: 'Đang xử lý…',
            ),
          ),
        );

        await tester.tap(find.text('Export save').last);
        await tester.pump();

        expect(liveRegion(tester).properties.label, 'Đang xử lý…');
        completer.complete();
        await tester.pump();
      },
    );
  });
}
