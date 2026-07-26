import 'package:flutter/material.dart';

class OptionalNoteField extends StatelessWidget {
  const OptionalNoteField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  static const _placeholder =
      'Example: normal reading, meter room locked, abnormal value...';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 2,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
        hintText: _placeholder,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
