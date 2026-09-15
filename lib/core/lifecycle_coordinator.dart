import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'audio_manager.dart';
import 'debug_log.dart';
import 'storage_service.dart';

enum RoyLifecycleState { foreground, background }

enum RoyLifecycleEvent { background, resumed }

typedef RoyLifecycleHook = Future<void> Function(RoyLifecycleEvent event);

class RoyLifecycleHookFailure {
  const RoyLifecycleHookFailure(this.name, this.error);
  final String name;
  final Object error;
}

/// Ordered, isolated lifecycle dispatcher shared by SDK modules and consumers.
class RoyLifecycleCoordinator extends GetxService with WidgetsBindingObserver {
  RoyLifecycleCoordinator({this.hookTimeout = const Duration(seconds: 2)});
  final Duration hookTimeout;
  final state = RoyLifecycleState.foreground.obs;
  final failures = <RoyLifecycleHookFailure>[].obs;
  final _hooks = <({String name, RoyLifecycleHook callback})>[];
  RoyLifecycleState? _lastDispatched;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static RoyLifecycleCoordinator? get maybe =>
      Get.isRegistered<RoyLifecycleCoordinator>()
      ? Get.find<RoyLifecycleCoordinator>()
      : null;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  void registerHook(String name, RoyLifecycleHook callback) {
    _hooks.add((name: name, callback: callback));
  }

  void removeHook(String name) {
    _hooks.removeWhere((hook) => hook.name == name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = switch (state) {
      AppLifecycleState.resumed => RoyLifecycleState.foreground,
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached => RoyLifecycleState.background,
    };
    if (_lastDispatched == next) return;
    _lastDispatched = next;
    this.state.value = next;
    unawaited(
      _dispatch(
        next == RoyLifecycleState.background
            ? RoyLifecycleEvent.background
            : RoyLifecycleEvent.resumed,
      ),
    );
  }

  Future<void> _dispatch(RoyLifecycleEvent event) async {
    if (event == RoyLifecycleEvent.background) {
      AudioManager.maybe?.pauseBgm();
      try {
        await StorageService.maybe?.flush();
      } catch (error) {
        failures.add(RoyLifecycleHookFailure('storage.flush', error));
      }
    } else {
      AudioManager.maybe?.resumeBgm();
    }
    for (final hook in List.of(_hooks)) {
      try {
        await hook.callback(event).timeout(hookTimeout);
      } catch (error) {
        failures.add(RoyLifecycleHookFailure(hook.name, error));
        dlog('lifecycle hook ${hook.name} failed: $error');
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _hooks.clear();
    super.onClose();
  }
}
