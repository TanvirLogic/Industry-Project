import 'package:flutter/material.dart';

class SocialLinksFormBlockUi extends StatelessWidget {
  final List<TextEditingController> platformControllers;
  final List<TextEditingController> urlControllers;
  final List<String> socialPlatforms;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const SocialLinksFormBlockUi({
    super.key,
    required this.platformControllers,
    required this.urlControllers,
    required this.socialPlatforms,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    assert(
      platformControllers.length == urlControllers.length,
      'platformControllers and urlControllers must have the same length',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Social links",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "To Delete Social link Swipe right or left",
          style: TextStyle(
            color: cs.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(platformControllers.length, (index) {
          return Padding(
            key: ValueKey('social_link_padding_$index'),
            padding: const EdgeInsets.only(bottom: 12),
            child: _SocialLinkFormRow(
              key: ObjectKey(platformControllers[index]),
              platformController: platformControllers[index],
              urlController: urlControllers[index],
              socialPlatforms: socialPlatforms,
              onRemove: () => onRemove(index),
            ),
          );
        }),
        UnconstrainedBox(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Add a Social link",
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.add, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialLinkFormRow extends StatefulWidget {
  final TextEditingController platformController;
  final TextEditingController urlController;
  final List<String> socialPlatforms;
  final VoidCallback onRemove;

  const _SocialLinkFormRow({
    super.key,
    required this.platformController,
    required this.urlController,
    required this.socialPlatforms,
    required this.onRemove,
  });

  @override
  State<_SocialLinkFormRow> createState() => _SocialLinkFormRowState();
}

class _SocialLinkFormRowState extends State<_SocialLinkFormRow> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: widget.key ?? const ValueKey('dismissible_row'),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.delete_outline, color: cs.error, size: 28),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Delete Social Link",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            content: Text(
              "Are you sure you want to delete this social link?",
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text("Cancel", style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text("Delete", style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => widget.onRemove(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 45,
              child: TextFormField(
                controller: widget.urlController,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: "Paste your Profile Link",
                  hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 45,
              child: DropdownButtonFormField<String>(
                initialValue: widget.socialPlatforms.contains(
                  widget.platformController.text.trim(),
                )
                    ? widget.platformController.text.trim()
                    : null,
                isExpanded: true,
                hint: Text(
                  "Platform",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                items: widget.socialPlatforms.map((platform) {
                  return DropdownMenuItem<String>(
                    value: platform,
                    child: Text(
                      platform,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) widget.platformController.text = value;
                },
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
