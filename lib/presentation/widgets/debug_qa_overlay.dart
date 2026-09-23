import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/audio_manager.dart';
import '../../core/connectivity_coordinator.dart';
import '../../core/experiment_bucketing_service.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../../core/replay_recorder.dart';
import '../../core/sdk_health_report.dart';
import '../../core/storage_service.dart';
import '../../core/utils/clamped_clock.dart';
import '../../core/utils/trusted_clock.dart';
import 'common/common_button.dart';

/// Hidden debug/QA overlay — a small long-press trigger in a screen corner
/// that opens a panel with 2 tabs: a read-only dump of live internal
/// package state (every `StorageService` key/value, audio mute, current
/// locale, clock diagnostics), and a Playground tab (IDEA-39) that lets a
/// QA tester/designer live-preview a `CommonButton` with adjustable
/// label/variant/color right on-device — no rebuild needed to answer
/// "what would this button look like in red with this label?".
///
/// Gated exactly like [dlog] (`lib/core/debug_log.dart`) — `kDebugMode ||
/// kProfileMode` — so a QA build (which is typically a profile build, not a
/// debug build) still gets it, while a release build never builds the
/// trigger or panel at all (this widget degrades to exactly [child]).
///
/// Usage — wrap your app's root widget:
/// ```dart
/// DebugQaOverlay(child: MaterialApp(...));
/// ```
class DebugQaOverlay extends StatefulWidget {
  const DebugQaOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DebugQaOverlay> createState() => _DebugQaOverlayState();
}

class _DebugQaOverlayState extends State<DebugQaOverlay> {
  bool _open = false;
  Timer? _refreshTimer;
  int _tab = 0;

  // IDEA-39 Playground state — same sample colors/label already used by
  // `example/lib/screens/widget_showcase_screen.dart`'s own CommonButton
  // demo, rather than inventing a new palette just for this panel.
  CommonButtonVariant _playgroundVariant = CommonButtonVariant.primary;
  Color _playgroundColor = NeonTheme.cyan;
  late final TextEditingController _playgroundLabelController =
      TextEditingController(text: 'Preview');

  // IDEA-42: Replay tab state — the exported capsule JSON, shown until
  // overwritten by the next export or the panel closes.
  String? _replayExport;

