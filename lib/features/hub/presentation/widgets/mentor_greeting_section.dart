import 'package:flutter/material.dart';

class GreetingSection extends StatelessWidget {
  final String? name;

  const GreetingSection({super.key, this.name});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name ?? 'User',
          style: TextStyle(
            fontSize: 20,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
