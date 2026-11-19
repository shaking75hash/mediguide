import 'package:flutter/material.dart';

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.fieldName = 'password',
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String fieldName;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _obscureText,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    decoration: widget.decoration.copyWith(
      suffixIcon: IconButton(
        tooltip: '${_obscureText ? 'Show' : 'Hide'} ${widget.fieldName}',
        onPressed: () => setState(() => _obscureText = !_obscureText),
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
