import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/save_integrity.dart';
import '../../../core/storage_service.dart';
import 'confirm_dialog.dart';
import 'common_button.dart';
import 'panel_card.dart';

enum _Status { idle, working, success, error }

/// UI for the save-backup flow `StorageService.exportAll()`/`importAll()`
/// and `save_integrity.dart`'s HMAC sign/verify already support at the
/// core layer but have no widget to drive them from.
///
/// Same "seam" convention as [CloudSaveProvider]/`PurchaseSeam`: this panel
/// owns none of the actual file/QR/share mechanism. [onExport] receives the
/// already-signed JSON string and is responsible for getting it out of the
/// app (write to a file, encode as a QR, share sheet...); [onImport] is
/// responsible for getting a JSON string back in (file picker, QR scan...)
/// and returns `null` if the caller cancelled — the panel treats that as a
/// silent no-op, not an error.
///
/// [secret] is the HMAC key from [signExport]/[verifyAndStrip] — supplied
/// by the consuming app for the same reason `save_integrity.dart`'s own doc
/// gives: a secret baked into this package would be shared (and leaked) by
/// every game built on it.
///
/// Import overwrites the entire local save (`StorageService.importAll`'s
/// own behavior), so it's gated behind a [showConfirmDialog] "are you
/// sure?" step first — export is non-destructive and has no such gate.
class BackupRestorePanel extends StatefulWidget {
  const BackupRestorePanel({
    super.key,
    required this.secret,
    required this.onExport,
    required this.onImport,
    this.title = 'Backup & Restore',
    this.exportLabel = 'Export save',
    this.importLabel = 'Restore save',
    this.confirmImportTitle = 'Restore save?',
    this.confirmImportMessage =
        'This replaces all current progress with the restored save. This '
        'cannot be undone.',
    this.exportSuccessMessage = 'Save exported.',
    this.importSuccessMessage = 'Save restored.',
    @visibleForTesting this.storage,
  });

  final String secret;

  /// Receives the signed JSON string to hand off to the actual
  /// file/QR/share mechanism.
  final Future<void> Function(String signedJson) onExport;

  /// Returns the JSON string to verify and import, or `null` if the caller
  /// cancelled (e.g. closed the file picker) — treated as a silent no-op.
  final Future<String?> Function() onImport;

  final String title;
  final String exportLabel;
  final String importLabel;
  final String confirmImportTitle;
  final String confirmImportMessage;
  final String exportSuccessMessage;
  final String importSuccessMessage;

  /// Overrides the ambient [StorageService.to] singleton — test-only seam.
  final StorageService? storage;

  @override
  State<BackupRestorePanel> createState() => _BackupRestorePanelState();
}

class _BackupRestorePanelState extends State<BackupRestorePanel> {
  _Status _status = _Status.idle;
  String? _message;

  StorageService get _storage => widget.storage ?? StorageService.to;

  bool get _busy => _status == _Status.working;

  Future<void> _handleExport() async {
    setState(() {
      _status = _Status.working;
      _message = null;
    });
    try {
      final signed = signExport(_storage.exportAll(), widget.secret);
      await widget.onExport(jsonEncode(signed));
      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _message = widget.exportSuccessMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _message = 'Export failed: $error';
      });
    }
  }

  Future<void> _handleImport() async {
    final confirmed = await showConfirmDialog(
      context,
      title: widget.confirmImportTitle,
      message: widget.confirmImportMessage,
      color: NeonTheme.red,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _status = _Status.working;
      _message = null;
    });
    try {
      final raw = await widget.onImport();
      if (raw == null) {
        if (!mounted) return;
        setState(() => _status = _Status.idle);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Backup data is not a valid save file.');
      }
      final verified = verifyAndStrip(decoded, widget.secret);
      await _storage.importAll(verified);
      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _message = widget.importSuccessMessage;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _message = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _message = 'Restore failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = NeonTheme.reducedMotion(context);
    return PanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: NeonTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  label: widget.exportLabel,
                  variant: CommonButtonVariant.secondary,
                  onTap: _busy ? null : _handleExport,
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: CommonButton(
                  label: widget.importLabel,
                  onTap: _busy ? null : _handleImport,
                ),
              ),
            ],
          ),
          // Status/warning-class message (IDEA-21 motion convention: flat
          // easeOut, no overshoot — this reports state, it isn't a reward
          // moment), height-animated so an empty->message transition
          // doesn't jump.
          AnimatedSize(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _status == _Status.idle
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: NeonTheme.s16),
                    child: Semantics(
                      liveRegion: true,
                      label: _busy ? 'Working…' : _message,
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          if (_busy)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color?>(
                                  NeonTheme.cyan,
                                ),
                              ),
                            )
                          else
                            Icon(
                              _status == _Status.error
                                  ? Icons.error
                                  : Icons.check_circle,
                              color: _status == _Status.error
                                  ? NeonTheme.red
                                  : NeonTheme.lime,
                              size: 18,
                            ),
                          const SizedBox(width: NeonTheme.s8),
                          Expanded(
                            child: Text(
                              _busy ? 'Working…' : (_message ?? ''),
                              style: TextStyle(
                                color: _status == _Status.error
                                    ? NeonTheme.red
                                    : NeonTheme.inkSoft,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
