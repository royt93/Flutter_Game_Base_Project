import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/save_integrity.dart';
import '../../../core/storage_service.dart';
import 'common_button.dart';
import 'panel_card.dart';

/// Outcome of [SaveHealthCard]'s most recent self-check.
enum SaveHealthResult {
  /// No check has run yet.
  unknown,

  /// The save exported and (if [SaveHealthCard.secret] was supplied)
  /// signed/verified cleanly.
  ok,

  /// [StorageService.exportAll]/`jsonEncode`/[signExport]/[verifyAndStrip]
  /// threw — see [SaveHealthCardState.errorMessage].
  error,
}

/// A small self-contained diagnostic card (IDEA-59) for "is the player's
/// save currently healthy" — the question support/QA gets asked after a
/// "I lost my progress" report, without needing a dev to pull device logs.
///
/// **What this actually checks, and why** (see `save_integrity.dart`'s own
/// class doc for the full picture): [StorageService] never tracks a "last
/// saved at" timestamp itself (every service just calls `setInt`/
/// `setString` directly, there's no single unified "save" event to hook),
/// and a live in-memory save is never itself HMAC-signed — only an
/// EXPORTED backup is (see [BackupRestorePanel]). Inventing either of
/// those from scratch (a save-time-tracking write on every persisted key,
/// or an app-wide signed-live-state cache) would be a much bigger, riskier
/// change than this card's own scope, and — for the write-tracking half —
/// would directly conflict with "must not add a new write to the real
/// save path" (adding a timestamp write on every `setInt`/`setString` call
/// touches the exact hot path this card must stay out of).
///
/// So instead of a passive "last save" observer, this card is an ACTIVE,
/// on-demand self-test: [check] (also run once on [initState]) reads
/// [StorageService.exportAll] (never writes), reports its serialized byte
/// size, and — only if [secret] is supplied — round-trips it through
/// [signExport]/[verifyAndStrip] as a live smoke test that the CURRENT
/// save data can still be serialized/signed/verified without error (e.g.
/// a corrupted/non-encodable value snuck into storage). It does not (and
/// cannot, without a secret AND a previously-exported blob to compare
/// against) tell you whether an OLDER save was tampered with — that's
/// [BackupRestorePanel]'s job at actual export/import time.
class SaveHealthCard extends StatefulWidget {
  const SaveHealthCard({
    super.key,
    this.secret,
    this.title = 'Save Health',
    this.checkLabel = 'Kiểm tra ngay',
    @visibleForTesting this.storage,
    @visibleForTesting this.nowMs,
  });

  /// HMAC key to smoke-test sign/verify with — same secret an app would
  /// pass to [BackupRestorePanel]. Left `null`, the card skips that part
  /// of the check entirely (still reports save size) rather than pretend
  /// to verify anything.
  final String? secret;

  final String title;
  final String checkLabel;

  /// Overrides the ambient [StorageService.to] singleton — test-only seam.
  final StorageService? storage;

  /// Overrides the clock used to stamp "last checked at" — test-only seam.
  final int Function()? nowMs;

  @override
  State<SaveHealthCard> createState() => SaveHealthCardState();
}

@visibleForTesting
class SaveHealthCardState extends State<SaveHealthCard> {
  int? _sizeBytes;
  int? _checkedAtMs;
  SaveHealthResult _result = SaveHealthResult.unknown;
  String? _errorMessage;

  /// Exposed `@visibleForTesting` so a test can assert on the outcome
  /// without parsing rendered text.
  @visibleForTesting
  SaveHealthResult get result => _result;

  @visibleForTesting
  String? get errorMessage => _errorMessage;

  int _now() =>
      (widget.nowMs ?? () => DateTime.now().millisecondsSinceEpoch)();

  /// Re-runs the check — a consumer can also call this via a
  /// [GlobalKey<SaveHealthCardState>] after their own save/backup flow
  /// completes, without needing this card to invent a cross-widget event
  /// bus for something only 1 caller at a time needs.
  void check() {
    final storage = widget.storage ?? StorageService.maybe;
    if (storage == null) {
      setState(() {
        _result = SaveHealthResult.error;
        _errorMessage = 'StorageService chưa được đăng ký (Get.put).';
        _sizeBytes = null;
        _checkedAtMs = _now();
      });
      return;
    }
    try {
      final raw = storage.exportAll();
      final bytes = utf8.encode(jsonEncode(raw)).length;
      final secret = widget.secret;
      if (secret != null && secret.isNotEmpty) {
        verifyAndStrip(signExport(raw, secret), secret);
      }
      setState(() {
        _sizeBytes = bytes;
        _result = SaveHealthResult.ok;
        _errorMessage = null;
        _checkedAtMs = _now();
      });
    } catch (error) {
      setState(() {
        _result = SaveHealthResult.error;
        _errorMessage = '$error';
        _checkedAtMs = _now();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    check();
  }

  String _formatTime(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final checkedAt = _checkedAtMs;
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
          Text(
            'Kiểm tra lần cuối: ${checkedAt == null ? '(chưa kiểm tra)' : _formatTime(checkedAt)}',
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _sizeBytes == null
                ? 'Kích thước save: —'
                : 'Kích thước save: ${_sizeBytes!} bytes',
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            widget.secret == null || widget.secret!.isEmpty
                ? 'HMAC: bỏ qua (chưa có secret)'
                : switch (_result) {
                    SaveHealthResult.ok => 'HMAC: hợp lệ',
                    SaveHealthResult.error => 'HMAC/save: lỗi — $_errorMessage',
                    SaveHealthResult.unknown => 'HMAC: chưa kiểm tra',
                  },
            style: TextStyle(
              color: _result == SaveHealthResult.error
                  ? NeonTheme.red
                  : NeonTheme.inkSoft,
              fontSize: 13,
            ),
          ),
          if (_result == SaveHealthResult.error &&
              (widget.secret == null || widget.secret!.isEmpty))
            Text(
              'Lỗi: $_errorMessage',
              style: TextStyle(color: NeonTheme.red, fontSize: 13),
            ),
          const SizedBox(height: NeonTheme.s16),
          CommonButton(
            key: const Key('saveHealthCardCheckNow'),
            label: widget.checkLabel,
            variant: CommonButtonVariant.secondary,
            onTap: check,
          ),
        ],
      ),
    );
  }
}
