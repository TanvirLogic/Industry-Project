import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';

class ManageModuleDescription extends StatefulWidget {
  final String title;
  final String text;

  const ManageModuleDescription({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  State<ManageModuleDescription> createState() => _ManageModuleDescriptionState();
}

class _ManageModuleDescriptionState extends State<ManageModuleDescription> {
  bool _expanded = false;
  bool _isOverflowing = false;
  double? _lastWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          widget.text.isNotEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    if (_lastWidth != constraints.maxWidth) {
                      _lastWidth = constraints.maxWidth;
                      final tp = TextPainter(
                        text: TextSpan(
                          text: widget.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                        maxLines: 4,
                        textDirection: TextDirection.ltr,
                      );
                      tp.layout(maxWidth: constraints.maxWidth);
                      if (tp.didExceedMaxLines != _isOverflowing) {
                        _isOverflowing = tp.didExceedMaxLines;
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.text,
                          maxLines: _expanded ? null : 4,
                          overflow: _expanded ? null : TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                        if (_isOverflowing)
                          GestureDetector(
                            onTap: () => setState(() => _expanded = !_expanded),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _expanded ? 'Show Less' : 'See More',
                                style: const TextStyle(
                                  color: AppColors.themeColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : RichText(
                  text: TextSpan(
                    text: "No ${widget.title} provided",
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.4),
                      height: 1.4,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
