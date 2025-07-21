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
    final gold = theme.colorScheme.primary;
    final hintStyle = theme.inputDecorationTheme.hintStyle?.copyWith(
      color: gold.withOpacity(0.7),
    );
    Widget? suffix;
    if (widget.isPassword) {
      suffix = IconButton(
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 20),
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
      style: theme.textTheme.bodyLarge,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: hintStyle,
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withOpacity(0.5), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withOpacity(0.3), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold, width: 2),
        ),
        suffixIcon: suffix,
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (widget.index * 100).ms).slideY(begin: 0.1, end: 0, duration: 400.ms, delay: (widget.index * 100).ms, curve: Curves.easeOut);
  }
} 