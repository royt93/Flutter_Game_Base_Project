import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

/// Safe summary only; raw storage, bundle JSON and log contents are not accepted
/// by this widget. The caller keeps the actual diagnostics payload.
@immutable
class SupportDiagnosticsSummary {
  SupportDiagnosticsSummary({
    required this.appVersion,
    required this.generatedAtText,
    required this.sections,
    this.truncated = false,
    this.errors = const <String, String>{},
  }) {
    if (appVersion.trim().isEmpty) {
      throw ArgumentError.value(appVersion, 'appVersion', 'must not be blank');
    }
    if (generatedAtText.trim().isEmpty) {
      throw ArgumentError.value(
        generatedAtText,
        'generatedAtText',
        'must not be blank',
      );
    }
    if (sections.any((section) => section.trim().isEmpty)) {
      throw ArgumentError.value(
        sections,
        'sections',
        'names must not be blank',
      );
    }
    if (errors.entries.any(
      (entry) => entry.key.trim().isEmpty || entry.value.trim().isEmpty,
    )) {
      throw ArgumentError.value(errors, 'errors', 'entries must not be blank');
    }
  }

  final String appVersion;
  final String generatedAtText;
  final List<String> sections;
  final bool truncated;

  /// Caller-sanitized section error summaries; never raw exception/log text.
  final Map<String, String> errors;
}

/// Displays a safe diagnostics summary and asks for explicit consent before
/// invoking the caller's share callback. It never receives the payload itself.
class SupportDiagnosticsCard extends StatefulWidget {
  SupportDiagnosticsCard({
    super.key,
    required this.summary,
    required this.onShare,
    this.preview,
    this.title = 'Support diagnostics',
    this.shareLabel = 'Share diagnostics',
    this.confirmLabel = 'Confirm share',
    this.cancelLabel = 'Cancel',
    this.previewLabel = 'Preview',
    this.closePreviewLabel = 'Close preview',
    this.confirmationText =
        'This shares the listed diagnostic summary with support.',
    this.errorLabel = 'Share failed. You can try again.',
    this.semanticLabel,
  }) {
    for (final (name, value) in [
      ('title', title),
      ('shareLabel', shareLabel),
      ('confirmLabel', confirmLabel),
      ('cancelLabel', cancelLabel),
      ('previewLabel', previewLabel),
      ('closePreviewLabel', closePreviewLabel),
      ('confirmationText', confirmationText),
      ('errorLabel', errorLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (semanticLabel != null && semanticLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        semanticLabel,
        'semanticLabel',
        'must not be blank',
      );
    }
  }

  final SupportDiagnosticsSummary summary;
  final Future<void> Function() onShare;
  final Widget? preview;
  final String title;
  final String shareLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String previewLabel;
  final String closePreviewLabel;
  final String confirmationText;
  final String errorLabel;
  final String? semanticLabel;

  @override
  State<SupportDiagnosticsCard> createState() => _SupportDiagnosticsCardState();
}

class _SupportDiagnosticsCardState extends State<SupportDiagnosticsCard> {
  bool _confirming = false;
  bool _sharing = false;
  bool _previewOpen = false;
  bool _shareFailed = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    try {
      await widget.onShare();
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _confirming = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _shareFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.summary.sections.toSet().toList()..sort();
    final spoken =
        widget.semanticLabel ??
        '${widget.title}, version ${widget.summary.appVersion}, '
            '${sections.length} sections${widget.summary.truncated ? ', truncated' : ''}';

    return Semantics(
      container: true,
      label: spoken,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NeonTheme.purple.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text('App ${widget.summary.appVersion}'),
            Text(widget.summary.generatedAtText),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final section in sections)
                  Container(
                    key: ValueKey('diagnosticsSection_$section'),
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NeonTheme.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: NeonTheme.cyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      section,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.summary.truncated)
              Text(
                'Some optional sections were omitted to fit the size limit.',
                style: TextStyle(color: NeonTheme.orange),
              ),
            if (widget.summary.errors.isNotEmpty)
              Text(
                '${widget.summary.errors.length} section(s) could not be included.',
                style: TextStyle(color: NeonTheme.orange),
              ),
            Text(
              'Logs and diagnostic details are shared only after confirmation.',
              style: TextStyle(color: NeonTheme.inkSoft, fontSize: 12),
            ),
            if (_shareFailed)
              Text(
                widget.errorLabel,
                key: const ValueKey('diagnosticsShareError'),
                style: TextStyle(color: NeonTheme.red),
              ),
            if (_confirming) ...[
              const SizedBox(height: 8),
              Text(widget.confirmationText),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CommonButton(
                    label: widget.confirmLabel,
                    semanticLabel: widget.confirmLabel,
                    loading: _sharing,
                    width: 180,
                    onTap: _sharing ? null : _share,
                  ),
                  CommonButton(
                    label: widget.cancelLabel,
                    variant: CommonButtonVariant.secondary,
                    width: 120,
                    onTap: _sharing
                        ? null
                        : () => setState(() => _confirming = false),
                  ),
                ],
              ),
            ] else
              CommonButton(
                key: const ValueKey('diagnosticsShareButton'),
                label: widget.shareLabel,
                semanticLabel: widget.shareLabel,
                width: double.infinity,
                onTap: _sharing
                    ? null
                    : () => setState(() => _confirming = true),
              ),
            if (widget.preview != null) ...[
              const SizedBox(height: 8),
              CommonButton(
                label: _previewOpen
                    ? widget.closePreviewLabel
                    : widget.previewLabel,
                variant: CommonButtonVariant.secondary,
                width: double.infinity,
                onTap: () => setState(() => _previewOpen = !_previewOpen),
              ),
              if (_previewOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: widget.preview,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