  void _startReplay() => setState(
    () => ReplayRecorder.maybe?.start(
      seed: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  void _stopReplay() => setState(() => ReplayRecorder.maybe?.stop());

  void _exportReplay() {
    final recorder = ReplayRecorder.maybe;
    if (recorder == null) return;
    final capsule = recorder.buildCapsule(appVersion: kAppVersion);
    setState(
      () => _replayExport = const JsonEncoder.withIndent(
        '  ',
      ).convert(capsule.toJson()),
    );
  }

  void _toggle() {
    setState(() => _open = !_open);
    _refreshTimer?.cancel();
    _refreshTimer = _open
        ? Timer.periodic(
            const Duration(milliseconds: 500),
            (_) => setState(() {}),
          )
        : null;
  }

  void _setTab(int tab) => setState(() => _tab = tab);

  // FEAT-93: Time Travel/Network Simulator tabs mutate EXTERNAL global
  // state (clamped_clock.dart's offset, ConnectivityCoordinator's forced
  // state) rather than State owned by this widget — this forces an
  // immediate rebuild after such a mutation instead of waiting up to
  // 500ms for the ambient `_refreshTimer` below to catch up.
  void _refreshQa() => setState(() {});

  void _setPlaygroundVariant(CommonButtonVariant variant) =>
      setState(() => _playgroundVariant = variant);

  void _setPlaygroundColor(Color color) =>
      setState(() => _playgroundColor = color);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _playgroundLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_open)
          _Panel(
            onClose: _toggle,
            tab: _tab,
            onTabChanged: _setTab,
            onQaChanged: _refreshQa,
            playgroundVariant: _playgroundVariant,
            playgroundColor: _playgroundColor,
            playgroundLabelController: _playgroundLabelController,
            onPlaygroundVariantChanged: _setPlaygroundVariant,
            onPlaygroundColorChanged: _setPlaygroundColor,
            replayExport: _replayExport,
            onStartReplay: _startReplay,
            onStopReplay: _stopReplay,
            onExportReplay: _exportReplay,
          ),
        // Kept on top of the panel (rather than under it) so long-pressing
        // the corner again always closes the panel too, not just tapping
        // outside it.
        Positioned(
          top: 0,
          right: 0,
          width: 48,
          height: 48,
          child: GestureDetector(
            key: const Key('debugQaOverlayTrigger'),
            behavior: HitTestBehavior.opaque,
            onLongPress: _toggle,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
    required this.onQaChanged,
    required this.playgroundVariant,
    required this.playgroundColor,
    required this.playgroundLabelController,
    required this.onPlaygroundVariantChanged,
    required this.onPlaygroundColorChanged,
    required this.replayExport,
    required this.onStartReplay,
    required this.onStopReplay,
    required this.onExportReplay,
  });

  final VoidCallback onClose;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onQaChanged;
  final CommonButtonVariant playgroundVariant;
  final Color playgroundColor;
  final TextEditingController playgroundLabelController;
  final ValueChanged<CommonButtonVariant> onPlaygroundVariantChanged;
  final ValueChanged<Color> onPlaygroundColorChanged;
  final String? replayExport;
  final VoidCallback onStartReplay;
  final VoidCallback onStopReplay;
  final VoidCallback onExportReplay;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose, // tap outside the panel dismisses it
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside the panel
              // IDEA-39: the Playground tab's ChoiceChip/TextField (and
              // any InkWell-based widget) need a Material ancestor —
              // this panel is dropped directly into the app's root Stack
              // via DebugQaOverlay, outside any Scaffold/Material.
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 320,
                  // FEAT-93: +80 over the prior 520 — the tab bar now
                  // wraps onto 2 lines (7 tabs), so each tab's own content
                  // area needs the same headroom it had before to avoid
                  // clipping/squeezing content near the bottom edge.
                  constraints: const BoxConstraints(maxHeight: 600),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Debug QA',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      // FEAT-93: `Wrap`, not `Row` of `Expanded` (the prior
                      // layout) — 7 tabs no longer fit on 1 line across
                      // this panel's fixed 320px width. `Wrap` flows the
                      // overflow onto a 2nd line instead of requiring a
                      // horizontal scroll — every tab stays simultaneously
                      // visible/tappable, so existing tests that
                      // `tester.tap(find.text('Replay'))` etc. directly
                      // (no scroll-into-view step) keep working unchanged.
                      Wrap(
                        children: [
                          _TabButton(
                            label: 'State',
                            selected: tab == 0,
                            onTap: () => onTabChanged(0),
                          ),
                          _TabButton(
                            label: 'Playground',
                            selected: tab == 1,
                            onTap: () => onTabChanged(1),
                          ),
                          _TabButton(
                            label: 'Replay',
                            selected: tab == 2,
                            onTap: () => onTabChanged(2),
                          ),
                          _TabButton(
                            label: 'Health',
                            selected: tab == 3,
                            onTap: () => onTabChanged(3),
                          ),
                          _TabButton(
                            label: 'Time Travel',
                            selected: tab == 4,
                            onTap: () => onTabChanged(4),
                          ),
                          _TabButton(
                            label: 'Network',
                            selected: tab == 5,
                            onTap: () => onTabChanged(5),
                          ),
                          _TabButton(
                            label: 'Variant',
                            selected: tab == 6,
                            onTap: () => onTabChanged(6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: switch (tab) {
                          0 => const _StateTab(),
                          1 => _PlaygroundTab(
                            variant: playgroundVariant,
                            color: playgroundColor,
                            labelController: playgroundLabelController,
                            onVariantChanged: onPlaygroundVariantChanged,
                            onColorChanged: onPlaygroundColorChanged,
                          ),
                          2 => _ReplayTab(
                            export: replayExport,
                            onStart: onStartReplay,
                            onStop: onStopReplay,
                            onExport: onExportReplay,
                          ),
                          3 => const _HealthTab(),
                          4 => _TimeTravelTab(onChanged: onQaChanged),
                          5 => _NetworkSimulatorTab(onChanged: onQaChanged),
                          _ => const _VariantSwitcherTab(),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A plain GestureDetector, not InkWell — this panel isn't inside a
    // Material ancestor (it's dropped directly into the app's root Stack
    // via DebugQaOverlay), and InkWell asserts one must exist.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? NeonTheme.cyan : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? NeonTheme.cyan : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _StateTab extends StatelessWidget {
  const _StateTab();

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.maybe?.exportAll() ?? const {};
    final audioMuted = AudioManager.maybe?.muted.value;
    final locale = LocaleService.maybe?.current.value;
    // IDEA-40: sampled fresh every panel rebuild (same 500ms auto-refresh
    // as the rest of this panel) — this is what a device smoke test
    // changing the REAL system clock via Settings watches change live,
    // since every other test of this class injects a fake sample instead
    // of touching the actual OS clock.
    int? trustedNowMs;
    ClockJudgement? trustedJudgement;
    if (StorageService.maybe != null) {
      final trustedClock = TrustedClockService();
      trustedNowMs = trustedClock.nowMsTrusted();
      trustedJudgement = trustedClock.lastJudgement;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audio muted: ${audioMuted?.toString() ?? "not registered"}'),
          Text('Locale: ${locale?.toString() ?? "not registered"}'),
          Text('Clock rewind blocked: $clockRewindBlockedCount'),
          Text(
            'TrustedClock now: '
            '${trustedNowMs?.toString() ?? "not registered"}',
          ),
          Text(
            'TrustedClock judgement: '
            '${trustedJudgement?.name ?? "n/a (first sample)"}',
          ),
          const Divider(),
          for (final entry in storage.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// IDEA-39: live `CommonButton` playground — a designer/QA can try a
/// different label/variant/color right on-device, without an engineer
/// changing code and rebuilding. Deliberately scoped to 1 widget
/// (`CommonButton`, the kit's most commonly reused one) rather than every
/// widget in `common/` — see this task's `## Quyết định` for why.
class _PlaygroundTab extends StatelessWidget {
  const _PlaygroundTab({
    required this.variant,
    required this.color,
    required this.labelController,
    required this.onVariantChanged,
    required this.onColorChanged,
  });

  final CommonButtonVariant variant;
  final Color color;
  final TextEditingController labelController;
  final ValueChanged<CommonButtonVariant> onVariantChanged;
  final ValueChanged<Color> onColorChanged;

  // Same sample palette `widget_showcase_screen.dart`'s own demos already
  // draw from — not a new set of colors invented just for this panel.
  static final _swatches = [
    NeonTheme.cyan,
    NeonTheme.magenta,
    NeonTheme.gold,
    NeonTheme.lime,
    NeonTheme.red,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CommonButton',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: labelController,
              builder: (context, value, _) => CommonButton(
                label: value.text.isEmpty ? ' ' : value.text,
                variant: variant,
                color: color,
                onTap: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Label'),
          TextField(
            key: const Key('debugQaPlaygroundLabelField'),
            controller: labelController,
            decoration: const InputDecoration(isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('Variant'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final v in CommonButtonVariant.values.where(
                (v) => v != CommonButtonVariant.icon,
              ))
                ChoiceChip(
                  key: Key('debugQaPlaygroundVariant_${v.name}'),
                  label: Text(v.name),
                  selected: variant == v,
                  onSelected: (_) => onVariantChanged(v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final swatch in _swatches)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('debugQaPlaygroundColor_${swatch.toARGB32()}'),
                    onTap: () => onColorChanged(swatch),
                    child: AnimatedContainer(
                      duration: NeonTheme.reducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: color == swatch ? 32 : 24,
                      height: color == swatch ? 32 : 24,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: color == swatch
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// IDEA-42: start/stop/export controls for [ReplayRecorder] — lets a QA
/// tester capture a bounded window of gameplay events and hand the
/// resulting JSON capsule to a developer, instead of a screen recording
/// that can't be fed back into the game to reproduce a bug.
class _ReplayTab extends StatelessWidget {
  const _ReplayTab({
    required this.export,
    required this.onStart,
    required this.onStop,
    required this.onExport,
  });

  final String? export;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final recorder = ReplayRecorder.maybe;
    if (recorder == null) {
      return const Text(
        'ReplayRecorder chưa được đăng ký (Get.put) trong app này.',
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recorder.isRecording
                ? 'Đang ghi — ${recorder.eventCount} sự kiện'
                : 'Không ghi — ${recorder.eventCount} sự kiện trong buffer',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommonButton(
                key: const Key('debugQaReplayStart'),
                label: 'Start',
                onTap: recorder.isRecording ? null : onStart,
              ),
              CommonButton(
                key: const Key('debugQaReplayStop'),
                label: 'Stop',
                variant: CommonButtonVariant.secondary,
                onTap: recorder.isRecording ? onStop : null,
              ),
              CommonButton(
                key: const Key('debugQaReplayExport'),
                label: 'Export',
                variant: CommonButtonVariant.secondary,
                onTap: recorder.eventCount == 0 ? null : onExport,
              ),
            ],
          ),
          if (export != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            SelectableText(
              export!,
              key: const Key('debugQaReplayExportOutput'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// FEAT-39: generates an [SdkHealthReport] on demand — a support/QA person
/// can paste the resulting JSON straight into a ticket, since every
/// section is already redacted to its own allowlist (see
/// `sdk_health_report.dart`). Self-contained (no state threaded through
/// [_Panel]) since generating a report needs nothing from the rest of this
/// overlay.
class _HealthTab extends StatefulWidget {
  const _HealthTab();

  @override
  State<_HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<_HealthTab> {
  String? _report;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final report = SdkHealthReport()..registerAll(defaultHealthCollectors());
    final json = await report.collectJson();
    if (!mounted) return;
    setState(() {
      _report = json;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonButton(
            key: const Key('debugQaHealthGenerate'),
            label: _loading ? 'Generating…' : 'Generate report',
            onTap: _loading ? null : _generate,
          ),
          if (_report != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            SelectableText(
              _report!,
              key: const Key('debugQaHealthOutput'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDebugOffset(int ms) {
  if (ms == 0) return '0 (không time travel)';
  final sign = ms < 0 ? '-' : '+';
  final d = Duration(milliseconds: ms.abs());
  return '$sign${d.inDays}d ${d.inHours.remainder(24)}h '
      '${d.inMinutes.remainder(60)}m';
}

/// FEAT-93: simulates advancing time WITHOUT touching the OS clock — QA
/// can see Daily Login/Quest/Energy/Season Event react instantly to
/// +2h/+24h/+7d. Applies via `clamped_clock.dart`'s debug-only
/// [setDebugTimeOffsetMs] (a no-op outside `kDebugMode`/`kProfileMode`),
/// which every `nowMsClamped`/`todayEpochDayClamped` caller already reads
/// from — no per-system wiring needed here.
class _TimeTravelTab extends StatelessWidget {
  const _TimeTravelTab({required this.onChanged});

  final VoidCallback onChanged;

  void _jump(Duration by) {
    setDebugTimeOffsetMs(debugTimeOffsetMs + by.inMilliseconds);
    onChanged();
  }

  void _reset() {
    setDebugTimeOffsetMs(0);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final storageReady = StorageService.maybe != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time Travel', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Offset hiện tại: ${_formatDebugOffset(debugTimeOffsetMs)}'),
          const SizedBox(height: 4),
          Text(
            storageReady
                ? 'nowMsClamped(): ${nowMsClamped()}'
                : 'StorageService chưa đăng ký trong app này.',
            key: const Key('debugQaTimeTravelNow'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommonButton(
                key: const Key('debugQaTimeTravelPlus2h'),
                label: '+2h',
                variant: CommonButtonVariant.secondary,
                onTap: () => _jump(const Duration(hours: 2)),
              ),
              CommonButton(
                key: const Key('debugQaTimeTravelPlus24h'),
                label: '+24h',
                variant: CommonButtonVariant.secondary,
                onTap: () => _jump(const Duration(hours: 24)),
              ),
              CommonButton(
                key: const Key('debugQaTimeTravelPlus7d'),
                label: '+7 ngày',
                variant: CommonButtonVariant.secondary,
                onTap: () => _jump(const Duration(days: 7)),
              ),
              CommonButton(
                key: const Key('debugQaTimeTravelReset'),
                label: 'Reset',
                onTap: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FEAT-93: forces `ConnectivityCoordinator` offline/degraded/online
/// without touching the device's real WiFi/cellular — see
/// `ConnectivityCoordinator.debugForceState`'s own doc for exactly how the
/// override interacts with real signal/probe events while active.
class _NetworkSimulatorTab extends StatelessWidget {
  const _NetworkSimulatorTab({required this.onChanged});

  final VoidCallback onChanged;

  void _force(ConnectivityState? state) {
    ConnectivityCoordinator.maybe?.debugForceState(state);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ConnectivityCoordinator.maybe;
    if (coordinator == null) {
      return const Text(
        'ConnectivityCoordinator chưa được đăng ký (Get.put) trong app này.',
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Network Simulator',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'State hiện tại: ${coordinator.state.name}',
            key: const Key('debugQaNetworkState'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommonButton(
                key: const Key('debugQaNetworkForceOffline'),
                label: 'Force offline',
                variant: CommonButtonVariant.secondary,
                onTap: () => _force(ConnectivityState.offline),
              ),
              CommonButton(
                key: const Key('debugQaNetworkForceDegraded'),
                label: 'Force degraded',
                variant: CommonButtonVariant.secondary,
                onTap: () => _force(ConnectivityState.degraded),
              ),
              CommonButton(
                key: const Key('debugQaNetworkForceOnline'),
                label: 'Force online',
                variant: CommonButtonVariant.secondary,
                onTap: () => _force(ConnectivityState.online),
              ),
              CommonButton(
                key: const Key('debugQaNetworkClear'),
                label: 'Clear (real)',
                onTap: () => _force(null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FEAT-93: overrides `ExperimentBucketingService.variantFor`'s result for
/// a typed-in experiment key/variant list — reflects at EVERY call site
/// reading that experiment, since the override lives inside `variantFor`
/// itself (`ExperimentBucketingService.debugSetVariantOverride`), not a
/// side channel only this tab reads.
class _VariantSwitcherTab extends StatefulWidget {
  const _VariantSwitcherTab();

  @override
  State<_VariantSwitcherTab> createState() => _VariantSwitcherTabState();
}

class _VariantSwitcherTabState extends State<_VariantSwitcherTab> {
  final _keyController = TextEditingController(text: 'demo_experiment');
  final _variantsController = TextEditingController(
    text: 'control,variant_a,variant_b',
  );

  @override
  void dispose() {
    _keyController.dispose();
    _variantsController.dispose();
    super.dispose();
  }

  List<String> get _variants => _variantsController.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final service = ExperimentBucketingService.maybe;
    if (service == null) {
      return const Text(
        'ExperimentBucketingService chưa được đăng ký (Get.put) trong app này.',
      );
    }
    final experimentKey = _keyController.text.trim();
    final variants = _variants;
    final current = experimentKey.isEmpty || variants.isEmpty
        ? null
        : service.variantFor(experimentKey, variants);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Variant Switcher',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Experiment key'),
          TextField(
            key: const Key('debugQaVariantKeyField'),
            controller: _keyController,
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          const Text('Variants (phân cách bởi dấu phẩy)'),
          TextField(
            key: const Key('debugQaVariantListField'),
            controller: _variantsController,
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang chọn: ${current ?? "-"}',
            key: const Key('debugQaVariantCurrent'),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final variant in variants)
                ChoiceChip(
                  key: Key('debugQaVariantChip_$variant'),
                  label: Text(variant),
                  selected: current == variant,
                  onSelected: (_) => setState(
                    () => service.debugSetVariantOverride(
                      experimentKey,
                      variant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          CommonButton(
            key: const Key('debugQaVariantClear'),
            label: 'Clear override',
            variant: CommonButtonVariant.secondary,
            onTap: variants.isEmpty
                ? null
                : () => setState(
                    () => service.debugSetVariantOverride(experimentKey, null),
                  ),
          ),
        ],
      ),
    );
  }
}
