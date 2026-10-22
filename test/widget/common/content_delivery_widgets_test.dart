import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

void main() {
  test('content delivery constructors validate caller input', () {
    expect(
      () => ContentPackStatusCard(
        status: ContentPackStatus.ready,
        contentVersion: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ContentPackStatusCard(
        status: ContentPackStatus.ready,
        contentVersion: 1,
        updatedAtText: ' ',
      ),
      throwsArgumentError,
    );
    expect(
      () => ScenePreloadStatusPanel(
        sceneId: ' ',
        status: ScenePreloadStatus.idle,
        progress: 0,
        itemCount: 1,
      ),
      throwsArgumentError,
    );
    for (final progress in [-0.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => ScenePreloadStatusPanel(
          sceneId: 'scene',
          status: ScenePreloadStatus.ready,
          progress: progress,
          itemCount: 1,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ScenePreloadStatusPanel(
        sceneId: 'scene',
        status: ScenePreloadStatus.ready,
        progress: 0.5,
        itemCount: -1,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('content pack status maps state and refresh retry safely', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentPackStatusCard(
            status: ContentPackStatus.ready,
            contentVersion: 4,
            updatedAtText: 'Today',
            onRefresh: () async {
              attempts++;
              if (attempts == 1) throw StateError('private content payload');
            },
          ),
        ),
      ),
    );
    expect(find.text('Content ready'), findsOneWidget);
    expect(find.text('Version: 4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contentPackRefresh')));
    await tester.pumpAndSettle();
    expect(find.text('Action failed. Try again.'), findsOneWidget);
    expect(find.textContaining('private content payload'), findsNothing);
    expect(
      tester
          .widget<CommonButton>(
            find.byKey(const ValueKey('contentPackRefresh')),
          )
          .label,
      'Retry update',
    );
    await tester.tap(find.byKey(const ValueKey('contentPackRefresh')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('content pack busy and null callback gate refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentPackStatusCard(
            status: ContentPackStatus.refreshing,
            contentVersion: 8,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.text('Updating content'), findsOneWidget);
    expect(
      tester
          .widget<CommonButton>(
            find.byKey(const ValueKey('contentPackRefresh')),
          )
          .onTap,
      isNull,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentPackStatusCard(
            status: ContentPackStatus.ready,
            contentVersion: 8,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('contentPackRefresh')), findsNothing);
  });

  testWidgets('preload status maps actions and reports typed progress', (
    tester,
  ) async {
    var starts = 0;
    var retries = 0;
    var cancels = 0;
    for (final (status, expected, actionKey) in [
      (ScenePreloadStatus.idle, 'Ready to preload', 'scenePreloadStart'),
      (ScenePreloadStatus.loading, 'Preparing scene', 'scenePreloadCancel'),
      (ScenePreloadStatus.ready, 'Scene ready', null),
      (
        ScenePreloadStatus.error,
        'Some required assets failed to load.',
        'scenePreloadRetry',
      ),
      (ScenePreloadStatus.cancelled, 'Preload cancelled', 'scenePreloadStart'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScenePreloadStatusPanel(
              sceneId: 'level-7',
              status: status,
              progress: 0.4,
              itemCount: 5,
              onStart: () async => starts++,
              onRetry: () async => retries++,
              onCancel: () => cancels++,
            ),
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Assets: 5'), findsOneWidget);
      for (final key in [
        'scenePreloadStart',
        'scenePreloadRetry',
        'scenePreloadCancel',
      ]) {
        expect(
          find.byKey(ValueKey(key)),
          actionKey == key ? findsOneWidget : findsNothing,
        );
      }
    }
    expect(starts, 0);
    expect(retries, 0);
    expect(cancels, 0);
  });

  testWidgets(
    'preload callbacks fire once, fail safely and external busy gates',
    (tester) async {
      var attempts = 0;
      var cancels = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScenePreloadStatusPanel(
              sceneId: 'level-8',
              status: ScenePreloadStatus.error,
              progress: 0.7,
              itemCount: 3,
              onRetry: () async {
                attempts++;
                if (attempts == 1) throw StateError('secret path /tmp/asset');
              },
              onCancel: () => cancels++,
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('scenePreloadRetry'));
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('/tmp/asset'), findsNothing);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScenePreloadStatusPanel(
              sceneId: 'level-8',
              status: ScenePreloadStatus.loading,
              progress: 0.7,
              itemCount: 3,
              busy: true,
              onCancel: () => cancels++,
            ),
          ),
        ),
      );
      final cancel = tester.widget<CommonButton>(
        find.byKey(const ValueKey('scenePreloadCancel')),
      );
      expect(cancel.onTap, isNull);
      expect(cancels, 0);
    },
  );

  testWidgets(
    'preload prevents duplicate start and resets stale callback error',
    (tester) async {
      final completer = Completer<void>();
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScenePreloadStatusPanel(
              sceneId: 'scene-a',
              status: ScenePreloadStatus.idle,
              progress: 0,
              itemCount: 2,
              onStart: () {
                starts++;
                return completer.future;
              },
            ),
          ),
        ),
      );
      final start = find.byKey(const ValueKey('scenePreloadStart'));
      await tester.tap(start);
      await tester.pump();
      await tester.tap(start);
      expect(starts, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScenePreloadStatusPanel(
              sceneId: 'scene-b',
              status: ScenePreloadStatus.idle,
              progress: 0,
              itemCount: 2,
              onStart: () async {},
            ),
          ),
        ),
      );
      completer.completeError(StateError('stale loader detail'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Action failed. Try again.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delivery widgets fit 320dp with 200% RTL text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ContentPackStatusCard(
                  status: ContentPackStatus.error,
                  contentVersion: 34,
                  updatedAtText: 'Updated several weeks ago',
                  onRefresh: () async {},
                ),
                ScenePreloadStatusPanel(
                  sceneId: 'very-long-scene-identifier-for-arabic-layout',
                  status: ScenePreloadStatus.error,
                  progress: 0.735,
                  itemCount: 12,
                  onStart: () async {},
                  onRetry: () async {},
                  onCancel: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
