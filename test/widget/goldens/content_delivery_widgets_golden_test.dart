import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'content_delivery_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  final cases = <({String name, Widget child})>[
    (
      name: 'pack_ready',
      child: ContentPackStatusCard(
        status: ContentPackStatus.ready,
        contentVersion: 3,
        updatedAtText: 'Today',
        onRefresh: _noop,
      ),
    ),
    (
      name: 'pack_refreshing',
      child: ContentPackStatusCard(
        status: ContentPackStatus.refreshing,
        contentVersion: 3,
        onRefresh: _noop,
      ),
    ),
    (
      name: 'pack_error',
      child: ContentPackStatusCard(
        status: ContentPackStatus.error,
        contentVersion: 3,
        onRefresh: _noop,
      ),
    ),
    (
      name: 'scene_idle',
      child: ScenePreloadStatusPanel(
        sceneId: 'level-7',
        status: ScenePreloadStatus.idle,
        progress: 0,
        itemCount: 5,
        onStart: _noop,
      ),
    ),
    (
      name: 'scene_loading',
      child: ScenePreloadStatusPanel(
        sceneId: 'level-7',
        status: ScenePreloadStatus.loading,
        progress: 0.64,
        itemCount: 5,
        busy: true,
        onCancel: () {},
      ),
    ),
    (
      name: 'scene_error',
      child: ScenePreloadStatusPanel(
        sceneId: 'level-7',
        status: ScenePreloadStatus.error,
        progress: 0.64,
        itemCount: 5,
        onRetry: _noop,
      ),
    ),
    (
      name: 'scene_ready',
      child: ScenePreloadStatusPanel(
        sceneId: 'level-7',
        status: ScenePreloadStatus.ready,
        progress: 1,
        itemCount: 5,
      ),
    ),
  ];

  for (final entry in cases) {
    testWidgets('Content delivery ${entry.name} golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(padding: const EdgeInsets.all(16), child: entry.child),
        goldenBaseName: 'content_delivery_${entry.name}',
      );
    });
  }
}

Future<void> _noop() async {}
