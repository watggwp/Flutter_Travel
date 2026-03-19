import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A StatefulWidget wrapper that provides password toggle — used by [CustomTextField].
class _PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType keyboardType;

  const _PasswordField({
    required this.hint,
    required this.prefixIcon,
    this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return _buildField(
      context,
      hint: widget.hint,
      prefixIcon: widget.prefixIcon,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF8B8FA8),
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

Widget _buildField(
  BuildContext context, {
  required String hint,
  required IconData prefixIcon,
  TextEditingController? controller,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  Widget? suffixIcon,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A2E),
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF6C63FF), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFEEF0FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD4D8FF), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );
}

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF1A1A2E),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        if (isPassword)
          _PasswordField(
            hint: hint,
            prefixIcon: prefixIcon,
            controller: controller,
            keyboardType: keyboardType,
          )
        else
          _buildField(
            context,
            hint: hint,
            prefixIcon: prefixIcon,
            controller: controller,
            keyboardType: keyboardType,
          ),
      ],
    );
  }
}
