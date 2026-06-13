import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bg = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF5F5F5);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? cs.outlineVariant : const Color(0xFFEFEFF0)),
      ),
      child: IconButton(
        icon: Icon(Icons.keyboard_arrow_left, color: cs.onSurface),
        onPressed: onPressed ?? () => Navigator.pop(context),
      ),
    );
  }
}
