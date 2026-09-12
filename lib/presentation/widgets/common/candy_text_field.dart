import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Candy-styled text input — [NeonTheme.card] background, rounded border,
/// glow when focused — for player-name entry, redeem codes, feedback forms,
/// etc. Fills the "Buttons & Interactive" category's one remaining gap
/// (every other control there has a candy-styled equivalent; text entry
/// previously had none, forcing a bare Material `TextField`).
///
/// Caller owns the [controller] (same "caller owns state" convention as
/// `WheelSpinnerController`/`ScreenShakeController`) — this widget holds no
/// text state of its own, only the transient focus/border-glow state.
class CandyTextField extends StatefulWidget {
  const CandyTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.color,
  });

  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// Focus border/glow color. Defaults to [NeonTheme.cyan].
  final Color? color;

  @override
  State<CandyTextField> createState() => _CandyTextFieldState();
}

class _CandyTextFieldState extends State<CandyTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonTheme.cyan;
    return AnimatedContainer(
      duration: NeonTheme.reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused ? color : NeonTheme.muted,
          width: _focused ? 2.5 : 2,
        ),
        boxShadow: _focused
            ? NeonTheme.glow(color, blur: 12, intensity: 0.4)
            : NeonTheme.drop(y: 2, blur: 6),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        validator: widget.validator,
        autovalidateMode: widget.validator == null
            ? null
            : AutovalidateMode.onUserInteraction,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: NeonTheme.ink,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        cursorColor: color,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: NeonTheme.inkSoft),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: color)
              : null,
          border: InputBorder.none,
          errorStyle: TextStyle(
            color: NeonTheme.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s16,
          ),
        ),
      ),
    );
  }
}
