import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedFormField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int index;
  final bool enabled;
  final bool? isValid;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  const AnimatedFormField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.index = 0,
    this.enabled = true,
    this.isValid,
    this.maxLength,
    this.onChanged,
  });

  @override
  State<AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<AnimatedFormField> {
  bool _obscure = true;
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
    widget.controller.addListener(_validate);
  }

  void _validate() {
    if (widget.validator == null) return;

    // Only validate if the field has been interacted with (not empty)
    if (widget.controller.text.isNotEmpty) {
      final res = widget.validator!(widget.controller.text);
      setState(() {
        _isValid = res == null; // Valid if no error message
      });
    } else {
      // Reset validation state when field is empty
      setState(() {
        _isValid = null;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.inputDecorationTheme.hintStyle?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );
    Widget? suffix;
    if (widget.isPassword) {
      suffix = IconButton(
        icon: Icon(
          _obscure ? Icons.visibility : Icons.visibility_off,
          size: 20,
        ),
        color: theme.iconTheme.color,
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    } else if (widget.isValid != null) {
      suffix = Icon(
        widget.isValid! ? Icons.check_circle : Icons.cancel,
        color: widget.isValid! ? Colors.green : Colors.red,
        size: 20,
      );
    } else if (_isValid != null) {
      suffix = Icon(
        _isValid! ? Icons.check_circle : Icons.cancel,
        color: _isValid! ? Colors.green : Colors.red,
        size: 20,
      );
    }

    return TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscure : false,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          style: theme.textTheme.bodyLarge,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: hintStyle,
            filled: theme.inputDecorationTheme.filled,
            fillColor: theme.inputDecorationTheme.fillColor,
            contentPadding: theme.inputDecorationTheme.contentPadding,
            border: theme.inputDecorationTheme.border,
            enabledBorder: theme.inputDecorationTheme.enabledBorder,
            focusedBorder: theme.inputDecorationTheme.focusedBorder,
            suffixIcon: suffix,
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (widget.index * 100).ms)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOut,
        );
  }
}
