import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

class SaveCloudScreen extends StatefulWidget {
  const SaveCloudScreen({super.key});

  @override
  State<SaveCloudScreen> createState() => _SaveCloudScreenState();
}

class _SaveCloudScreenState extends State<SaveCloudScreen> {
  static const _secret = 'save-cloud-demo-secret';
  static const _scoreSuffix = 'demo_score';

  late final SaveSlotManager _slots;
  late final CloudSaveProvider _cloud;
  late final DisasterRecoverySaveExport _recovery;
  String? _lastBackup;
  String _status = 'Create a save slot, add score, then back it up.';

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _slots =
        SaveSlotManager.maybe ??
        Get.put(SaveSlotManager(maxSlots: 3), permanent: true);
    _cloud = Get.isRegistered<CloudSaveProvider>()
        ? Get.find<CloudSaveProvider>()
        : Get.put<CloudSaveProvider>(FakeCloudSaveProvider(), permanent: true);
    _recovery = DisasterRecoverySaveExport(
      storage: StorageService.to,
      slotManager: _slots,
    );
  }

  int _scoreFor(String slotId) =>
      StorageService.to.getInt(_slots.keyFor(slotId, _scoreSuffix));

  Future<void> _createSlot() async {
    final next = _slots.listSlots().length + 1;
    final slot = _slots.createSlot('Hero Slot $next');
    await _slots.setActiveSlot(slot.id);
    if (!mounted) return;
    setState(() {
      _status = 'Created ${slot.displayName}.';
    });
  }

  Future<void> _setActive(String slotId) async {
    await _slots.setActiveSlot(slotId);
    if (!mounted) return;
    setState(() {
      _status =
          'Selected ${_slots.listSlots().firstWhere((s) => s.id == slotId).displayName}.';
    });
  }

  Future<void> _addScore() async {
    final slotId = _slots.activeSlotId;
    if (slotId == null) return;
    final key = _slots.keyFor(slotId, _scoreSuffix);
    await StorageService.to.setInt(key, _scoreFor(slotId) + 10);
    _slots.touchSlot(slotId);
    if (!mounted) return;
    setState(() {
      _status = 'Added +10 score to active slot.';
    });
  }

  Future<void> _deleteSlot(String slotId) async {
    await _slots.deleteSlot(slotId);
    if (!mounted) return;
    setState(() {
      _status = 'Deleted slot.';
    });
  }

  Future<void> _uploadCloud() async {
    await _cloud.signIn();
    await _cloud.upload(StorageService.to.exportAll());
    if (!mounted) return;
    setState(() {
      _status = 'Uploaded local save to fake cloud.';
    });
  }

  Future<void> _downloadCloud() async {
    await _cloud.signIn();
    final data = await _cloud.download();
    if (data == null) {
      if (!mounted) return;
      setState(() {
        _status = 'Cloud is empty.';
      });
      return;
    }
    await StorageService.to.importAll(data);
    if (!mounted) return;
    setState(() {
      _status = 'Downloaded fake cloud save.';
    });
  }

  Future<void> _exportSelectedSlot() async {
    final slotId = _slots.activeSlotId;
    if (slotId == null) return;
    final result = _recovery.buildExport(
      slotIds: [slotId],
      appVersion: kAppVersion,
    );
    final bundle = result.value;
    if (bundle == null) {
      setState(() {
        _status = 'Export failed.';
      });
      return;
    }
    _lastBackup = jsonEncode(_recovery.sign(bundle, _secret));
    if (!mounted) return;
    setState(() {
      _status = 'Exported selected slot backup.';
    });
  }

  Future<void> _restoreSelectedBackup() async {
    final raw = _lastBackup;
    if (raw == null) {
      setState(() {
        _status = 'No backup yet.';
      });
      return;
    }
    final decoded = jsonDecode(raw);
    final preview = _recovery.previewRestore(
      Map<String, Object?>.from(decoded as Map),
      _secret,
    );
    final value = preview.value;
    if (value == null) {
      setState(() {
        _status = 'Backup is invalid.';
      });
      return;
    }
    await _recovery.applyRestore(value);
    if (!mounted) return;
    setState(() {
      _status = 'Restored ${value.entries.length} slot from backup.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots.listSlots();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'save_cloud'.tr, onBack: Get.back),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                child: PanelCard(
                  child: Text(_status, style: TextStyle(color: NeonTheme.ink)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  children: [
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Save Slots',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s8),
                          if (slots.isEmpty)
                            Text(
                              'No slots yet.',
                              style: TextStyle(color: NeonTheme.inkSoft),
                            )
                          else
                            for (final slot in slots)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: NeonTheme.s8,
                                ),
                                child: CommonListTile(
                                  title: slot.displayName,
                                  subtitle:
                                      'Score: ${_scoreFor(slot.id)}${slot.id == _slots.activeSlotId ? ' • Active' : ''}',
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: NeonTheme.red,
                                    ),
                                    onPressed: () => _deleteSlot(slot.id),
                                  ),
                                  onTap: () => _setActive(slot.id),
                                ),
                              ),
                          Row(
                            children: [
                              Expanded(
                                child: CommonButton(
                                  label: 'Create slot',
                                  onTap: _slots.canCreateSlot
                                      ? _createSlot
                                      : null,
                                ),
                              ),
                              const SizedBox(width: NeonTheme.s8),
                              Expanded(
                                child: CommonButton(
                                  label: '+10 score',
                                  variant: CommonButtonVariant.secondary,
                                  onTap: _slots.activeSlotId == null
                                      ? null
                                      : _addScore,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    BackupRestorePanel(
                      secret: _secret,
                      exportLabel: 'Export all',
                      importLabel: 'Restore all',
                      onExport: (json) async {
                        _lastBackup = json;
                      },
                      onImport: () async => _lastBackup,
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Cloud & selected slot backup',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s16),
                          Wrap(
                            spacing: NeonTheme.s8,
                            runSpacing: NeonTheme.s8,
                            children: [
                              CommonButton(
                                label: 'Upload cloud',
                                onTap: _uploadCloud,
                              ),
                              CommonButton(
                                label: 'Download cloud',
                                onTap: _downloadCloud,
                              ),
                              CommonButton(
                                label: 'Export selected',
                                variant: CommonButtonVariant.secondary,
                                onTap: _slots.activeSlotId == null
                                    ? null
                                    : _exportSelectedSlot,
                              ),
                              CommonButton(
                                label: 'Restore selected',
                                variant: CommonButtonVariant.secondary,
                                onTap: _restoreSelectedBackup,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
